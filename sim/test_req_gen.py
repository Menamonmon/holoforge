import cocotb
from cocotb.triggers import Timer
import os
from pathlib import Path
import sys

from cocotb.clock import Clock
from cocotb.triggers import (
	Timer,
	ClockCycles,
	RisingEdge,
	FallingEdge,
	ReadOnly,
	ReadWrite,
	with_timeout,
	First,
	Join,
)
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner
from cocotb.binary import BinaryValue

from random import getrandbits
import random

HRES = 64
VRES = 32


def print_twos_complement(num, bit_size):
	# Mask the number to fit within the specified bit_size
	raw_binary = get_twos_complement(num, bit_size)
	print(f"{num} = {raw_binary}")


def get_twos_complement(num, bit_size):
	raw_binary = format(num & ((1 << bit_size) - 1), f"0{bit_size}b")
	return raw_binary


def pack_values(values, size):
	# pack the values in a string of bits
	return "".join([get_twos_complement(v, size) for v in reversed(values)])


async def reset(rst, clk):
	"""Helper function to issue a reset signal to our module"""
	rst.value = 1
	await RisingEdge(clk)
	rst.value = 0
	await RisingEdge(clk)


@cocotb.test()
async def test_pattern(dut):
	"""Your simulation test!
	TODO: Flesh this out with value sets and print statements. Maybe even some assertions, as a treat.
	"""
	cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
	# dut.hcount.value = 0
	# dut.vcount.value = 0
	dut.addr.value = 0
	dut.data_in.value = 0
	dut.strobe_in.value = 0
	dut.ready_in.value = 0
	dut.valid_in.value = 0
	await reset(dut.rst_in, dut.clk_in)
	# (hcount,vcount,valid_in,rdy_in,mask_zero,)
	grid = []
	valid_grid = []
	SUBGRIDW = 11
	SUBGRIDH = 23
	for vcount in range(VRES):  # vcount from 0 to VRES - 1
		row = []
		valid_row = []
		for hcount in range(HRES):  # hcount from 0 to HRES - 1
			valid_row.append(random.randint(0, 1))
			row.append(random.randint(0, 0xFFFF))
		grid.append(row)
		valid_grid.append(valid_row)

	out_req = []
	x = 1
	for vcount in range(VRES):
		for hcount in range(HRES):
			dut.valid_in.value = valid_grid[vcount][hcount]
			# dut.ready_in.value=random.randint(0,1)
			strobe_in = random.randint(0, 1)
			dut.strobe_in.value = strobe_in
			dut.data_in.value = grid[vcount][hcount]
			if strobe_in == 0 or valid_grid[vcount][hcount] == 0:
				grid[vcount][hcount] = None
			# dut.hcount.value = hcount
			# dut.vcount.value = vcount
			dut.addr.value = hcount + (vcount * HRES)

			dut.ready_in.value = 0
			x = random.randint(1, 10)
			for _ in range(x):
				await RisingEdge(dut.clk_in)
				if dut.valid_out.value == 1 and dut.ready_in.value == 1:
					out_req.append(
						[dut.data_out.value, dut.strobe_out.value, dut.addr_out.value]
					)
			dut.ready_in.value = 1
			while dut.ready_out.value == 0:
				await RisingEdge(dut.clk_in)
				if dut.valid_out.value == 1 and dut.ready_in.value == 1:
					out_req.append(
						[dut.data_out.value, dut.strobe_out.value, dut.addr_out.value]
					)

			await RisingEdge(dut.clk_in)
			if dut.valid_out.value == 1 and dut.ready_in.value == 1:
				out_req.append(
					[dut.data_out.value, dut.strobe_out.value, dut.addr_out.value]
				)
	for _ in range(random.randint(0, 200)):
		dut.valid_in.value = 0
		# dut.hcount.value = random.randint(0, 63)
		# dut.vcount.value = random.randint(0, 31)
		dut.addr.value = random.randint(0, 2047)
		await RisingEdge(dut.clk_in)
		if dut.valid_out.value == 1 and dut.ready_in.value == 1:
			out_req.append(
				[dut.data_out.value, dut.strobe_out.value, dut.addr_out.value]
			)
	ans_grid = [[None for _ in range(HRES)] for __ in range(VRES)]
	for ans in out_req:
		raw_addr = ans[2] << 3
		data = ans[0]
		strobe = ans[1]
		for i in range(8):
			cur_addr = raw_addr + i
			# print(cur_addr//HRES,"addr")
			# print(cur_addr)
			# print(len(grid),"grid")
			# print(len(grid[0]),"grid again")
			flip = 8 - i - 1
			strb = strobe.binstr[2 * flip : 2 * flip + 2]
			assert strb in ("00", "11")
			if strb == "11":
				ans_grid[cur_addr // HRES][cur_addr % HRES] = int(
					data.binstr[flip * 16 : (flip + 1) * 16], 2
				)
	for vcount in range(VRES):
		for hcount in range(HRES):
			print(hcount, vcount, valid_grid[vcount][hcount], "coords")
			print(ans_grid[vcount][hcount], "answer")
			print(grid[vcount][hcount], "out grid")
			assert ans_grid[vcount][hcount] == grid[vcount][hcount]

	# one flaw in this test bench is i need the extra cycle but the valid ins will save me here
	# await better_test(dut)
	# await basic_stacking_test(dut,basic_hcount,basic_vcount,basic_data,basic_rdy_list,mask_list)


def test_TEST_NAME():  # chang ethis
	"""Boilerplate code"""
	sim = os.getenv("SIM", "icarus")
	proj_path = Path(__file__).resolve().parent.parent
	sys.path.append(str(proj_path / "sim" / "model"))
	sources = [
		proj_path / "src" / "hdl" / "graphics" / "framebuffer" / "pixel_stacker.sv"
	]  # change this
	build_test_args = ["-Wall"]
	parameters = {
		"HRES": HRES,
		"VRES": VRES,
	}
	sys.path.append(str(proj_path / "sim"))
	runner = get_runner(sim)
	runner.build(
		sources=sources,
		hdl_toplevel="pixel_stacker",  # change this
		always=True,
		build_args=build_test_args,
		parameters=parameters,
		timescale=("1ns", "1ps"),
		waves=True,
	)
	run_test_args = []
	runner.test(
		hdl_toplevel="pixel_stacker",  # change this
		test_module="test_req_gen",  # change this
		test_args=run_test_args,
		waves=True,
	)


if __name__ == "__main__":
	test_TEST_NAME()  # CHANGE THIS
