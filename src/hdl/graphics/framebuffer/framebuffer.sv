// `timescale 1ns / 1ps

// module framebuffer#(

// )(
//     input wire clk_in,
//     input wire rst_in,
//     input wire valid_in,
//     input logic [HRES-1:0]x,
//     input logic [VRES-1:0]y,
//     input logic [DEPTH-1:0]z,
//     input logic [15:0] rgb_in,
//     input logic last_pixel,
// )
//     localparam HRES=1280;
//     localparam VRES=720
//     //module should take in x_in,y_in, check if its valid in the depth buffer, then add the pixel to the stacker.

//     //if 0 unshifted location is the DRAM 
//     logic write_bit;
//     logic read_bit;
//     logic write_addr;
//     logic valid_piped
//     logic valid_depth_write;
//     logic [DEPTH-1:0] depth;
//     assign write_addr=x+(320*y);
//     always_ff@(posedge clk_in)begin
//         if(rst_in)begin
//             write_bit<=1;
//             read_bit<=0;
//         end
//         if(last_pixel)begin
//             write_bit<=!write_bit;
//             read_bit<=!read_bit;
//         end
//     end

//     //depth ram 
//     //so we're abusing the 2 port dram here, first port for writing is gonna be the pipelined signals, reliant on teh comparison of whats coming out of the 
//     //second port
//     assign valid_depth_write=(valid_piped && depth>=z)
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

//     //DRAM Stuff from lab 6

//     logic [127:0] camera_chunk;
//     logic [127:0] camera_axis_tdata;
//     logic         camera_axis_tlast;
//     logic         camera_axis_tready;
//     logic         camera_axis_tvalid;

//     // takes our 16-bit values and deserialize/stack them into 128-bit messages to write to DRAM
//     // the data pipeline is designed such that we can fairly safely assume its always ready.
//     stacker stacker_inst(
//         .clk_in(clk_camera),
//         .rst_in(sys_rst_camera),
//         .pixel_tvalid(camera_valid),
//         .pixel_tready(),
//         .pixel_tdata(camera_pixel),
//         .pixel_tlast((camera_hcount==HRES-1 && camera_vcount==VRES-1)), 
//         .chunk_tvalid(camera_axis_tvalid),
//         .chunk_tready(camera_axis_tready),
//         .chunk_tdata(camera_axis_tdata),
//         .chunk_tlast(camera_axis_tlast));
    
//     logic [127:0] camera_ui_axis_tdata;
//     logic         camera_ui_axis_tlast;
//     logic         camera_ui_axis_tready;
//     logic         camera_ui_axis_tvalid;
//     logic         camera_ui_axis_prog_empty;
    
//     // FIFO data queue of 128-bit messages, crosses clock domains to the 81.25MHz
//     // UI clock of the memory interface
//     ddr_fifo_wrap camera_data_fifo(
//         .sender_rst(sys_rst_camera),
//         .sender_clk(clk_camera),
//         .sender_axis_tvalid(camera_axis_tvalid),
//         .sender_axis_tready(camera_axis_tready),
//         .sender_axis_tdata(camera_axis_tdata),
//         .sender_axis_tlast(camera_axis_tlast),
//         .receiver_clk(clk_ui),
//         .receiver_axis_tvalid(camera_ui_axis_tvalid),
//         .receiver_axis_tready(camera_ui_axis_tready),
//         .receiver_axis_tdata(camera_ui_axis_tdata),
//         .receiver_axis_tlast(camera_ui_axis_tlast),
//         .receiver_axis_prog_empty(camera_ui_axis_prog_empty));

//     logic [127:0] display_ui_axis_tdata;
//     logic         display_ui_axis_tlast;
//     logic         display_ui_axis_tready;
//     logic         display_ui_axis_tvalid;
//     logic         display_ui_axis_prog_full;

//     // these are the signals that the MIG IP needs for us to define!
//     // MIG UI --> generic outputs
//     logic [26:0]  app_addr;
//     logic [2:0]   app_cmd;
//     logic         app_en;
//     // MIG UI --> write outputs
//     logic [127:0] app_wdf_data;
//     logic         app_wdf_end;
//     logic         app_wdf_wren;
//     logic [15:0]  app_wdf_mask;
//     // MIG UI --> read inputs
//     logic [127:0] app_rd_data;
//     logic         app_rd_data_end;
//     logic         app_rd_data_valid;
//     // MIG UI --> generic inputs
//     logic         app_rdy;
//     logic         app_wdf_rdy;
//     // MIG UI --> misc
//     logic         app_sr_req; 
//     logic         app_ref_req;
//     logic         app_zq_req; 
//     logic         app_sr_active;
//     logic         app_ref_ack;
//     logic         app_zq_ack;
//     logic         init_calib_complete;
    

