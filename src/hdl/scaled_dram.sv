// HOLOFORGE - Top Level Module
`timescale 1ns / 1ps `default_nettype none
module scaled_dram (
    input  wire         clk_100mhz,
    output logic [15:0] led,
    // camera bus
    input  wire  [ 7:0] camera_d,    // 8 parallel data wires
    output logic        cam_xclk,    // XC driving camera
    input  wire         cam_hsync,   // camera hsync wire
    input  wire         cam_vsync,   // camera vsync wire
    input  wire         cam_pclk,    // camera pixel clock
    inout  wire         i2c_scl,     // i2c inout clock
    inout  wire         i2c_sda,     // i2c inout data
    input  wire  [15:0] sw,
    input  wire  [ 3:0] btn,
    output logic [ 2:0] rgb0,
    output logic [ 2:0] rgb1,
    // seven segment
    output logic [ 3:0] ss0_an,      //anode control for upper four digits of seven-seg display
    output logic [ 3:0] ss1_an,      //anode control for lower four digits of seven-seg display
    output logic [ 6:0] ss0_c,       //cathode controls for the segments of upper four digits
    output logic [ 6:0] ss1_c,       //cathod controls for the segments of lower four digits
    // hdmi port
    output logic [ 2:0] hdmi_tx_p,   //hdmi output signals (positives) (blue, green, red)
    output logic [ 2:0] hdmi_tx_n,   //hdmi output signals (negatives) (blue, green, red)
    output logic        hdmi_clk_p,
    hdmi_clk_n,

    // New for week 6: DDR3 ports
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
    output wire        ddr3_odt
);

  // Clock and Reset Signals: updated for a couple new clocks!
  logic sys_rst_camera;
  logic sys_rst_pixel;

  logic clk_camera;
  logic clk_pixel;
  logic clk_5x;


  logic clk_migref;
  logic sys_rst_migref;

  logic clk_ui;
  logic clk_xc;
  logic sys_rst_ui;

  logic clk_100_passthrough;
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
  // shut up those RGBs
  assign rgb0 = 0;
  assign rgb1 = 0;

  assign cam_xclk = clk_xc;
  logic sys_rst;
  assign sys_rst = btn[0];  //use for resetting all logic
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



  localparam int HRES = 320;
  localparam int VRES = 180;
  localparam int FULL_HRES = 1280;
  localparam int FULL_VRES = 720;
  localparam int ADDR_MAX = (HRES * VRES);

  logic stacker_ready_out;
  logic [15:0] data;
  logic [26:0] addr;
  logic next_data_ready;
  logic [$clog2(HRES)-1:0] hcount;
  logic [$clog2(VRES)-1:0] vcount;
  assign next_data_ready = stacker_ready_out;

  // Horizontal counter

  evt_counter #(
      .MAX_COUNT(ADDR_MAX)
  ) addr_counter (
      .clk_in(clk_100_passthrough),
      .rst_in(sys_rst),
      .evt_in(framebuffer_ready_out),
      .count_out(graphics_addr_out)
  );

  evt_counter #(
      .MAX_COUNT(HRES)
  ) hcounter (
      .clk_in(clk_100_passthrough),
      .rst_in(sys_rst),
      .evt_in(framebuffer_ready_out),
      .count_out(hcount)
  );

  // Vertical counter
  evt_counter #(
      .MAX_COUNT(VRES)
  ) vcounter (
      .clk_in(clk_100_passthrough),
      .rst_in(sys_rst),
      .evt_in((hcount == HRES - 1) && framebuffer_ready_out),
      .count_out(vcount)
  );


  // Generate 8 instances of test_pattern_generator
  logic [7:0] test_red;
  logic [7:0] test_green;
  logic [7:0] test_blue;

  test_pattern_generator #(
      .HRES(HRES),
      .VRES(VRES)
  ) pattern_gen (
      .sel_in(sw[15:14]),
      .hcount_in(hcount),
      .vcount_in(vcount),
      .red_out(test_red),
      .green_out(test_green),
      .blue_out(test_blue)
  );
  assign graphics_color_out = {test_red[7:3], test_green[7:2], test_blue[7:3]};
  assign graphics_valid_out = 1'b1;


  logic btn_rising_edge;
  logic prev_btn;
  always_ff @(posedge clk_100mhz) begin
    btn_rising_edge <= btn[1] && !prev_btn;
    prev_btn <= btn[1];
  end

  localparam Z_WIDTH = 19;
  logic        frame_buff_tvalid;
  logic        frame_buff_tready;
  logic [15:0] frame_buff_tdata;
  logic        frame_buff_tlast;
  logic [15:0] frame_buff_pixel;

  assign led = sw;  //to verify the switch values

  logic graphics_valid_out;
  logic graphics_last_pixel_out;
  logic graphics_last_tri_out;
  logic [26:0] graphics_addr_out;
  logic [15:0] graphics_color_out;
  logic [Z_WIDTH-1:0] graphics_depth_out;
  logic framebuffer_ready_out;
  logic graphics_ready_out;

  logic [26:0] read_req_addr;
  logic [26:0] read_res_addr;

  framebuffer #(
      .Z_WIDTH(Z_WIDTH),
      .SCALE_FACTOR(SCALE_FACTOR),
      .HRES(HRES),
      .VRES(VRES)
  ) dut (
      .clk_100mhz        (clk_100mhz),
      .sys_rst           (sys_rst),
      .valid_in          (graphics_valid_out),
      .addr_in           (graphics_addr_out),
      .depth_in          (graphics_depth_out),
      //   .frame_override    (sw[6]),
      .color_in          (graphics_color_out),
      .rasterizer_rdy_out(framebuffer_ready_out),
      .clear_sig         (btn_rising_edge),

      // DEBUG SIGNALS
      .read_addr(read_req_addr),
      .s_axi_araddr(read_res_addr),

      .clk_100_passthrough,
      .clk_pixel,
      .clk_migref,
      .sys_rst_migref,
      .clk_ui,

      .frame_buff_tvalid(frame_buff_tvalid),
      .frame_buff_tready(frame_buff_tready),
      .frame_buff_tdata (frame_buff_tdata),
      .frame_buff_tlast (frame_buff_tlast),

      .ddr3_dq     (ddr3_dq),
      .ddr3_dqs_n  (ddr3_dqs_n),
      .ddr3_dqs_p  (ddr3_dqs_p),
      .ddr3_addr   (ddr3_addr),
      .ddr3_ba     (ddr3_ba),
      .ddr3_ras_n  (ddr3_ras_n),
      .ddr3_cas_n  (ddr3_cas_n),
      .ddr3_we_n   (ddr3_we_n),
      .ddr3_reset_n(ddr3_reset_n),
      .ddr3_ck_p   (ddr3_ck_p),
      .ddr3_ck_n   (ddr3_ck_n),
      .ddr3_cke    (ddr3_cke),
      .ddr3_dm     (ddr3_dm),
      .ddr3_odt    (ddr3_odt)
  );

  // ZOOMING LOGIC
  localparam SCALE_FACTOR = FULL_HRES / HRES;  // HAS TO BE THE SAME FOR BOTH HRES AND VRES
  localparam LOG_SCALE_FACTOR = $clog2(SCALE_FACTOR);
  logic [$clog2(HRES)-1:0] hcount_scaled;
  logic [$clog2(VRES)-1:0] vcount_scaled;
  logic [LOG_SCALE_FACTOR-1:0] inner_hcount;
  logic [LOG_SCALE_FACTOR-1:0] inner_vcount;
  assign hcount_scaled = hcount_hdmi >> LOG_SCALE_FACTOR;
  assign vcount_scaled = vcount_hdmi >> LOG_SCALE_FACTOR;
  assign inner_hcount = hcount_hdmi[LOG_SCALE_FACTOR-1:0];
  assign inner_vcount = vcount_hdmi[LOG_SCALE_FACTOR-1:0];

  // only ready on the 4th cycle when drawing within the screen
  assign frame_buff_tready = (inner_hcount == 0) && (frame_buff_tlast ? (active_draw_hdmi && hcount_scaled ==  HRES-1 && vcount_scaled == VRES-1) : (hcount_scaled < HRES && vcount_scaled < VRES));


  // TODO: CHECK THE BEGINNING OF THE SCREEN
  assign frame_buff_pixel = frame_buff_tvalid ? frame_buff_tdata : 16'h8410; // only take a pixel when a handshake happens???
  always_ff @(posedge clk_pixel) begin
    fb_red   <= {frame_buff_pixel[15:11], 3'b0};
    fb_green <= {frame_buff_pixel[10:5], 2'b0};
    fb_blue  <= {frame_buff_pixel[4:0], 3'b0};
  end

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

  // Seven Segment Display

  logic [31:0] ssd_out;
  logic [ 6:0] ss_c;

  seven_segment_controller sevensegg (
      .clk_in (clk_ui),
      .rst_in (btn[0]),
      .val_in (ssd_out),
      .cat_out(ss_c),
      .an_out ({ss0_an, ss1_an})
  );
  assign ss0_c = ss_c;
  assign ss1_c = ss_c;

  //   assign ssd_out = sw[15] ? read_res_addr : read_req_addr;
  always_comb begin
    case (sw[12:10])
      0: ssd_out = read_res_addr;
      1: ssd_out = read_req_addr;
      2: ssd_out = frame_buff_tready;
      3: ssd_out = frame_buff_tvalid;
      4: ssd_out = framebuffer_ready_out;
      5: ssd_out = graphics_valid_out;
      6: ssd_out = graphics_ready_out;
      7: ssd_out = graphics_color_out;
    endcase

  end


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

endmodule  // top_level


`default_nettype wire



// e0002000e000e00020002000e000e0002000
// 2000e000e0002000e0002000200020002000
