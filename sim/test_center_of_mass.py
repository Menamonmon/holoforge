import os
import sys
from pathlib import Path
import random

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import (
    ReadOnly, ClockCycles
)

IMAGE_HEIGHT = 256
IMAGE_WIDTH = 256

def generate_random_region(x_max, y_max):
    x_min = random.randint(0, x_max // 2)
    y_min = random.randint(0, y_max // 2)
    x_max = random.randint(x_min + 1, x_max)
    y_max = random.randint(y_min + 1, y_max)
    return x_min, x_max, y_min, y_max

@cocotb.test()
async def test_center_of_mass(dut):
	cocotb.start_soon(
		Clock(dut.clk_in, 1, units="ns").start()
	)  # Slower clock for clk_in

	dut.rst_in.value = 1
	
	await ClockCycles(dut.clk_in, 10)

	dut.rst_in.value = 0
	await ClockCycles(dut.clk_in, 10)
	
	print("dut.valid_out.value: ", dut.valid_out.value)
	print("dut.x_out.value: ", dut.x_out.value)
	print("dut.y_out.value: ", dut.y_out.value)
	print("dut.x_sum.value: ", dut.x_sum.value)
	print("dut.y_sum.value: ", dut.y_sum.value)
	print("dut.pixel_count.value: ", dut.pixel_count.value)
 
	assert dut.valid_out.value == 0 and dut.x_out.value == 0 and dut.y_out.value == 0 and dut.x_sum.value == 0 and dut.y_sum.value == 0 and dut.pixel_count.value == 0, "Initial values are not zero"

 
	
	for frame in range(20):
		x_min, x_max, y_min, y_max = generate_random_region(IMAGE_WIDTH, IMAGE_HEIGHT)
		for y in range(IMAGE_HEIGHT):
			for x in range(IMAGE_WIDTH):
				if x >= x_min and x <= x_max and y >= y_min and y <= y_max:
					dut.x_in.value = x
					dut.y_in.value = y

					dut.valid_in.value = 1
					await ClockCycles(dut.clk_in, 1)

				dut.valid_in.value = 0
				await ClockCycles(dut.clk_in, 1)
		# tabulate signal
		dut.tabulate_in.value = 1

		await ClockCycles(dut.clk_in, 1)

		dut.tabulate_in.value = 0
		
		for i in range(1000):
			await ClockCycles(dut.clk_in, 1)
			if (dut.valid_out.value == 1):
				print("dut.x_out.value: ", int(dut.x_out.value), sum(range(x_min, x_max + 1)) // (x_max - x_min + 1))
				print("dut.y_out.value: ", int(dut.y_out.value), sum(range(y_min, y_max + 1)) // (y_max - y_min + 1))
				assert int(dut.x_out.value) == sum(range(x_min, x_max + 1)) // (x_max - x_min + 1), "x_out value is not correct"
				assert int(dut.y_out.value) == sum(range(y_min, y_max + 1)) // (y_max - y_min + 1), "y_out value is not correct"
				print("random region: ", x_min, x_max, y_min, y_max)
				break
		# while dut.valid_out.value == 0:
		# 	await ClockCycles(dut.clk_in, 1)
		# 	if (dut.valid_out.value == 1):
		# 		print("dut.x_out.value: ", dut.x_out.value)
		# 		print("dut.y_out.value: ", dut.y_out.value)
		# 		break



	

def main():
    """Simulate the counter using the Python runner."""
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "center_of_mass.sv", proj_path / "hdl" / "divider.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="center_of_mass",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="center_of_mass",
        test_module="test_center_of_mass",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    main()
