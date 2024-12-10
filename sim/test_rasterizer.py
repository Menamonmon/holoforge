import os
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import (
	RisingEdge,
)
from cocotb.binary import LogicArray

from FixedPoint import FXfamily, FXnum
import random
import math
from utils import *
import numpy as np
from rasterize_tri_sim import Triangle

max_cam_dist = 10000
vw = 3
vh = 3
HRES = 320
VRES = 180
PRECISION = 14


def get_bit_width(val, frac):
	if val < 1:
		return math.ceil(math.log2(1 / val)) + 1 + frac
	return math.ceil(math.log2(val)) + 1 + frac


vw_hres = vw / HRES
bits_vw_hres = get_bit_width(vw_hres, PRECISION)
vw_hres_fam = FXfamily(PRECISION, bits_vw_hres - PRECISION)
vw_hres = vw_hres_fam(vw_hres).toBinaryString().replace(".", "")
print(vw_hres)

vh_vres = vh / VRES
bits_vh_vres = get_bit_width(vh_vres, PRECISION)
vh_vres_fam = FXfamily(PRECISION, bits_vh_vres - PRECISION)
print(vh_vres)
vh_vres = vh_vres_fam(vh_vres).toBinaryString().replace(".", "")

hres_vw = HRES / vw
bits_hres_vw = get_bit_width(hres_vw, PRECISION)
hres_vw_fam = FXfamily(PRECISION, bits_hres_vw - PRECISION)
print(hres_vw)
hres_vw = hres_vw_fam(hres_vw).toBinaryString().replace(".", "")

vres_vh = VRES / vh
bits_hres_vw = get_bit_width(vres_vh, PRECISION)
vres_vh_fam = FXfamily(PRECISION, bits_vh_vres - PRECISION)
print(vres_vh)
vres_vh = vres_vh_fam(vres_vh).toBinaryString().replace(".", "")


# max_tri_size = vw * vh * 0.5  # takes n bits, and 1/max_tri_size would also take n bits
# inv_precision = math.ceil(math.log2(max_tri_size)) + 14

parameters = {
	"XWIDTH": math.ceil(math.log2(vw)) + 1 + PRECISION,
	"YWIDTH": math.ceil(math.log2(vh)) + 1 + PRECISION,
	"ZWIDTH": math.ceil(math.log2(max_cam_dist)) + 1 + PRECISION,
	"XFRAC": PRECISION,
	"YFRAC": PRECISION,
	"ZFRAC": PRECISION,
	"FB_HRES": HRES,
	"FB_VRES": VRES,
	# "VH": vh,
	# "VW": vw,
	# parameter HRES_BY_VW_WIDTH = 7,
	# parameter HRES_BY_VW_FRAC  = 0,
	# parameter VRES_BY_VH_WIDTH = 6,
	# parameter VRES_BY_VH_FRAC  = 0,
	# parameter [HRES_BY_VW_WIDTH-1:0] HRES_BY_VW  = 1,
	# parameter [VRES_BY_VH_WIDTH-1:0] VRES_BY_VH = 1
	# parameter VW_BY_HRES_WIDTH = 6,
	# parameter VW_BY_HRES_FRAC = 0,
	# parameter VH_BY_VRES_WIDTH = 7,
	# parameter VH_BY_VRES_FRAC = 0,
	# parameter [VW_BY_HRES_WIDTH-1:0] VW_BY_HRES = 1,
	# parameter [VH_BY_VRES_WIDTH-1:0] VH_BY_VRES = 1
	"VW_BY_HRES_WIDTH": bits_vw_hres,
	"VW_BY_HRES_FRAC": PRECISION,
	"VH_BY_VRES_WIDTH": bits_vh_vres,
	"VH_BY_VRES_FRAC": PRECISION,
	"VW_BY_HRES": int(BinaryValue(vw_hres)),
	"VH_BY_VRES": int(BinaryValue(vh_vres)),
	"HRES_BY_VW_WIDTH": bits_hres_vw,
	"HRES_BY_VW_FRAC": PRECISION,
	"VRES_BY_VH_WIDTH": bits_vh_vres,
	"VRES_BY_VH_FRAC": PRECISION,
	"HRES_BY_VW": int(BinaryValue(hres_vw)),
	"VRES_BY_VH": int(BinaryValue(vres_vh)),
}


print("#PARAMETERS#")
print(parameters)
print("#PARAMETERS#")

XWIDTH = parameters["XWIDTH"]
YWIDTH = parameters["YWIDTH"]
ZWIDTH = parameters["ZWIDTH"]
XFRAC = parameters["XFRAC"]
YFRAC = parameters["YFRAC"]
ZFRAC = parameters["ZFRAC"]
FB_HRES = parameters["FB_HRES"]
FB_VRES = parameters["FB_VRES"]
# VH = parameters["VH"]
# VW = parameters["VW"]

VW_BY_HRES_WIDTH = parameters["VW_BY_HRES_WIDTH"]
VW_BY_HRES_FRAC = parameters["VW_BY_HRES_FRAC"]
VH_BY_VRES_WIDTH = parameters["VH_BY_VRES_WIDTH"]
VH_BY_VRES_FRAC = parameters["VH_BY_VRES_FRAC"]
HRES_BY_VW_WIDTH = parameters["HRES_BY_VW_WIDTH"]
HRES_BY_VW_FRAC = parameters["HRES_BY_VW_FRAC"]
VRES_BY_VH_WIDTH = parameters["VRES_BY_VH_WIDTH"]
VRES_BY_VH_FRAC = parameters["VRES_BY_VH_FRAC"]

