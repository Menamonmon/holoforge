import os
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ReadOnly, ClockCycles
from cocotb.runner import get_runner
from cocotb.triggers import RisingEdge, Timer
from cocotb.binary import BinaryValue
from FixedPoint import FXfamily, FXnum

import random
import math
from math import sin, cos
from utils import *

WIDTH_P = 16
WIDTH_C = 18
WIDTH_V = 16
WIDTH_DOT = 14
WIDTH_NDC = 18
FRAC_BITS = 14
TWO_OVER_VIEWPORT_H = 1
TWO_OVER_VIEWPORT_W = 1

normalized_fam = FXfamily(FRAC_BITS, WIDTH_P - FRAC_BITS)
c_fam = FXfamily(FRAC_BITS, WIDTH_C - FRAC_BITS)


def calculate_ndc(P, C, u, v, n):
	subbed_values = [0, 0, 0]
	dotted_vals = [0, 0, 0]
	spherical_coords = [u, v, n]
	for i in range(3):
		subbed_values[i] = P[i] - C[i]
	for k in range(3):
		for j in range(3):
			dotted_vals[k] += float(subbed_values[j]) * float(spherical_coords[k][j])
	return dotted_vals


async def reset_dut(dut):
	"""Reset the DUT."""
	dut.rst.value = 1
	await RisingEdge(dut.clk)
	dut.rst.value = 0
	await RisingEdge(dut.clk)


@cocotb.test()
async def test_projection(dut):
	"""Test simple projection case."""
	# Initialize Clock
	cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())  # 100MHz clock

	# Reset DUT
	await reset_dut(dut)

	# Define Test Inputs
	phi = 20
	theta = 55
	# P = [float(i) for i in gen_vec_by_magnitude(3, 1)]
	# C = [float(i) for i in gen_vec_by_magnitude(3, 1)]
	P = np.array([0.011, -0.011, 0.011])
	# # C = [float(i) for i in gen_vec_by_magnitude(3, 1)]
	C = np.array([0.01, -0.001, 0.02])
	test_case = {
		# "P": [.05, -.02,.06],
		# "C": [.01, -.001, .02],
		"P": P,
		"C": C,
		"u": [sin(phi) * sin(theta), sin(phi) * sin(theta), 0],
		"v": [-cos(phi) * cos(theta), cos(phi) * sin(theta), -sin(theta)],
		"n": [sin(phi) * cos(theta), sin(phi) * sin(theta), sin(phi)],
		# "u": [1, 0, 0],
		# "v": [0, 1, 0],
		# "n": [0, 0, 1],
	}
	dut.P.value = BinaryValue(
		vec_to_bin([normalized_fam(i) for i in test_case["P"]], WIDTH_P)
	)
	dut.C.value = BinaryValue(vec_to_bin([c_fam(i) for i in test_case["C"]], WIDTH_C))
	dut.u.value = BinaryValue(
		vec_to_bin([normalized_fam(i) for i in test_case["u"]], WIDTH_V)
	)
	dut.v.value = BinaryValue(
		vec_to_bin([normalized_fam(i) for i in test_case["v"]], WIDTH_V)
	)
	dut.n.value = BinaryValue(
		vec_to_bin([normalized_fam(i) for i in test_case["n"]], WIDTH_V)
	)
	dut.valid_in.value = 1
	await RisingEdge(dut.clk)
	dut.valid_in.value = 0
	await RisingEdge(dut.clk)
	
	P_cam_x = dut.P_cam_x.value.signed_integer / 2**FRAC_BITS
	P_cam_y = dut.P_cam_y.value.signed_integer / 2**FRAC_BITS
	P_cam_z = dut.P_cam_z.value.signed_integer / 2**FRAC_BITS

	print(P_cam_x, P_cam_y, P_cam_z)
	print(P - C)

	for _ in range(10):await RisingEdge(dut.clk)

	# print(P, C)

	# Capture Outputs
	valid_out = dut.valid_out.value
	ndc_x = dut.NDC_x.value.signed_integer
	ndc_y = dut.NDC_y.value.signed_integer
	ndc_z = dut.NDC_z.value.signed_integer

	# Compute Expected Outputs
	right_ans = calculate_ndc(**test_case)

	print("meowx", ndc_x / 2**FRAC_BITS)
	print("meowx", right_ans[0])

	print("meowy", ndc_y / 2**FRAC_BITS)
	print("meowy", right_ans[1])

	print("meowz", ndc_z / 2**FRAC_BITS)
	print("meowz", right_ans[2])
	# Verify Output
	# assert valid_out == 1, "valid_out was not high when expected."
	# assert ndc_x == right_ans[0]
	# assert ndc_y == right_ans[1]
	# assert ndc_z == right_ans[2]


# Add more test cases as needed following the same structure


def main():
	"""Simulate the projection_3d_to_2d module using the Python runner."""
	sim = os.getenv("SIM", "icarus")
	proj_path = Path(__file__).resolve().parent.parent
	sys.path.append(str(proj_path / "sim" / "model"))
	sources = [
		proj_path / "src" / "hdl" / "pre_proc" / "v_to_ndc.sv",
		proj_path / "src" / "hdl" / "common" / "fixed_point_mult.sv",
		proj_path / "src" / "hdl" / "common" / "fixed_point_fast_dot.sv",
		proj_path / "src" / "hdl" / "common" / "pipeline.sv",
	]
	build_test_args = ["-Wall"]
	sys.path.append(str(proj_path / "sim"))
	runner = get_runner(sim)
	params = {}
	runner.build(
		sources=sources,
		hdl_toplevel="v_to_ndc",
		always=True,
		build_args=build_test_args,
		parameters=params,
		timescale=("1ns", "1ps"),
		waves=True,
	)
	run_test_args = []
	runner.test(
		hdl_toplevel="v_to_ndc",
		test_module="test_v_to_ndc",
		test_args=run_test_args,
		waves=True,
	)


if __name__ == "__main__":
	main()
