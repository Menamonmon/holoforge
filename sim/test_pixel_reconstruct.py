import os
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import ReadOnly, FallingEdge, RisingEdge, ClockCycles
from math import log2, ceil

IMAGE_WIDTH = 10
IMAGE_HEIGHT = 10

CLK_PERIOD = 10
PIXEL_CLK_PERIOD = 2

# Pixel clock generator
async def PixelClock(dut, n):
	for _ in range(n):
		await ClockCycles(dut.clk_in, PIXEL_CLK_PERIOD)


async def PixelCycle(dut, n):
	for _ in range(n):
		dut.camera_pclk_in.value = 1
		await PixelClock(dut, 1)
		dut.camera_pclk_in.value = 0
		await PixelClock(dut, 1)

@cocotb.test()
async def test_pixel_reconstruct(dut):
	# Start the two clocks
	# cocotb.start_soon(Clock(dut.camera_pclk_in, PIXEL_CLK_PERIOD, units="ns").start())
	cocotb.start_soon(
		Clock(dut.clk_in, CLK_PERIOD, units="ns").start()
	)  # Slower clock for clk_in

	dut.rst_in.value = 1
	
	await PixelCycle(dut, 3)
	

	dut.rst_in.value = 0
	await PixelCycle(dut, 3)
 
	for frame in range(1):
		dut.camera_vs_in.value = 1
		for y in range(IMAGE_HEIGHT):
			dut.camera_hs_in.value = 1
			for x in range(IMAGE_WIDTH):
				dut.camera_data_in.value = x
				await PixelCycle(dut, 1)
				dut.camera_data_in.value = ~x 
				await PixelCycle(dut, 1)

				# Add assertion to check pixel data out
				# assert (
				# 	dut.pixel_data_out.value == 0b1111000000001111
				# ), f"Pixel data mismatch at {x}, y={y}"

			dut.camera_hs_in.value = 0
			await PixelCycle(dut, 1)
		dut.camera_vs_in.value = 0
		await PixelCycle(dut, 1)


def main():
	"""Simulate the counter using the Python runner."""
	sim = os.getenv("SIM", "icarus")
	proj_path = Path(__file__).resolve().parent.parent
	sys.path.append(str(proj_path / "sim" / "model"))
	sources = [proj_path / "hdl" / "pixel_reconstruct.sv"]
	build_test_args = ["-Wall"]
	parameters = {
		"HCOUNT_WIDTH": ceil(log2(IMAGE_WIDTH)),
		"VCOUNT_WIDTH": ceil(log2(IMAGE_HEIGHT)),
	}
	sys.path.append(str(proj_path / "sim"))
	runner = get_runner(sim)
	runner.build(
		sources=sources,
		hdl_toplevel="pixel_reconstruct",
		always=True,
		build_args=build_test_args,
		parameters=parameters,
		timescale=("1ns", "1ps"),
		waves=True,
	)
	run_test_args = []
	runner.test(
		hdl_toplevel="pixel_reconstruct",
		test_module="test_pixel_reconstruct",
		test_args=run_test_args,
		waves=True,
	)


if __name__ == "__main__":
	main()