VW_BY_HRES = parameters["VW_BY_HRES"]
VH_BY_VRES = parameters["VH_BY_VRES"]
HRES_BY_VW = parameters["HRES_BY_VW"]
VRES_BY_VH = parameters["VRES_BY_VH"]

xfam = FXfamily(XFRAC, XWIDTH - XFRAC)
yfam = FXfamily(YFRAC, YWIDTH - YFRAC)
zfam = FXfamily(ZFRAC, ZWIDTH - ZFRAC)
hres_vw_fam = FXfamily(HRES_BY_VW_FRAC, HRES_BY_VW_WIDTH - HRES_BY_VW_FRAC)
vres_vh_fam = FXfamily(VRES_BY_VH_FRAC, VRES_BY_VH_WIDTH - VRES_BY_VH_FRAC)
vw_hres_fam = FXfamily(VW_BY_HRES_FRAC, VW_BY_HRES_WIDTH - VW_BY_HRES_FRAC)
vh_vres_fam = FXfamily(VH_BY_VRES_FRAC, VH_BY_VRES_WIDTH - VH_BY_VRES_FRAC)


async def RisingEdgeCycles(dut, cycles):
	for _ in range(cycles):
		await RisingEdge(dut.clk_in)


async def reset_rasterizer(dut):
	dut.rst_in.value = 1
	await RisingEdge(dut.clk_in)
	await RisingEdge(dut.clk_in)
	assert dut.ready_out.value == 1
	assert dut.valid_out.value == 0
	dut.rst_in.value = 0
	await RisingEdge(dut.clk_in)


@cocotb.test()
async def test_rasterizer(dut):
	cocotb.start_soon(Clock(dut.clk_in, 2, units="ns").start())
	# ensure all params match
	for key, val in parameters.items():
		print(key, BinaryValue(val), BinaryValue(getattr(dut, key).value))

	await reset_rasterizer(dut)

	async def rasterize(triangle):
		# convert triangle into x y z value
		print("RASTERIZING")
		buffer = np.zeros((FB_VRES, FB_HRES))
		triangle = np.array(triangle)
		tri_x = [xfam(triangle[i][0]) for i in range(3)]
		tri_y = [yfam(triangle[i][1]) for i in range(3)]
		# tri_z = gen_random_vector(3, ZWIDTH, ZFRAC, zfam)
		tri_z = [zfam(i * 1000) for i in range(3)]

		# feed the inputs

		dut.valid_in.value = 1
		dut.ready_in.value = 1
		dut.x.value = BinaryValue(vec_to_bin(tri_x, XWIDTH))
		dut.y.value = BinaryValue(vec_to_bin(tri_y, YWIDTH))
		dut.z.value = BinaryValue(vec_to_bin(tri_z, ZWIDTH))

		# keep awaiting until the valid out is hit and read the hcount vcount values
		await RisingEdge(dut.clk_in)
		dut.valid_in.value = 0
		await RisingEdge(dut.clk_in)
		cycles = 0
		pixel_cycles = 0
		while dut.ready_out.value == 0:
			cycles += 1
			if dut.valid_out.value == 1:
				try:
					hcount = int(dut.hcount_out.value)
					vcount = int(dut.vcount_out.value)
					addr = vcount * FB_HRES + hcount
					addr_out = int(dut.addr_out.value)
					assert addr == addr_out
					buffer[vcount][hcount] = int(dut.z_out.value) / 2**ZFRAC
					pixel_cycles += 1
				except:
					print("MALFORMED PIXEL")

			await RisingEdge(dut.clk_in)

		# assert dut.ready_out.value == 1 # ensure the rasterizer is ready for the next triangle
		print("PIXEL CYCLE EFFICIENTY", pixel_cycles / cycles)

		# display_bitmap(buffer)
		display_frame_pixelized(buffer)
		print("RASTERIZATION DONE")

	# triangle = Triangle(vw, vh, rasterize)
	# triangle.show()

	for _ in range(10):
		triangle = generate_triangle_fast(vw, vh)
		await rasterize(triangle)


def main():
	"""Simulate the counter using the Python runner."""
	sim = os.getenv("SIM", "icarus")
	proj_path = Path(__file__).resolve().parent.parent
	sys.path.append(str(proj_path / "sim" / "model"))
	print(proj_path)
	sources = [
		proj_path
		/ "src"
		/ "hdl"
		/ "graphics"
		/ "rasterizer"
		/ "barycentric_interpolator.sv",
		proj_path / "src" / "hdl" / "graphics" / "common" / "barycentric_coeffs.sv",
		proj_path / "src" / "hdl" / "graphics" / "rasterizer" / "rasterizer.sv",
		proj_path / "src" / "hdl" / "graphics" / "rasterizer" / "inv_area.sv",
		proj_path / "src" / "hdl" / "common" / "fixed_point_slow_dot.sv",
		proj_path / "src" / "hdl" / "common" / "fixed_point_fast_dot.sv",
		proj_path / "src" / "hdl" / "common" / "fixed_point_mult.sv",
		proj_path / "src" / "hdl" / "common" / "fixed_adder.sv",
		proj_path / "src" / "hdl" / "common" / "pipeline.sv",
		proj_path / "src" / "hdl" / "common" / "fixed_point_div.sv",
		proj_path / "src" / "hdl" / "common" / "boundary_evt_counter.sv",
	]
	build_test_args = ["-Wall"]
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
	try:
		runner.test(
			hdl_toplevel="rasterizer",
			test_module="test_rasterizer",
			test_args=run_test_args,
			waves=True,
		)
	except KeyboardInterrupt:
		print("CLOSING")


if __name__ == "__main__":
	main()
