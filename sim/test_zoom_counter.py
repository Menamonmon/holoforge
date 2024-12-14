import os
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import ReadOnly, RisingEdge


@cocotb.test()
async def test_zoom_counter(dut):
	cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
	dut.rst_in.value = 1
	await RisingEdge(dut.clk_in)
	await RisingEdge(dut.clk_in)
	dut.rst_in.value = 0
	await RisingEdge(dut.clk_in)
	for i in range(10000):
		dut.evt_in.value = (i % 5) == 0
		await RisingEdge(dut.clk_in)


def main():
	"""Simulate the counter using the Python runner."""
	sim = os.getenv("SIM", "icarus")
	proj_path = Path(__file__).resolve().parent.parent
	sys.path.append(str(proj_path / "sim" / "model"))
	sources = [proj_path / "src" / "hdl" / "common" / "zoom_counter.sv"]
	build_test_args = ["-Wall"]
	parameters = {}
	sys.path.append(str(proj_path / "sim"))
	runner = get_runner(sim)
	runner.build(
		sources=sources,
		hdl_toplevel="zoom_counter",
		always=True,
		build_args=build_test_args,
		parameters=parameters,
		timescale=("1ns", "1ps"),
		waves=True,
	)
	run_test_args = []
	runner.test(
		hdl_toplevel="zoom_counter",
		test_module="test_zoom_counter",
		test_args=run_test_args,
		waves=True,
	)


if __name__ == "__main__":
	main()