//     // this traffic generator handles reads and writes issued to the MIG IP,
//     // which in turn handles the bus to the DDR chip.
//     traffic_generator readwrite_looper(
//         // Outputs
//         .app_addr         (app_addr[26:0]),
//         .app_cmd          (app_cmd[2:0]),
//         .app_en           (app_en),
//         .app_wdf_data     (app_wdf_data[127:0]),
//         .app_wdf_end      (app_wdf_end),
//         .app_wdf_wren     (app_wdf_wren),
//         .app_wdf_mask     (app_wdf_mask[15:0]),
//         .app_sr_req       (app_sr_req),
//         .app_ref_req      (app_ref_req),
//         .app_zq_req       (app_zq_req),
//         .write_axis_ready (camera_ui_axis_tready),
//         .read_axis_data   (display_ui_axis_tdata),
//         .read_axis_tlast  (display_ui_axis_tlast),
//         .read_axis_valid  (display_ui_axis_tvalid),
//         // Inputs
//         .clk_in           (clk_ui),
//         .rst_in           (sys_rst_ui),
//         .app_rd_data      (app_rd_data[127:0]),
//         .app_rd_data_end  (app_rd_data_end),
//         .app_rd_data_valid(app_rd_data_valid),
//         .app_rdy          (app_rdy),
//         .app_wdf_rdy      (app_wdf_rdy),
//         .app_sr_active    (app_sr_active),
//         .app_ref_ack      (app_ref_ack),
//         .app_zq_ack       (app_zq_ack),
//         .init_calib_complete(init_calib_complete),
//         .write_axis_data  (camera_ui_axis_tdata),
//         .write_axis_tlast (camera_ui_axis_tlast),
//         .write_axis_valid (camera_ui_axis_tvalid),
//         .write_axis_smallpile(camera_ui_axis_prog_empty),
//         .read_axis_af     (display_ui_axis_prog_full),
//         .read_axis_ready  (display_ui_axis_tready) //,
//         // Uncomment for part 2!
//         // .zoom_view_en ( zoom_view ),
//         // .zoom_view_x ( center_x_ui ),
//         // .zoom_view_y( center_y_ui )
//     );

//     // the MIG IP!
//     ddr3_mig ddr3_mig_inst 
//         (
//         .ddr3_dq(ddr3_dq),
//         .ddr3_dqs_n(ddr3_dqs_n),
//         .ddr3_dqs_p(ddr3_dqs_p),
//         .ddr3_addr(ddr3_addr),
//         .ddr3_ba(ddr3_ba),
//         .ddr3_ras_n(ddr3_ras_n),
//         .ddr3_cas_n(ddr3_cas_n),
//         .ddr3_we_n(ddr3_we_n),
//         .ddr3_reset_n(ddr3_reset_n),
//         .ddr3_ck_p(ddr3_ck_p),
//         .ddr3_ck_n(ddr3_ck_n),
//         .ddr3_cke(ddr3_cke),
//         .ddr3_dm(ddr3_dm),
//         .ddr3_odt(ddr3_odt),
//         .sys_clk_i(clk_migref),
//         .app_addr(app_addr),
//         .app_cmd(app_cmd),
//         .app_en(app_en),
//         .app_wdf_data(app_wdf_data),
//         .app_wdf_end(app_wdf_end),
//         .app_wdf_wren(app_wdf_wren),
//         .app_rd_data(app_rd_data),
//         .app_rd_data_end(app_rd_data_end),
//         .app_rd_data_valid(app_rd_data_valid),
//         .app_rdy(app_rdy),
//         .app_wdf_rdy(app_wdf_rdy), 
//         .app_sr_req(app_sr_req),
//         .app_ref_req(app_ref_req),
//         .app_zq_req(app_zq_req),
//         .app_sr_active(app_sr_active),
//         .app_ref_ack(app_ref_ack),
//         .app_zq_ack(app_zq_ack),
//         .ui_clk(clk_ui), 
//         .ui_clk_sync_rst(sys_rst_ui),
//         .app_wdf_mask(app_wdf_mask),
//         .init_calib_complete(init_calib_complete),
//         // .device_temp(device_temp),
//         .sys_rst(!sys_rst_migref) // active low
//     );
    
//     logic [127:0] display_axis_tdata;
//     logic         display_axis_tlast;
//     logic         display_axis_tready;
//     logic         display_axis_tvalid;
//     logic         display_axis_prog_empty;
    
//     ddr_fifo_wrap pdfifo(
//         .sender_rst(sys_rst_ui),
//         .sender_clk(clk_ui),
//         .sender_axis_tvalid(display_ui_axis_tvalid),
//         .sender_axis_tready(display_ui_axis_tready),
//         .sender_axis_tdata(display_ui_axis_tdata),
//         .sender_axis_tlast(display_ui_axis_tlast),
//         .sender_axis_prog_full(display_ui_axis_prog_full),
//         .receiver_clk(clk_pixel),
//         .receiver_axis_tvalid(display_axis_tvalid),
//         .receiver_axis_tready(display_axis_tready),
//         .receiver_axis_tdata(display_axis_tdata),
//         .receiver_axis_tlast(display_axis_tlast),
//         .receiver_axis_prog_empty(display_axis_prog_empty));

//     logic frame_buff_tvalid;
//     logic frame_buff_tready;
//     logic [15:0] frame_buff_tdata;
//     logic        frame_buff_tlast;

//     unstacker unstacker_inst(
//         .clk_in(clk_pixel),
//         .rst_in(sys_rst_pixel),
//         .chunk_tvalid(display_axis_tvalid),
//         .chunk_tready(display_axis_tready),
//         .chunk_tdata(display_axis_tdata),
//         .chunk_tlast(display_axis_tlast),
//         .pixel_tvalid(frame_buff_tvalid),
//         .pixel_tready(frame_buff_tready),
//         .pixel_tdata(frame_buff_tdata),
//         .pixel_tlast(frame_buff_tlast));
// endmodule