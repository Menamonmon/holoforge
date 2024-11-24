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
DIV_WIDTH=45

TWO_OVER_VIEWPORT_H = 2/3
TWO_OVER_VIEWPORT_W = 2/3

normalized_fam = FXfamily(FRAC_BITS, WIDTH_P - FRAC_BITS)
div_fam=FXfamily(FRAC_BITS,DIV_WIDTH-FRAC_BITS)



def calculate_renorm(ndc):
    x_renorm=float(ndc[0])/float(ndc[2])
    y_renorm=float(ndc[0])/float(ndc[2])
    return (x_renorm,y_renorm)

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
	await RisingEdge(dut.clk_in)
	dut.rst.value = 0
	await RisingEdge(dut.clk_in)


@cocotb.test()
async def test_projection(dut):
	"""Test simple projection case."""
	#Initialize Clock
	cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())  # 100MHz clock

	#Reset DUT
	await reset_dut(dut)


	#Calc NDC, Do Division, figure out if we do it
	#then pad inputs
	phi = random.randint(1, 360)
	theta = random.randint(1, 360)
	P = [float(i) for i in gen_vec_by_magnitude(3, 1)]
	C = [float(i) for i in gen_vec_by_magnitude(3, 1)]
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
	NDC = calculate_ndc(**test_case)
	renorm=calculate_renorm(NDC)
	ans_valid=0
	if(renorm[0]>-TWO_OVER_VIEWPORT_W and renorm[0]<TWO_OVER_VIEWPORT_W and renorm[1]>-TWO_OVER_VIEWPORT_H and renorm[1<TWO_OVER_VIEWPORT_H]):
		ans_valid=1
	dut.ndc.value = BinaryValue(vec_to_bin([(i) for i in NDC], WIDTH_P))
	dut.valid_in.value = 1
	await RisingEdge(dut.clk_in)
	dut.valid_in.value = 0
	await RisingEdge(dut.clk_in)
	while dut.ready_out!=1:
		await RisingEdge(dut.clk_in)
	valid_out = dut.valid_out.value

	assert valid_out==ans_valid
	dut_x_renorm=dut.x_renorm.value.signed.integer/2**FRAC_BITS
	dut_y_renorm=dut.y_renorm.value.signed_integer/2**FRAC_BITS
	assert abs(renorm[0]-dut_x_renorm)
	assert abs(renorm[1]-dut_y_renorm) 
	x_renorm = dut.x_renorm.value.signed_integer
	y_renorm = dut.y_renorm.value.signed_integer
	z = dut.NDC_z.value.signed_integer

	#Compute Expected Outputs
	right_ans = calculate_ndc(NDC)

	#Verify Output
	#assert valid_out == 1, "valid_out was not high when expected."
	assert abs(x_renorm/2**FRAC_BITS-right_ans[0])<(4/(2**FRAC_BITS))
	assert abs(y_renorm/2**FRAC_BITS-right_ans[1])<(4/(2**FRAC_BITS))




def main():
	"""Simulate the projection_3d_to_2d module using the Python runner."""
	sim = os.getenv("SIM", "icarus")
	proj_path = Path(__file__).resolve().parent.parent
	sys.path.append(str(proj_path / "sim" / "model"))
	sources = [
		proj_path / "src" / "hdl" / "pre_proc" / "renorm.sv",
		proj_path / "src" / "hdl" / "common" / "fixed_point_div.sv",
	]
	build_test_args = ["-Wall"]
	sys.path.append(str(proj_path / "sim"))
	runner = get_runner(sim)
	params = {}
	runner.build(
		sources=sources,
		hdl_toplevel="renorm",
		always=True,
		build_args=build_test_args,
		parameters=params,
		timescale=("1ns", "1ps"),
		waves=True,
	)
	run_test_args = []
	runner.test(
		hdl_toplevel="renorm",
		test_module="test_renorm",
		test_args=run_test_args,
		waves=True,
	)


if __name__ == "__main__":
	main()
