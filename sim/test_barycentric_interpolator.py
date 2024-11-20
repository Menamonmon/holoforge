import os
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import (
	RisingEdge,
)
from cocotb.binary import LogicArray

from FixedPoint import FXfamily, FXnum
import random
import math
from utils import *
import numpy as np

max_cam_dist = 10
vw = 3
vh = 3


max_tri_size = vw * vh * 0.5  # takes n bits, and 1/max_tri_size would also take n bits
inv_precision = math.ceil(math.log2(max_tri_size)) + 14

PRECISION = 14
parameters = {
	"VAL_WIDTH": math.ceil(math.log2(max_cam_dist)) + 1 + PRECISION,
	"VAL_FRAC": PRECISION,
	"AINV_WIDTH": 2 * inv_precision + 1,
	"AINV_FRAC": inv_precision,
	"XWIDTH": math.ceil(math.log2(vw)) + 1 + PRECISION,
	"YWIDTH": math.ceil(math.log2(vh)) + 1 + PRECISION,
	"FRAC": PRECISION,
}

VAL_WIDTH = parameters["VAL_WIDTH"]
VAL_FRAC = parameters["VAL_FRAC"]
AINV_WIDTH = parameters["AINV_WIDTH"]
AINV_FRAC = parameters["AINV_FRAC"]
XWIDTH = parameters["XWIDTH"]
YWIDTH = parameters["YWIDTH"]
FRAC = parameters["FRAC"]
A_WIDTH = XWIDTH - FRAC + YWIDTH + 3

xfam = FXfamily(FRAC, XWIDTH - FRAC)
yfam = FXfamily(FRAC, YWIDTH - FRAC)
ysubfam = FXfamily(FRAC, 1 + YWIDTH - FRAC)
afam = FXfamily(AINV_FRAC, AINV_WIDTH - AINV_FRAC)
areafam = FXfamily(FRAC, A_WIDTH - FRAC)
zfam = FXfamily(VAL_FRAC, VAL_WIDTH - VAL_FRAC)


