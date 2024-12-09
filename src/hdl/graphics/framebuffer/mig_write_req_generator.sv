// `timescale 1ns / 1ps
// module mig_write_req_generator #(
//     parameter HRES=320,
//     parameter VRES=180
//     )(
//     input wire clk_in,
//     input wire rst_in,
//     input wire [hres_width-1:0] hcount,
//     input wire [vres_width-1:0] vcount,
//     input wire [15:0] color,
//     input wire frame,
//     input wire mask_zero,
//     input wire rdy_in,//coming from out_fifo
//     input wire valid_in,//coming from rasterizer
//     //output logic
//     output logic rdy_out,//back propagating rdy_in from out_fifo
//     output logic [addr_width]addr_out,
//     output logic [7:0][15:0]data_out,
//     output logic [15:0]strobe_out,
//     output logic valid_out
// );
//     localparam addr_width=$clog2((HRES+(HRES*VRES))/2);
//     localparam hres_width=$clog2(HRES);
//     localparam vres_width=$clog2(VRES);
//     localparam addr_out_width=27;
//     localparam addr_left_over=27-(addr_width+1+1);

//     enum logic [1:0]{
//         IDLE,
//         STACKING,
//         HOLD
//     } state;

//     enum logic {
//         NEXT_IDLE,
//         NEXT_STACKING
//     }   prev_state;
    
//     //internal var
//     logic [7:0][15:0] data;
//     logic [addr_width-1:0] addr;
//     logic [15:0] strobe;
//     logic [3:0] index;
//     logic [3:0] prev_index;
//     logic [addr_width-1:0] next_addr;
//     logic currently_stacking;
//     logic [3:0] strobe_index;
//     logic will_be_ready;
//     logic [7:0] emergen_c_data;
//     logic [25:0] emergen_c_add;
//     logic next_state;
//     logic [addr_width:0] prev_addr;


//     always_comb begin
//         addr=hcount+(HRES*vcount);
//         index=addr[2:0];
//         strobe_index=index<<1;
//         //need to be done
//         will_be_ready=(!valid_out || (rdy_in));
//         rdy_out=will_be_ready;
//     end

//     always_ff@(posedge clk_in)begin
//         if (rst_in)begin
//             data<=128'b0;
//             strobe<=16'b0;
//             prev_index<=4'b0;
//             currently_stacking<=0;
//             next_addr<=128'b0;
//             valid_out<=0;
//             data_out<=128'b0;
//             state<=STACKING;
//             addr_out<=0;
//             strobe_out<=0;
//             prev_state<=0;
//         end else begin
//         case(state)
//         IDLE:begin
//             if(valid_in && rdy_out)begin
//                 next_addr<=addr+1;
//                 prev_index<=index;
//                 data[addr[2:0]]<=color;
//                 prev_addr<=addr;
//                 case(index)
//                     0:begin
//                         strobe[1:0]<=2'b11;  
//                     end
//                     1:begin
//                         strobe[3:0]<={2'b11,2'b0};
//                     end
//                     2:begin
//                         strobe[5:0]<={2'b11,4'b0};
//                     end
//                     3:begin
//                         strobe[7:0]<={2'b11,6'b0};
//                     end
//                     4:begin
//                         strobe[9:0]<={2'b11,8'b0};
//                     end
//                     5:begin
//                         strobe[11:0]<={2'b11,10'b0};
//                     end
//                     6:begin
//                         strobe[13:0]<={2'b11,12'b0};
//                     end
//                     7:begin
//                         strobe[15:0]<={2'b11,14'b0};
//                     end
//                 endcase
//                 if(index==7)begin
//                     valid_out<=1;
//                     data_out<={color,data[6:0]};
//                     strobe_out<={{2{!mask_zero}},14'b0};
//                     addr_out<={frame,addr<<4};
//                     if(will_be_ready)begin
//                         state<=IDLE;
//                     end else begin
//                         state<=HOLD;
//                         next_state<=NEXT_IDLE;
//                     end 
//                 end else begin
//                     state<=STACKING;
//                 end 

//             end
//         end

