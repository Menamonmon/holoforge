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
VH = 20
VW = 20
VH_OVER_TWO = VH / 2
VH_OVER_TWO_WIDTH = get_bit_width(VH_OVER_TWO, FRAC_BITS)
two_over_vh_fam = FXfamily(FRAC_BITS, VH_OVER_TWO_WIDTH - FRAC_BITS)

VW_OVER_TWO = VW / 2
VW_OVER_TWO_WIDTH = get_bit_width(VW_OVER_TWO, FRAC_BITS)
two_over_vw_fam = FXfamily(FRAC_BITS, VW_OVER_TWO_WIDTH - FRAC_BITS)

VH_OVER_TWO = int(
    BinaryValue(
        two_over_vh_fam(VH_OVER_TWO).toBinaryString().replace(".", ""),
        VH_OVER_TWO_WIDTH,
        True,
        2,
    )
)

VW_OVER_TWO = int(
    BinaryValue(
        two_over_vw_fam(VW_OVER_TWO).toBinaryString().replace(".", ""),
        VW_OVER_TWO_WIDTH,
        True,
        2,
    )
)


VIEWPORT_H_POSITION_WIDTH = get_bit_width(VH, FRAC_BITS)
VIEWPORT_W_POSITION_WIDTH = get_bit_width(VW, FRAC_BITS)

DIV_WIDTH = 2 * FRAC_BITS + 1
normalized_fam = FXfamily(FRAC_BITS, P_WIDTH - FRAC_BITS)
div_fam = FXfamily(FRAC_BITS, DIV_WIDTH - FRAC_BITS)
c_fam = FXfamily(FRAC_BITS, C_WIDTH - FRAC_BITS)

print(f"VH_OVER_TWO: {VH_OVER_TWO}, {VH_OVER_TWO / 2**FRAC_BITS}")
print(f"VW_OVER_TWO: {VW_OVER_TWO}, {VW_OVER_TWO / 2**FRAC_BITS}")

params = {
    "P_WIDTH": P_WIDTH,
    "C_WIDTH": C_WIDTH,
    "V_WIDTH": V_WIDTH,
    "FRAC_BITS": FRAC_BITS,
    "VH_OVER_TWO": VH_OVER_TWO,
    "VH_OVER_TWO_WIDTH": VH_OVER_TWO_WIDTH,
    "VW_OVER_TWO": VW_OVER_TWO,
    "VW_OVER_TWO_WIDTH": VW_OVER_TWO_WIDTH,
    "VIEWPORT_H_POSITION_WIDTH": VIEWPORT_H_POSITION_WIDTH,
    "VIEWPORT_W_POSITION_WIDTH": VIEWPORT_W_POSITION_WIDTH,
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
        P = [float(i) for i in gen_vec_by_magnitude(3, 1)]
        C = [float(i) for i in gen_vec_by_magnitude(3, 1)]
        test_case = {
            "P": P,
            "C": C,
            "u": [sin(phi) * sin(theta), sin(phi) * sin(theta), 0],
            "v": [-cos(phi) * cos(theta), cos(phi) * sin(theta), -sin(theta)],
            "n": [sin(phi) * cos(theta), sin(phi) * sin(theta), sin(phi)],
        }

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
        # set inputs
        dut.P.value = BinaryValue(
            vec_to_bin([normalized_fam(i) for i in test_case["P"]], P_WIDTH)
        )
        dut.C.value = BinaryValue(
            vec_to_bin([c_fam(i) for i in test_case["C"]], C_WIDTH)
        )
        dut.u.value = BinaryValue(
            vec_to_bin([normalized_fam(i) for i in test_case["u"]], V_WIDTH)
        )
        dut.v.value = BinaryValue(
            vec_to_bin([normalized_fam(i) for i in test_case["v"]], V_WIDTH)
        )
        dut.n.value = BinaryValue(
            vec_to_bin([normalized_fam(i) for i in test_case["n"]], V_WIDTH)
        )

        await RisingEdge(dut.clk_in)
        dut.valid_in.value = 0
        assert dut.valid_out.value == 0
        await RisingEdge(dut.clk_in)
        # next module is still not ready
        assert dut.ready_out.value == 0

        # print all the values
        expected_vals = calculate_projection(**test_case)
        xrenorm = expected_vals[0]
        yrenorm = expected_vals[1]
        out_of_bounds = (
            xrenorm < -VW_OVER_TWO / 2**FRAC_BITS
            or xrenorm > VW_OVER_TWO / 2**FRAC_BITS
            or yrenorm < -VH_OVER_TWO / 2**FRAC_BITS
            or yrenorm > VH_OVER_TWO / 2**FRAC_BITS
        )
        expected_vals[0] += VW_OVER_TWO / 2**FRAC_BITS
        expected_vals[1] += VH_OVER_TWO / 2**FRAC_BITS
        print(f"Expected: {expected_vals}")
        print(out_of_bounds)
        if out_of_bounds:
            assert dut.valid_out.value == 0
            assert dut.ready_out.value == 1
        else:

            # wait for 1000 cycles without a valid input (pipeline empty but next one still needs a value)
            for i in range(100):
                await RisingEdge(dut.clk_in)
                try:
                    assert dut.valid_out.value == 0
                    assert dut.ready_out.value == 0
                except:
                    actuals = [
                        dut.viewport_x_position.value.signed_integer / 2**FRAC_BITS,
                        dut.viewport_y_position.value.signed_integer / 2**FRAC_BITS,
                        dut.z_depth.value.signed_integer / 2**FRAC_BITS,
                    ]
                    print(f"Actuals: {actuals}")
                    raise Exception("failure")

            # set the ready_in signal to 1 and see what happens

            dut.ready_in.value = 1
            await RisingEdge(dut.clk_in)
            await RisingEdge(dut.clk_in)
            actual_vals = [
                dut.viewport_x_position.value.signed_integer / 2**FRAC_BITS,
                dut.viewport_y_position.value.signed_integer / 2**FRAC_BITS,
                dut.z_depth.value.signed_integer / 2**FRAC_BITS,
            ]
            print(f"Actuals: {actual_vals}")
            if out_of_bounds:
                print("OUT OF BOUNDS")
                pass
                # assert dut.valid_out.value == 0
                # assert abs(expected_vals[0] - actual_vals[0]) < 8 / 2**FRAC_BITS
                # assert abs(expected_vals[1] - actual_vals[1]) < 8 / 2**FRAC_BITS
                # assert abs(expected_vals[2] - actual_vals[2]) < 8 / 2**FRAC_BITS
            else:
                assert dut.valid_out.value == 1
                assert dut.ready_out.value == 1
                assert abs(expected_vals[0] - actual_vals[0]) < 0.1
                assert abs(expected_vals[1] - actual_vals[1]) < 0.1
                assert abs(expected_vals[2] - actual_vals[2]) < 0.1

    for t in range(100):
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
        / "graphics"
        / "pre_proc"
        / "project_vertex_to_viewport.sv",
        proj_path / "src" / "hdl" / "common" / "fixed_point_div.sv",
        proj_path / "src" / "hdl" / "common" / "fixed_point_fast_dot.sv",
        proj_path / "src" / "hdl" / "common" / "pipeline.sv",
    ]
    build_test_args = ["-Wall"]
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="project_vertex_to_viewport",
        always=True,
        build_args=build_test_args,
        parameters=params,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="project_vertex_to_viewport",
        test_module="test_project_vertex_to_viewport",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    main()
