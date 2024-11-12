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
from FixedPoint import FXnum, FXfamily


## Project F Library - div Test Bench (cocotb)
## (C)2023 Will Green, open source software released under the MIT License
## Learn more at https://projectf.io/verilog-lib/

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from FixedPoint import FXfamily, FXnum

WIDTH = 20 # must match Makefile
FRAC_BITS = 14  # must match Makefile
fp_family = FXfamily(
	n_bits=FRAC_BITS, n_intbits=WIDTH - FRAC_BITS
)  # need +1 because n_intbits includes sign


async def reset_dut(dut):
	await RisingEdge(dut.clk_in)
	dut.rst_in.value = 0
	await RisingEdge(dut.clk_in)
	dut.rst_in.value = 1
	await RisingEdge(dut.clk_in)
	dut.rst_in.value = 0
	await RisingEdge(dut.clk_in)


async def test_dut_divide(dut, a, b, log=True):
	cocotb.start_soon(Clock(dut.clk_in, 1, units="ns").start())
	await reset_dut(dut)

	await RisingEdge(dut.clk_in)
	dut.A.value = BinaryValue(FXnum(a, fp_family).toBinaryString().replace(".", ""))
	dut.B.value = BinaryValue(FXnum(b, fp_family).toBinaryString().replace(".", ""))
	dut.valid_in.value = 1

	await RisingEdge(dut.clk_in)
	dut.valid_in.value = 0

	# wait for calculation to complete
	while not dut.done.value:
		await RisingEdge(dut.clk_in)

	# model quotient: covert twice to ensure division is handled consistently
	#                 https://github.com/rwpenney/spfpm/issues/14
	model_val = fp_family(float(fp_family(a)) / float(fp_family(b)))

	# divide dut result by scaling factor
	val = fp_family(dut.Q.value.signed_integer / 2**FRAC_BITS)

	# log numerical signals
	if log:
		dut._log.info("dut a:     " + dut.A.value.binstr)
		dut._log.info("dut b:     " + dut.B.value.binstr)
		dut._log.info("dut val:   " + dut.Q.value.binstr)
		dut._log.info(
			"           " + val.toDecimalString(precision=fp_family.fraction_bits)
		)
		dut._log.info("model val: " + model_val.toBinaryString())
		dut._log.info(
			"           " + model_val.toDecimalString(precision=fp_family.fraction_bits)
		)

	# check output signals on 'done'
	assert dut.busy.value == 0, "busy is not 0!"
	assert dut.done.value == 1, "done is not 1!"
	assert dut.valid_out.value == 1, "valid is not 1!"
	assert dut.zerodiv.value == 0, "dbz is not 0!"
	assert dut.overflow.value == 0, "ovf is not 0!"
	assert val == model_val, "dut val doesn't match model val"

	# check 'done' is high for one tick
	await RisingEdge(dut.clk_in)
	assert dut.done.value == 0, "done is not 0!"


# simple division tests (no rounding required)
@cocotb.test()
async def simple_1(dut):
	"""Test 6/2"""
	await test_dut_divide(dut=dut, a=6, b=2)


@cocotb.test()
async def simple_2(dut):
	"""Test 15/3"""
	await test_dut_divide(dut=dut, a=15, b=3)


@cocotb.test()
async def simple_3(dut):
	"""Test 13/4"""
	await test_dut_divide(dut=dut, a=13, b=4)


@cocotb.test()
async def simple_4(dut):
	"""Test 3/12"""
	await test_dut_divide(dut=dut, a=3, b=12)


@cocotb.test()
async def simple_5(dut):
	"""Test 7.5/2"""
	await test_dut_divide(dut=dut, a=7.5, b=2)


# sign tests
@cocotb.test()
async def sign_1(dut):
	"""Test 3/2"""
	await test_dut_divide(dut=dut, a=3, b=2)


@cocotb.test()
async def sign_2(dut):
	"""Test -3/2"""
	await test_dut_divide(dut=dut, a=-3, b=2)


@cocotb.test()
async def sign_3(dut):
	"""Test 3/-2"""
	await test_dut_divide(dut=dut, a=3, b=-2)


@cocotb.test()
async def sign_4(dut):
	"""Test -3/-2"""
	await test_dut_divide(dut=dut, a=-3, b=-2)


# rounding tests
@cocotb.test()
async def round_1(dut):
	"""Test 5.0625/2"""
	await test_dut_divide(dut=dut, a=5.0625, b=2)


@cocotb.test()
async def round_2(dut):
	"""Test 7.0625/2"""
	await test_dut_divide(dut=dut, a=7.0625, b=2)


