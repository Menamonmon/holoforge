import os
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import (
	ReadOnly,
)


def get_expected(data_in):
    if not (0 <= data_in <= 255):
        raise ValueError("Input must be an integer between 0 and 255.")

    # Extract the LSB and calculate the sum of 1's in the byte
    lsb = data_in & 1
    sum_ones = bin(data_in).count("1")

    # Initialize the output as the LSB
    output_value = lsb

    # Determine which option to use
    if sum_ones > 4 or (sum_ones == 4 and lsb == 0):
        # Option Two: XNOR operation
        for i in range(1, 8):
            bit1 = (data_in >> i) & 1
            bit2 = (data_in >> (7 - i)) & 1
            output_value = (output_value << 1) | int(not (bit1 ^ bit2))  # XNOR
        output_value = (output_value << 1) | 0  # Append 0 for option two
    else:
        # Option One: XOR operation
        for i in range(1, 8):
            bit1 = (data_in >> i) & 1
            bit2 = (data_in >> (7 - i)) & 1
            output_value = (output_value << 1) | (bit1 ^ bit2)  # XOR
        output_value = (output_value << 1) | 1  # Append 1 for option one

    return output_value


@cocotb.test()
async def test_tm_choice(dut):
	# cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())

	# values = [i for i in range(2**8 - 1)]
	values = [0b1111_1110]
	for val in values:
		expected = get_expected(val)
		dut.data_in.value = val
		await ReadOnly()
		received = int(dut.qm_out.value)
		print(f"data_in: {val:08b}, qm_out: {received:09b}")
		# assert (
		# 	received == expected
		# ), f"data_in: {val:08b}, qm_out: {received:09b}, qm_out (expected): {expected:09b} "


def main():
	"""Simulate the counter using the Python runner."""
	sim = os.getenv("SIM", "icarus")
	proj_path = Path(__file__).resolve().parent.parent
	sys.path.append(str(proj_path / "sim" / "model"))
	sources = [proj_path / "hdl" / "tm_choice.sv"]
	build_test_args = ["-Wall"]
	parameters = {}
	sys.path.append(str(proj_path / "sim"))
	runner = get_runner(sim)
	runner.build(
		sources=sources,
		hdl_toplevel="tm_choice",
		always=True,
		build_args=build_test_args,
		parameters=parameters,
		timescale=("1ns", "1ps"),
		waves=True,
	)
	run_test_args = []
	runner.test(
		hdl_toplevel="tm_choice",
		test_module="test_tm_choice",
		test_args=run_test_args,
		waves=True,
	)


if __name__ == "__main__":
	main()
