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
from random import getrandbits
import re


async def reset(rst, clk):
	"""Helper function to issue a reset signal to our module"""
	rst.value = 1
	await ClockCycles(clk, 3)
	rst.value = 0
	await ClockCycles(clk, 2)


async def drive_data(dut, data_byte, control_bits, ve_bit):
	"""submit a set of data values as input, then wait a clock cycle for them to stay there."""
	dut.data_in.value = data_byte
	dut.control_in.value = control_bits
	dut.ve_in.value = ve_bit
	await ClockCycles(dut.clk_in, 1)


def decode_data(log_data):
	# Regular expressions to match the inputs and outputs
	input_pattern = r"(\d+ns)\s+Setting inputs (.+)"
	output_pattern = r"(\d+ns)\s+Module output (0x[0-9A-Fa-f]+) = (0b[01]+)\s+Running tally on output wire:\s+(-?\d+)"

	inputs = re.findall(input_pattern, log_data)
	outputs = re.findall(output_pattern, log_data)

	result = []

	# Combine the inputs and outputs into pairs
	for inp, out in zip(inputs, outputs):
		input_time, input_data = inp
		output_time, output_hex, output_bin, tally = out
		result.append(
			{
				"time": input_time,
				"inputs": eval(input_data),  # Convert string to dictionary
				"output": {"hex": output_hex, "bin": output_bin, "tally": int(tally)},
			}
		)

	return result


@cocotb.test()
async def test_tmds(dut):
	"""Your simulation test!
	TODO: Flesh this out with value sets and print statements. Maybe even some assertions, as a treat.
	"""
	cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
	# set all inputs to 0
	dut.data_in.value = 0
	dut.control_in.value = 0
	dut.ve_in.value = 0
	# use helper function to assert reset signal
	await reset(dut.rst_in, dut.clk_in)

	data = []
	with open("./../test_text", "r") as file:
		data = decode_data(file.read())

	for i, row in enumerate(data):
		inps = row["inputs"]
		await drive_data(
			dut, int(inps["data"], 16), int(inps["control"], 16), int(inps["ve"], 16)
		)

		# check the outputs
		tmds_out = int(row["output"]["hex"], 16)
		tally = row["output"]["tally"]
		dut.tmds_out_dummy.value = tmds_out
		dut.cnt_dummy.value = tally
		actual_tally = int(dut.cnt.value)
		actual_tmds_out = int(dut.tmds_out.value)
		# if i > 5:
		# 	assert tmds_out == actual_tmds_out and tally == actual_tally, f"Output mismatch with expected value {tmds_out} and {tally}, got {actual_tmds_out} and {actual_tally}"

	# # example usage of the helper function to set all the input values you want to set
	# # you probably want to make lots more of these.
	# await drive_data(dut, 0x44, 0b00, 1)
	# # a clock cycle has now passed: see the helper function. read your outputs here!

	# await drive_data(dut, 0x55, 0b00, 1)

	# await drive_data(dut, 0x00, 0b01, 0)

	# await drive_data(dut, 0x00, 0b11, 0)


def test_tmds_runner():
	"""Run the TMDS runner. Boilerplate code"""
	hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
	sim = os.getenv("SIM", "icarus")
	proj_path = Path(__file__).resolve().parent.parent
	sys.path.append(str(proj_path / "sim" / "model"))
	sources = [
		proj_path / "hdl" / "tmds_encoder.sv",
		proj_path / "hdl" / "tm_choice.sv",
	]
	build_test_args = ["-Wall"]
	parameters = {}
	sys.path.append(str(proj_path / "sim"))
	runner = get_runner(sim)
	runner.build(
		sources=sources,
		hdl_toplevel="tmds_encoder",
		always=True,
		build_args=build_test_args,
		parameters=parameters,
		timescale=("1ns", "1ps"),
		waves=True,
	)
	run_test_args = []
	runner.test(
		hdl_toplevel="tmds_encoder",
		test_module="test_tmds_encoder",
		test_args=run_test_args,
		waves=True,
	)


if __name__ == "__main__":
	test_tmds_runner()