@cocotb.test()
async def round_3(dut):
	"""Test 15.9375/2"""
	await test_dut_divide(dut=dut, a=15.9375, b=2)


@cocotb.test()
async def round_4(dut):
	"""Test 14.9375/2"""
	await test_dut_divide(dut=dut, a=14.9375, b=2)


@cocotb.test()
async def round_5(dut):
	"""Test 13/7"""
	await test_dut_divide(dut=dut, a=13, b=7)


@cocotb.test()
async def round_6(dut):
	"""Test 8.1875/4"""
	await test_dut_divide(dut=dut, a=8.1875, b=4)


@cocotb.test()
async def round_7(dut):
	"""Test 12.3125/8"""
	await test_dut_divide(dut=dut, a=12.3125, b=8)


@cocotb.test()
async def round_8(dut):  # negative
	"""Test -7.0625/2"""
	await test_dut_divide(dut=dut, a=-7.0625, b=2)


@cocotb.test()
async def round_9(dut):  # negative
	"""Test -5.0625/2"""
	await test_dut_divide(dut=dut, a=-5.0625, b=2)


# min edge tests
@cocotb.test()
async def min_1(dut):
	"""Test 0.125/2"""
	await test_dut_divide(dut=dut, a=0.125, b=2)


@cocotb.test()
async def min_2(dut):
	"""Test 0.0625/2"""
	await test_dut_divide(dut=dut, a=0.0625, b=2)


@cocotb.test()
async def min_3(dut):
	"""Test 0/2"""
	await test_dut_divide(dut=dut, a=0, b=2)


@cocotb.test()
async def min_4(dut):  # negative
	"""Test -0.0625/2"""
	await test_dut_divide(dut=dut, a=-0.0625, b=2)


# max edge tests
@cocotb.test()
async def max_1(dut):
	"""Test 15.9375/1"""
	await test_dut_divide(dut=dut, a=15.9375, b=1)


@cocotb.test()
async def max_2(dut):
	"""Test 7.9375/0.5"""
	await test_dut_divide(dut=dut, a=7.9375, b=0.5)


@cocotb.test()
async def max_3(dut):  # negative
	"""Test -15.9375/1"""
	await test_dut_divide(dut=dut, a=-15.9375, b=1)


@cocotb.test()
async def max_4(dut):  # negative
	"""Test -7.9375/0.5"""
	await test_dut_divide(dut=dut, a=-7.9375, b=0.5)


# test non-binary values (can't be precisely represented in binary)
@cocotb.test()
async def nonbin_1(dut):
	"""Test 1/0.2"""
	await test_dut_divide(dut=dut, a=1, b=0.2)


@cocotb.test()
async def nonbin_2(dut):
	"""Test 1.9/0.2"""
	await test_dut_divide(dut=dut, a=1.9, b=0.2)


@cocotb.test()
async def nonbin_3(dut):
	"""Test 0.4/0.2"""
	await test_dut_divide(dut=dut, a=0.4, b=0.2)


# test fails - model and DUT choose different sides of true value
@cocotb.test()
async def nonbin_4(dut):
	"""Test 3.6/0.6"""
	await test_dut_divide(dut=dut, a=3.6, b=0.6)


# test fails - model and DUT choose different sides of true value
@cocotb.test()
async def nonbin_5(dut):
	"""Test 0.4/0.1"""
	await test_dut_divide(dut=dut, a=0.4, b=0.1)


# divide by zero and overflow tests
@cocotb.test()
async def dbz_1(dut):
	"""Test 2/0 [div by zero]"""
	cocotb.start_soon(Clock(dut.clk_in, 1, units="ns").start())
	await reset_dut(dut)

	await RisingEdge(dut.clk_in)
	a = 2
	b = 0
	dut.A.value = int(a * 2**FRAC_BITS)
	dut.B.value = int(b * 2**FRAC_BITS)
	dut.valid_in.value = 1

	await RisingEdge(dut.clk_in)
	dut.valid_in.value = 0

	# wait for calculation to complete
	while not dut.done.value:
		await RisingEdge(dut.clk_in)

	# check output signals on 'done'
	assert dut.busy.value == 0, "busy is not 0!"
	assert dut.done.value == 1, "done is not 1!"
	assert dut.valid_out.value == 0, "valid is not 0!"
	assert dut.zerodiv.value == 1, "dbz is not 1!"
	assert dut.overflow.value == 0, "ovf is not 0!"

	# check 'done' is high for one tick
	await RisingEdge(dut.clk_in)
	assert dut.done.value == 0, "done is not 0!"


@cocotb.test()
async def dbz_2(dut):
	"""Test 13/4 [after dbz]"""
	await test_dut_divide(dut=dut, a=13, b=4)

