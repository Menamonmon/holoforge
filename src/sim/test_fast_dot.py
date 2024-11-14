import os
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import ReadOnly, ClockCycles
from cocotb.binary import BinaryValue

import random
import math

# A_size, B_size = random.randint(18, 18), random.randint(11, 11)
# A_frac, B_frac = random.randint(0, A_size - 1), random.randint(0, B_size - 1)
# P_frac = (A_frac + B_frac) // 2
# n = 3
# parameters = {
#     "A_WIDTH": A_size,
#     "B_WIDTH": B_size,
#     "A_FRAC_BITS": A_frac,
#     "B_FRAC_BITS": B_frac,
#     "P_FRAC_BITS": P_frac,
#     "N": n,
# }


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


def generate_twos_complement_random(A_size):
	# Generate a random integer within the range for two's complement with A_size bits
	min_val = -(1 << (A_size - 1))
	max_val = (1 << (A_size - 1)) - 1
	return random.randint(min_val, max_val)


@cocotb.test()
async def test_fixed_point_slow_dot(dut):
	cocotb.start_soon(
		Clock(dut.clk_in, 2, units="ns").start()
	)  # Slower clock for clk_in

	await ClockCycles(dut.clk_in, 2)
	# await ReadOnly()
	# reset test
	dut.rst_in.value = 1
	await ClockCycles(dut.clk_in, 2)

	# assert dut.P.value == 0
	# assert dut.i.value == 0
	# assert dut.valid_out.value == 0

	dut.rst_in.value = 0

	await ClockCycles(dut.clk_in, 2)

	# make a list of tests with variable size
	test_count = 100
	A_size = dut.A_WIDTH.value
	B_size = dut.B_WIDTH.value
	A_frac_bits = dut.A_FRAC_BITS.value
	B_frac_bits = dut.B_FRAC_BITS.value
	P_frac_bits = dut.P_FRAC_BITS.value
	P_extra_frac_bits = A_frac_bits + B_frac_bits - P_frac_bits
	D_Width=A_size+B_size-P_extra_frac_bits+2
	# assert P_extra_frac_bits >= 0, f"P_extra_frac_bits: {P_extra_frac_bits} < 0"

	for t in range(test_count):
		# all the ranges that are made by two complement

		A_vec = [generate_twos_complement_random(A_size) for i in range(3)]
		B_vec = [generate_twos_complement_random(B_size) for i in range(3)]
		# max and min numbers
		# 1
		# 1 + 4 = 5
		# 5 + 9 = 14

		# go through all the possible combinations of values for A_vec and B_vec

		# combine the vectors into a single value

		# print A and B as hex numbers (both A_vec and A and B)

		dut.A.value = BinaryValue(
			pack_values(A_vec, A_size), n_bits=A_size * 3, bigEndian=False
		)
		dut.B.value = BinaryValue(
			pack_values(B_vec, B_size), n_bits=B_size * 3, bigEndian=False
		)
		# dut.valid_in.value = 1
		# dut.valid_in.value = 0
		P_size = A_size + B_size + math.ceil(math.log2(3))
		P = 0
		for i in range(3):
			P += (A_vec[i] * B_vec[i])
			# assert (
			# 	dut.ACC_WIDTH.value == P_size
			# ), f"ACC_WIDTH: {dut.ACC_WIDTH.value} != {P_size}"
			# assert math.ceil(math.log2(P)) <= dut.ACC_WIDTH.value, f"Overflow detected: {P} > {dut.FULL_WIDTH.value}"
			# assert (
			# 	P == dut.P.value.signed_integer
			# ), f"i: {i}, A: {A_vec[i]}, B: {B_vec[i]}, P: {P} != {dut.accumulator.value.signed_integer}"

		await ClockCycles(dut.clk_in, 4)
		# assert dut.valid_out.value == 1
		out = dut.D.value.signed_integer
		print(BinaryValue(get_twos_complement(P,D_Width)))
		print(BinaryValue(get_twos_complement(out,D_Width)))
		assert out == P>>P_extra_frac_bits

def gen_params():
	# iterator that yields all the possible parameter values
	A_size_range = range(3, 18)
	B_size_range = range(3, 25)
	A_frac_range = 0  # to A_size - 1
	B_frac_range = 0  # to B_size - 1
	P_frac_range = 0  # to A_frac + B_frac
	n = range(3, 10)
	A_size_range = range(18, 19)
	B_size_range = range(25, 26)
	A_frac_range = 0  # to A_size - 1
	B_frac_range = 0  # to B_size - 1
	P_frac_range = 0  # to A_frac + B_frac
	n = range(3, 4)

	for A_size in A_size_range:
		for B_size in B_size_range:
			for A_frac in range(A_size):
				for B_frac in range(B_size):
					for P_frac in range(A_frac + B_frac):
							yield {
								"A_WIDTH": A_size,
								"B_WIDTH": B_size,
								"A_FRAC_BITS": A_frac,
								"B_FRAC_BITS": B_frac,
								"P_FRAC_BITS": P_frac,
							}


def main():
	"""Simulate the counter using the Python runner."""
	sim = os.getenv("SIM", "icarus")
	proj_path = Path(__file__).resolve().parent.parent
	sys.path.append(str(proj_path / "sim" / "model"))
	sources = [proj_path / "hdl" / "common" / "fixed_point_fast_dot.sv",proj_path / "hdl" / "common" / "fixed_point_mult.sv"]
	build_test_args = ["-Wall"]
	sys.path.append(str(proj_path / "sim"))
	runner = get_runner(sim)
	for params in gen_params():
		print("RUNNING TEST FOR PARAMS", params)
		# parameters.update(params)
		runner.build(
			sources=sources,
			hdl_toplevel="fixed_point_fast_dot",
			always=True,
			build_args=build_test_args,
			parameters=params,
			timescale=("1ns", "1ps"),
			waves=True,
		)
		run_test_args = []
		runner.test(
			hdl_toplevel="fixed_point_fast_dot",
			test_module="test_fast_dot",
			test_args=run_test_args,
			waves=True,
		)


if __name__ == "__main__":
	main()