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

async def basic_stacking_test(dut,hlist,vlist,data,rdy_list,mask): 
    #test if it like actually stacks properly
    addr_out=hlist[0]+(hlist[0]*vlist[0])
    data_out=pack_values(data,16)
    expec_strob="0000000000000000"
    
    for meow in range(len(hlist)):
        i=meow%8
        dut.valid_in.value=1
        dut.hcount.value=hlist[i]
        dut.vcount.value=vlist[i]
        dut.color.value=data[i]
        dut.mask_zero.value=mask[i]
        dut.rdy_in.value=1
        if(mask[i]==0):
            expec_strob= expec_strob[:i*2] + "11" + expec_strob[i*2+2:]
        print(expec_strob)
        print(len(expec_strob))
        await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)
    print("meow2",BinaryValue(data_out,n_bits=128,bigEndian=False))
    assert dut.valid_out==1
    assert dut.strobe_out==BinaryValue(expec_strob[::-1],n_bits=16,bigEndian=False)
    assert dut.data_out==BinaryValue(data_out,n_bits=128,bigEndian=False)


async def better_test(dut,hlist,vlist,data,rdy_list,mask):
    data_stack = [0] * 8
    strobe_stack = ['0'] * 16
    currently_stacking = False
    prev_index = -1
    index = -1
    prev_addr = None
    next_addr = None
    state = 'STACKING'
    rdy_in = 1  

    #6.006 was not a wast of time!
    valid_out=[0]
    data_out=[None]
    strobe_out=[None]

    for i in range(len(hlist)):
        #drive inputs
        dut.valid_in.value=1
        dut.hcount.value=hlist[i]
        dut.vcount.value=vlist[i]
        dut.color.value=data[i]
        dut.mask_zero.value=mask[i]
        dut.rdy_in.value=rdy_list[i]

        #update internal vals
        addr=hlist[i] + 320*vlist[i]
        prev_index=index
        index=addr & 7
        if next_addr is None:
            next_addr=addr+1
        misaligned=(addr!=next_addr)

        output_next_cycle=False
        #do the stacking ourselves now
        if not currently_stacking:
            #set vals accoridngly
            data_stack[index]=data[i]
            if mask[i] == 0:
                    strobe_stack[index*2] = '1'
                    strobe_stack[index*2+1] = '1'
            #house keeping
            next_addr=addr+1
            currently_stacking=True
            prev_index=index
        else:
            if misaligned:
                output_next_cycle=True
                currently_stacking=False
            else:
                #we're alligned and we keep stacking
                data_stack[index] = data[i]
                if mask[i] == 0:
                    strobe_stack[index*2] = '1'
                    strobe_stack[index*2+1] = '1'
                next_addr = addr + 1
                if index == 7:
                    output_next_cycle = True
                    currently_stacking = False
        if output_next_cycle:
            #prep to return the data
            valid_out.append(1)
            #yoink new data_out
            data_out_packed=pack_values(data_stack,16)
            data_out_val=BinaryValue(data_out_packed,n_bits=128,bigEndian=False)
            data_out.append(data_out_val)
            #yoink new str_out
            strobe_out_str=''.join(strobe_stack[::-1])
            strobe_out.append(strobe_out_str)
            #reset data_stack and strobe_stack
            data_stack=[0]*8
            strobe_stack=['0']*16
            #start yoinking new data if valid (cause it lowkey dosen't matter if we're misaligned or alligned)
            data_stack[index] = data[i]
            if mask[i] == 0:
                strobe_stack[index*2] = '1'
                strobe_stack[index*2+1] = '1'
            next_addr = addr + 1
            currently_stacking = True
        else:
            valid_out.append(0)
            data_out.append(None)
            strobe_out.append(None)
        await RisingEdge(dut.clk_in)
        print(valid_out[0],dut.valid_out)
        if valid_out[0]==1:
            assert dut.valid_out.value==1
            print(data_out[0])
            print(dut.data_out.value)
            print(strobe_out[0])
            print(dut.strobe_out)
            assert dut.data_out.value==data_out[0]
            assert dut.strobe_out.value==strobe_out[0]
            print("meowith")
        data_out.pop(0)
        strobe_out.pop(0)
        valid_out.pop(0)
                
            

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
    basic_hcount=[x for x in range(24)]
    basic_vcount=[0,0,0,1,0,1,0,1]*3
    # basic_vcount=[0,0,0,0]+[2 for i in range(24)]
    basic_data=[0,10,0,20,0,10,30,10]*3
    basic_rdy_list=[1,1,1,1,1,1,1,1]*3
    mask_list=[0,0,1,0,0,0,0,0]*3

    #one flaw in this test bench is i need the extra cycle but the valid ins will save me here
    await better_test(dut,basic_hcount,basic_vcount,basic_data,basic_rdy_list,mask_list)
    # await basic_stacking_test(dut,basic_hcount,basic_vcount,basic_data,basic_rdy_list,mask_list)
    basic_hcount=[0,1,2,3,4,5,6,7,1]
    basic_vcount=[0,0,0,0,0,0,0,0,0]
    basic_data=[0,10,0,200,1000,1000,30,10,1]
    basic_rdy_list=[1,1,1,1,1,1,1,1]


     


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
