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
import trimesh
import pprint

P_WIDTH = 16
C_WIDTH = 18
V_WIDTH = 16
FRAC_BITS = 14
VH = 30
VW = 30
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


VIEWPORT_H_POSITION_WIDTH = get_bit_width(VH, FRAC_BITS) + 1
VIEWPORT_W_POSITION_WIDTH = get_bit_width(VW, FRAC_BITS) + 1

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


async def feed_triangle_and_normal(dut, triangle, normal, C, u, v, n, idx):
    dut.valid_in.value = 1
    dut.tri_id_in.value = idx
    P0 = triangle[0]
    P0_bin = vec_to_bin([normalized_fam(i) for i in P0], P_WIDTH)
    P1 = triangle[1]
    P1_bin = vec_to_bin([normalized_fam(i) for i in P1], P_WIDTH)
    P2 = triangle[2]
    P2_bin = vec_to_bin([normalized_fam(i) for i in P2], P_WIDTH)
    dut.P.value = BinaryValue("".join([P0_bin, P1_bin, P2_bin]))
    dut.C.value = BinaryValue(vec_to_bin([c_fam(i) for i in C], C_WIDTH))
    dut.u.value = BinaryValue(vec_to_bin([normalized_fam(i) for i in u], V_WIDTH))
    dut.v.value = BinaryValue(vec_to_bin([normalized_fam(i) for i in v], V_WIDTH))
    dut.n.value = BinaryValue(vec_to_bin([normalized_fam(i) for i in n], V_WIDTH))
    await RisingEdge(dut.clk_in)
    dut.valid_in.value = 0
    await RisingEdge(dut.clk_in)
    assert dut.valid_out.value == 0
    assert dut.ready_out.value == 0

    # print("NORMAL", normal)
    dut.shader_inst.raw_normal.value = BinaryValue(
        vec_to_bin([normalized_fam(i) for i in normal], 16)
    )

    await RisingEdge(dut.clk_in)

    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)
    dut.shader_inst.praw_color.value = 2**16 - 1
    await RisingEdge(dut.clk_in)


