import cocotb
import os
import random
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import (
	Timer,
	ClockCycles,
	RisingEdge,
	FallingEdge,
	ReadOnly,
	with_timeout,
)
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner


# utility function to reverse bits:
def reverse_bits(n, size):
	reversed_n = 0
	for i in range(size):
		reversed_n = (reversed_n << 1) | (n & 1)
		n >>= 1
	return reversed_n


# test spi message:
SPI_RESP_MSG = 0x2345
# flip them:
SPI_RESP_MSG = reverse_bits(SPI_RESP_MSG, 16)

CLOCK_FREQ = 100_000_000
BAUD_RATE = 1000_000


@cocotb.test()
async def test_a(dut):
	"""cocotb test for seven segment controller"""
	dut._log.info("Starting...")
	cocotb.start_soon(Clock(dut.clk_in, 10 ** 9 * (1 / CLOCK_FREQ), units="ns").start())
	dut._log.info("Holding reset...")

	# Testing reset conditions
	dut.rst_in.value = 1
	dut.trigger_in.value = 0
	await ClockCycles(dut.clk_in, 50)  # wait three clock cycles
	assert (
		dut.busy_out.value == 0 and dut.tx_wire_out.value == 1
	)  # idle conditions check
	dut.rst_in.value = 1
	dut.trigger_in.value = 1
	await ClockCycles(dut.clk_in, 50)  # wait three clock cycles
	assert (
		dut.busy_out.value == 0 and dut.tx_wire_out.value == 1
	)  # idle conditions check

	# Testing normal operation
	dut.rst_in.value = 0
	dut.trigger_in.value = 0
	await ClockCycles(dut.clk_in, 50)
	# idle conditions with no trigger check

	assert dut.busy_out.value == 0 and dut.tx_wire_out.value == 1

	TEST_BYTE = 0x67
	for i in range(10):
		# Passing in a value
		dut.rst_in.value = 0
		dut.trigger_in.value = 1
		dut.data_byte_in.value = TEST_BYTE

		await ClockCycles(dut.clk_in, 1)
		await ReadOnly()
		assert dut.busy_out.value == 1, "Busy signal not high"

		cycles_per_bit = CLOCK_FREQ // BAUD_RATE
		total_cycles = cycles_per_bit * 10  # start end bits and 8 data bits
		print("TOTAL CYCLES: ", total_cycles)

		for i in range(total_cycles):
			await ClockCycles(dut.clk_in, 1)
			current_value = dut.tx_wire_out.value
			I = i // cycles_per_bit
			if I == 0:
				expected_value = 0
			elif I == 9:
				expected_value = 1
			else:
				expected_value = (TEST_BYTE >> (I - 1)) & 1

			assert (
				current_value == expected_value
			), f"Expected {expected_value} but got {current_value} at cycle {i}. for the value {TEST_BYTE:>08b} and I = {I}"
			assert dut.busy_out.value == 1, "Busy signal not high"

		# idle conditions with no trigger check
		# await ClockCycles(dut.clk_in, 50)
		assert  dut.tx_wire_out.value == 1

def uart_transmit_runner():
	"""Simulate the counter using the Python runner."""
	hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
	sim = os.getenv("SIM", "icarus")
	proj_path = Path(__file__).resolve().parent.parent
	sys.path.append(str(proj_path / "sim" / "model"))
	sources = [proj_path / "hdl" / "uart_transmit.sv"]
	build_test_args = ["-Wall"]
	parameters = {
		"INPUT_CLOCK_FREQ": CLOCK_FREQ,
		"BAUD_RATE": BAUD_RATE,
	}  #!!!change these to do different versions
	sys.path.append(str(proj_path / "sim"))
	runner = get_runner(sim)
	runner.build(
		sources=sources,
		hdl_toplevel="uart_transmit",
		always=True,
		build_args=build_test_args,
		parameters=parameters,
		timescale=("1ns", "1ps"),
		waves=True,
	)
	run_test_args = []
	runner.test(
		hdl_toplevel="uart_transmit",
		test_module="test_uart_transmit",
		test_args=run_test_args,
		waves=True,
	)


if __name__ == "__main__":
	uart_transmit_runner()
