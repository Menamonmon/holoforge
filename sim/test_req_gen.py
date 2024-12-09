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
import random

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
		dut.data_in.value=data[i]
		dut.strobe_in.value=mask[i]
		dut.ready_in.value=1
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


async def better_test(dut):
	# a better test is we get a 2d array, we also just get a list of RDY,ins 
	# and rdy_outs, we step through the 2D array randomly toggling ready_in ready_out
	#we make python code that can handle it then yeah

	grid=[]
	HRES=64
	VRES=36
	addr_width = ((HRES + (HRES * VRES)) // 2 - 1).bit_length()
	grid = []
	for vcount in range(VRES):  # vcount from 0 to VRES - 1
		row = []
		for hcount in range(HRES):  # hcount from 0 to HRES - 1
			# Each cell: [hcount, vcount, color, mask_zero, valid_in]
			color = random.choice([0,0xFFFF])
			# color = 5
			# mask_zero = random.choice([0, 1])
			mask_zero=0
			valid_in = random.choice([0,1])  # Random valid_in
			# valid_in=1
			# print(mask_zero)
			# print(valid_in)
			frame = random.choice([0,1])
			row.append([hcount, vcount, color, mask_zero, valid_in,frame])
		grid.append(row)
	
	#statey vars
	data_stack = [0] * 8
	strobe_stack = ['0'] * 16
	currently_stacking = False
	prev_index = -1
	index = -1
	next_addr = None
	valid_out_queue = []
	data_out_queue = []
	strobe_out_queue = []
	addr_out_queue = []
	prev_addr = None

	num_cycles = len(grid) * len(grid[0]) + 100  # Extra cycles for output
	# rdy_list = [1 for _ in range(num_cycles)]
	rdy_list=([1]*5+[0]*50)*50


	total_cycles = num_cycles
	cycle = 0
	input_index = 0  # Index to keep track of current input position
	input_length = len(grid) * len(grid[0])
	IDLE = 0
	STACKING = 1
	HOLD = 2
	state = IDLE
	next_state = IDLE
	expec_valid_out_next_cycle=0


	def enq_outputs(data,strobe,addr,frame):
		valid_out_queue.append(1)
		data_out_queue.append(pack_values(data,16))
		strobe_out_queue.append(''.join(strobe[::-1]))
		addr_out_val=(frame<<(addr_width+4)|(addr<<4))
		addr_out_queue.append(addr_out_val)


	print(total_cycles,"cycles")
	while cycle < total_cycles:
		 #rdy_in is first concern

		rdy_in = rdy_list[cycle]

		#if we have valid_data on the queue
		will_be_ready = (len(valid_out_queue) == 0) or rdy_in

		valid_in = 0
		hcount = 0
		vcount = 0
		color = 0
		mask_zero = 0
		if state == IDLE or state == STACKING:
			if input_index < input_length:
				#so if we're out of vars this lets get rid of whatever current on the line
				hcount, vcount, color, mask_zero, valid_in,frame = grid[input_index // HRES][input_index % HRES]
				addr = hcount + (HRES * vcount)
				index = addr & 7
				strobe_index = index << 1
				print("input index",input_index)
				print(addr,next_addr,"addys")
				# print(input_index,"nmeow")
				# print(valid_in)
				input_index+=1
				if valid_in and will_be_ready:
					if state == IDLE:
						data_stack = [0] * 8
						strobe_stack = ['0'] * 16
						next_addr = addr + 1
						prev_addr = addr
					else:
						print(addr,next_addr,"addresse")
						if addr!=next_addr:
						#Missalinged send data start clean
							print("mis allign")
							enq_outputs(data_stack.copy(),strobe_stack.copy(),prev_addr,frame)
							data_stack = [0] * 8
							strobe_stack = ['0'] * 16
							prev_addr = addr
							next_addr = addr + 1
							if will_be_ready:
								state=STACKING
							else:
								state=HOLD
								next_state=STACKING
					#stack data
					data_stack[index] = color
					if(not mask_zero):
						strobe_stack[strobe_index]="0"
						strobe_stack[strobe_index+1]="0"
					else:
						strobe_stack[strobe_index]="1"
						strobe_stack[strobe_index+1]="1"
					prev_index = index
					next_addr = addr + 1
					currently_stacking=True
					print(index,"index")
					if index == 7:
						print("fully stacked")
						enq_outputs(data_stack.copy(),strobe_stack.copy(),prev_addr,frame)
						# print(pack_values(data_stack,16),"we have data")
						# print(strobe_stack)
						currently_stacking = False
						if will_be_ready:
							state = IDLE
						else:
							state = HOLD
							next_state = IDLE
					else:
						state = STACKING
		elif state==HOLD:
			print("in hold")
			valid_in=1
			if rdy_in:
				state=next_state
			else:
				pass
		#drive inputs
		dut.valid_in.value=valid_in
		dut.hcount.value=hcount
		dut.vcount.value=vcount
		dut.data_in.value=color
		dut.strobe_in.value=mask_zero
		dut.ready_in.value=rdy_in
		await RisingEdge(dut.clk_in)
		cycle+=1
		# print(cycle)
		# print(valid_out_queue)
		#now we compare outputs
		if expec_valid_out_next_cycle==1:
			expec_valid_out_next_cycle=0
			print(dut.valid_out,"valid_out_in_the_you_get_the_poiint")
			# assert dut.valid_out==1
			# assert dut.data_out==data_out_queue.pop(0)
			print("stroe anity check")
			print(dut.strobe_out,"dut")
			print(strobe_out_queue[0],"test strobe_out")
			# assert dut.strobe_out==strobe_out_queue.pop(0)
			print("meow")
		if valid_out_queue:
			print(valid_out_queue,"Python valid")
			print(dut.valid_out.value,"Verilog valid")
			expec_valid_out_next_cycle=1
			valid_out_queue.pop(0)
		else:
			expec_valid_out=0




	# data_stack = [0] * 8
	# strobe_stack = ['0'] * 16
	# currently_stacking = False
	# prev_index = -1
	# index = -1
	# prev_addr = None
	# next_addr = None
	# state = 'STACKING'
	# rdy_in = 1  

	# #6.006 was not a wast of time!
	# valid_out=[0]
	# data_out=[None]
	# strobe_out=[None]

	# for i in range(len(hlist)):
	#     #drive inputs
	#     dut.valid_in.value=1
	#     dut.hcount.value=hlist[i]
	#     dut.vcount.value=vlist[i]
	#     dut.color.value=data[i]
	#     dut.mask_zero.value=mask[i]
	#     dut.rdy_in.value=rdy_list[i]

	#     #update internal vals
	#     addr=hlist[i] + 320*vlist[i]
	#     prev_index=index
	#     index=addr & 7
	#     if next_addr is None:
	#         next_addr=addr+1
	#     misaligned=(addr!=next_addr)

	#     output_next_cycle=index==7
	#     #do the stacking ourselves now
	#     if not currently_stacking:
	#         #set vals accoridngly
	#         data_stack[index]=data[i]
	#         if mask[i] == 0:
	#                 strobe_stack[index*2] = '1'
	#                 strobe_stack[index*2+1] = '1'
	#         #house keeping
	#         next_addr=addr+1
	#         currently_stacking=True
	#         prev_index=index
	#     else:
	#         if misaligned:
	#             output_next_cycle=True
	#             currently_stacking=False
	#         else:
	#             #we're alligned and we keep stacking
	#             data_stack[index] = data[i]
	#             if mask[i] == 0:
	#                 strobe_stack[index*2] = '1'
	#                 strobe_stack[index*2+1] = '1'
	#             next_addr = addr + 1
	#             if index == 7:
	#                 output_next_cycle = True
	#                 currently_stacking = False
	#     if output_next_cycle:
	#         #prep to return the data
	#         valid_out.append(1)
	#         #yoink new data_out
	#         data_out_packed=pack_values(data_stack,16)
	#         data_out_val=BinaryValue(data_out_packed,n_bits=128,bigEndian=False)
	#         data_out.append(data_out_val)
	#         #yoink new str_out
	#         strobe_out_str=''.join(strobe_stack[::-1])
	#         strobe_out.append(strobe_out_str)
	#         #reset data_stack and strobe_stack
	#         data_stack=[0]*8
	#         strobe_stack=['0']*16
	#         #start yoinking new data if valid (cause it lowkey dosen't matter if we're misaligned or alligned)
	#         data_stack[index] = data[i]
	#         if mask[i] == 0:
	#             strobe_stack[index*2] = '1'
	#             strobe_stack[index*2+1] = '1'
	#         next_addr = addr + 1
	#         currently_stacking = True
	#     else:
	#         valid_out.append(0)
	#         data_out.append(None)
	#         strobe_out.append(None)
	#     await RisingEdge(dut.clk_in)
	#     print(valid_out[0],dut.valid_out)
	#     if valid_out[0]==1:
	#         assert dut.valid_out.value==1
	#         print(data_out[0])
	#         print(dut.data_out.value)
	#         print(strobe_out[0])
	#         print(dut.strobe_out)
	#         assert dut.data_out.value==data_out[0]
	#         assert dut.strobe_out.value==strobe_out[0]
	#         print("meowith")
	#     data_out.pop(0)
	#     strobe_out.pop(0)
	#     valid_out.pop(0)
				
			
			

@cocotb.test()
async def test_pattern(dut):
	""" Your simulation test!
		TODO: Flesh this out with value sets and print statements. Maybe even some assertions, as a treat.
	"""
	cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
	dut.hcount.value=0
	dut.vcount.value=0
	dut.data_in.value=0
	dut.strobe_in.value=0
	dut.ready_in.value=0
	dut.valid_in.value=0
	await reset(dut.rst_in,dut.clk_in)
	# (hcount,vcount,valid_in,rdy_in,mask_zero,)
	grid=[]
	HRES=64
	VRES=32
	addr_width = ((HRES + (HRES * VRES)) // 2 - 1).bit_length()
	grid = []
	valid_grid=[]
	for vcount in range(VRES):  # vcount from 0 to VRES - 1
		row = []
		valid_row=[]
		for hcount in range(HRES):  # hcount from 0 to HRES - 1
			valid_row.append(1)
			row.append(random.randint(0,0xFFFF))
		grid.append(row)
		valid_grid.append(valid_row)

	out_req=[]
	x=1
	for vcount in range(VRES):
		for hcount in range(HRES):
			dut.valid_in.value=valid_grid[vcount][hcount]
			# dut.ready_in.value=random.randint(0,1)
			strobe_in=1
			dut.strobe_in.value=strobe_in
			dut.data_in.value=grid[vcount][hcount]
			if(strobe_in==0 or valid_grid[vcount][hcount]==0):
				grid[vcount][hcount]=None
			dut.hcount.value=hcount
			dut.vcount.value=vcount
			
			# dut.ready_in.value=0
			# x=75
			# for _ in range(x):
			# 	await RisingEdge(dut.clk_in)
			dut.ready_in.value=1

			while dut.ready_out.value==0:
				await RisingEdge(dut.clk_in)
				if(dut.valid_out.value==1 and dut.ready_in.value==1):
					out_req.append([dut.data_out.value,dut.strobe_out.value,dut.addr_out.value])

			await RisingEdge(dut.clk_in)
			if(dut.valid_out.value==1 and dut.ready_in.value==1):
				out_req.append([dut.data_out.value,dut.strobe_out.value,dut.addr_out.value])
	for _ in range(random.randint(0,200)):
		dut.valid_in.value=0
		dut.hcount.value=random.randint(0,63)
		dut.vcount.value=random.randint(0,31)
		await RisingEdge(dut.clk_in)
		if(dut.valid_out.value==1 and dut.ready_in.value==1):
			out_req.append([dut.data_out.value,dut.strobe_out.value,dut.addr_out.value])
	ans_grid=[[None for _ in range(HRES)] for __ in range(VRES)]
	for ans in out_req:
		raw_addr=ans[2]<<3
		data=ans[0]
		strobe=ans[1]
		for i in range(8):
			cur_addr=raw_addr+i
			# print(cur_addr//HRES,"addr")
			# print(cur_addr)
			# print(len(grid),"grid")
			# print(len(grid[0]),"grid again")
			flip=8-i-1
			if(strobe.binstr[2*flip:2*flip+2]=="11"):
				ans_grid[cur_addr//HRES][cur_addr%HRES]=int(data.binstr[flip*16:(flip+1)*16],2)
	for vcount in range(VRES):
		for hcount in range(HRES):
			print(hcount,vcount,valid_grid[vcount][hcount],"coords")
			print(ans_grid[vcount][hcount],"answer")
			print(grid[vcount][hcount],"out grid")
			assert ans_grid[vcount][hcount]==grid[vcount][hcount]
		





	#one flaw in this test bench is i need the extra cycle but the valid ins will save me here
	# await better_test(dut)
	# await basic_stacking_test(dut,basic_hcount,basic_vcount,basic_data,basic_rdy_list,mask_list)
	


	 


def test_TEST_NAME(): #chang ethis
	"""Boilerplate code"""
	sim = os.getenv("SIM", "icarus")
	proj_path = Path(__file__).resolve().parent.parent
	sys.path.append(str(proj_path / "sim" / "model"))
	sources = [
		proj_path / "src" /"hdl"/ "graphics"/ "framebuffer"/ "pixel_stacker.sv"
		] #change this
	build_test_args = ["-Wall"]
	parameters = {}
	sys.path.append(str(proj_path / "sim"))
	runner = get_runner(sim)
	runner.build(
		sources=sources,
		hdl_toplevel="pixel_stacker", #change this
		always=True,
		build_args=build_test_args,
		parameters=parameters,
		timescale = ('1ns','1ps'),
		waves=True
	)
	run_test_args = []
	runner.test(
		hdl_toplevel="pixel_stacker", #change this
		test_module="test_req_gen", #change this
		test_args=run_test_args,
		waves=True
	)

if __name__ == "__main__":
	test_TEST_NAME() #CHANGE THIS
