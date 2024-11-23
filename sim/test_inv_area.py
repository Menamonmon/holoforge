import os
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import (
	RisingEdge,
)

from FixedPoint import FXfamily, FXnum
import random
import math
from utils import *

XWIDTH = 20
YWIDTH = 20
FRAC = 14

parameters = {
	"XWIDTH": XWIDTH,
	"YWIDTH": YWIDTH,
	"FRAC": FRAC,
}

xfam = FXfamily(FRAC, XWIDTH - FRAC)
yfam = FXfamily(FRAC, YWIDTH - FRAC)


@cocotb.test()
async def test_inv_area(dut):
	cocotb.start_soon(Clock(dut.clk_in, 2, units="ns").start())

	# test reset
	dut.rst_in.value = 1

	await RisingEdge(dut.clk_in)

	await RisingEdge(dut.clk_in)

	assert dut.done.value == 0
	assert dut.valid_out.value == 0

	dut.rst_in.value = 0

	await RisingEdge(dut.clk_in)

	# test input
	async def test_inv_area():
		xvec = gen_random_vector(3, XWIDTH, FRAC, xfam)
		yvec = gen_random_vector(3, YWIDTH, FRAC, yfam)
		dut.valid_in.value = 1
		dut.x.value = BinaryValue(vec_to_bin(xvec, XWIDTH))
		dut.y.value = BinaryValue(vec_to_bin(yvec, YWIDTH))

		await RisingEdge(dut.clk_in)

		dut.valid_in.value = 0

		# wait for calculation to complete
		cycle_count = 0
		while not dut.done.value:
			await RisingEdge(dut.clk_in)
			cycle_count += 1

		# model result
		SUB_WIDTH = YWIDTH + 1
		ysubfam = FXfamily(FRAC, SUB_WIDTH - FRAC)
		ysub = [
			ysubfam(float(yvec[1]) - float(yvec[2])),
			ysubfam(float(yvec[2]) - float(yvec[0])),
			ysubfam(float(yvec[0]) - float(yvec[1])),
		]

		# results final: x1(y2 - y3) + x2(y3 - y1) + x3(y1 - y2)

		# model result
		# INV_WIDTH = 2 * FRAC + 1
		INV_WIDTH = 31
		inv_fam = FXfamily(FRAC, INV_WIDTH - FRAC)

		DOT_WIDTH = 2 + (XWIDTH - FRAC) + (SUB_WIDTH - FRAC) + FRAC
		dot_fam = FXfamily(FRAC, DOT_WIDTH - FRAC)

		raw_model_val = round(sum(
			[
				float(x) * float(y)
				for x, y in zip(xvec, ysub)
			]
		) * 2**FRAC)
		raw_iarea = 1 / raw_model_val
		raw_model = 1/raw_iarea

		# model_val_dot = dot_fam(raw_model_val)

		# assert str(dut.dot_out.value) == model_val_dot.toBinaryString().replace(".", "")
		assert abs(dut.dot_out.value.signed_integer - raw_model_val) <= 1 # +/- error
		raw_model_val = dut.dot_out.value.signed_integer / 2**FRAC

		model_val = inv_fam(inv_fam(1) / inv_fam((raw_model_val)))

		assert dut.valid_out.value == 1
		iarea = dut.iarea.value.signed_integer / 2**FRAC
		assert float(iarea) - float(1/raw_model_val) < 2**(-FRAC), f"{iarea} != {model_val} (real: {1 / raw_model_val})"
		# assert str(dut.iarea) == model_val.toBinaryString().replace(".", "")
		# print(f"iarea: {iarea} == {model_val}")
		# print(f"raw_iarea: {raw_iarea} == {model_val}")
		# print("iarea error: ", abs(iarea - model_val))

	for i in range(100):
		await test_inv_area()


def main():
	"""Simulate the counter using the Python runner."""
	sim = os.getenv("SIM", "icarus")
	proj_path = Path(__file__).resolve().parent.parent
	sys.path.append(str(proj_path / "sim" / "model"))
	print(proj_path)
	sources = [
		proj_path / "src" / "hdl" / "graphics" / "rasterizer" / "inv_area.sv",
		proj_path / "src" / "hdl" / "common" / "fixed_point_div.sv",
		proj_path / "src" / "hdl" / "common" / "fixed_point_slow_dot.sv",
	]
	build_test_args = ["-Wall"]
	sys.path.append(str(proj_path / "sim"))
	runner = get_runner(sim)
	runner.build(
		sources=sources,
		hdl_toplevel="inv_area",
		always=True,
		build_args=build_test_args,
		parameters=parameters,
		timescale=("1ns", "1ps"),
		waves=True,
	)
	run_test_args = []
	runner.test(
		hdl_toplevel="inv_area",
		test_module="test_inv_area",
		test_args=run_test_args,
		waves=True,
	)


if __name__ == "__main__":
	main()
