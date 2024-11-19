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

MAX_COUNT = 10000

parameters = {
	"MAX_COUNT": MAX_COUNT
}

def generate_random_int_boundary(min, max):

	# generate a tuple of i < j and they're both random number
	i = random.randint(min, max - 1)
	j = random.randint(i, max)
	return i, j


@cocotb.test()
async def test_inv_area(dut):
	cocotb.start_soon(Clock(dut.clk_in, 2, units="ns").start())

	# test reset
	tests = 10

	for _ in range(tests):
		dut.rst_in.value = 1

		await RisingEdge(dut.clk_in)

		await RisingEdge(dut.clk_in)
		minval, maxval = generate_random_int_boundary(0, MAX_COUNT)
		dut.rst_in.value = 0
		dut.min.value = minval
		dut.max.value = maxval
		trials = 10

		await RisingEdge(dut.clk_in)
		await RisingEdge(dut.clk_in)
		for _ in range(trials):
			for i in range(minval, maxval + 1):
				assert int(dut.count_out.value) == i
				await RisingEdge(dut.clk_in)

	


def main():
	"""Simulate the counter using the Python runner."""
	sim = os.getenv("SIM", "icarus")
	proj_path = Path(__file__).resolve().parent.parent
	sys.path.append(str(proj_path / "sim" / "model"))
	print(proj_path)
	sources = [
		# proj_path / "src" / "hdl" / "graphics" / "rasterizer" / "boundary_counter.sv",
		# proj_path / "src" / "hdl" / "common" / "fixed_point_div.sv",
		proj_path
		/ "src"
		/ "hdl"
		/ "common"
		/ "boundary_counter.sv",
	]
	build_test_args = ["-Wall"]
	sys.path.append(str(proj_path / "sim"))
	runner = get_runner(sim)
	runner.build(
		sources=sources,
		hdl_toplevel="boundary_counter",
		always=True,
		build_args=build_test_args,
		parameters=parameters,
		timescale=("1ns", "1ps"),
		waves=True,
	)
	run_test_args = []
	runner.test(
		hdl_toplevel="boundary_counter",
		test_module="test_boundary_counter",
		test_args=run_test_args,
		waves=True,
	)


if __name__ == "__main__":
	main()
