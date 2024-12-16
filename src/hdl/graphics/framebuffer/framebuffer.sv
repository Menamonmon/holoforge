`default_nettype none

module framebuffer #(
    Z_WIDTH = 15,
    SCALE_FACTOR = 1,
    HRES = 320,
    VRES = 180
) (

    input wire clk_100mhz,
    input wire sys_rst,

    //in from rasterizer/vid src
    input wire valid_in,
    input wire strobe_in,
    input wire [26:0] addr_in,
    input wire [Z_WIDTH-1:0] depth_in,
    input wire [15:0] color_in,
    input wire frame,
    //out to rasterizrer/vid src
    output logic rasterizer_rdy_out,
    //out casue we're the clock wizard
    input wire clk_100_passthrough,
    input wire clk_migref,
    input wire clk_pixel,
    input wire sys_rst_migref,
    //out to TMDS HDMI STUFF
    output logic frame_buff_tvalid,
    input wire frame_buff_tready,
    output logic [15:0] frame_buff_tdata,
    output logic frame_buff_tlast,

    //ddr stuff
    inout  wire  [15:0] ddr3_dq,
    inout  wire  [ 1:0] ddr3_dqs_n,
    inout  wire  [ 1:0] ddr3_dqs_p,
    output wire  [12:0] ddr3_addr,
    output wire  [ 2:0] ddr3_ba,
    output wire         ddr3_ras_n,
    output wire         ddr3_cas_n,
    output wire         ddr3_we_n,
    output wire         ddr3_reset_n,
    output wire         ddr3_ck_p,
    output wire         ddr3_ck_n,
    output wire         ddr3_cke,
    output wire  [ 1:0] ddr3_dm,
    output wire         ddr3_odt,
    output logic [26:0] read_addr,
    output logic [26:0] s_axi_araddr,

    output wire clk_ui

);
  localparam DEPTH = HRES * VRES;
  localparam DOUBLE_DEPTH = HRES * VRES * 2;
  localparam CHUNK_DEPTH = (HRES * VRES) / 8;
  localparam CHUNK_HRES = HRES / 8;
  localparam COMPLETE_CYCLES = 10;

  //ddr_whisperer signals
  logic [143:0] write_data;
  logic data_fifo_valid_in;
  logic data_fifo_ready_out;
  logic addr_fifo_valid_in;
  logic addr_fifo_ready_out;
  logic [26:0] write_addr;
  logic s_axi_arvalid;
  assign write_addr[26:13] = 14'b0;

  assign s_axi_arvalid = 1'b1;

  logic               s_axi_arready;
  logic               s_axi_rready;
  logic               s_axi_rvalid;

  logic [      127:0] display_axis_tdata;
  logic               display_axis_tlast;
  logic               display_axis_tready;
  logic               display_axis_tvalid;
  logic               display_axis_prog_empty;
  logic               stacker_last;
  logic               stacker_rdy_out;
  logic               sys_rst_ui;
  logic               stacker_valid_out;
  //depth ram stuff
  logic               valid_depth_write;
  logic [Z_WIDTH-1:0] depth;

  logic               sys_rst_pixel;
  assign sys_rst_pixel = sys_rst;

  //Pixel Stacker
  pixel_stacker #(
      .HRES(HRES),
      .VRES(VRES)
  ) rollled_stacker (
      .clk_in(clk_100_passthrough),
      .rst_in(sys_rst),
      .ready_in(addr_fifo_ready_out && data_fifo_ready_out),
      .valid_in(valid_in),
      .ready_out(rasterizer_rdy_out),
      .strobe_in(strobe_in),
      .addr(addr_in),
      .data_in(color_in),
      .addr_out(write_addr[12:0]),
      .data_out(write_data[143:16]),
      .strobe_out(write_data[15:0]),
      .valid_out(stacker_valid_out)
  );

  //  DDR Talking to
  zoom_counter #(
      .ROW_COUNT(CHUNK_HRES),
      .COL_COUNT(VRES),
      .SCALE_FACTOR(SCALE_FACTOR)
  ) read_req_addr_counter (
      .clk_in(clk_ui),
      .rst_in(sys_rst_ui),
      .evt_in(s_axi_arready && s_axi_arvalid),
      .count_out(s_axi_araddr)
  );

  logic last_frame_chunk;
  zoom_counter #(
      .ROW_COUNT(CHUNK_HRES),
      .COL_COUNT(VRES),
      .SCALE_FACTOR(SCALE_FACTOR)
  ) read_resp_addr_counter (
      .clk_in(clk_ui),
      .rst_in(sys_rst_ui),
      .evt_in(s_axi_rready && s_axi_rvalid),
      .count_out(read_addr),
      .last_out(last_frame_chunk)
  );

  ddr_whisperer ddr_time (
      .ddr3_dq(ddr3_dq),
      .ddr3_dqs_n(ddr3_dqs_n),
      .ddr3_dqs_p(ddr3_dqs_p),
      .ddr3_addr(ddr3_addr),
      .ddr3_ba(ddr3_ba),
      .ddr3_ras_n(ddr3_ras_n),
      .ddr3_cas_n(ddr3_cas_n),
      .ddr3_we_n(ddr3_we_n),
      .ddr3_reset_n(ddr3_reset_n),
      .ddr3_ck_p(ddr3_ck_p),
      .ddr3_ck_n(ddr3_ck_n),
      .ddr3_cke(ddr3_cke),
      .ddr3_dm(ddr3_dm),
      .ddr3_odt(ddr3_odt),
      .frame_in(frame),

      .input_data_clk_in(clk_100_passthrough),
      .input_data_rst(sys_rst),
      .output_data_clk_in(clk_pixel),
      .output_data_rst_in(sys_rst_pixel),

      .clk_migref(clk_migref),
      .sys_rst_migref(sys_rst_migref),

      .write_data(write_data),
      .last_write(stacker_last),

      .data_fifo_valid_in (stacker_valid_out),
      .data_fifo_ready_out(data_fifo_ready_out),

      .addr_fifo_valid_in (stacker_valid_out),
      .addr_fifo_ready_out(addr_fifo_ready_out),

      .write_addr(write_addr),

      .s_axi_arvalid(s_axi_arvalid),
      .s_axi_arready(s_axi_arready),
      .s_axi_araddr (s_axi_araddr),

      .s_axi_rready(s_axi_rready),
      .s_axi_rvalid(s_axi_rvalid),

      .data_reciever_rdy  (display_axis_tready),
      .data_reciever_valid(display_axis_tvalid),
      .data_reciever_last (display_axis_tlast),
      .data_reciever_data (display_axis_tdata),

      .last_frame_chunk(last_frame_chunk),
      .clk_ui(clk_ui),
      .sys_rst_ui(sys_rst_ui)

  );

  //Data going out to frame/tmds stuff
  unstacker unstacker_inst (
      .clk_in(clk_pixel),
      .rst_in(sys_rst_pixel),
      .chunk_tvalid(display_axis_tvalid),
      .chunk_tready(display_axis_tready),
      .chunk_tdata(display_axis_tdata),
      .chunk_tlast(display_axis_tlast),
      .pixel_tvalid(frame_buff_tvalid),
      .pixel_tready(frame_buff_tready),
      .pixel_tdata(frame_buff_tdata),
      .pixel_tlast(frame_buff_tlast)
  );

endmodule


`default_nettype wire
