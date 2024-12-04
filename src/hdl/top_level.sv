`timescale 1ns / 1ps `default_nettype none

module top_level (
    input  wire         clk_100mhz,
    output logic [15:0] led,
    // camera bus

    input  wire  [15:0] sw,
    input  wire  [ 3:0] btn,
    output logic [ 3:0] ss0_an,  //anode control for upper four digits of seven-seg display
    output logic [ 3:0] ss1_an,  //anode control for lower four digits of seven-seg display
    output logic [ 6:0] ss0_c,   //cathode controls for the segments of upper four digits
    output logic [ 6:0] ss1_c    //cathod controls for the segments of lower four digits
);

  // localparam A_WIDTH = 18
  // localparam A_FRAC_BITS = 14;
  // localparam B_WIDTH = 25;
  // localparam B_FRAC_BITS = 14;
  // localparam P_FRAC_BITS = 14;
  // localparam N = 3;

  // localparam P_WIDTH = A_WIDTH + B_WIDTH - A_FRAC_BITS - B_FRAC_BITS + P_FRAC_BITS;
  // logic signed [P_WIDTH - 1:0] P;
  // logic signed [N-1:0][A_WIDTH-1:0] A;
  // logic signed [N-1:0][B_WIDTH-1:0] B;
  // logic done;

  // fixed_point_slow_dot #(
  //     .A_WIDTH(18),
  //     .B_WIDTH(25),
  //     .A_FRAC_BITS(14),
  //     .B_FRAC_BITS(14),
  //     .P_FRAC_BITS(14)
  // ) test_slow_dot (
  //     .clk_in(clk_100mhz),
  //     .rst_in(1'b0),
  //     .A(A),
  //     .B(B),
  //     .valid_in(1'b1),
  //     .valid_out(done),
  //     .P(P)
  // );
  // assign led = P[15:0];
  // #PARAMETERS#
  // {'XWIDTH': 17, 'YWIDTH': 17, 'ZWIDTH': 29, 'XFRAC': 14, 'YFRAC': 14, 'ZFRAC': 14, 'FB_HRES': 320, 'FB_VRES': 180, 'VH': 3, 'VW': 3, 'VW_BY_HRES_WIDTH': 22, 'VW_BY_HRES_FRAC': 14, 'VH_BY_VRES_WIDTH': 21, 'VH_BY_VRES_FRAC': 14, 'VW_BY_HRES': 154, 'VH_BY_VRES': 273, 'HRES_BY_VW_WIDTH': 21, 'HRES_BY_VW_FRAC': 14, 'VRES_BY_VH_WIDTH': 21, 'VRES_BY_VH_FRAC': 14, 'HRES_BY_VW': 1747627, 'VRES_BY_VH': 983040}
  // #PARAMETERS#

//   logic [2:0][16:0] x;
//   logic [2:0][16:0] y;
//   logic [2:0][28:0] z;

//   random_noise #(
//       .N(3 * 17),
//       .LFSR_WIDTH(3 * 17)
//   ) noisex (
//       .clk_in(clk_100mhz),
//       .rst_in(1'b0),
//       .noise (x)
//   );

//   random_noise #(
//       .N(3 * 17),
//       .LFSR_WIDTH(3 * 17)
//   ) noisey (
//       .clk_in(clk_100mhz),
//       .rst_in(1'b0),
//       .noise (y)
//   );

//   random_noise #(
//       .N(3 * 29),
//       .LFSR_WIDTH(3 * 29)
//   ) noisez (
//       .clk_in(clk_100mhz),
//       .rst_in(1'b0),
//       .noise (z)
//   );

//   rasterizer #(
//       .XWIDTH(17),
//       .YWIDTH(17),
//       .ZWIDTH(29),
//       .XFRAC(14),
//       .YFRAC(14),
//       .ZFRAC(14),
//       .FB_HRES(320),
//       .FB_VRES(180),
//       .VH(3),
//       .VW(3),
//       .VW_BY_HRES_WIDTH(22),
//       .VW_BY_HRES_FRAC(14),
//       .VH_BY_VRES_WIDTH(21),
//       .VH_BY_VRES_FRAC(14),
//       .VW_BY_HRES(154),
//       .VH_BY_VRES(273),
//       .HRES_BY_VW_WIDTH(21),
//       .HRES_BY_VW_FRAC(14),
//       .VRES_BY_VH_WIDTH(21),
//       .VRES_BY_VH_FRAC(14),
//       .HRES_BY_VW(1747627),
//       .VRES_BY_VH(983040)
//   ) el_rasterizer (
//       .clk_in(clk_100mhz),
//       .rst_in(1'b0),
//       .valid_in(1'b1),
//       .ready_in(1'b1),
//       .x(x),
//       .y(y),
//       .z(z),
//       .valid_out(led[0]),
//       .ready_out(led[1]),
//       .hcount_out(led[2]),
//       .vcount_out(led[3]),
//       .z_out(led[5])
//   );

