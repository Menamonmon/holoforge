

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

//framebuffer refrence
`timescale 1ns / 1ps `default_nettype none
module top_level (
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
    output logic        hdmi_clk_p,hdmi_clk_n,

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

  // shut up those RGBs
  assign rgb0 = 0;
  assign rgb1 = 0;
  //clk_wiz stuff

  // Clock and Reset Signals: updated for a couple new clocks!
  logic sys_rst_camera;
  logic sys_rst_pixel;

  logic clk_camera;
  logic clk_pixel;
  logic clk_5x;


  logic clk_migref;
  logic sys_rst_migref;

  logic clk_ui;
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

  assign sys_rst_camera = btn[0];  //use for resetting camera side of logic
  assign sys_rst_pixel = btn[0];  //use for resetting hdmi/draw side of logic
  assign sys_rst_migref = btn[0];


  logic sys_rst;


  //DONT TOUCH THESE
  logic clk_xc;
  assign cam_xclk = clk_xc;

  assign sys_rst_pixel = btn[0];  //use for resetting hdmi/draw side of logic
  assign sys_rst = btn[0];  // reset for graphics....


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
  localparam int ADDR_MAX = (HRES * VRES);






  //im praying i can just copy paste this and it'll give me the excact same functionality
  // Compute next_data_ready based on FIFO readiness
  logic stacker_ready_out;
  logic [15:0] data;
  logic [26:0] addr;
  logic next_data_ready;
  logic [$clog2(HRES)-1:0] hcount;
  logic [$clog2(VRES)-1:0] vcount;
  assign next_data_ready = stacker_ready_out;

  // Horizontal counter

  logic [$clog2(ADDR_MAX)-1:0] stacker_addr;
  evt_counter #(
      .MAX_COUNT(ADDR_MAX)
  ) addr_counter (
      .clk_in(clk_100_passthrough),
      .rst_in(sys_rst),
      .evt_in(next_data_ready),
      .count_out(stacker_addr)
  );

  evt_counter #(
      .MAX_COUNT(HRES)
  ) hcounter (
      .clk_in(clk_100_passthrough),
      .rst_in(sys_rst),
      .evt_in(next_data_ready),
      .count_out(hcount)
  );

  // Vertical counter
  evt_counter #(
      .MAX_COUNT(VRES)
  ) vcounter (
      .clk_in(clk_100_passthrough),
      .rst_in(sys_rst),
      .evt_in((hcount == HRES - 1) && next_data_ready),
      .count_out(vcount)
  );


  logic stacker_valid_in;

  // Generate 8 instances of test_pattern_generator
  logic [7:0] test_red;
  logic [7:0] test_green;
  logic [7:0] test_blue;

  test_pattern_generator #(
      .HRES(HRES),
      .VRES(VRES)
  ) pattern_gen (
      .sel_in(frame_tester+2),
      .hcount_in(hcount),
      .vcount_in(vcount),
      .red_out(test_red),
      .green_out(test_green),
      .blue_out(test_blue)
  );
  assign data = {test_red[7:3], test_green[7:2], test_blue[7:3]};




  //hear up you have to integrate rasterizer stuff

  logic        frame_buff_tvalid;
  logic        frame_buff_tready;
  logic [15:0] frame_buff_tdata;
  logic        frame_buff_tlast;
  logic [15:0] frame_buff_pixel;


  logic frame_tester;
  logic [6:0] frame_delay;
  evt_counter #(
      .MAX_COUNT(100)
    ) frame_counter (
      .clk_in(clk_100_passthrough),
      .rst_in(sys_rst),
      .evt_in(ADDR_MAX-1==stacker_addr),
      .count_out(frame_delay)
  );
  logic clear_sig; 
  localparam Z_WIDTH = 16;
  assign frame_tester=sw[6];
  logic rising_edge_switch;
  always_ff@(posedge clk_100_passthrough)begin
    rising_edge_switch<=btn[3];
    clear_sig<=!rising_edge_switch && btn[3];
  end
  framebuffer #(
        .Z_WIDTH(Z_WIDTH),
        .HRES(HRES),
        .VRES(VRES)
    ) dut (
        .clk_100mhz        (clk_100mhz),
        .sys_rst           (sys_rst),
        .valid_in          (sw[4]),
        .addr_in           (stacker_addr),
        .depth_in          ({sw[13:11],4'b0}),
        .color_in          (data),
        .rasterizer_rdy_out(stacker_ready_out),

        .clk_100_passthrough,
        .clk_pixel,
        .clk_migref,
        .sys_rst_migref,
        .sw,
        //TODO:Change This
        .clear_sig, 

        //pretty useful debugging signal
        // .frame_override(frame_tester),

        .ss0_an,
        .ss1_an,
        .ss0_c,
        .ss1_c,

        .frame_buff_tvalid (frame_buff_tvalid),
        .frame_buff_tready (frame_buff_tready),
        .frame_buff_tdata  (frame_buff_tdata),
        .frame_buff_tlast  (frame_buff_tlast),

        .ddr3_dq           (ddr3_dq),
        .ddr3_dqs_n        (ddr3_dqs_n),
        .ddr3_dqs_p        (ddr3_dqs_p),
        .ddr3_addr         (ddr3_addr),
        .ddr3_ba           (ddr3_ba),
        .ddr3_ras_n        (ddr3_ras_n),
        .ddr3_cas_n        (ddr3_cas_n),
        .ddr3_we_n         (ddr3_we_n),
        .ddr3_reset_n      (ddr3_reset_n),
        .ddr3_ck_p         (ddr3_ck_p),
        .ddr3_ck_n         (ddr3_ck_n),
        .ddr3_cke          (ddr3_cke),
        .ddr3_dm           (ddr3_dm),
        .ddr3_odt          (ddr3_odt)
    );



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
  assign frame_buff_tready = frame_buff_tlast ? (active_draw_hdmi && hcount_hdmi ==  HRES-1 && vcount_hdmi == VRES-1) : (hcount_hdmi<HRES && vcount_hdmi<VRES);

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




// =======
//   // parameters {'P_WIDTH': 16, 'C_WIDTH': 18, 'V_WIDTH': 16, 'FRAC_BITS': 14, 'VH_OVER_TWO': 12288, 'VH_OVER_TWO_WIDTH': 16, 'VW_OVER_TWO': 12288, 'VW_OVER_TWO_WIDTH': 16, 'VIEWPORT_H_POSITION_WIDTH': 18, 'VIEWPORT_W_POSITION_WIDTH': 18, 'NUM_TRI': 12, 'NUM_COLORS': 256, 'FB_HRES': 320, 'FB_VRES': 180, 'HRES_BY_VW_WIDTH': 23, 'HRES_BY_VW_FRAC': 14, 'VRES_BY_VH_WIDTH': 22, 'VRES_BY_VH_FRAC': 14, 'HRES_BY_VW': 3495253, 'VRES_BY_VH': 1966080, 'VW_BY_HRES_WIDTH': 23, 'VW_BY_HRES_FRAC': 14, 'VH_BY_VRES_WIDTH': 22, 'VH_BY_VRES_FRAC': 14, 'VW_BY_HRES': 77, 'VH_BY_VRES': 137}

//   logic [2:0][15:0] P;
//   logic [2:0][17:0] C;
//   logic [2:0][15:0] u;
//   logic [2:0][15:0] v;
//   logic [2:0][15:0] n;
//   logic valid_out;
//   logic ready_out;
//   logic last_pixel_out;
//   logic [2:0][18:0] hcount_out;
//   logic [2:0][18:0] vcount_out;
//   logic [2:0][29:0] z_out;
//   logic [8:0] color_out;

//   random_noise #(
//       .N(3 * 16),
//       .LFSR_WIDTH(3 * 16)
//   ) P_noise (
//       .clk_in(clk_100mhz),
//       .rst_in(1'b0),
//       .noise (P)
//   );

//   random_noise #(
//       .N(3 * 18),
//       .LFSR_WIDTH(3 * 18)
//   ) C_noise (
//       .clk_in(clk_100mhz),
//       .rst_in(1'b0),
//       .noise (C)
//   );

//   random_noise #(
//       .N(3 * 16),
//       .LFSR_WIDTH(3 * 16)
//   ) u_noise (
//       .clk_in(clk_100mhz),
//       .rst_in(1'b0),
//       .noise (u)
//   );

//   random_noise #(
//       .N(3 * 16),
//       .LFSR_WIDTH(3 * 16)
//   ) v_noise (
//       .clk_in(clk_100mhz),
//       .rst_in(1'b0),
//       .noise (v)
//   );

//   random_noise #(
//       .N(3 * 16),
//       .LFSR_WIDTH(3 * 16)
//   ) n_noise (
//       .clk_in(clk_100mhz),
//       .rst_in(1'b0),
//       .noise (n)
//   );



//   graphics_pipeline_no_brom #(
//       .C_WIDTH(18),
//       .P_WIDTH(16),
//       .V_WIDTH(16),
//       .FRAC_BITS(14),
//       .VH_OVER_TWO(12288),
//       .VH_OVER_TWO_WIDTH(16),
//       .VW_OVER_TWO(12288),
//       .VW_OVER_TWO_WIDTH(16),
//       .VIEWPORT_H_POSITION_WIDTH(18),
//       .VIEWPORT_W_POSITION_WIDTH(18),
//       .NUM_TRI(12),
//       .NUM_COLORS(256),
//       .FB_HRES(320),
//       .FB_VRES(180),
//       .HRES_BY_VW_WIDTH(23),
//       .HRES_BY_VW_FRAC(14),
//       .VRES_BY_VH_WIDTH(22),
//       .VRES_BY_VH_FRAC(14),
//       .HRES_BY_VW(3495253),
//       .VRES_BY_VH(1966080),
//       .VW_BY_HRES_WIDTH(23),
//       .VW_BY_HRES_FRAC(14),
//       .VH_BY_VRES_WIDTH(22),
//       .VH_BY_VRES_FRAC(14),
//       .VW_BY_HRES(77),
//       .VH_BY_VRES(137)
//   ) graphics_goes_brrrrrr (
//       .clk_in(clk_100mhz),
//       .rst_in(1'b0),
//       .valid_in(1'b1),
//       .ready_in(1'b1),
//       .tri_id_in(4'b0),
//       .P(P),
//       .C(C),
//       .u(u),
//       .v(v),
//       .n(n),
//       .valid_out(valid_out),
//       .ready_out(ready_out),
//       .last_pixel_out(last_pixel_out),
//       .hcount_out(hcount_out),
//       .vcount_out(vcount_out),
//       .z_out(z_out),
//       .color_out(color_out)
//   );

//   assign led = color_out;
//   assign ss0_an = hcount_out;
//   assign ss1_an = vcount_out;
//   assign ss0_c = z_out[0][7:0];
//   assign ss1_c = z_out[0][15:8];

// endmodule  // top_level



