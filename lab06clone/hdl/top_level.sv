`timescale 1ns / 1ps `default_nettype none
module top_level (
    input  wire         clk_100mhz,
    output logic [15:0] led,
    // camera bus
    input  wire  [ 7:0] camera_d,      // 8 parallel data wires
    output logic        cam_xclk,      // XC driving camera
    input  wire         cam_hsync,     // camera hsync wire
    input  wire         cam_vsync,     // camera vsync wire
    input  wire         cam_pclk,      // camera pixel clock
    inout  wire         i2c_scl,       // i2c inout clock
    inout  wire         i2c_sda,       // i2c inout data
    input  wire  [15:0] sw,
    input  wire  [ 3:0] btn,
    output logic [ 2:0] rgb0,
    output logic [ 2:0] rgb1,
    // seven segment
    output logic [ 3:0] ss0_an,        //anode control for upper four digits of seven-seg display
    output logic [ 3:0] ss1_an,        //anode control for lower four digits of seven-seg display
    output logic [ 6:0] ss0_c,         //cathode controls for the segments of upper four digits
    output logic [ 6:0] ss1_c,         //cathod controls for the segments of lower four digits
    // hdmi port
    output logic [ 2:0] hdmi_tx_p,     //hdmi output signals (positives) (blue, green, red)
    output logic [ 2:0] hdmi_tx_n,     //hdmi output signals (negatives) (blue, green, red)
    output logic        hdmi_clk_p,
    hdmi_clk_n,  //differential hdmi clock
    // New for week 6: DDR3 ports
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
    output wire         ddr3_odt
);

  // shut up those RGBs
  assign rgb0 = 0;
  assign rgb1 = 0;

  // Clock and Reset Signals: updated for a couple new clocks!
  logic sys_rst_camera;
  logic sys_rst_pixel;

  logic clk_camera;
  logic clk_pixel;
  logic clk_5x;
  logic clk_xc;


  logic clk_migref;
  logic sys_rst_migref;

  logic clk_ui;
  logic sys_rst_ui;

  logic clk_100_passthrough;

  // clocking wizards to generate the clock speeds we need for our different domains
  // clk_camera: 200MHz, fast enough to comfortably sample the cameera's PCLK (50MHz)
  cw_hdmi_clk_wiz wizard_hdmi (
      .sysclk(clk_100_passthrough),
      .clk_pixel(clk_pixel),
      .clk_tmds(clk_5x),
      .reset(0)
  );

  cw_fast_clk_wiz wizard_migcam (
      .clk_in1(clk_100mhz),
      .clk_camera(clk_camera),
      .clk_mig(clk_migref),
      .clk_xc(clk_xc),
      .clk_100(clk_100_passthrough),
      .reset(0)
  );

  // assign camera's xclk to pmod port: drive the operating clock of the camera!
  // this port also is specifically set to high drive by the XDC file.
  assign cam_xclk = clk_xc;

  assign sys_rst_camera = btn[0];  //use for resetting camera side of logic
  assign sys_rst_pixel = btn[0];  //use for resetting hdmi/draw side of logic
  assign sys_rst_migref = btn[0];


  // video signal generator signals
  logic [7:0] fb_red, fb_green, fb_blue;
  logic        hsync_hdmi;
  logic        vsync_hdmi;
  logic [10:0] hcount_hdmi;
  logic [ 9:0] vcount_hdmi;
  logic        active_draw_hdmi;
  logic        new_frame_hdmi;
  logic [ 5:0] frame_count_hdmi;
  logic        nf_hdmi;

  // rgb output values
  logic [7:0] red, green, blue;
  assign red   = fb_red;
  assign green = fb_green;
  assign blue  = fb_blue;

  //ALL AXI STREAM VARS ARE GOING HERE

  //write_data 
  logic [127:0]       s_axi_wdata;
  logic               s_axi_wlast;
  logic               s_axi_wvalid;
  logic               s_axi_wready;
  //write_add
  logic [ 26:0]       s_axi_awaddr;
  logic               s_axi_awvalid;
  logic               s_axi_awready;
  logic               s_axi_awlast;
  //read addy;
  logic               s_axi_arvalid;
  logic               s_axi_arready;
  logic             [26:0]  s_axi_araddr;
  //read_data;
  logic [127:0]       s_axi_rdata;
  logic               s_axi_rresp;
  logic               s_axi_rlast;
  logic               s_axi_rvalid;
  logic               s_axi_rready;

  logic               read_addr_ready;
  logic               wr_last;


  logic [  7:0][15:0] write_data;
  logic [ 26:0]       write_addr;
  logic               addr_fifo_ready_out;
  logic               data_fifo_ready_out;
  logic               addr_fifo_valid_in;
  logic               data_fifo_valid_in;
  logic               stacker_last;
  
  logic prev_btn;
  always_ff@(posedge clk_camera)begin
    prev_btn<=btn[1];
  end

  test_stacker test_stacker_inst (
      .clk_in(clk_camera),
      .rst_in(sys_rst_camera),
      .addr_fifo_ready_in(addr_fifo_ready_out),
      .data_fifo_ready_in(data_fifo_ready_out),
      .pattern_sel_in(sw[15:14]),
      .addr_fifo_valid_in(addr_fifo_valid_in),
      .data_fifo_valid_in(data_fifo_valid_in),
      .addr_fifo_data_in(write_addr),
      .data_fifo_data_in(write_data),
      .last_out(stacker_last)
  );


  // FIFO data queue of 128-bit messages, crosses clock domains to the 81.25MHz
  ddr_fifo_wrap write_data_fifo (
      .sender_rst(sys_rst_camera),
      .sender_clk(clk_camera),
      .sender_axis_tvalid(data_fifo_valid_in),
      .sender_axis_tready(data_fifo_ready_out),
      .sender_axis_tdata(write_data),
      .sender_axis_tlast(stacker_last),
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
      .sender_rst(sys_rst_camera),
      .sender_clk(clk_camera),
      .sender_axis_tvalid(addr_fifo_valid_in),
      .sender_axis_tready(addr_fifo_ready_out),
      .sender_axis_tdata({5'b0,write_addr}),
      .sender_axis_tlast(stacker_last),
      .sender_axis_prog_full(),

      .receiver_clk(clk_ui),
      .receiver_axis_tvalid(s_axi_awvalid),
      .receiver_axis_tready(s_axi_awready),
      .receiver_axis_tdata(s_axi_awaddr),
      .receiver_axis_tlast(s_axi_awlast),
      .receiver_axis_prog_empty()
  );

  logic [127:0] display_ui_axis_tdata;
  logic         display_ui_axis_tlast;
  logic         display_ui_axis_tready;
  logic         display_ui_axis_tvalid;
  logic         display_ui_axis_prog_full;

  // these are the signals that the MIG IP needs for us to define!
  // MIG UI --> generic outputs
  logic [ 26:0] app_addr;
  logic [  2:0] app_cmd;
  logic         app_en;
  // MIG UI --> write outputs
  logic [127:0] app_wdf_data;
  logic         app_wdf_end;
  logic         app_wdf_wren;
  logic [ 15:0] app_wdf_mask;
  // MIG UI --> read inputs
  logic [127:0] app_rd_data;
  logic         app_rd_data_end;
  logic         app_rd_data_valid;
  // MIG UI --> generic inputs
  logic         app_rdy;
  logic         app_wdf_rdy;
  // MIG UI --> misc
  logic         app_sr_req;
  logic         app_ref_req;
  logic         app_zq_req;
  logic         app_sr_active;
  logic         app_ref_ack;
  logic         app_zq_ack;
  logic         init_calib_complete;

  logic [ 26:0] read_addr;

  logic [6:0] ss_c;

  
  assign s_axi_arvalid = 1'b1;
  evt_counter #(
      .MAX_COUNT(115200)
  ) read_req_addr (
      .clk_in(clk_ui),
      .rst_in(sys_rst_ui),
      .evt_in(s_axi_arready && s_axi_arvalid),
      .count_out(s_axi_araddr)
  );

  logic [20:0] next_addr;
  evt_counter #(
    .MAX_COUNT(70000)
  ) addr_display(
    .clk_in(clk_camera),
    .rst_in(sys_rst_camera),
    .evt_in(1'b1),
    .count_out(next_addr)
  );
  logic [31:0] seven_seg_write;
  always_comb begin
  if(next_addr==0)begin
    seven_seg_write=s_axi_araddr;
  end
  end

  seven_segment_controller(
    .clk_in(clk_ui),
    .rst_in(sys_rst_ui),
    .val_in(seven_seg_write),
    .cat_out(ss_c),
    .an_out({ss0_an,ss1_an})
  );
  assign ss0_c=ss_c;
  assign ss1_c=ss_c;
  // the MIG IP!

  //empty signals to not make it mad
  logic [1:0] s_axi_bresp;
  logic s_axi_bvalid;
  logic cs_n;
  logic mmcm_locked;
  mig_7series_0 u_mig_7series_0 (

      // Memory interface ports
      .ddr3_addr          (ddr3_addr),           // output [12:0]		ddr3_addr
      .ddr3_ba            (ddr3_ba),             // output [2:0]		ddr3_ba
      .ddr3_cas_n         (ddr3_cas_n),          // output			ddr3_cas_n
      .ddr3_ck_n          (ddr3_ck_n),           // output [0:0]		ddr3_ck_n
      .ddr3_ck_p          (ddr3_ck_p),           // output [0:0]		ddr3_ck_p
      .ddr3_cke           (ddr3_cke),            // output [0:0]		ddr3_cke
      .ddr3_ras_n         (ddr3_ras_n),          // output			ddr3_ras_n
      .ddr3_reset_n       (ddr3_reset_n),        // output			ddr3_reset_n
      .ddr3_we_n          (ddr3_we_n),           // output			ddr3_we_n
      .ddr3_dq            (ddr3_dq),             // inout [15:0]		ddr3_dq
      .ddr3_dqs_n         (ddr3_dqs_n),          // inout [1:0]		ddr3_dqs_n
      .ddr3_dqs_p         (ddr3_dqs_p),          // inout [1:0]		ddr3_dqs_p
      .init_calib_complete(init_calib_complete), // output			init_calib_complete

      .ddr3_dm        (ddr3_dm),             // output [1:0]		ddr3_dm
      .ddr3_odt       (ddr3_odt),            // output [0:0]		ddr3_odt
      // Application interface ports
      .ui_clk         (clk_ui),              // output			ui_clk
      .ui_clk_sync_rst(sys_rst_ui),          // output			ui_clk_sync_rst
      .mmcm_locked    (mmcm_locked),         // output			mmcm_locked
      .aresetn        (!sys_rst_ui),     // input			aresetn
      .app_sr_req     (1'b0),                // input			app_sr_req
      .app_ref_req    (1'b0),                // input			app_ref_req
      .app_zq_req     (1'b0),                // input			app_zq_req
      .app_sr_active  (app_sr_active),       // output			app_sr_active
      .app_ref_ack    (app_ref_ack),         // output			app_ref_ack
      .app_zq_ack     (app_zq_ack),          // output			app_zq_ack
      // Slave Interface Write Address Ports
      // MIG ADDRESS WRITE IN
      .s_axi_awid     (4'b0000),             // input [3:0]			s_axi_awid
      .s_axi_awaddr   (s_axi_awaddr[26:0]),  // input [26:0]			s_axi_awaddr
      //FIXED
      .s_axi_awlen    (8'b0),                // input [7:0]			s_axi_awlen
      .s_axi_awsize   (3'b100),              // input [2:0]			s_axi_awsize
      .s_axi_awburst  (2'b00),               // input [1:0]			s_axi_awburst

      .s_axi_awlock (1'b0),  // input [0:0]			s_axi_awlock
      .s_axi_awcache(4'b0),  // input [3:0]			s_axi_awcache
      .s_axi_awprot (3'b0),  // input [2:0]			s_axi_awprot
      .s_axi_awqos  (4'b0),  // input [3:0]			s_axi_awqos

      //TODO:CHANGEME
      .s_axi_awvalid(s_axi_awvalid),  // input			s_axi_awvalid
      .s_axi_awready(s_axi_awready),  // output			s_axi_awready
      // Slave Interface Write Data Ports
      //   .s_axi_wdata({
      //     {16{sw[15]}},
      //     {16{sw[14]}},
      //     {16{sw[13]}},
      //     {16{sw[12]}},
      //     {16{sw[11]}},
      //     {16{sw[10]}},
      //     {16{sw[9]}},
      //     {16{sw[8]}}
      //   }),  // input [127:0]			s_axi_wdata
      // MIG DATA WRITE IN
      .s_axi_wdata(s_axi_wdata),
      .s_axi_wstrb(16'hFFFF),  // input [15:0]			s_axi_wstrb
      //this matters
      // wlast is 1 will result in 1 element bursts
      // TODO: LOOK INTO THIS IF WE GET TOO MUCH DELAY FROM DRAM....
      .s_axi_wlast(1'b1),  // input			s_axi_wlast
      //TODO:CHANGE ME
      .s_axi_wvalid(s_axi_wvalid),  // input			s_axi_wvalid
      .s_axi_wready(s_axi_wready),  // output			s_axi_wready
      // Slave Interface Write Response Ports
      .s_axi_bid(),  // output [3:0]			s_axi_bid
      .s_axi_bresp(s_axi_bresp),  // output [1:0]			s_axi_bresp
      .s_axi_bvalid(s_axi_bvalid),  // output			s_axi_bvalid
      .s_axi_bready(1'b1),  // input			s_axi_bready
      // Slave Interface Read Address Ports
      .s_axi_arid(4'b0000),  // input [3:0]			s_axi_arid
      .s_axi_araddr(s_axi_araddr<<4),  // input [26:0]			s_axi_araddr

      .s_axi_arlen  (8'b0),    // input [7:0]			s_axi_arlen
      .s_axi_arsize (3'b100),  // input [2:0]			s_axi_arsize
      .s_axi_arburst(2'b00),   // input [1:0]			s_axi_arburst
      .s_axi_arlock (1'b0),    // input [0:0]			s_axi_arlock
      .s_axi_arcache(4'b0),    // input [3:0]			s_axi_arcache
      .s_axi_arprot (3'b0),    // input [2:0]			s_axi_arprot
      .s_axi_arqos  (4'b0),    // input [3:0]			s_axi_arqos

      .s_axi_arvalid(s_axi_arvalid),  // input			s_axi_arvalid
      .s_axi_arready(s_axi_arready),  // output			s_axi_arready

      // Slave Interface Read Data Ports
      .s_axi_rid  (),      // output [3:0]			s_axi_rid
      .s_axi_rdata(s_axi_rdata),  // output [127:0]			s_axi_rdata
      .s_axi_rresp(s_axi_rresp),  // output  [1:0]			s_axi_rresp

      //this matters
      .s_axi_rlast (s_axi_rlast),   // output			s_axi_rlast
      .s_axi_rvalid(s_axi_rvalid),  // output			s_axi_rvalid
      .s_axi_rready(s_axi_rready),  // input			s_axi_rready
      // System Clock Ports
      .sys_clk_i   (clk_migref),

      // Reference Clock Ports
      .sys_rst(!sys_rst_migref)  // input sys_rst
  );


  logic [127:0] display_axis_tdata;
  logic         display_axis_tlast;
  logic         display_axis_tready;
  logic         display_axis_tvalid;
  logic         display_axis_prog_empty;

  logic         last_frame_chunk;

  evt_counter #(
      .MAX_COUNT(115200)
  ) read_resp_addr (
      .clk_in(clk_ui),
      .rst_in(sys_rst_ui),
      .evt_in(s_axi_rready && s_axi_rvalid),
      .count_out(read_addr)
  );

  assign last_frame_chunk = read_addr == 115200 - 1;

  ddr_fifo_wrap read_data_fifo (
      .sender_rst(sys_rst_ui),
      .sender_clk(clk_ui),
      .sender_axis_tvalid(s_axi_rvalid),
      .sender_axis_tready(s_axi_rready),
      .sender_axis_tdata(s_axi_rdata),
      .sender_axis_tlast(last_frame_chunk),
      .sender_axis_prog_full(),

      .receiver_clk(clk_pixel),
      .receiver_axis_tvalid(display_axis_tvalid),
      .receiver_axis_tready(display_axis_tready),
      .receiver_axis_tdata(display_axis_tdata),
      .receiver_axis_tlast(display_axis_tlast),
      .receiver_axis_prog_empty()
  );

  logic        frame_buff_tvalid;
  logic        frame_buff_tready;
  logic [15:0] frame_buff_tdata;
  logic        frame_buff_tlast;

  //   logic         test_stacker_unstacker_tvalid;
  //   logic         test_stacker_unstacker_tready;
  //   logic [127:0] test_stacker_unstacker_tdata;
  //   logic         test_stacker_unstacker_tlast;

  //   basic_stacker test_stacker_inst2 (
  //       .clk_in(clk_pixel),
  //       .rst_in(sys_rst_pixel),
  //       .data_fifo_ready_in(test_stacker_unstacker_tready),
  //       .pattern_sel_in(sw[15:14]),
  //       .data_fifo_valid_in(test_stacker_unstacker_tvalid),
  //       .addr_fifo_data_in(),
  //       .data_fifo_data_in(test_stacker_unstacker_tdata),
  //       .last_out(test_stacker_unstacker_tlast)
  //   );


  unstacker unstacker_inst (
      .clk_in(clk_pixel),
      .rst_in(sys_rst_pixel),
      .chunk_tvalid(display_axis_tvalid),
      .chunk_tready(display_axis_tready),
      .chunk_tdata(display_axis_tdata),
      .chunk_tlast(display_axis_tlast),
      //   .chunk_tvalid(test_stacker_unstacker_tvalid),
      //   .chunk_tready(test_stacker_unstacker_tready),
      //   .chunk_tdata(test_stacker_unstacker_tdata),
      //   .chunk_tlast(test_stacker_unstacker_tlast),
      .pixel_tvalid(frame_buff_tvalid),
      .pixel_tready(frame_buff_tready),
      .pixel_tdata(frame_buff_tdata),
      .pixel_tlast(frame_buff_tlast)
  );

  logic [15:0] frame_buff_pixel;
  // TODO: CHECK WHY THIS IS GIVING BLUE AT THE BEGINNING OF THE SCREEN....
  assign frame_buff_pixel = frame_buff_tvalid & frame_buff_tready ? frame_buff_tdata : 16'hf800; // only take a pixel when a handshake happens???
  always_ff @(posedge clk_pixel) begin
    fb_red   <= {frame_buff_pixel[15:11], 3'b0};
    fb_green <= {frame_buff_pixel[10:5], 2'b0};
    fb_blue  <= {frame_buff_pixel[4:0], 3'b0};
  end


  // : assign frame_buff_tready
  // I did this in 1 (kind of long) line. an always_comb block could also work.
  //assign frame_buff_tready = (active_draw_hdmi)&&(!frame_buff_tlast || (hcount_hdmi==1279 && vcount_hdmi==719)); // change me!!
  assign frame_buff_tready = frame_buff_tlast ? (active_draw_hdmi && hcount_hdmi ==  1279 && vcount_hdmi == 719) : active_draw_hdmi;

  // HDMI video signal generator
  video_sig_gen vsg (
      .pixel_clk_in(clk_pixel),
      .rst_in(sys_rst_pixel),
      .hcount_out(hcount_hdmi),
      .vcount_out(vcount_hdmi),
      .vs_out(vsync_hdmi),
      .hs_out(hsync_hdmi),
      .nf_out(nf_hdmi),
      .ad_out(active_draw_hdmi),
      .fc_out(frame_count_hdmi)
  );


  // HDMI Output: just like before!

  logic [9:0] tmds_10b   [0:2];  //output of each TMDS encoder!
  logic       tmds_signal[2:0];  //output of each TMDS serializer!

  tmds_encoder tmds_red (
      .clk_in(clk_pixel),
      .rst_in(sys_rst_pixel),
      .data_in(red),
      .control_in(2'b0),
      .ve_in(active_draw_hdmi),
      .tmds_out(tmds_10b[2])
  );

  tmds_encoder tmds_green (
      .clk_in(clk_pixel),
      .rst_in(sys_rst_pixel),
      .data_in(green),
      .control_in(2'b0),
      .ve_in(active_draw_hdmi),
      .tmds_out(tmds_10b[1])
  );

  tmds_encoder tmds_blue (
      .clk_in(clk_pixel),
      .rst_in(sys_rst_pixel),
      .data_in(blue),
      .control_in({vsync_hdmi, hsync_hdmi}),
      .ve_in(active_draw_hdmi),
      .tmds_out(tmds_10b[0])
  );


  //three tmds_serializers (blue, green, red):
  //MISSING: two more serializers for the green and blue tmds signals.
  tmds_serializer red_ser (
      .clk_pixel_in(clk_pixel),
      .clk_5x_in(clk_5x),
      .rst_in(sys_rst_pixel),
      .tmds_in(tmds_10b[2]),
      .tmds_out(tmds_signal[2])
  );
  tmds_serializer green_ser (
      .clk_pixel_in(clk_pixel),
      .clk_5x_in(clk_5x),
      .rst_in(sys_rst_pixel),
      .tmds_in(tmds_10b[1]),
      .tmds_out(tmds_signal[1])
  );
  tmds_serializer blue_ser (
      .clk_pixel_in(clk_pixel),
      .clk_5x_in(clk_5x),
      .rst_in(sys_rst_pixel),
      .tmds_in(tmds_10b[0]),
      .tmds_out(tmds_signal[0])
  );

  //output buffers generating differential signals:
  //three for the r,g,b signals and one that is at the pixel clock rate
  //the HDMI receivers use recover logic coupled with the control signals asserted
  //during blanking and sync periods to synchronize their faster bit clocks off
  //of the slower pixel clock (so they can recover a clock of about 742.5 MHz from
  //the slower 74.25 MHz clock)
  OBUFDS OBUFDS_blue (
      .I (tmds_signal[0]),
      .O (hdmi_tx_p[0]),
      .OB(hdmi_tx_n[0])
  );
  OBUFDS OBUFDS_green (
      .I (tmds_signal[1]),
      .O (hdmi_tx_p[1]),
      .OB(hdmi_tx_n[1])
  );
  OBUFDS OBUFDS_red (
      .I (tmds_signal[2]),
      .O (hdmi_tx_p[2]),
      .OB(hdmi_tx_n[2])
  );
  OBUFDS OBUFDS_clock (
      .I (clk_pixel),
      .O (hdmi_clk_p),
      .OB(hdmi_clk_n)
  );


  // Nothing To Touch Down Here:
  // register writes to the camera

  // The OV5640 has an I2C bus connected to the board, which is used
  // for setting all the hardware settings (gain, white balance,
  // compression, image quality, etc) needed to start the camera up.
  // We've taken care of setting these all these values for you:
  // "rom.mem" holds a sequence of bytes to be sent over I2C to get
  // the camera up and running, and we've written a design that sends
  // them just after a reset completes.

  // If the camera is not giving data, press your reset button.

  logic busy, bus_active;
  logic cr_init_valid, cr_init_ready;

  logic recent_reset;
  always_ff @(posedge clk_camera) begin
    if (sys_rst_camera) begin
      recent_reset  <= 1'b1;
      cr_init_valid <= 1'b0;
    end else if (recent_reset) begin
      cr_init_valid <= 1'b1;
      recent_reset  <= 1'b0;
    end else if (cr_init_valid && cr_init_ready) begin
      cr_init_valid <= 1'b0;
    end
  end

  logic [23:0] bram_dout;
  logic [ 7:0] bram_addr;

  // ROM holding pre-built camera settings to send
  xilinx_single_port_ram_read_first #(
      .RAM_WIDTH(24),
      .RAM_DEPTH(256),
      .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
      .INIT_FILE("rom.mem")
  ) registers (
      .addra(bram_addr),  // Address bus, width determined from RAM_DEPTH
      .dina(24'b0),  // RAM input data, width determined from RAM_WIDTH
      .clka(clk_camera),  // Clock
      .wea(1'b0),  // Write enable
      .ena(1'b1),  // RAM Enable, for additional power savings, disable port when not in use
      .rsta(sys_rst_camera),  // Output reset (does not affect memory contents)
      .regcea(1'b1),  // Output register enable
      .douta(bram_dout)  // RAM output data, width determined from RAM_WIDTH
  );

  logic [23:0] registers_dout;
  logic [ 7:0] registers_addr;
  assign registers_dout = bram_dout;
  assign bram_addr = registers_addr;

  logic con_scl_i, con_scl_o, con_scl_t;
  logic con_sda_i, con_sda_o, con_sda_t;

  // NOTE these also have pullup specified in the xdc file!
  // access our inouts properly as tri-state pins
  IOBUF IOBUF_scl (
      .I (con_scl_o),
      .IO(i2c_scl),
      .O (con_scl_i),
      .T (con_scl_t)
  );
  IOBUF IOBUF_sda (
      .I (con_sda_o),
      .IO(i2c_sda),
      .O (con_sda_i),
      .T (con_sda_t)
  );

  // provided module to send data BRAM -> I2C
  camera_registers crw (
      .clk_in(clk_camera),
      .rst_in(sys_rst_camera),
      .init_valid(cr_init_valid),
      .init_ready(cr_init_ready),
      .scl_i(con_scl_i),
      .scl_o(con_scl_o),
      .scl_t(con_scl_t),
      .sda_i(con_sda_i),
      .sda_o(con_sda_o),
      .sda_t(con_sda_t),
      .bram_dout(registers_dout),
      .bram_addr(registers_addr)
  );

  // a handful of debug signals for writing to registers
  assign led[0] = 0;
  assign led[1] = cr_init_valid;
  assign led[2] = cr_init_ready;
  assign led[15:3] = 0;

endmodule  // top_level


`default_nettype wire

