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
from test_pre_proc_shader import feed_triangle_and_normal
import pprint

P_WIDTH = 16
C_WIDTH = 18
V_WIDTH = 16
FRAC_BITS = 14
VH = 1.5
VW = 2.66
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

NUM_TRI = 3000
NUM_COLORS = 256
N = 3
FB_HRES = 320
FB_VRES = 180

PRECISION = FRAC_BITS

vw_hres = VW / FB_HRES
bits_vw_hres = get_bit_width(vw_hres, PRECISION)
vw_hres_fam = FXfamily(PRECISION, bits_vw_hres - PRECISION)
vw_hres = vw_hres_fam(vw_hres).toBinaryString().replace(".", "")
print(vw_hres)

vh_vres = VH / FB_VRES
bits_vh_vres = get_bit_width(vh_vres, PRECISION)
vh_vres_fam = FXfamily(PRECISION, bits_vh_vres - PRECISION)
print(vh_vres)
vh_vres = vh_vres_fam(vh_vres).toBinaryString().replace(".", "")

hres_vw = FB_HRES / VW
bits_hres_vw = get_bit_width(hres_vw, PRECISION)
print(bits_hres_vw)
hres_vw_fam = FXfamily(PRECISION, bits_hres_vw - PRECISION)
print(hres_vw)
hres_vw = hres_vw_fam(hres_vw).toBinaryString().replace(".", "")
print("ERR", float(hres_vw) - FB_HRES / VW)

vres_vh = FB_VRES / VH
bits_hres_vw = get_bit_width(vres_vh, PRECISION)
vres_vh_fam = FXfamily(PRECISION, bits_vh_vres - PRECISION)
print(vres_vh)
vres_vh = vres_vh_fam(vres_vh).toBinaryString().replace(".", "")
print("ERR", float(vres_vh) - FB_VRES / VH)


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
	# "VIEWPORT_H_POSITION_WIDTH": VIEWPORT_H_POSITION_WIDTH + 1,
	# "VIEWPORT_W_POSITION_WIDTH": VIEWPORT_W_POSITION_WIDTH + 1,
	"VIEWPORT_H_POSITION_WIDTH": VIEWPORT_H_POSITION_WIDTH,
	"VIEWPORT_W_POSITION_WIDTH": VIEWPORT_W_POSITION_WIDTH,
	"NUM_TRI": NUM_TRI,
	"NUM_COLORS": NUM_COLORS,
	"FB_HRES": FB_HRES,
	"FB_VRES": FB_VRES,
	"HRES_BY_VW_WIDTH": bits_vw_hres,
	"HRES_BY_VW_FRAC": PRECISION,
	"VRES_BY_VH_WIDTH": bits_vh_vres,
	"VRES_BY_VH_FRAC": PRECISION,
	"HRES_BY_VW": int(BinaryValue(hres_vw)),
	"VRES_BY_VH": int(BinaryValue(vres_vh)),
	"VW_BY_HRES_WIDTH": bits_hres_vw,
	"VW_BY_HRES_FRAC": PRECISION,
	"VH_BY_VRES_WIDTH": bits_vh_vres,
	"VH_BY_VRES_FRAC": PRECISION,
	"VW_BY_HRES": int(BinaryValue(vw_hres)),
	"VH_BY_VRES": int(BinaryValue(vh_vres)),
}
print("parameters", params)


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


