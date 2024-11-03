import os
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import (
	ClockCycles,
)

HRES = 20
VRES = 20


@cocotb.test()
async def test_line_buffer(dut):
	cocotb.start_soon(
		Clock(dut.clk_in, 1, units="ns").start()
	)  # Slower clock for clk_in

	async def reset():
		dut.rst_in.value = 1
		await ClockCycles(dut.clk_in, 10)
		dut.rst_in.value = 0
		dut.data_valid_in.value = 0
		await ClockCycles(dut.clk_in, 10)

	await reset()

	for f in range(1):
		for y in range(VRES):
			for x in range(HRES):
				pixel = (y * HRES + x) & 0xFFFF_FFFF_FFFF
				dut.data_in.value = pixel
				dut.data_valid_in.value = 1
				dut.vcount_in.value = y
				dut.hcount_in.value = x
				await ClockCycles(dut.clk_in, 1)



def main():
	"""Simulate the counter using the Python runner."""
	sim = os.getenv("SIM", "icarus")
	proj_path = Path(__file__).resolve().parent.parent
	sys.path.append(str(proj_path / "sim" / "model"))
	sources = [
		proj_path / "hdl" / "convolution.sv",
		proj_path / "hdl" / "pipeline.sv",
		proj_path / "hdl" / "kernels.sv",
	]
	build_test_args = ["-Wall"]
	# parameters = {"HRES": HRES, "VRES": VRES}
	parameters = {}
	sys.path.append(str(proj_path / "sim"))
	runner = get_runner(sim)
	runner.build(
		sources=sources,
		hdl_toplevel="convolution",
		always=True,
		build_args=build_test_args,
		parameters=parameters,
		timescale=("1ns", "1ps"),
		waves=True,
	)
	run_test_args = []
	runner.test(
		hdl_toplevel="convolution",
		test_module="test_convolution",
		test_args=run_test_args,
		waves=True,
	)


if __name__ == "__main__":
	main()
