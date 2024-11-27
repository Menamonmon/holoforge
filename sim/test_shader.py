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

NUM_TRI = 12
NUM_COLORS = 256

params = {
    "NUM_TRI": NUM_TRI,
    "NUM_COLORS": NUM_COLORS,
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


def calculate_projection(P, C, u, v, n):
    ndcx, ndcy, ndcz = calculate_ndc(P, C, u, v, n)
    x_renorm = ndcx / ndcz
    y_renorm = ndcy / ndcz
    return [x_renorm, y_renorm, ndcz]


normalized_fam = FXfamily(14, 2)


@cocotb.test()
async def test_shader(dut):
    """Test simple projection case."""
    # Initialize Clock
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())  # 100MHz clock

    # Reset DUT
    await reset_dut(dut)

    async def test_single():
        # testing FSM
        dut.valid_in.value = 0
        dut.ready_in.value = 0  # next module is not ready

        # wait for 1000 cycles without a valid input (pipeline empty but next one still needs a value)
        for i in range(100):
            await RisingEdge(dut.clk_in)
            assert dut.valid_out.value == 0
            assert dut.ready_out.value == 1

        # new state
        dut.valid_in.value = 1
        # cn = [1, 1, 1]
        # tn = [1, 1, 1]
        cn = gen_vec_by_magnitude(3, 1)
        tn = gen_vec_by_magnitude(3, 1)
        dut.cam_normal_in.value = BinaryValue(
            vec_to_bin([normalized_fam(i) for i in cn], 16)
        )
        # set inputs
        await RisingEdge(dut.clk_in)
        dut.valid_in.value = 0
        assert dut.valid_out.value == 0
        await RisingEdge(dut.clk_in)
        dut.raw_normal.value = BinaryValue(
            vec_to_bin([normalized_fam(i) for i in tn], 16)
        )
        dut.color_ids.value = 0
        # next module is still not ready
        assert dut.ready_out.value == 0
        await RisingEdge(dut.clk_in)
        await RisingEdge(dut.clk_in)
        dut.raw_color.value = random.randint(0, 2**16 - 1)
        prod = sum(x * y for x, y in zip(cn, tn))
        for i in range(2):
            await RisingEdge(dut.clk_in)  #
        col = str(dut.raw_color.value)
        print(len(col))
        print(col)
        rstr = "".join([col[i] for i in range(5)])
        gstr = "".join([col[i] for i in range(5, 11)])
        bstr = "".join([col[i] for i in range(11, 16)])
        r, g, b = int(rstr, 2), int(gstr, 2), int(bstr, 2)
        print(r, g, b)

        # at the fifth cycle read the intensity
        print(cn, tn)
        intensity = dut.intensity.value.signed_integer / 2**14
        print("intensity", intensity)
        print("prod", prod)
        assert abs(-prod - intensity) < 2**-13
        dut.ready_in.value = 1
        await RisingEdge(dut.clk_in)
        if prod > 0:
            assert dut.short_circuit.value == 1
            return
        await RisingEdge(dut.clk_in)
        await RisingEdge(dut.clk_in)
        await RisingEdge(dut.clk_in)
        await RisingEdge(dut.clk_in)
        assert dut.valid_out.value == 1
        col = str(dut.color_out.value)
        print(len(col))
        print(col)
        rstr = "".join([col[i] for i in range(5)])
        gstr = "".join([col[i] for i in range(5, 11)])
        bstr = "".join([col[i] for i in range(11, 16)])
        rs, gs, bs = int(rstr, 2), int(gstr, 2), int(bstr, 2)
        print(round(r * -prod), round(g * -prod), round(b * -prod))
        assert abs(rs - round(r * -prod)) <= 1
        assert abs(gs - round(g * -prod)) <= 1
        assert abs(bs - round(b * -prod)) <= 1
        await RisingEdge(dut.clk_in)
        await RisingEdge(dut.clk_in)
        return

    for t in range(1000):
        await test_single()


def main():
    """Simulate the projection_3d_to_2d module using the Python runner."""
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [
        proj_path / "src" / "hdl" / "graphics" / "shader" / "shader.sv",
        proj_path / "src" / "hdl" / "graphics" / "shader" / "light_intensity.sv",
        proj_path / "src" / "hdl" / "common" / "fixed_point_div.sv",
        proj_path / "src" / "hdl" / "common" / "brom.v",
        proj_path / "src" / "hdl" / "common" / "fixed_point_fast_dot.sv",
        proj_path / "src" / "hdl" / "common" / "fixed_point_mult.sv",
        proj_path / "src" / "hdl" / "common" / "pipeline.sv",
    ]
    build_test_args = ["-Wall"]
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="shader",
        always=True,
        build_args=build_test_args,
        parameters=params,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="shader",
        test_module="test_shader",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    main()
