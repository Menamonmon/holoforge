// HOLOFORGE - Top Level Module
`timescale 1ns / 1ps `default_nettype none
module test_toplevel (
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
    // // hdmi port
    output logic [ 2:0] hdmi_tx_p,   //hdmi output signals (positives) (blue, green, red)
    output logic [ 2:0] hdmi_tx_n,   //hdmi output signals (negatives) (blue, green, red)
    output logic        hdmi_clk_p,
    hdmi_clk_n,

    // // New for week 6: DDR3 ports
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

  assign sys_rst = btn[0];  //use for resetting all logic
  assign sys_rst_camera = btn[0];  //use for resetting camera side of logic
  assign sys_rst_pixel = btn[0];  //use for resetting hdmi/draw side of logic
  assign sys_rst_migref = btn[0];

  // shut up those RGBs
  assign rgb0 = 0;
  assign rgb1 = 0;

  assign cam_xclk = clk_xc;
  logic        sys_rst;



  // video signal generator signals
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


  localparam int HRES = 320;
  localparam int VRES = 180;
  localparam int FULL_HRES = 1280;
  localparam int FULL_VRES = 720;

  logic stacker_ready_out;
  logic [15:0] data;
  logic [26:0] addr;
  logic next_data_ready;
  logic [$clog2(HRES)-1:0] hcount;
  logic [$clog2(VRES)-1:0] vcount;
  assign next_data_ready = stacker_ready_out;

  logic        frame_buff_tvalid;
  logic        frame_buff_tready;
  logic [15:0] frame_buff_tdata;
  logic        frame_buff_tlast;
  logic [15:0] pixel_depth;

  localparam TRI_COUNT = 12;
  localparam TRI_BRAM_SIZE = 20;


  logic frame_tester;
  assign led = sw;  //to verify the switch values


  // DEBUGGING ON SEVEN SEGMENT DISPLAY
  logic prev_btn;
  logic btn_rising_edge;

  logic prev_btn2;
  logic btn_rising_edge2;

  always_ff @(posedge clk_100_passthrough) begin
    prev_btn <= btn[1];
    btn_rising_edge <= btn[1] & ~prev_btn;

    prev_btn2 <= btn[2];
    btn_rising_edge2 <= btn[2] & ~prev_btn2;
  end


  logic [31:0] ssd_out;
  logic [6:0] ss_c;


  logic [15:0] current_tri_vertex;
  logic [16:0] tri_id;
  logic signed [2:0][2:0][15:0] tri_vertices;
  logic tri_valid;


  // TRIANGLE FETCH

  tri_fetch #(
      .TRI_COUNT(TRI_COUNT)
  ) tri_fetch_inst (
      .clk_in(clk_100_passthrough),  //system clock
      .rst_in(sys_rst),  //system reset
      .ready_in(graphics_ready_out),  // TODO: change this ot  //system reset
      .valid_out(tri_valid),
      .tri_vertices_out(tri_vertices),
      .tri_id_out(tri_id)
  );


  // GRAPHICS PIPELINE PARAMS

  // parameters = {
  //     "P_WIDTH": 16,
  //     "C_WIDTH": 18,
  //     "V_WIDTH": 16,
  //     "FRAC_BITS": 14,
  //     "VH_OVER_TWO": 12288,
  //     "VH_OVER_TWO_WIDTH": 16,
  //     "VW_OVER_TWO": 21791,
  //     "VW_OVER_TWO_WIDTH": 17,
  //     "VIEWPORT_H_POSITION_WIDTH": 18,
  //     "VIEWPORT_W_POSITION_WIDTH": 19,
  //     "NUM_TRI": 12,
  //     "NUM_COLORS": 256,
  //     "FB_HRES": 320,
  //     "FB_VRES": 180,
  //     "HRES_BY_VW_WIDTH": 22,
  //     "HRES_BY_VW_FRAC": 14,
  //     "VRES_BY_VH_WIDTH": 22,
  //     "VRES_BY_VH_FRAC": 14,
  //     "HRES_BY_VW": 1971008,
  //     "VRES_BY_VH": 1966080,
  //     "VW_BY_HRES_WIDTH": 23,
  //     "VW_BY_HRES_FRAC": 14,
  //     "VH_BY_VRES_WIDTH": 22,
  //     "VH_BY_VRES_FRAC": 14,
  //     "VW_BY_HRES": 136,
  //     "VH_BY_VRES": 137,
  // }


  localparam C_WIDTH = 18;
  localparam COLOR_WIDTH = 16;
  localparam Z_WIDTH = C_WIDTH + 1;

  logic signed [2:0][C_WIDTH-1:0] C;
  logic signed [2:0][15:0] u, v, n;

  //   assign C = 
  always_comb begin
    // case (sw[3:0])
    //   0: begin
    // C = 54'b110010100111100001000111111000000101001100100110101100;
    // u = 48'h00003646de16;
    // v = 48'hd070e94edbaf;
    // n = 48'h2ad3e6ccd7aa;
    C = 54'b111100000000000000000000000000000000000110111011011010;
    u = 48'hc8930000e000;
    v = 48'h000040000000;
    n = 48'h20000000c893;
    //   end

    //   1: begin
    //   end

    //   2: begin
    //     C = 54'b111100000000000000000110111011011010000000000000000000;
    //     u = 48'h00000000c000;
    //     v = 48'hc893e0000000;
    //     n = 48'h2000c8930000;
    //   end
    // endcase
  end

  //   assign tri_vertices = 144'h2000e000e0002000e0002000200020002000;
  // 0.5, 0.5, 0.5


  localparam HWIDTH = $clog2(HRES);
  localparam VWIDTH = $clog2(VRES);
  localparam XWIDTH = 18;
  localparam YWIDTH = 19;

  logic [HWIDTH-1:0] hcount_max, hcount_min;
  logic [VWIDTH-1:0] vcount_max, vcount_min;
  logic [XWIDTH-1:0] x_max, x_min;
  logic [YWIDTH-1:0] y_max, y_min;
  logic graphics_valid_out;
  logic graphics_last_pixel_out;
  logic graphics_last_tri_out;
  logic [26:0] graphics_addr_out;
  logic [15:0] graphics_color_out;
  logic [Z_WIDTH-1:0] graphics_depth_out;
  logic framebuffer_ready_out;
  logic graphics_ready_out;

  graphics_pipeline_no_brom #(
      .P_WIDTH(16),
      .C_WIDTH(C_WIDTH),
      .V_WIDTH(16),
      .FRAC_BITS(14),
      .VH_OVER_TWO(12288),
      .VH_OVER_TWO_WIDTH(16),
      .VW_OVER_TWO(21791),
      .VW_OVER_TWO_WIDTH(17),
      .VIEWPORT_H_POSITION_WIDTH(18),
      .VIEWPORT_W_POSITION_WIDTH(19),
      .NUM_TRI(TRI_COUNT),
      .NUM_COLORS(256),
      .N(3),
      .FB_HRES(HRES),
      .FB_VRES(VRES),
      .HRES_BY_VW_WIDTH(22),
      .HRES_BY_VW_FRAC(14),
      .VRES_BY_VH_WIDTH(22),
      .VRES_BY_VH_FRAC(14),
      .HRES_BY_VW(1971008),
      .VRES_BY_VH(1966080),
      .VW_BY_HRES_WIDTH(23),
      .VW_BY_HRES_FRAC(14),
      .VH_BY_VRES_WIDTH(22),
      .VH_BY_VRES_FRAC(14),
      .VW_BY_HRES(136),
      .VH_BY_VRES(137)
  ) graphics_goes_brrrrrr (
      .clk_in(clk_100_passthrough),
      .rst_in(sys_rst),
      .valid_in(tri_valid),
      .ready_in(1'b1),
      .tri_id_in(tri_id),
      .P(tri_vertices),
      .C(C),
      .u(u),
      .v(v),
      .n(n),
      .valid_out(graphics_valid_out),
      .ready_out(graphics_ready_out),
      .last_pixel_out(graphics_last_pixel_out),
      .addr_out(graphics_addr_out),
      .hcount_out(hcount),
      .vcount_out(vcount),
      .z_out(graphics_depth_out),
      .color_out(graphics_color_out),

      // DEBUGGING VALUES
      .x_min_out(x_min),
      .x_max_out(x_max),
      .y_min_out(y_min),
      .y_max_out(y_max),
      .hcount_min_out(hcount_min),
      .hcount_max_out(hcount_max),
      .vcount_min_out(vcount_min),
      .vcount_max_out(vcount_max)
  );


  localparam DEPTH = HRES * VRES;
  logic [26:0] clearing_write_addr;
  evt_counter #(
      .MAX_COUNT(DEPTH)
  ) write_addr_counter (
      .clk_in(clk_100_passthrough),
      .rst_in(sys_rst),
      .evt_in(1'b1),
      .count_out(clearing_write_addr)
  );

  // write addressing

  logic [26:0] write_addr;
  logic [26:0] pwrite_addr;
  logic [15:0] write_color;
  logic [15:0] pwrite_color;
  logic pgraphics_valid_out;
  logic [Z_WIDTH-1:0] pgraphics_depth_out;

  logic clearing;
  assign clearing = sw[7];

  assign write_addr = clearing ? clearing_write_addr : graphics_addr_out;
  assign write_color = clearing ? 16'h0000 : graphics_depth_out[Z_WIDTH-3:Z_WIDTH-18];

  logic [15:0] pixel_color;

  logic [Z_WIDTH-1:0] existing_depth;

  logic depth_check;

  // DEPTH MUXING LOGIC
  // on cycle 0
  // depth is generated
  // pipeline the depth 2 cycles for depth check
  // at cycle 2
  // write enable going into the write port for depth ram and color is based on depth < depth_ram | depth_ram == 0
  // at cycle 3
  // write address is pipelined to be the read address from the previous cycle
  logic allow_write;

  // DEPTH BUFFER
  xilinx_true_dual_port_read_first_1_clock_ram #(
      //IF WE GET ERROR CHANGE RAM WIDTH
      .RAM_WIDTH(12),
      .RAM_DEPTH(DEPTH),
      .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
      .INIT_FILE("./data/empty.mem")
  ) depth_ram (
      //WRITING SIDE
      .clka(clk_100_passthrough),
      .rsta(sys_rst),
      .addra(pwrite_addr),  //pixels are stored using this math
      .dina(pgraphics_depth_out[Z_WIDTH-1:Z_WIDTH-12]),
      .wea(allow_write),
      .ena(1'b1),
      .regcea(1'b1),
      .douta(),  //never read from this side

      .rstb(sys_rst),
      .addrb(graphics_addr_out),  //transformed lookup pixel
      .dinb(),
      .web(1'b0),
      .enb(graphics_valid_out),
      .regceb(1'b1),
      .doutb(existing_depth[Z_WIDTH-1:Z_WIDTH-12])
  );


  // TODO: check the signage on this...
  assign depth_check = (pgraphics_depth_out < existing_depth) || existing_depth == 0;


  pipeline #(
      .STAGES(2),
      .DATA_WIDTH(27)
  ) write_addr_pipe (
      .clk_in(clk_100_passthrough),
      .data(write_addr),
      .data_out(pwrite_addr)
  );

  pipeline #(
      .STAGES(2),
      .DATA_WIDTH(1)
  ) graphics_valid_out_pipe (
      .clk_in(clk_100_passthrough),
      .data(graphics_valid_out),
      .data_out(pgraphics_valid_out)
  );

  pipeline #(
      .STAGES(2),
      .DATA_WIDTH(COLOR_WIDTH)
  ) color_pipe (
      .clk_in(clk_100_passthrough),
      .data(write_color),
      .data_out(pwrite_color)
  );

  pipeline #(
      .STAGES(2),
      .DATA_WIDTH(Z_WIDTH)
  ) depth_pipe (
      .clk_in(clk_100_passthrough),
      .data(graphics_depth_out),
      .data_out(pgraphics_depth_out)
  );

  assign allow_write = (depth_check && pgraphics_valid_out) || clearing;

  // FRAMEBUFFER
  // BRAM Frame Buffer
  //   xilinx_true_dual_port_read_first_2_clock_ram #(
  //       //IF WE GET ERROR CHANGE RAM WIDTH
  //       .RAM_WIDTH(16),
  //       .RAM_DEPTH(DEPTH),
  //       .RAM_PERFORMANCE("HIGH_PERFORMANCE")
  //   ) color_ram (
  //       //WRITING SIDE
  //       .clka(clk_100_passthrough),
  //       .rsta(sys_rst),

  //       .addra(pwrite_addr),  //pixels are stored using this math
  //       .wea(allow_write),
  //       .dina(pwrite_color),
  //       .ena(1'b1),
  //       .douta(),  //never read from this side
  //       .regcea(1'b1),

  //       .rstb(sys_rst_pixel),
  //       .clkb(clk_pixel),
  //       .addrb(read_addr),  //transformed lookup pixel
  //       .web(1'b0),
  //       .enb(active_draw_hdmi),
  //       .doutb(pixel_color),

  //       .regceb(1'b1)
  //   );

  // DRAM Frame Buffer
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
      //   .valid_in          (graphics_valid_out),
      //   .addr_in           (graphics_addr_out),
      //   .depth_in          (graphics_depth_out),
      //   .color_in          (graphics_color_out),
      .valid_in          (allow_write),
      .addr_in           (pwrite_addr),
      .depth_in          (pgraphics_depth_out),
      .color_in          (pwrite_color),
      .rasterizer_rdy_out(framebuffer_ready_out),

      .clear_sig(btn_rising_edge),
      //   .frame_override    (sw[6]),

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
  logic [COLOR_WIDTH-1:0] frame_buff_pixel;
  assign frame_buff_pixel = frame_buff_tvalid ? frame_buff_tdata : 16'h8410; // only take a pixel when a handshake happens???
  always_ff @(posedge clk_pixel) begin
    if (sw[9]) begin
      red   <= {frame_buff_pixel[15:11], 3'b0};
      green <= {frame_buff_pixel[10:5], 2'b0};
      blue  <= {frame_buff_pixel[4:0], 3'b0};
    end else begin
      //   red   <= pixel_depth != 0 ? 8'hff : 8'h00;
      //   green <= pixel_depth != 0 ? 8'hff : 8'h00;
      //   blue  <= pixel_depth != 0 ? 8'hff : 8'h00;
    end
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

  //   assign clk_100_passthrough = clk_100mhz;
  //   assign clk_pixel = clk_100_passthrough;

  always_ff @(posedge clk_100_passthrough) begin
    case (sw[3:2])
      0: begin
        case (sw[5:4])
          0: current_tri_vertex <= tri_vertices[0][0];
          1: current_tri_vertex <= tri_vertices[0][1];
          2: current_tri_vertex <= tri_vertices[0][2];
        endcase
      end

      1: begin
        case (sw[5:4])
          0: current_tri_vertex <= tri_vertices[1][0];
          1: current_tri_vertex <= tri_vertices[1][1];
          2: current_tri_vertex <= tri_vertices[1][2];
        endcase
      end

      2: begin
        case (sw[5:4])
          0: current_tri_vertex <= tri_vertices[2][0];
          1: current_tri_vertex <= tri_vertices[2][1];
          2: current_tri_vertex <= tri_vertices[2][2];
        endcase
      end
    endcase
  end


  always_ff @(posedge clk_100_passthrough) begin
    case (sw[15:10])
      0:  ssd_out <= hcount;
      1:  ssd_out <= vcount;
      2:  ssd_out <= hcount_max;
      3:  ssd_out <= hcount_min;
      4:  ssd_out <= x_min;
      5:  ssd_out <= x_max;
      6:  ssd_out <= y_min;
      7:  ssd_out <= y_max;
      8:  ssd_out <= tri_id;
      9:  ssd_out <= current_tri_vertex;
      10: ssd_out <= tri_valid;
      11: ssd_out <= graphics_addr_out;
      12: ssd_out <= graphics_depth_out;
      13: ssd_out <= graphics_color_out;
      14: ssd_out <= graphics_valid_out;
      15: ssd_out <= graphics_ready_out;
      16: ssd_out <= graphics_last_pixel_out;
      17: ssd_out <= framebuffer_ready_out;
    endcase
  end
  seven_segment_controller sevensegg (
      .clk_in (clk_100_passthrough),
      .rst_in (btn[0]),
      .val_in (ssd_out),
      .cat_out(ss_c),
      .an_out ({ss0_an, ss1_an})
  );
  assign ss0_c = ss_c;
  assign ss1_c = ss_c;


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

endmodule  // top_level


`default_nettype wire
