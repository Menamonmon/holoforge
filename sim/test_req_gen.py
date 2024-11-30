import cocotb
from cocotb.triggers import Timer
import os
from pathlib import Path
import sys

from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,ReadWrite,with_timeout, First, Join
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner
from cocotb.binary import BinaryValue

from random import getrandbits

def print_twos_complement(num, bit_size):
	# Mask the number to fit within the specified bit_size
	raw_binary = get_twos_complement(num, bit_size)
	print(f"{num} = {raw_binary}")


def get_twos_complement(num, bit_size):
	raw_binary = format(num & ((1 << bit_size) - 1), f"0{bit_size}b")
	return raw_binary


def pack_values(values, size):
	# pack the values in a string of bits
	return "".join([get_twos_complement(v, size) for v in reversed(values)])


async def reset(rst,clk):
    """ Helper function to issue a reset signal to our module """
    rst.value = 1
    await RisingEdge(clk)
    rst.value = 0
    await RisingEdge(clk)

async def basic_stacking_test(dut,hlist,vlist,data,rdy_list): 
    #test if it like actually stacks properly
    addr_out=hlist[0]+(hlist[0]*vlist[0])
    data_out=pack_values(data,16)
    print(data_out)
    for i in range(8):
        dut.valid_in.value=1
        dut.hcount.value=hlist[i]
        dut.vcount.value=vlist[i]
        print(vlist)
        dut.color.value=data[i]
        dut.rdy_in.value=1
        await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)
    assert dut.valid_out==1
    assert dut.data_out==BinaryValue(data_out,n_bits=128,bigEndian=False)
# async def anul(dut,hlist,vlist,data,rdy_list):
#     #first half should calc right values
#     expec_vals_out
#     for i in range()

@cocotb.test()
async def test_pattern(dut):
    """ Your simulation test!
        TODO: Flesh this out with value sets and print statements. Maybe even some assertions, as a treat.
    """
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.hcount.value=0
    dut.vcount.value=0
    dut.color.value=0
    dut.frame.value=0
    dut.mask_zero.value=0
    dut.rdy_in.value=0
    dut.valid_in.value=0
    await reset(dut.rst_in,dut.clk_in)
    basic_hcount=[0,1,2,3,4,5,6,7]
    basic_vcount=[0,0,0,0,0,0,0,0]
    basic_data=[0,10,0,20,0,10,30,10]
    basic_rdy_list=[1,1,1,1,1,1,1,1]
    await basic_stacking_test(dut,basic_hcount,basic_vcount,basic_data,basic_rdy_list)
    basic_hcount=[0,1,2,3,4,5,6,7]
    basic_vcount=[0,0,0,0,0,0,0,0]
    basic_data=[0,10,0,200,1000,1000,30,10]
    basic_rdy_list=[1,1,1,1,1,1,1,1]
    await basic_stacking_test(dut,basic_hcount,basic_vcount,basic_data,basic_rdy_list)


     


def test_TEST_NAME(): #chang ethis
    """Boilerplate code"""
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [
        proj_path / "src" /"hdl"/ "graphics"/ "framebuffer"/ "mig_write_req_generator.sv"
        ] #change this
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="mig_write_req_generator", #change this
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="mig_write_req_generator", #change this
        test_module="test_req_gen", #change this
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    test_TEST_NAME() #CHANGE THIS