# @cocotb.test()
async def ovf_1(dut):
	"""Test 8/0.25 [overflow]"""
	cocotb.start_soon(Clock(dut.clk_in, 1, units="ns").start())
	await reset_dut(dut)

	await RisingEdge(dut.clk_in)
	a = 8
	b = 0.25
	dut.A.value = int(a * 2**FRAC_BITS)
	dut.B.value = int(b * 2**FRAC_BITS)
	dut.valid_in.value = 1

	await RisingEdge(dut.clk_in)
	dut.valid_in.value = 0

	# wait for calculation to complete
	while not dut.done.value:
		await RisingEdge(dut.clk_in)

	# check output signals on 'done'
	assert dut.busy.value == 0, "busy is not 0!"
	assert dut.done.value == 1, "done is not 1!"
	assert dut.valid_out.value == 0, "valid is not 0"
	assert dut.zerodiv.value == 0, "dbz is not 0!"
	assert dut.overflow.value == 1, "ovf is not 1!"

	# check 'done' is high for one tick
	await RisingEdge(dut.clk_in)
	assert dut.done.value == 0, "done is not 0!"


@cocotb.test()
async def ovf_2(dut):
	"""Test 11/7 [after ovf]"""
	await test_dut_divide(dut=dut, a=11, b=7)


# @cocotb.test()
async def ovf_3(dut):
	"""Test -16/1 [overflow]"""
	cocotb.start_soon(Clock(dut.clk_in, 1, units="ns").start())
	await reset_dut(dut)

	await RisingEdge(dut.clk_in)
	a = -16
	b = 1
	dut.A.value = int(a * 2**FRAC_BITS)
	dut.B.value = int(b * 2**FRAC_BITS)
	dut.valid_in.value = 1

	await RisingEdge(dut.clk_in)
	dut.valid_in.value = 0

	# wait for calculation to complete
	while not dut.done.value:
		await RisingEdge(dut.clk_in)

	# check output signals on 'done'
	assert dut.busy.value == 0, "busy is not 0!"
	assert dut.done.value == 1, "done is not 1!"
	assert dut.valid_out.value == 0, "valid is not 0"
	assert dut.zerodiv.value == 0, "dbz is not 0!"
	assert dut.overflow.value == 1, "ovf is not 1!"

	# check 'done' is high for one tick
	await RisingEdge(dut.clk_in)
	assert dut.done.value == 0, "done is not 0!"


# @cocotb.test()
async def ovf_4(dut):
	"""Test 1/-16 [overflow]"""
	cocotb.start_soon(Clock(dut.clk_in, 1, units="ns").start())
	await reset_dut(dut)

	await RisingEdge(dut.clk_in)
	a = 1
	b = -16
	dut.A.value = int(a * 2**FRAC_BITS)
	dut.B.value = int(b * 2**FRAC_BITS)
	dut.valid_in.value = 1

	await RisingEdge(dut.clk_in)
	dut.valid_in.value = 0

	# wait for calculation to complete
	while not dut.done.value:
		await RisingEdge(dut.clk_in)

	# check output signals on 'done'
	assert dut.busy.value == 0, "busy is not 0!"
	assert dut.done.value == 1, "done is not 1!"
	assert dut.valid_out.value == 0, "valid is not 0"
	assert dut.zerodiv.value == 0, "dbz is not 0!"
	assert dut.overflow.value == 1, "ovf is not 1!"

	# check 'done' is high for one tick
	await RisingEdge(dut.clk_in)
	assert dut.done.value == 0, "done is not 0!"


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


def gen_params():
	yield {"WIDTH": WIDTH, "FRAC_BITS": FRAC_BITS}

def main():
	"""Simulate the counter using the Python runner."""
	sim = os.getenv("SIM", "icarus")
	proj_path = Path(__file__).resolve().parent.parent
	sys.path.append(str(proj_path / "sim" / "model"))
	sources = [proj_path / "src" / "hdl" / "common" / "fixed_point_div.sv"]
	build_test_args = ["-Wall"]
	sys.path.append(str(proj_path / "sim"))
	runner = get_runner(sim)
	for params in gen_params():
		print("RUNNING TEST FOR PARAMS", params)
		# parameters.update(params)
		runner.build(
			sources=sources,
			hdl_toplevel="fixed_point_div",
			always=True,
			build_args=build_test_args,
			parameters=params,
			timescale=("1ns", "1ps"),
			waves=True,
		)
		run_test_args = []
		runner.test(
			hdl_toplevel="fixed_point_div",
			test_module="test_fixed_point_div",
			test_args=run_test_args,
			waves=True,
		)


if __name__ == "__main__":
	main()
