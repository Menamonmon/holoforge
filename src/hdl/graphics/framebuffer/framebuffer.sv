// module framebuffer#()(
//     input wire clk_in,
//     input wire rst_in,

//     input wire valid_in,
//     input wire [2:0][15:0] coords,
//     input wire frame,
//     input wire rdy_in,
//     input wire [15:0]data,

//     output wire [127:0] data,
//     output wire 


     

// );
//     //and the data in is the rasterizer and thats it 
//     //I think the goal of this module is the data out is the data going into the hdmi in our top level

//     assign valid_depth_write=(valid_piped && depth>=z)
//     logic [15:0] hcount;
//     logic [15:0] vcount

//     pipeline#(.STAGES(2),.WIDTH(1)) valid_piped(
//         .clk_in(clk_in),
//         .data(valid_in),
//         .data_out(valid_piped)
//     )
//     pipeline#(.STAGES(2),.WIDTH(1)) valid_piped(
//         .clk_in(clk_in),
//         .data(valid_in),
//         .data_out(valid_piped)
//     )
//     pipeline#(.STAGES(2),.WIDTH(1)) valid_piped(
//         .clk_in(clk_in),
//         .data(valid_in),
//         .data_out(valid_piped)
//     )
//     blk_mem_gen_0 frame_buffer (
//         .addra(write_addr), //pixels are stored using this math
//         .clka(clk_in),
//         .wea(valid_depth_write),
//         .dina(camera_mem),
//         .ena(1'b1),
//         .douta(), //never read from this side
//         .addrb(addrb),//transformed lookup pixel
//         .dinb(16'b0),
//         .clkb(clk_pixel),
//         .web(1'b0),
//         .enb(1'b1),
//         .doutb(depth)
//   );


// endmodule
  