mig_write_req_generator write_gen(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .hcount(),
    .vcount(),
    .color(),
    .frame(),
    .mask_zero(),
    .rdy_in(),
    .valid_in(),

    .rdy_out(),
    .addr_out(),
    .data_out(),
    .strobe_out(),
    .valid_out(1)
);

ddr_fifo_wrap write_data_fifo(

.sender_rst(rst_in),
.sender_clk(clk_in),
.sender_axis_tvalid(),
.sender_axis_tready(),
.sender_axis_tdata(),
.sender_axis_tlast(),
.sender_axis_prog_full(),

.receiver_clk(clk_pixel),
.receiver_axis_tvalid(s_axi_wvalid),
.receiver_axis_tready(s_axi_wready),
.receiver_axis_tdata(s_axi_wdata),
.receiver_axis_tlast(s_axi_wlast),
.receiver_axis_prog_empty(display_axis_prog_empty));

ddr_fifo_wrap write_add_fifo(
.sender_rst(rst_in),
.sender_clk(clk_in),
.sender_axis_tvalid(),
.sender_axis_tready(),
.sender_axis_tdata(),
.sender_axis_tlast(),
.sender_axis_prog_full(),
.receiver_clk(clk_pixel),
.receiver_axis_tvalid(),
.receiver_axis_tready(),
.receiver_axis_tdata(),
.receiver_axis_tlast(),
.receiver_axis_prog_empty());


ddr_fifo_wrap read_address_fifo(
.sender_rst(sys_rst_ui),
.sender_clk(clk_ui),
.sender_axis_tvalid(),
.sender_axis_tready(),
.sender_axis_tdata(),
.sender_axis_tlast(),
.sender_axis_prog_full(),

.receiver_clk(clk_pixel),
.receiver_axis_tvalid(),
.receiver_axis_tready(),
.receiver_axis_tdata(),
.receiver_axis_tlast(),
.receiver_axis_prog_empty()
);

ddr_fifo_wrap read_data_fifo(
.sender_rst(rst_in),
.sender_clk(clk_in),
.sender_axis_tvalid(s_axi_rvalid),
.sender_axis_tready(s_axi_rready),
.sender_axis_tdata(s_axi_rdata),
.sender_axis_tlast(s_axi_rlast),
.sender_axis_prog_full(),

.receiver_clk(clk_pixel),
.receiver_axis_tvalid(),
.receiver_axis_tready(),
.receiver_axis_tdata(),
.receiver_axis_tlast(),
.receiver_axis_prog_empty()
);



