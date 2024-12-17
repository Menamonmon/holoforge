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

P_WIDTH = 16
C_WIDTH = 18
V_WIDTH = 16
FRAC_BITS = 14


DIV_WIDTH = 2 * FRAC_BITS + 1
normalized_fam = FXfamily(FRAC_BITS, P_WIDTH - FRAC_BITS)
div_fam = FXfamily(FRAC_BITS, DIV_WIDTH - FRAC_BITS)
c_fam = FXfamily(FRAC_BITS, C_WIDTH - FRAC_BITS)

params = {}


async def reset_dut(dut):
	"""Reset the DUT."""
	dut.rst_in.value = 1
	await RisingEdge(dut.clk_in)
	dut.rst_in.value = 0
	await RisingEdge(dut.clk_in)


@cocotb.test()
async def test_project_vertex_to_viewport(dut):
	"""Test simple projection case."""
	# Initialize Clock
	cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())  # 100MHz clock

	# Reset DUT
	await reset_dut(dut)

	async def test_single():
		phi = math.radians(random.randint(1, 180))
		theta = math.radians(random.randint(1, 360))
		radius = min(max(random.random(), 0.01), 1) * 5
		C, u, v, n = calculate_camera_basis(phi, theta, radius)
		await reset_dut(dut)

		dut.valid_in.value = 1
		dut.sin_phi_in.value = BinaryValue(vec_to_bin([normalized_fam(sin(phi))], 16))
		dut.cos_phi_in.value = BinaryValue(vec_to_bin([normalized_fam(cos(phi))], 16))
		dut.sin_theta_in.value = BinaryValue(
			vec_to_bin([normalized_fam(sin(theta))], 16)
		)
		dut.cos_theta_in.value = BinaryValue(
			vec_to_bin([normalized_fam(cos(theta))], 16)
		)
		dut.mag_in = BinaryValue(vec_to_bin([c_fam(radius)], 18))
		await RisingEdge(dut.clk_in)
		dut.valid_in.value = 0

		for i in range(5):
			phi = math.radians(random.randint(1, 180))
			theta = math.radians(random.randint(1, 360))
			dut.sin_phi_in.value = BinaryValue(
				vec_to_bin([normalized_fam(sin(phi))], 16)
			)
			dut.cos_phi_in.value = BinaryValue(
				vec_to_bin([normalized_fam(cos(phi))], 16)
			)
			dut.sin_theta_in.value = BinaryValue(
				vec_to_bin([normalized_fam(sin(theta))], 16)
			)
			dut.cos_theta_in.value = BinaryValue(
				vec_to_bin([normalized_fam(cos(theta))], 16)
			)

			await RisingEdge(dut.clk_in)

		ans_u = list(
			reversed(
				[
					int(BinaryValue(x, 16, True, 2)) / 2**14
					for x in split_bit_array(dut.u_out.value.binstr, 3)
				]
			)
		)
		ans_v = list(
			reversed(
				[
					int(BinaryValue(x, 16, True, 2)) / 2**14
					for x in split_bit_array(dut.v_out.value.binstr, 3)
				]
			)
		)
		ans_n = list(
			reversed(
				[
					int(BinaryValue(x, 16, True, 2)) / 2**14
					for x in split_bit_array(dut.n_out.value.binstr, 3)
				]
			)
		)

		ans_C = list(
			reversed(
				[
					int(BinaryValue(x, 18, True, 2)) / 2**14
					for x in split_bit_array(dut.pos_out.value.binstr, 3)
				]
			)
		)

		print(f"u: {u}, v: {v}, n: {n}")
		print(f"ans_u: {ans_u}, ans_v: {ans_v}, ans_n: {ans_n}")
		print(f"C: {C}")
		print(f"ans_C: {ans_C}")
		assert dut.valid_out.value == 1
		tol = 1e-3

		assert abs(ans_u[0] - u[0]) < tol
		assert abs(ans_u[1] - u[1]) < tol
		assert abs(ans_u[2] - u[2]) < tol

		assert abs(ans_v[0] - v[0]) < tol
		assert abs(ans_v[1] - v[1]) < tol
		assert abs(ans_v[2] - v[2]) < tol

		assert abs(ans_n[0] - n[0]) < tol
		assert abs(ans_n[1] - n[1]) < tol
		assert abs(ans_n[2] - n[2]) < tol

		assert abs(ans_C[0] - C[0]) < tol
		assert abs(ans_C[1] - C[1]) < tol
		assert abs(ans_C[2] - C[2]) < tol

	for i in range(1000):
		await test_single()



def main():
	"""Simulate the projection_3d_to_2d module using the Python runner."""
	sim = os.getenv("SIM", "icarus")
	proj_path = Path(__file__).resolve().parent.parent
	sys.path.append(str(proj_path / "sim" / "model"))
	sources = [
		proj_path / "src" / "hdl" / "camera" / "camera_control.sv",
		proj_path / "src" / "hdl" / "common" / "fixed_point_mult.sv",
		proj_path / "src" / "hdl" / "common" / "pipeline.sv",
	]
	build_test_args = ["-Wall"]
	sys.path.append(str(proj_path / "sim"))
	runner = get_runner(sim)
	runner.build(
		sources=sources,
		hdl_toplevel="camera_control",
		always=True,
		build_args=build_test_args,
		parameters=params,
		timescale=("1ns", "1ps"),
		waves=True,
	)
	run_test_args = []
	runner.test(
		hdl_toplevel="camera_control",
		test_module="test_camera_control",
		test_args=run_test_args,
		waves=True,
	)


if __name__ == "__main__":
	main()