//         STACKING:begin
//             if(valid_in)begin
//                 if(addr==next_addr)begin
//                     next_addr<=addr+1;
//                     data[index]<=color;
//                     strobe[strobe_index]<=(mask_zero)? 1'b0:1'b1;
//                     strobe[strobe_index+1]<= (mask_zero)? 1'b0:1'b1;
//                     prev_index<=index;
//                     prev_addr<=addr;
//                     if(index==7)begin
//                         data_out<={color,data[6:0]};
//                         valid_out<=1;
//                         strobe_out<={{2{!mask_zero}},strobe[13:0]};
//                         addr_out<={frame,addr<<4};
//                         if(will_be_ready)begin
//                             state<=IDLE;
//                         end else begin
//                             state<=HOLD;
//                             next_state<=NEXT_STACKING;
//                         end
//                     end
//                 end else begin
//                     //we're missalligned
//                     if(!will_be_ready)begin
//                         state<=HOLD;
//                         next_state=NEXT_STACKING;
//                     end
//                     valid_out<=1;
//                     addr_out<={frame,prev_addr<<4};
//                     prev_addr<=addr;
//                     case(prev_index)
//                             0:begin
//                                 data_out<={112'b0,data[0]};
//                                 strobe_out<={14'b0,strobe[1:0]};
//                             end
//                             1:begin
//                                 data_out <= {96'b0, data[1:0]};
//                                 strobe_out<={12'b0,strobe[3:0]};
//                             end
//                             2: begin
//                                 data_out <= {80'b0, data[2:0]};
//                                 strobe_out <= {10'b0, strobe[5:0]};
//                             end
//                             3: begin
//                                 data_out <= {64'b0, data[3:0]};
//                                 strobe_out <= {8'b0, strobe[7:0]};
//                             end
//                             4: begin
//                                 data_out <= {48'b0, data[4:0]};
//                                 strobe_out <= {6'b0,strobe[9:0]}; 
//                             end
//                             5: begin
//                                 data_out <= {32'b0, data[5:0]};
//                                 strobe_out <= {4'b0, strobe[11:0]};
//                             end
//                             6: begin
//                                 data_out <= {16'b0, data[6:0]};
//                                 strobe_out <= {2'b0, strobe[13:0]};
//                             end
//                             7:begin
//                                 data_out<=data;
//                                 strobe_out<=strobe;
//                             end
//                     endcase
//                     //we have new data in need to allign it
//                     prev_index<=index;
//                     next_addr<=addr+1;
//                     case(addr[2:0])
//                         0:begin
//                             data[0]<=color;
//                             strobe[1:0]<=2'b11;  
//                         end
//                         1:begin
//                             data[1:0]<={color,16'b0};
//                             strobe[3:0]<={2'b11,2'b0};
//                         end
//                         2:begin
//                             data[2:0]<={color,32'b0};
//                             strobe[5:0]<={2'b11,4'b0};
//                         end
//                         3:begin
//                             data[3:0]<={color,48'b0};
//                             strobe[7:0]<={2'b11,6'b0};
//                         end
//                         4:begin
//                             data[4:0]<={color,64'b0};
//                             strobe[9:0]<={2'b11,8'b0};
//                         end
//                         5:begin
//                             data[5:0]<={color,80'b0};
//                             strobe[11:0]<={2'b11,10'b0};
//                         end
//                         6:begin
//                             data[6:0]<={color,96'b0};
//                             strobe[13:0]<={2'b11,12'b0};
//                         end
//                         7:begin
//                             data<={color,112'b0};
//                             strobe[15:0]<={2'b11,14'b0};
//                         end
//                     endcase
//                 end
//             end
//         end

//         HOLD:begin
//             if(rdy_in)begin
//                 if(next_state==NEXT_STACKING)begin
//                     state<=STACKING;
//                 end else begin
//                     state<=IDLE;
//                 end
//             end 
//         end
//         endcase
//         //other logic
//         if(rdy_in && valid_out)begin
//             valid_out<=0;
//         end
//         end
//     end
// endmodule
// // import cocotb
// // from cocotb.triggers import RisingEdge
// // import random

// // @cocotb.test()
// // async def better_test(dut):
// //     # Parameters
// //     HRES = dut.HRES.value.integer
// //     VRES = dut.VRES.value.integer

// //     # Derived parameters
// //     addr_width = ((HRES + (HRES * VRES)) // 2 - 1).bit_length()
// //     hres_width = (HRES - 1).bit_length()
// //     vres_width = (VRES - 1).bit_length()

// //     # Initialize DUT inputs
// //     dut.clk_in.value = 0
// //     dut.rst_in.value = 1
// //     dut.valid_in.value = 0
// //     dut.hcount.value = 0
// //     dut.vcount.value = 0
// //     dut.color.value = 0
// //     dut.mask_zero.value = 0
// //     dut.rdy_in.value = 1  # Start with ready
// //     dut.frame.value = 0

