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

params = {

}


def calculate_renorm(ndc):
	x_renorm = float(ndc[0]) / float(ndc[2])
	y_renorm = float(ndc[0]) / float(ndc[2])
	return (x_renorm, y_renorm)


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
		# Calc NDC, Do Division, figure out if we do it
		# then pad inputs
		phi = math.radians(random.randint(1, 360))
		theta = math.radians(random.randint(1, 360))
		mag = 4
		u = [-sin(phi)*sin(theta),sin(phi)*sin(theta),0]
		v = [-cos(phi)*cos(theta),cos(phi)*sin(theta)]
		n = [sin(phi)*cos(theta),sin(phi)*sin(theta),sin(phi)]
		pos= [mag*sin(phi)*cos(theta),mag*sin(phi)*sin(theta),mag*sin(theta)]
		await reset_dut(dut)
		dut.valid_in.value=1
		dut.sin_phi_in.value=BinaryValue(vec_to_bin([normalized_fam(sin(phi))],16))
		dut.cos_phi_in.value=BinaryValue(vec_to_bin([normalized_fam(cos(phi))],16))
		dut.sin_theta_in.value=BinaryValue(vec_to_bin([normalized_fam(sin(theta))],16))
		dut.cos_theta_in.value=BinaryValue(vec_to_bin([normalized_fam(cos(theta))],16))
		dut.mag_int=BinaryValue(mag)
		for i in range(4):
			await RisingEdge(dut.clk_in)
		print((dut.v.value)//2*FRAC_BITS)
		print(v)
	await test_single()

def main():
	"""Simulate the projection_3d_to_2d module using the Python runner."""
	sim = os.getenv("SIM", "icarus")
	proj_path = Path(__file__).resolve().parent.parent
	sys.path.append(str(proj_path / "sim" / "model"))
	sources = [
		proj_path
		/ "src"
		/ "hdl"
		/ "camera"
		/ "camera_control.sv",
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