@cocotb.test()
async def test_graphics(dut):
	"""Test simple projection case."""
	# Initialize Clock
	cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())  # 100MHz clock

	# Reset DUT
	await reset_dut(dut)

	# load obj file from path and populate the triangle vertices and normals
	# with the data from the obj file

	triangles, normals = load_obj_as_numpy(
		"../scripts/test_data/iconsanhedron/model_normalized.obj"
		# "../scripts/test_data/cube/model_normalized.obj"
		# "../scripts/test_data/sphere/model_normalized.obj"
	)
	# print(len(triangles), len(normals))
	colors = [2**16 - 1 for i in range(len(triangles))]

	# dut.ready_in.value = 0
	# dut.valid_in.value = 0
	# await RisingEdge(dut.clk_in)

	# assert dut.valid_out.value == 0
	# assert dut.ready_out.value == 1

	# phi = math.radians(random.randint(1, 180))
	# theta = math.radians(random.randint(1, 360))
	phi = math.radians(32)
	theta = math.radians(132)
	radius = 1.5
	C, u, v, n = calculate_camera_basis(phi, theta, radius)

	print(f"C: {C}")
	print(f"u: {u}")
	print(f"v: {v}")
	print(f"n: {n}")
	tri_xes = []
	tri_yes = []
	tri_depths = []
	tri_ids = []

	pixel_map = np.full((FB_VRES, FB_HRES), 0)
	dut.ready_in.value = 1
	tri_idx = 0

	for triangle, normal in zip(triangles, normals):
		print("TRIANGLE NUMBER", tri_idx)
		await feed_triangle_and_normal(
			dut.pre_proc_shader_inst, triangle, normal, C, u, v, n, tri_idx
		)
		tri_idx += 1

		# while dut.ready_out.value == 0:
		#     await RisingEdge(dut.clk_in)

		# if dut.rasterizer_valid_in.value == 0:
		#     continue
		short_circuit = False
		while dut.rasterizer_inst.valid_in.value == 0:
			if (
				dut.pre_proc_shader_inst.shader_short_circuit.value == 1
				or dut.pre_proc_shader_inst.vertex_pre_proc_short_circuit.value == 1
			):
				short_circuit = True
				break
			await RisingEdge(dut.clk_in)

		if short_circuit:
			continue

		while dut.rasterizer_inst.ready_out.value == 0:
			await RisingEdge(dut.clk_in)

		# ready results
		depths = [
			int(BinaryValue(x, dut.ZWIDTH.value, True, 0)) / 2**14
			for x in split_bit_array((dut.z_depth.value.binstr), 3)
		]
		# print("INFORMATION")
		viewports_x = [
			int(BinaryValue(x, VIEWPORT_W_POSITION_WIDTH, True, 2)) / 2**14
			# x
			for x in split_bit_array((dut.viewport_x_position.value.binstr), 3)
		]

		viewports_y = [
			int(BinaryValue(x, VIEWPORT_H_POSITION_WIDTH, True, 2)) / 2**14
			# x
			for x in split_bit_array(
				(dut.viewport_y_position.value.binstr),
				3,
			)
		]
		tri_xes.append(list(viewports_x))
		tri_yes.append(list(viewports_y))
		tri_depths.append(list(depths))
		tri_ids.append(tri_idx - 1)
		x, y, z = project_triangle(triangle, C, u, v, n)
		print("DEPTHS: ", depths, z)
		print(
			"UNNORMALIZED DEPTHS",
			[z[0] * 2**FRAC_BITS, z[1] * 2**FRAC_BITS, z[2] * 2**FRAC_BITS],
		)

		# wait until we get a valid out from the toplevel module
		count = 0
		counted = False
		display_frame_pixelized(pixel_map, "./full_renders")
		negative_depths = 0
		positive_depths = 0
		cycle_counters = 0
		valid_tri = False
		for l in range(20_000):
			cycle_counters += 1
			if cycle_counters > 50 and not valid_tri:
				break
			else:
				if dut.rasterizer_valid_in.value == 1:
					valid_tri = True

			# pause for a random number of cycle while driving the inputs at some random points
			# if random.randint(0, 1) == 0:
			# 	dut.ready_in.value = 0
			# 	for i in range(random.randint(0, 10)):
			# 		# for i in range(5):
			# 		await RisingEdge(dut.clk_in)
			# 	dut.ready_in.value = 1
			# 	await RisingEdge(dut.clk_in)
			# else:
			# 	await RisingEdge(dut.clk_in)
			await RisingEdge(dut.clk_in)

			if dut.rasterizer_inst.last_pixel.value == 1:
				break

			if dut.valid_out.value == 1:
				if (
					"x" in dut.hcount_out.value
					or "x" in dut.vcount_out.value
					or "x" in dut.z_out.value
				):
					print("ERROR THIS  HAS AN EX")
				else:
					hcount = int(dut.hcount_out.value)
					vcount = int(dut.vcount_out.value)
					addr_out = int(dut.addr_out.value)
					addr = vcount * FB_HRES + hcount
					assert addr == addr_out
					depth = int(dut.z_out.value)
					if depth < 0:
						negative_depths += 1
						continue

					# make sure the depth is within the 3 values of the depths for that triangle
					# min_d = min(depths)
					# max_d = max(depths)
					# if depth < min_d or depth > max_d:
					#     negative_depths += 1
					#     continue
					if depth >= 40000:
						# print("DEPTH", depth)
						continue

					positive_depths += 1
					if (
						pixel_map[vcount][hcount] == 0
						or pixel_map[vcount][hcount] > depth
					):
						pixel_map[vcount][hcount] = depth
					# pixel_map[vcount][hcount] = 1
					# if pixel_map[vcount][hcount] == 0 or pixel_map[vcount][hcount] > depth:
					# pixel_map[vcount][hcount] = 1
		# print(np.max(pixel_map))
		# display_frame_pixelized(pixel_map, "./full_renders")
		tot = negative_depths + positive_depths
		if tot == 0:
			continue
		print(
			f"NEGATIVE DEPTHS: {negative_depths/tot}, POSITIVE DEPTHS: {positive_depths/tot}"
		)
	print("X TRIANGLES")
	display_frame_pixelized(pixel_map, "./full_renders")
	pprint.pprint(tri_xes)
	print("Y TRIANGLES")
	pprint.pprint(tri_yes)
	print("TRIANGLE IDS", tri_ids)
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
		proj_path / "src" / "hdl" / "common" / "pipeline.sv",
		proj_path / "src" / "hdl" / "common" / "boundary_evt_counter.sv",
		proj_path / "src" / "hdl" / "graphics" / "rasterizer" / "rasterizer.sv",
		proj_path / "src" / "hdl" / "graphics" / "rasterizer" / "inv_area.sv",
		proj_path
		/ "src"
		/ "hdl"
		/ "graphics"
		/ "rasterizer"
		/ "barycentric_interpolator.sv",
		proj_path / "src" / "hdl" / "graphics" / "common" / "barycentric_coeffs.sv",
		proj_path / "src" / "hdl" / "graphics" / "shader" / "light_intensity.sv",
		proj_path / "src" / "hdl" / "graphics" / "shader" / "shader.sv",
		proj_path / "src" / "hdl" / "common" / "brom.v",
		proj_path / "src" / "hdl" / "common" / "fixed_point_fast_dot.sv",
		proj_path / "src" / "hdl" / "common" / "fixed_adder.sv",
		proj_path / "src" / "hdl" / "common" / "fixed_point_mult.sv",
		proj_path / "src" / "hdl" / "graphics" / "tl" / "pre_proc_shader.sv",
		proj_path / "src" / "hdl" / "graphics" / "tl" / "graphics_pipeline_no_brom.sv",
	]
	# sources = find_sv_files(proj_path / "src" / "hdl")
	build_test_args = ["-Wall"]
	sys.path.append(str(proj_path / "sim"))
	runner = get_runner(sim)
	runner.build(
		sources=sources,
		hdl_toplevel="graphics_pipeline_no_brom",
		always=True,
		build_args=build_test_args,
		parameters=params,
		timescale=("1ns", "1ps"),
		waves=True,
	)
	run_test_args = []
	runner.test(
		hdl_toplevel="graphics_pipeline_no_brom",
		test_module="test_graphics_pipeline_integ_test",
		test_args=run_test_args,
		waves=True,
	)


if __name__ == "__main__":
	main()
