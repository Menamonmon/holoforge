import os
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import (
	ClockCycles
)
import struct
import libscrc
import random

crc32 = libscrc.mpeg2

def reverse_bits(n,size):
    reversed_n = 0
    for i in range(size):
        reversed_n = (reversed_n << 1) | (n & 1)
        n >>= 1
    return reversed_n

@cocotb.test()
async def test_crc32_mpeg2(dut):
	# create clock
	cocotb.start_soon(
		Clock(dut.clk_in, 1, units="ns").start()
	)  # Slower clock for clk_in
	
	async def reset():
		dut.rst_in = 1
		await ClockCycles(dut.clk_in, 10)
		assert dut.data_out == 0xFFFF_FFFF
		dut.rst_in = 0
		dut.data_valid_in = 0
		await ClockCycles(dut.clk_in, 10)
		assert dut.data_out == 0xFFFF_FFFF

	await reset()


	TESTS = [random.randint(-sys.maxsize-1, sys.maxsize) for i in range(100)]
	def get_crc32_mpeg2(data):
		return libscrc.mpeg2(struct.pack('>L', data))
	
	for test in TESTS:
		await reset()
		crc = get_crc32_mpeg2(test)
		# feed in the data into dut starting with msb
  
		for i in range(32):
			msb = (test >> (31 - i)) & 1
			print(msb)
			dut.data_in = msb
			dut.data_valid_in = 1
			await ClockCycles(dut.clk_in, 1)
			dut.data_valid_in = 0
			dut.data_in = random.randint(0, 1)
			await ClockCycles(dut.clk_in, 3)
			out = int(dut.data_out)
			# local_crc = get_crc32_mpeg2(test >> (31 - i))
			# assert out == crc, f"crc32({hex(test)}) = {hex(crc)} != {hex(out)}"

		await ClockCycles(dut.clk_in, 1)
		out = int(dut.data_out)
		assert out == crc, f"crc32({hex(test)}) = {hex(crc)} != {hex(out)}"


	
	



def main():
    """Simulate the counter using the Python runner."""
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "crc32_mpeg2.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="crc32_mpeg2",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="crc32_mpeg2",
        test_module="test_crc32_mpeg2",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    main()