@cocotb.test()
async def test_pre_proc_shader(dut):
    """Test simple projection case."""
    # Initialize Clock
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())  # 100MHz clock

    # Reset DUT
    await reset_dut(dut)
    # dut.rst_in.value = 1

    # load obj file from path and populate the triangle vertices and normals
    # with the data from the obj file

    triangles, normals = load_obj_as_numpy(
        "../scripts/test_data/cube/model_normalized.obj"
        # "../scripts/test_data/Car/turkey_normalized_normalized.obj"
    )
    triangles_norm = list(zip(triangles, normals))
    # random.shuffle(triangles_norm)
    print("TRIS", triangles_norm)
    colors = [2**16 - 1 for i in range(len(triangles))]

    dut.ready_in.value = 0
    dut.valid_in.value = 0
    await RisingEdge(dut.clk_in)

    assert dut.valid_out.value == 0
    assert dut.ready_out.value == 1

    # phi = math.radians(random.randint(1, 180))
    # theta = math.radians(random.randint(1, 360))
    phi = math.radians(175)
    theta = math.radians(220)
    radius = 2
    C, v, u, n = calculate_camera_basis(phi, theta, radius)

    print(f"C: {C}")
    print(f"u: {u}")
    print(f"v: {v}")
    print(f"n: {n}")
    tri_xes = []
    tri_yes = []

    tri_idx = 0
    for triangle, normal in triangles_norm:
        print(triangle, normal)
        dut.valid_in.value = 1
        await feed_triangle_and_normal(dut, triangle, normal, C, u, v, n, tri_idx)
        tri_idx += 1
        # dut.P.value = BinaryValue(
        # 	vec_to_bin([normalized_fam(i) for i in triangle], P_WIDTH)
        # )
        # print(triangle)
        # P0 = triangle[0]
        # P0_bin = vec_to_bin([normalized_fam(i) for i in P0], P_WIDTH)
        # P1 = triangle[1]
        # P1_bin = vec_to_bin([normalized_fam(i) for i in P1], P_WIDTH)
        # P2 = triangle[2]
        # P2_bin = vec_to_bin([normalized_fam(i) for i in P2], P_WIDTH)
        # dut.P.value = BinaryValue("".join([P0_bin, P1_bin, P2_bin]))
        # dut.C.value = BinaryValue(vec_to_bin([c_fam(i) for i in C], C_WIDTH))
        # dut.u.value = BinaryValue(vec_to_bin([normalized_fam(i) for i in u], V_WIDTH))
        # dut.v.value = BinaryValue(vec_to_bin([normalized_fam(i) for i in v], V_WIDTH))
        # dut.n.value = BinaryValue(vec_to_bin([normalized_fam(i) for i in n], V_WIDTH))
        # await RisingEdge(dut.clk_in)
        # dut.valid_in.value = 0
        # await RisingEdge(dut.clk_in)
        # assert dut.valid_out.value == 0
        # assert dut.ready_out.value == 0

        # dut.shader_inst.raw_normal.value = BinaryValue(
        # 	vec_to_bin([normalized_fam(i) for i in normal], 16)
        # )

        # await RisingEdge(dut.clk_in)
        # while dut.ready_out.value == 0:
        # 	await RisingEdge(dut.clk_in)
        # while dut.state.value != 2:
        #     await RisingEdge(dut.clk_in)
        for i in range(100):
            await RisingEdge(dut.clk_in)

        # await RisingEdge(dut.clk_in)

        # let the valid pipeline pass through
        if dut.valid_out.value == 1:
            dut.ready_in.value = 1
            await RisingEdge(dut.clk_in)
            # ready results
            depths = [
                int(BinaryValue(x, 16, True, 2)) / 2**14
                for x in split_bit_array((dut.z_depth_out.value.binstr), 3)
            ]
            print("INFORMATION")
            print(depths)
            viewports_x = [
                int(BinaryValue(x, VIEWPORT_W_POSITION_WIDTH, True, 2)) / 2**14
                # x
                for x in split_bit_array((dut.viewport_x_positions_out.value.binstr), 3)
            ]

            viewports_y = [
                int(BinaryValue(x, VIEWPORT_H_POSITION_WIDTH, True, 2)) / 2**14
                # x
                for x in split_bit_array(
                    (dut.viewport_y_positions_out.value.binstr),
                    3,
                )
            ]
            print(viewports_x)
            print(viewports_y)

            dut.ready_in.value = 0
            projected_triangle = project_triangle(triangle, C, u, v, n)
            print(projected_triangle)
            tri_xes.append(list(viewports_x))
            tri_yes.append(list(viewports_y))

        await RisingEdge(dut.clk_in)
        await RisingEdge(dut.clk_in)
        await RisingEdge(dut.clk_in)
        # return
        # return
        # return
        # valid preprocessing

    print("X TRIANGLES")
    pprint.pprint(tri_xes)
    print("Y TRIANGLES")
    pprint.pprint(tri_yes)

    plot_triangles(tri_xes, tri_yes)


def main():
    """Simulate the projection_3d_to_2d module using the Python runner."""
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [
        proj_path / "src" / "hdl" / "graphics" / "pre_proc" / "vertex_pre_proc.sv",
        proj_path
        / "src"
        / "hdl"
        / "graphics"
        / "pre_proc"
        / "project_vertex_to_viewport.sv",
        proj_path / "src" / "hdl" / "common" / "fixed_point_div.sv",
        # proj_path / "src" / "hdl" / "common" / "fixed_point_fast_dot.sv",
        proj_path / "src" / "hdl" / "common" / "pipeline.sv",
        proj_path / "src" / "hdl" / "graphics" / "shader" / "shader.sv",
        proj_path / "src" / "hdl" / "graphics" / "shader" / "light_intensity.sv",
        # proj_path / "src" / "hdl" / "common" / "fixed_point_div.sv",
        proj_path / "src" / "hdl" / "common" / "brom.v",
        proj_path / "src" / "hdl" / "common" / "fixed_point_fast_dot.sv",
        proj_path / "src" / "hdl" / "common" / "fixed_point_mult.sv",
        proj_path / "src" / "hdl" / "graphics" / "tl" / "pre_proc_shader.sv",
        # proj_path / "src" / "hdl" / "common" / "pipeline.sv",
    ]
    build_test_args = ["-Wall"]
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="pre_proc_shader",
        always=True,
        build_args=build_test_args,
        parameters=params,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="pre_proc_shader",
        test_module="test_pre_proc_shader",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    main()
