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

CLOCK_FREQ = 4
BAUD_RATE = 1
BAUD_PERIOD = CLOCK_FREQ // BAUD_RATE

@cocotb.test()
async def test_a(dut):
    """cocotb test for seven segment controller"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10**9 * (1 / CLOCK_FREQ), units="ns").start())
    dut._log.info("Holding reset...")

    # Testing reset conditions
    dut.rst_in.value = 1
    dut.rx_wire_in.value = 0
    await ClockCycles(dut.clk_in, 50)  # wait three clock cycles
    assert dut.new_data_out.value == 0  # idle conditions check
    dut.rst_in.value = 1
    dut.rx_wire_in.value = 1
    await ClockCycles(dut.clk_in, 50)  # wait three clock cycles
    assert dut.new_data_out.value == 0  # idle conditions check

    # Testing normal operation
    dut.rst_in.value = 0
    for i in range(50):
        await ClockCycles(dut.clk_in, 1)
        # idle conditions with no trigger check
        assert dut.new_data_out.value == 0

    # temporary start bit not lasting for long enough
    dut.rx_wire_in.value = 0
    for i in range(BAUD_PERIOD // 2 - 2):
        await ClockCycles(dut.clk_in, 1)
        # idle conditions with no trigger check
        assert dut.new_data_out.value == 0

    dut.rx_wire_in.value = 1
    for i in range(500):
        await ClockCycles(dut.clk_in, 1)
        assert dut.new_data_out.value == 0

    # TESTS = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0b0111_1111]
    TESTS = [0b1100_0110]
    async def send_byte(TEST_BYTE, bad_end=False):
        # Passing in a value
        dut.rst_in.value = 0
        # full clean transmission of a byte
        cycles_per_bit = CLOCK_FREQ // BAUD_RATE
        total_cycles = cycles_per_bit * 10  # start end bits and 8 data bits
        print("TOTAL CYCLES: ", total_cycles)

        data_caught = False
        for i in range(total_cycles + 1):
            await ClockCycles(dut.clk_in, 1)
            if i < total_cycles:
                I = i // cycles_per_bit
                if I == 0:
                    expected_value = 0
                elif I == 9:
                    expected_value = int(bad_end == False)
                else:
                    expected_value = (TEST_BYTE >> (I - 1)) & 1

                dut.rx_wire_in.value = expected_value
            # await ReadOnly()
            if dut.new_data_out.value == 1:
                print(dut.data_byte_out.value, TEST_BYTE)
                assert dut.data_byte_out.value == TEST_BYTE
                data_caught = True

        # assert data_caught == (True if not bad_end else False), "Data not caught"
        await ClockCycles(dut.clk_in, 20)

    for i in range(len(TESTS)):
        TEST_BYTE = TESTS[i]

        await send_byte(TEST_BYTE)
        await send_byte(TEST_BYTE, True)

def uart_receive_runner():
	"""Simulate the counter using the Python runner."""
	hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
	sim = os.getenv("SIM", "icarus")
	proj_path = Path(__file__).resolve().parent.parent
	sys.path.append(str(proj_path / "sim" / "model"))
	sources = [proj_path / "hdl" / "uart_receive.sv"]
	build_test_args = ["-Wall"]
	parameters = {
		"INPUT_CLOCK_FREQ": CLOCK_FREQ,
		"BAUD_RATE": BAUD_RATE,
	}  #!!!change these to do different versions
	sys.path.append(str(proj_path / "sim"))
	runner = get_runner(sim)
	runner.build(
		sources=sources,
		hdl_toplevel="uart_receive",
		always=True,
		build_args=build_test_args,
		parameters=parameters,
		timescale=("1ns", "1ps"),
		waves=True,
	)
	run_test_args = []
	runner.test(
		hdl_toplevel="uart_receive",
		test_module="test_uart_receive",
		test_args=run_test_args,
		waves=True,
	)


if __name__ == "__main__":
	uart_receive_runner()
