module framebuffer#()(
    input clk_in,
    input rst_in,

    output rdy_out,
    input valid_in,
    input [2:0][15:0] coords,
    


);

    assign valid_depth_write=(valid_piped && depth>=z)

    pipeline#(.STAGES(2),.WIDTH(1)) valid_piped(
        .clk_in(clk_in),
        .data(valid_in),
        .data_out(valid_piped)
    )
    blk_mem_gen_0 frame_buffer (
        .addra(write_addr), //pixels are stored using this math
        .clka(clk_in),
        .wea(valid_depth_write),
        .dina(camera_mem),
        .ena(1'b1),
        .douta(), //never read from this side
        .addrb(addrb),//transformed lookup pixel
        .dinb(16'b0),
        .clkb(clk_pixel),
        .web(1'b0),
        .enb(1'b1),
        .doutb(depth)
  );

  ddr_whisperer(

  );

endmodule
  