@cocotb.test()
async def test_inv_area(dut):
	cocotb.start_soon(Clock(dut.clk_in, 2, units="ns").start())

	# test reset
	tests = 100

	for testi in range(tests):
		dut.rst_in.value = 1

		await RisingEdge(dut.clk_in)

		await RisingEdge(dut.clk_in)

		# 3 random numbers for z
		zvec = gen_random_vector(3, VAL_WIDTH, VAL_FRAC, zfam)

		triangle_raw = generate_triangle_fast(vw, vh)

		# triangle_raw = np.array(list(([(2, 2), (3, 3), (3, 0)])), dtype=np.float64)
		triangle = [
			(xfam(triangle_raw[i][0]), yfam(triangle_raw[i][1])) for i in range(3)
		]
		tri_area = triangle_area(triangle_raw) * 2
		if abs(tri_area) < 1**-inv_precision:
			continue
		inv_triangle_area = 1 / tri_area
		inv_triangle_area = afam(inv_triangle_area)
		tri_x = [triangle[i][0] for i in range(3)]
		tri_y = [triangle[i][1] for i in range(3)]
		dut.rst_in.value = 0
		dut.x_tri.value = BinaryValue(vec_to_bin(tri_x, XWIDTH))
		dut.y_tri.value = BinaryValue(vec_to_bin(tri_y, YWIDTH))
		dut.vals_in.value = BinaryValue(vec_to_bin(zvec, VAL_WIDTH))
		dut.iarea_in.value = BinaryValue(
			inv_triangle_area.toBinaryString().replace(".", "")
		)

		# sweep all the possible x, y values in the range (0, vw) and (0, vh) with fixed point increments
		# for x in range(vw * 2 ** FRAC):
		# 	for y in range(vh * 2 ** FRAC):
		# 		dut.x_in.value = BinaryValue(x, XWIDTH)
		# 		dut.y_in.value = BinaryValue(y, YWIDTH)
		# 		await RisingEdge(dut.clk_in)

		# sweep across the triangle bounding box
		x_min = int(float(min(tri_x)) * 2**FRAC)
		x_max = int(float(max(tri_x)) * 2**FRAC)
		y_min = int(float(min(tri_y)) * 2**FRAC)
		y_max = int(float(max(tri_y)) * 2**FRAC)

		count_in_tri = 0
		vals = []

		error = 0
		factor_error = 0
		trials = 100
		print(f"100 Trials for test {testi}th random triangle")

		for _ in range(trials):
			i = random.randint(x_min, x_max) / 2**FRAC
			j = random.randint(y_min, y_max) / 2**FRAC
			# i = 2.5
			# j = 1.5

			x = xfam(i)
			y = yfam(j)

			dut.x_in.value = BinaryValue(x.toBinaryString().replace(".", ""))
			dut.y_in.value = BinaryValue(y.toBinaryString().replace(".", ""))

			await RisingEdge(dut.clk_in)
			for _ in range(4):
				await RisingEdge(dut.clk_in)

			# read the areas
			a1 = int(BinaryValue(dut.a1.value.binstr, A_WIDTH, True, 2)) / 2**FRAC
			a2 = int(BinaryValue(dut.a2.value.binstr, A_WIDTH, True, 2)) / 2**FRAC
			a3 = int(BinaryValue(dut.a3.value.binstr, A_WIDTH, True, 2)) / 2**FRAC
			moda1, moda2, moda3 = barycentric_raw_areas(i, j, triangle_raw)

			error = max(error, abs(a1 - moda1), abs(a2 - moda2), abs(a3 - moda3))
			assert abs(a1 - moda1) < 4 / 2**FRAC
			assert abs(a2 - moda2) < 4 / 2**FRAC
			assert abs(a3 - moda3) < 4 / 2**FRAC

			await RisingEdge(dut.clk_in)
			await RisingEdge(dut.clk_in)

			is_in_tri = int(
				a1 / tri_area >= 0
				and a2 / tri_area >= 0
				and a3 / tri_area >= 0
				and a1 / tri_area <= 1
				and a2 / tri_area <= 1
				and a3 / tri_area <= 1
			)
			scaled_area_trunc_raw = dut.scaled_areas_trunc.value.binstr
			scaled_areas_trunc = [
				int(BinaryValue(x, len(scaled_area_trunc_raw) / 3, True, 2)) / 2**FRAC
				for x in reversed(split_bit_array(scaled_area_trunc_raw, 3))
			]
			scaled_areas_raw = dut.scaled_areas.value.binstr
			scaled_areas = [
				int(BinaryValue(x, len(scaled_areas_raw) / 3, True, 2)) / 2**FRAC
				for x in reversed(split_bit_array(scaled_areas_raw, 3))
			]

			assert abs(scaled_areas[0] - a1 / tri_area) < 4 / 2**FRAC
			assert abs(scaled_areas[1] - a2 / tri_area) < 4 / 2**FRAC
			assert abs(scaled_areas[2] - a3 / tri_area) < 4 / 2**FRAC
			factor_error = max(
				factor_error,
				abs(scaled_areas[0] - a1 / tri_area),
				abs(scaled_areas[1] - a2 / tri_area),
				abs(scaled_areas[2] - a3 / tri_area),
			)
			for _ in range(4):
				await RisingEdge(dut.clk_in)

			assert int(dut.valid_out.value) == is_in_tri
			if is_in_tri:
				# make sure that scaled did not overflow and that the trunc area is the same number
				assert scaled_areas_trunc == scaled_areas
		print(f"Max raw area error: {error}")
		print(f"Max interp factor error: {factor_error}")


def main():
	"""Simulate the counter using the Python runner."""
	sim = os.getenv("SIM", "icarus")
	proj_path = Path(__file__).resolve().parent.parent
	sys.path.append(str(proj_path / "sim" / "model"))
	print(proj_path)
	sources = [
		proj_path
		/ "src"
		/ "hdl"
		/ "graphics"
		/ "rasterizer"
		/ "barycentric_interpolator.sv",
		# proj_path / "src" / "hdl" / "common" / "fixed_point_div.sv",
		proj_path / "src" / "hdl" / "common" / "fixed_point_fast_dot.sv",
		proj_path / "src" / "hdl" / "common" / "fixed_point_mult.sv",
		proj_path / "src" / "hdl" / "common" / "pipeline.sv",
	]
	build_test_args = ["-Wall"]
	sys.path.append(str(proj_path / "sim"))
	runner = get_runner(sim)
	runner.build(
		sources=sources,
		hdl_toplevel="barycentric_interpolator",
		always=True,
		build_args=build_test_args,
		parameters=parameters,
		timescale=("1ns", "1ps"),
		waves=True,
	)
	run_test_args = []
	runner.test(
		hdl_toplevel="barycentric_interpolator",
		test_module="test_barycentric_interpolator",
		test_args=run_test_args,
		waves=True,
	)


if __name__ == "__main__":
	main()
