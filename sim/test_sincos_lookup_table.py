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

HRES = 320
VRES = 180

ENTIRES = VRES
FILENAME = "../src/data/theta_cos_table.mem"

params = {"ENTRIES": ENTIRES, "FILENAME": FILENAME}


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

    for hcount in range(ENTIRES):
        dut.x.value = hcount
        expected = cos(-(math.pi / 2 + 2 * math.pi * hcount / ENTIRES))
        if "x" not in dut.val_out.value:
            print(
                f"out: {dut.val_out.value.signed_integer / 2 ** 14}, expected: {expected}"
            )
        await RisingEdge(dut.clk_in)
        await RisingEdge(dut.clk_in)


def main():
    """Simulate the projection_3d_to_2d module using the Python runner."""
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [
        proj_path / "src" / "hdl" / "common" / "sincos_lookup_table.sv",
        proj_path / "src" / "hdl" / "common" / "brom.v",
        proj_path / "src" / "hdl" / "common" / "pipeline.sv",
    ]
    build_test_args = ["-Wall"]
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="sincos_lookup_table",
        always=True,
        build_args=build_test_args,
        parameters=params,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="sincos_lookup_table",
        test_module="test_sincos_lookup_table",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    main()