// //     # Reset the DUT
// //     await RisingEdge(dut.clk_in)
// //     for _ in range(5):
// //         await RisingEdge(dut.clk_in)
// //     dut.rst_in.value = 0

// //     # Clock generation
// //     cocotb.start_soon(clock_gen(dut))

// //     # Grid initialization
// //     grid = []
// //     for vcount in range(9):  # vcount from 0 to 8
// //         row = []
// //         for hcount in range(8):  # hcount from 0 to 7
// //             # Each cell: [hcount, vcount, color, mask_zero, valid_in]
// //             color = random.randint(0, 0xFFFF)
// //             mask_zero = random.choice([0, 1])
// //             valid_in = 1  # For this test, we set valid_in to 1
// //             row.append([hcount, vcount, color, mask_zero, valid_in])
// //         grid.append(row)

// //     # Variables for internal emulation
// //     data_stack = [0] * 8
// //     strobe_stack = ['0'] * 16
// //     prev_index = -1
// //     index = -1
// //     next_addr = None
// //     valid_out_queue = []
// //     data_out_queue = []
// //     strobe_out_queue = []
// //     addr_out_queue = []
// //     prev_addr = None

// //     # Simulate rdy_in randomly
// //     num_cycles = len(grid) * len(grid[0]) + 100  # Extra cycles for output
// //     rdy_list = [random.choice([0, 1]) for _ in range(num_cycles)]

// //     total_cycles = num_cycles
// //     cycle = 0
// //     input_index = 0  # Index to keep track of current input position
// //     input_length = len(grid) * len(grid[0])

// //     # Simulated State Machine
// //     IDLE = 0
// //     STACKING = 1
// //     HOLD = 2
// //     state = IDLE
// //     next_state = IDLE

// //     # Main test loop
// //     while cycle < total_cycles:
// //         # Update rdy_in
// //         rdy_in = rdy_list[cycle]
// //         dut.rdy_in.value = rdy_in

// //         # Determine will_be_ready based on internal valid_out and rdy_in
// //         will_be_ready = (len(valid_out_queue) == 0) or rdy_in

// //         # Initialize input values
// //         valid_in = 0
// //         hcount = 0
// //         vcount = 0
// //         color = 0
// //         mask_zero = 0

// //         # Handle state machine
// //         if state == IDLE or state == STACKING:
// //             if input_index < input_length:
// //                 hcount, vcount, color, mask_zero, valid_in = grid[input_index // 8][input_index % 8]
// //                 addr = hcount + HRES * vcount
// //                 index = addr & 7
// //                 strobe_index = index << 1

// //                 if valid_in and will_be_ready:
// //                     if state == IDLE:
// //                         # Start stacking
// //                         data_stack = [0] * 8
// //                         strobe_stack = ['0'] * 16
// //                         next_addr = addr + 1
// //                         prev_addr = addr
// //                     else:
// //                         if addr != next_addr:
// //                             # Address misalignment detected
// //                             # Output current stack
// //                             enqueue_output(valid_out_queue, data_out_queue, strobe_out_queue, addr_out_queue,
// //                                            data_stack.copy(), strobe_stack.copy(), prev_addr, dut.frame.value.integer)
// //                             # Start new stack
// //                             data_stack = [0] * 8
// //                             strobe_stack = ['0'] * 16
// //                             prev_addr = addr
// //                             next_addr = addr + 1

// //                     # Stack the current data
// //                     data_stack[index] = color
// //                     set_strobe(strobe_stack, index, mask_zero)
// //                     prev_index = index
// //                     next_addr = addr + 1
// //                     currently_stacking = True
// //                     input_index += 1

