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
		assert dut.line_buffer_out.value == 0
		dut.rst_in.value = 0
		dut.data_valid_in.value = 0
		await ClockCycles(dut.clk_in, 10)

	await reset()

	# feed in a whole frame pixel by pixel where every pixel is 16 bits
	# the frame is a 1280x720 image
	for i in range(HRES):
		dut.pixel_data_in.value = i & 0xFFFF
		dut.data_valid_in.value = 1
		dut.vcount_in.value = 0
		dut.hcount_in.value = i
		await ClockCycles(dut.clk_in, 1)
		# if i >= 2:
		# 	assert dut.vcount_out == (0 - 2) % 2
		# 	assert dut.hcount_out == i - 2

	for f in range(1):
		for y in range(VRES):
			for x in range(HRES):
				pixel = (y * HRES + x) & 0xFFFF

				dut.pixel_data_in.value = pixel
				dut.data_valid_in.value = 1
				dut.vcount_in.value = y
				dut.hcount_in.value = x
				await ClockCycles(dut.clk_in, 1)

				if x >= 2:
					# line_buffer_out is a 3x3 window of the image centered at (y - 2, x - 2)
					cx = x - 2
					cy = (y - 2) % VRES

					# line_buffer_out is the line at cx, and cy - 1, cy, cy + 1
					kernel_line = [0] * 3
					kernel_line[0] = ((cy - 1) * HRES + cx) & 0xFFFF
					kernel_line[1] = (cy * HRES + cx) & 0xFFFF
					kernel_line[2] = ((cy + 1) * HRES + cx) & 0xFFFF
					kline = (
						kernel_line[0] << (48 - 16)
						| kernel_line[1] << (48 - 32)
						| kernel_line[2]
					)
					res = int(dut.line_buffer_out.value)
					if res != kline:
						print(f"Expected: {kline:08x}")
						print(f"Got     : {res:08x}")

				# assert dut.vcount_out == y
				# assert dut.hcount_out == x
				# assert dut.data_valid_out == 1


def main():
	"""Simulate the counter using the Python runner."""
	sim = os.getenv("SIM", "icarus")
	proj_path = Path(__file__).resolve().parent.parent
	sys.path.append(str(proj_path / "sim" / "model"))
	sources = [
		proj_path / "hdl" / "line_buffer.sv",
		proj_path / "hdl" / "pipeline.sv",
		proj_path / "hdl" / "xilinx_true_dual_port_read_first_1_clock_ram.v",
	]
	build_test_args = ["-Wall"]
	parameters = {"HRES": HRES, "VRES": VRES}
	sys.path.append(str(proj_path / "sim"))
	runner = get_runner(sim)
	runner.build(
		sources=sources,
		hdl_toplevel="line_buffer",
		always=True,
		build_args=build_test_args,
		parameters=parameters,
		timescale=("1ns", "1ps"),
		waves=True,
	)
	run_test_args = []
	runner.test(
		hdl_toplevel="line_buffer",
		test_module="test_line_buffer",
		test_args=run_test_args,
		waves=True,
	)


if __name__ == "__main__":
	main()
