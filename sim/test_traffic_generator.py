# test_traffic_generator.py

import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random
import os
import sys
from pathlib import Path
import random

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import (
	ReadOnly, ClockCycles
)


async def reset_dut(dut, cycles=5):
	"""Reset the DUT."""
	dut.rst_in.value = 1
	await ClockCycles(dut.clk_in, cycles)
	dut.rst_in.value = 0
	await RisingEdge(dut.clk_in)


@cocotb.test()
async def test_traffic_generator(dut):
	"""Test basic read/write operations of the traffic generator."""

	# Generate clock
	clock = Clock(dut.clk_in, 10, units="ns")  # 100 MHz clock
	cocotb.start_soon(clock.start())

	# Reset the DUT
	await reset_dut(dut)

	# Assert reset behavior
	assert dut.app_en.value == 0, "App enable should be 0 after reset."
	assert dut.app_cmd.value == 0, "App command should be 0 after reset."

	# Simulate calibration completion
	dut.init_calib_complete.value = 1
	# await RisingEdge(dut.clk_in)
	await ClockCycles(dut.clk_in, 1)

	# Test write behavior: Simulate some data on the write axis
	for i in range(5):
		dut.write_axis_data.value = random.randint(0, 2**128 - 1)
		dut.write_axis_valid.value = 1
		dut.write_axis_tlast.value = 0 if i < 4 else 1  # Set TLAST at the end
		await ClockCycles(dut.clk_in, 1)
		while not dut.write_axis_ready.value:
			await ClockCycles(dut.clk_in, 1)

	# Assert app_wdf_data matches write data
	for i in range(5):
		await ClockCycles(dut.clk_in, 1)
		assert (
			dut.app_wdf_data.value == dut.write_axis_data.value
		), "Data mismatch in write operation."

	# Test read behavior
	for i in range(3):
		dut.app_rd_data.value = random.randint(0, 2**128 - 1)
		dut.app_rd_data_valid.value = 1
		await ClockCycles(dut.clk_in, 1)
		if dut.read_axis_valid.value:
			print(f"Read axis data: {hex(dut.read_axis_data.value)}")
		assert (
			dut.read_axis_data.value == dut.app_rd_data.value
		), "Data mismatch in read operation."

	# Assert that read_axis_valid is high when app_rd_data_valid is asserted
	if dut.app_rd_data_valid.value:
		assert (
			dut.read_axis_valid.value == 1
		), "read_axis_valid should be high when app_rd_data_valid is high."

	# Finish simulation
	dut._log.info("Test completed successfully.")


def main():
	"""Simulate the counter using the Python runner."""
	sim = os.getenv("SIM", "icarus")
	proj_path = Path(__file__).resolve().parent.parent
	sys.path.append(str(proj_path / "sim" / "model"))
	sources = [
		proj_path / "hdl" / "traffic_generator.sv",
		proj_path / "hdl" / "divider.sv",
		proj_path / "hdl" / "evt_counter.sv",
	]
	build_test_args = ["-Wall"]
	parameters = {}
	sys.path.append(str(proj_path / "sim"))
	runner = get_runner(sim)
	runner.build(
		sources=sources,
		hdl_toplevel="traffic_generator",
		always=True,
		build_args=build_test_args,
		parameters=parameters,
		timescale=("1ns", "1ps"),
		waves=True,
	)
	run_test_args = []
	runner.test(
		hdl_toplevel="traffic_generator",
		test_module="test_traffic_generator",
		test_args=run_test_args,
		waves=True,
	)


if __name__ == "__main__":
	main()