// //                     if index == 7:
// //                         # Output the data
// //                         enqueue_output(valid_out_queue, data_out_queue, strobe_out_queue, addr_out_queue,
// //                                        data_stack.copy(), strobe_stack.copy(), addr, dut.frame.value.integer)
// //                         currently_stacking = False
// //                         if will_be_ready:
// //                             state = IDLE
// //                         else:
// //                             state = HOLD
// //                             next_state = IDLE
// //                     else:
// //                         state = STACKING
// //                 else:
// //                     if valid_in:
// //                         # Even if we can't proceed, we should advance input_index to avoid stalling
// //                         input_index += 1
// //                     if currently_stacking and will_be_ready:
// //                         # Output the data
// //                         enqueue_output(valid_out_queue, data_out_queue, strobe_out_queue, addr_out_queue,
// //                                        data_stack.copy(), strobe_stack.copy(), prev_addr, dut.frame.value.integer)
// //                         currently_stacking = False
// //                         if will_be_ready:
// //                             state = IDLE
// //                         else:
// //                             state = HOLD
// //                             next_state = IDLE
// //                     else:
// //                         state = IDLE
// //             else:
// //                 # No more inputs
// //                 if currently_stacking and will_be_ready:
// //                     # Output any remaining data
// //                     enqueue_output(valid_out_queue, data_out_queue, strobe_out_queue, addr_out_queue,
// //                                    data_stack.copy(), strobe_stack.copy(), prev_addr, dut.frame.value.integer)
// //                     currently_stacking = False
// //                 state = IDLE
// //         elif state == HOLD:
// //             valid_in = 0  # Keep valid_in low during HOLD
// //             if rdy_in:
// //                 state = next_state
// //             else:
// //                 # Remain in HOLD
// //                 pass

// //         # Drive DUT inputs
// //         dut.valid_in.value = valid_in
// //         dut.hcount.value = hcount
// //         dut.vcount.value = vcount
// //         dut.color.value = color
// //         dut.mask_zero.value = mask_zero

// //         # Update rdy_out according to will_be_ready
// //         dut.rdy_out.value = will_be_ready

// //         await RisingEdge(dut.clk_in)
// //         cycle += 1

// //         # Compare outputs
// //         if valid_out_queue:
// //             expected_valid_out = valid_out_queue[0]
// //         else:
// //             expected_valid_out = 0

// //         if dut.valid_out.value.integer == 1:
// //             if expected_valid_out == 1:
// //                 # Compare outputs
// //                 expected_data = data_out_queue.pop(0)
// //                 expected_strobe = strobe_out_queue.pop(0)
// //                 expected_addr_out = addr_out_queue.pop(0)
// //                 valid_out_queue.pop(0)

// //                 dut_data = dut.data_out.value.integer
// //                 dut_strobe = dut.strobe_out.value.integer
// //                 dut_addr_out = dut.addr_out.value.integer

// //                 assert dut_data == expected_data, f"Cycle {cycle}: data_out mismatch"
// //                 assert dut_strobe == expected_strobe, f"Cycle {cycle}: strobe_out mismatch"
// //                 assert dut_addr_out == expected_addr_out, f"Cycle {cycle}: addr_out mismatch"
// //             else:
// //                 assert False, f"Cycle {cycle}: DUT asserted valid_out unexpectedly"
// //         else:
// //             if expected_valid_out == 1:
// //                 # DUT should have asserted valid_out
// //                 pass  # Wait for DUT to assert valid_out
// //             else:
// //                 # Both DUT and expected are not asserting valid_out
// //                 pass

// // async def clock_gen(dut):
// //     """Clock generation."""
// //     while True:
// //         dut.clk_in.value = 0
// //         await RisingEdge(dut.clk_in)
// //         dut.clk_in.value = 1
// //         await RisingEdge(dut.clk_in)

// // def set_strobe(strobe_stack, index, mask_zero):
// //     if mask_zero == 0:
// //         strobe_stack[index * 2] = '1'
// //         strobe_stack[index * 2 + 1] = '1'
// //     else:
// //         strobe_stack[index * 2] = '0'
// //         strobe_stack[index * 2 + 1] = '0'

// // def enqueue_output(valid_out_queue, data_out_queue, strobe_out_queue, addr_out_queue, data_stack, strobe_stack, addr, frame):
// //     valid_out_queue.append(1)
// //     data_out_packed = pack_values(data_stack)
// //     data_out_queue.append(data_out_packed)
// //     strobe_out_str = ''.join(strobe_stack[::-1])
// //     strobe_out_val = int(strobe_out_str, 2)
// //     strobe_out_queue.append(strobe_out_val)
// //     addr_out_val = (frame << (addr_width)) | (addr << 4)
// //     addr_out_queue.append(addr_out_val)

// // def pack_values(data_stack):
// //     """
// //     Packs a list of 8 16-bit values into a single 128-bit integer.
// //     """
// //     packed_value = 0
// //     for i in range(8):
// //         packed_value |= (data_stack[i] & 0xFFFF) << (16 * i)
// //     return packed_value