mig_7series_0 u_mig_7series_0 (

    // Memory interface ports
    .ddr3_addr                      (ddr3_addr),  // output [12:0]		ddr3_addr
    .ddr3_ba                        (ddr3_ba),  // output [2:0]		ddr3_ba
    .ddr3_cas_n                     (ddr3_cas_n),  // output			ddr3_cas_n
    .ddr3_ck_n                      (ddr3_ck_n),  // output [0:0]		ddr3_ck_n
    .ddr3_ck_p                      (ddr3_ck_p),  // output [0:0]		ddr3_ck_p
    .ddr3_cke                       (ddr3_cke),  // output [0:0]		ddr3_cke
    .ddr3_ras_n                     (ddr3_ras_n),  // output			ddr3_ras_n
    .ddr3_reset_n                   (ddr3_reset_n),  // output			ddr3_reset_n
    .ddr3_we_n                      (ddr3_we_n),  // output			ddr3_we_n
    .ddr3_dq                        (ddr3_dq),  // inout [15:0]		ddr3_dq
    .ddr3_dqs_n                     (ddr3_dqs_n),  // inout [1:0]		ddr3_dqs_n
    .ddr3_dqs_p                     (ddr3_dqs_p),  // inout [1:0]		ddr3_dqs_p
    .init_calib_complete            (init_calib_complete),  // output			init_calib_complete
      
	.ddr3_cs_n                      (ddr3_cs_n),  // output [0:0]		ddr3_cs_n
    .ddr3_dm                        (ddr3_dm),  // output [1:0]		ddr3_dm
    .ddr3_odt                       (ddr3_odt),  // output [0:0]		ddr3_odt
    // Application interface ports
    .ui_clk                         (ui_clk),  // output			ui_clk
    .ui_clk_sync_rst                (ui_clk_sync_rst),  // output			ui_clk_sync_rst
    .mmcm_locked                    (mmcm_locked),  // output			mmcm_locked
    .aresetn                        (aresetn),  // input			aresetn
    .app_sr_req                     (app_sr_req),  // input			app_sr_req
    .app_ref_req                    (app_ref_req),  // input			app_ref_req
    .app_zq_req                     (app_zq_req),  // input			app_zq_req
    .app_sr_active                  (app_sr_active),  // output			app_sr_active
    .app_ref_ack                    (app_ref_ack),  // output			app_ref_ack
    .app_zq_ack                     (app_zq_ack),  // output			app_zq_ack
    // Slave Interface Write Address Ports
    .s_axi_awid                     (s_axi_awid),  // input [3:0]			s_axi_awid
    .s_axi_awaddr                   (s_axi_awaddr),  // input [26:0]			s_axi_awaddr
    .s_axi_awlen                    (s_axi_awlen),  // input [7:0]			s_axi_awlen
    .s_axi_awsize                   (s_axi_awsize),  // input [2:0]			s_axi_awsize
    .s_axi_awburst                  (s_axi_awburst),  // input [1:0]			s_axi_awburst
    //fixed
    
    .s_axi_awlock                   (s_axi_awlock),  // input [0:0]			s_axi_awlock
    .s_axi_awcache                  (s_axi_awcache),  // input [3:0]			s_axi_awcache
    .s_axi_awprot                   (s_axi_awprot),  // input [2:0]			s_axi_awprot
    .s_axi_awqos                    (s_axi_awqos),  // input [3:0]			s_axi_awqos

    .s_axi_awvalid                  (s_axi_awvalid),  // input			s_axi_awvalid
    .s_axi_awready                  (s_axi_awready),  // output			s_axi_awready
    // Slave Interface Write Data Ports
    .s_axi_wdata                    (s_axi_wdata),  // input [127:0]			s_axi_wdata
    .s_axi_wstrb                    (s_axi_wstrb),  // input [15:0]			s_axi_wstrb
    .s_axi_wlast                    (s_axi_wlast),  // input			s_axi_wlast
    .s_axi_wvalid                   (s_axi_wvalid),  // input			s_axi_wvalid
    .s_axi_wready                   (s_axi_wready),  // output			s_axi_wready
    // Slave Interface Write Response Ports
    .s_axi_bid                      (s_axi_bid),  // output [3:0]			s_axi_bid
    .s_axi_bresp                    (s_axi_bresp),  // output [1:0]			s_axi_bresp
    .s_axi_bvalid                   (s_axi_bvalid),  // output			s_axi_bvalid
    .s_axi_bready                   (s_axi_bready),  // input			s_axi_bready
    // Slave Interface Read Address Ports
    .s_axi_arid                     (s_axi_arid),  // input [3:0]			s_axi_arid
    .s_axi_araddr                   (s_axi_araddr),  // input [26:0]			s_axi_araddr
    .s_axi_arlen                    (s_axi_arlen),  // input [7:0]			s_axi_arlen
    .s_axi_arsize                   (s_axi_arsize),  // input [2:0]			s_axi_arsize
    .s_axi_arburst                  (s_axi_arburst),  // input [1:0]			s_axi_arburst

    .s_axi_arlock                   (s_axi_arlock),  // input [0:0]			s_axi_arlock
    .s_axi_arcache                  (s_axi_arcache),  // input [3:0]			s_axi_arcache
    .s_axi_arprot                   (s_axi_arprot),  // input [2:0]			s_axi_arprot
    .s_axi_arqos                    (s_axi_arqos),  // input [3:0]			s_axi_arqos
    .s_axi_arvalid                  (s_axi_arvalid),  // input			s_axi_arvalid
    .s_axi_arready                  (s_axi_arready),  // output			s_axi_arready
    // Slave Interface Read Data Ports
    .s_axi_rid                      (s_axi_rid),  // output [3:0]			s_axi_rid
    .s_axi_rdata                    (s_axi_rdata),  // output [127:0]			s_axi_rdata
    .s_axi_rresp                    (s_axi_rresp),  // output [1:0]			s_axi_rresp
    .s_axi_rlast                    (s_axi_rlast),  // output			s_axi_rlast
    .s_axi_rvalid                   (s_axi_rvalid),  // output			s_axi_rvalid
    .s_axi_rready                   (s_axi_rready),  // input			s_axi_rready
    // System Clock Ports
    .sys_clk_i                       (sys_clk_i),
    // Reference Clock Ports
    .clk_ref_i                      (clk_ref_i),
    .sys_rst                        (sys_rst) // input sys_rst
    );
    




endmodule  


`default_nettype wire

