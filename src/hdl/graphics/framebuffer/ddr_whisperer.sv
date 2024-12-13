`timescale 1ns / 1ps `default_nettype none
module ddr_whisperer (
    //ddr stuf
    inout  wire [15:0] ddr3_dq,
    inout  wire [ 1:0] ddr3_dqs_n,
    inout  wire [ 1:0] ddr3_dqs_p,
    output wire [12:0] ddr3_addr,
    output wire [ 2:0] ddr3_ba,
    output wire        ddr3_ras_n,
    output wire        ddr3_cas_n,
    output wire        ddr3_we_n,
    output wire        ddr3_reset_n,
    output wire        ddr3_ck_p,
    output wire        ddr3_ck_n,
    output wire        ddr3_cke,
    output wire [ 1:0] ddr3_dm,
    output wire        ddr3_odt,

    //clks for input data and output data(assuming their in different domains)
    input wire input_data_clk_in,
    input wire input_data_rst,

    input wire output_data_clk_in,
    input wire output_data_rst_in,

    input wire clk_migref,
    input wire sys_rst_migref,
    input wire frame_in,

    //Write AXI signals in and out
    //data
    input wire [143:0] write_data,
    input wire last_write,
    input wire data_fifo_valid_in,
    output wire data_fifo_ready_out,

    //addr
    input wire addr_fifo_valid_in,
    output logic addr_fifo_ready_out,
    input wire [26:0] write_addr,

    //Read Data Axi Signals in and out

    //Addr
    input wire s_axi_arvalid,
    output logic s_axi_arready,
    input wire [26:0] s_axi_araddr,
    //data
    output logic s_axi_rvalid,
    output logic s_axi_rready,

    input wire data_reciever_rdy,
    output wire data_reciever_valid,
    output wire data_reciever_last,
    output logic [127:0] data_reciever_data,

    input wire last_frame_chunk,

    output wire clk_ui,
    output wire sys_rst_ui


);
  // logic clk_ui

  //dumb ddr signals
  logic app_ref_ack;
  logic app_sr_active;
  logic app_zq_ack;

  logic s_axi_rlast;
  logic init_calib_complete;
  logic mmcm_locked;
  logic s_axi_rresp;

  //axi write addr signals
  logic [143:0] s_axi_wdata;
  logic s_axi_wvalid;
  logic s_axi_wready;
  logic s_axi_wlast;

  //axi write data signals
  logic [31:0] s_axi_awaddr;
  logic s_axi_awvalid;
  logic s_axi_awready;
  logic s_axi_awlast;

  //axi read addr signals were all declared in inputs outputs
  //axi read data signals
  logic [127:0] s_axi_rdata;

  logic [1:0] s_axi_bresp;
  logic s_axi_bvalid;

  logic frame_in_cdc_1;
  logic frame_in_cdc_2;

  always_ff @(posedge clk_ui) begin
    frame_in_cdc_1 <= frame_in;
    frame_in_cdc_2 <= frame_in_cdc_1;
  end

  ddr_fifo_wrap #(
      .BIT_WIDTH(144)
  ) write_data_fifo (
      .sender_rst(input_data_rst),
      .sender_clk(input_data_clk_in),
      .sender_axis_tvalid(data_fifo_valid_in),
      .sender_axis_tready(data_fifo_ready_out),
      .sender_axis_tdata(write_data),
      .sender_axis_tlast(last_write),
      .sender_axis_prog_full(),

      .receiver_clk(clk_ui),
      .receiver_axis_tvalid(s_axi_wvalid),
      .receiver_axis_tready(s_axi_wready),
      .receiver_axis_tdata(s_axi_wdata),
      .receiver_axis_tlast(s_axi_wlast),
      .receiver_axis_prog_empty()
  );

  ddr_fifo_wrap #(
      .BIT_WIDTH(32)
  ) write_addr_fifo (
      .sender_rst(input_data_rst),
      .sender_clk(input_data_clk_in),
      .sender_axis_tvalid(addr_fifo_valid_in),
      .sender_axis_tready(addr_fifo_ready_out),
      .sender_axis_tdata({5'b0, frame_in, write_addr[21:0], 4'b0}),
      .sender_axis_tlast(last_write),
      .sender_axis_prog_full(),

      .receiver_clk(clk_ui),
      .receiver_axis_tvalid(s_axi_awvalid),
      .receiver_axis_tready(s_axi_awready),
      .receiver_axis_tdata(s_axi_awaddr),
      .receiver_axis_tlast(s_axi_awlast),
      .receiver_axis_prog_empty()
  );

  ddr_fifo_wrap read_data_fifo (
      .sender_rst(sys_rst_ui),
      .sender_clk(clk_ui),
      .sender_axis_tvalid(s_axi_rvalid),
      .sender_axis_tready(s_axi_rready),
      .sender_axis_tdata(s_axi_rdata),
      .sender_axis_tlast(last_frame_chunk),
      .sender_axis_prog_full(),

      .receiver_clk(output_data_clk_in),
      .receiver_axis_tvalid(data_reciever_valid),
      .receiver_axis_tready(data_reciever_rdy),
      .receiver_axis_tdata(data_reciever_data),
      .receiver_axis_tlast(data_reciever_last),
      .receiver_axis_prog_empty()
  );




  mig_7series_0 u_mig_7series_0 (
      // Memory interface ports
      .ddr3_addr          (ddr3_addr),            // output [12:0]		ddr3_addr
      .ddr3_ba            (ddr3_ba),              // output [2:0]		ddr3_ba
      .ddr3_cas_n         (ddr3_cas_n),           // output			ddr3_cas_n
      .ddr3_ck_n          (ddr3_ck_n),            // output [0:0]		ddr3_ck_n
      .ddr3_ck_p          (ddr3_ck_p),            // output [0:0]		ddr3_ck_p
      .ddr3_cke           (ddr3_cke),             // output [0:0]		ddr3_cke
      .ddr3_ras_n         (ddr3_ras_n),           // output			ddr3_ras_n
      .ddr3_reset_n       (ddr3_reset_n),         // output			ddr3_reset_n
      .ddr3_we_n          (ddr3_we_n),            // output			ddr3_we_n
      .ddr3_dq            (ddr3_dq),              // inout [15:0]		ddr3_dq
      .ddr3_dqs_n         (ddr3_dqs_n),           // inout [1:0]		ddr3_dqs_n
      .ddr3_dqs_p         (ddr3_dqs_p),           // inout [1:0]		ddr3_dqs_p
      .init_calib_complete(init_calib_complete),  // output			init_calib_complete
      .ddr3_dm            (ddr3_dm),              // output [1:0]		ddr3_dm
      .ddr3_odt           (ddr3_odt),             // output [0:0]		ddr3_odt

      // Application interface ports
      .ui_clk         (clk_ui),         // output			ui_clk
      .ui_clk_sync_rst(sys_rst_ui),     // output			ui_clk_sync_rst
      .mmcm_locked    (mmcm_locked),    // output			mmcm_locked
      .aresetn        (!sys_rst_ui),    // input			aresetn
      .app_sr_req     (1'b0),           // input			app_sr_req
      .app_ref_req    (1'b0),           // input			app_ref_req
      .app_zq_req     (1'b0),           // input			app_zq_req
      .app_sr_active  (app_sr_active),  // output			app_sr_active
      .app_ref_ack    (app_ref_ack),    // output			app_ref_ack
      .app_zq_ack     (app_zq_ack),     // output			app_zq_ack

      // Slave Interface Write Address Ports
      .s_axi_awid   (4'b0000),             // input [3:0]			s_axi_awid
      .s_axi_awaddr (s_axi_awaddr[26:0]),  // input [26:0]			s_axi_awaddr
      .s_axi_awlen  (8'b0),                // input [7:0]			s_axi_awlen
      .s_axi_awsize (3'b100),              // input [2:0]			s_axi_awsize
      .s_axi_awburst(2'b00),               // input [1:0]			s_axi_awburst
      .s_axi_awlock (1'b0),                // input [0:0]			s_axi_awlock
      .s_axi_awcache(4'b0),                // input [3:0]			s_axi_awcache
      .s_axi_awprot (3'b0),                // input [2:0]			s_axi_awprot
      .s_axi_awqos  (4'b0),                // input [3:0]			s_axi_awqos
      .s_axi_awvalid(s_axi_awvalid),       // input			s_axi_awvalid
      .s_axi_awready(s_axi_awready),       // output			s_axi_awready

      // Slave Interface Write Data Ports
      .s_axi_wdata(s_axi_wdata[143:16]),
      //   .s_axi_wdata(128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
      .s_axi_wstrb(s_axi_wdata[15:0]),  // input [15:0]			s_axi_wstrb
      .s_axi_wlast(1'b1),  // input			s_axi_wlast
      .s_axi_wvalid(s_axi_wvalid),  // input			s_axi_wvalid
      .s_axi_wready(s_axi_wready),  // output			s_axi_wready
      .s_axi_bid(),  // output [3:0]			s_axi_bid
      .s_axi_bresp(s_axi_bresp),  // output [1:0]			s_axi_bresp
      .s_axi_bvalid(s_axi_bvalid),  // output			s_axi_bvalid
      .s_axi_bready(1'b1),  // input			s_axi_bready

      // Slave Interface Read Address Ports
      .s_axi_arid(4'b0000),  // input [3:0]			s_axi_arid
      .s_axi_araddr({!frame_in_cdc_2, s_axi_araddr[21:0], 4'b0}),  // input [26:0]			s_axi_araddr
      .s_axi_arlen(8'b0),  // input [7:0]			s_axi_arlen
      .s_axi_arsize(3'b100),  // input [2:0]			s_axi_arsize
      .s_axi_arburst(2'b00),  // input [1:0]			s_axi_arburst
      .s_axi_arlock(1'b0),  // input [0:0]			s_axi_arlock
      .s_axi_arcache(4'b0),  // input [3:0]			s_axi_arcache
      .s_axi_arprot(3'b0),  // input [2:0]			s_axi_arprot
      .s_axi_arqos(4'b0),  // input [3:0]			s_axi_arqos
      .s_axi_arvalid(s_axi_arvalid),  // input			s_axi_arvalid
      .s_axi_arready(s_axi_arready),  // output			s_axi_arready

      // Slave Interface Read Data Ports
      .s_axi_rid   (),              // output [3:0]			s_axi_rid
      .s_axi_rdata (s_axi_rdata),   // output [127:0]			s_axi_rdata
      .s_axi_rresp (s_axi_rresp),   // output  [1:0]			s_axi_rresp
      .s_axi_rlast (s_axi_rlast),   // output			s_axi_rlast
      .s_axi_rvalid(s_axi_rvalid),  // output			s_axi_rvalid
      .s_axi_rready(s_axi_rready),  // input			s_axi_rready

      // System Clock Ports
      .sys_clk_i(clk_migref),

      // Reference Clock Ports
      .sys_rst(!sys_rst_migref)  // input sys_rst
  );
endmodule
