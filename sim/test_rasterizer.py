import os
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import (
    ReadOnly,
)


@cocotb.test()
async def test_rasterizer(dut):
    assert 1 == 0
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())

    await ReadOnly()


def main():
    """Simulate the counter using the Python runner."""
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "rasterizer.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="rasterizer",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="rasterizer",
        test_module="test_rasterizer",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    main()
