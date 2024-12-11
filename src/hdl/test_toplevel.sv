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
    output logic [ 6:0] ss1_c        //cathod controls for the segments of lower four digits
    // // hdmi port
    // output logic [ 2:0] hdmi_tx_p,   //hdmi output signals (positives) (blue, green, red)
    // output logic [ 2:0] hdmi_tx_n,   //hdmi output signals (negatives) (blue, green, red)
    // output logic        hdmi_clk_p,
    // hdmi_clk_n,

    // // New for week 6: DDR3 ports
    // inout  wire [15:0] ddr3_dq,
    // inout  wire [ 1:0] ddr3_dqs_n,
    // inout  wire [ 1:0] ddr3_dqs_p,
    // output wire [12:0] ddr3_addr,
    // output wire [ 2:0] ddr3_ba,
    // output wire        ddr3_ras_n,
    // output wire        ddr3_cas_n,
    // output wire        ddr3_we_n,
    // output wire        ddr3_reset_n,
    // output wire        ddr3_ck_p,
    // output wire        ddr3_ck_n,
    // output wire        ddr3_cke,
    // output wire [ 1:0] ddr3_dm,
    // output wire        ddr3_odt
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
  assign clk_100_passthrough = clk_100mhz;
  //   cw_hdmi_clk_wiz wizard_hdmi (
  //       .sysclk(clk_100_passthrough),
  //       .clk_pixel(clk_pixel),
  //       .clk_tmds(clk_5x),
  //       .reset(0)
  //   );

  //   cw_fast_clk_wiz wizard_migcam (
  //       .clk_in1(clk_100mhz),
  //       .clk_camera(clk_camera),
  //       .clk_mig(clk_migref),
  //       .clk_xc(clk_xc),
  //       .clk_100(clk_100_passthrough),
  //       .reset(0)
  //   );
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

  //   logic [$clog2(ADDR_MAX)-1:0] stacker_addr;
  //   evt_counter #(
  //       .MAX_COUNT(ADDR_MAX)
  //   ) addr_counter (
  //       .clk_in(clk_100_passthrough),
  //       .rst_in(sys_rst),
  //       .evt_in(next_data_ready),
  //       .count_out(stacker_addr)
  //   );

  //   evt_counter #(
  //       .MAX_COUNT(HRES)
  //   ) hcounter (
  //       .clk_in(clk_100_passthrough),
  //       .rst_in(sys_rst),
  //       .evt_in(next_data_ready),
  //       .count_out(hcount)
  //   );

  //   // Vertical counter
  //   evt_counter #(
  //       .MAX_COUNT(VRES)
  //   ) vcounter (
  //       .clk_in(clk_100_passthrough),
  //       .rst_in(sys_rst),
  //       .evt_in((hcount == HRES - 1) && next_data_ready),
  //       .count_out(vcount)
  //   );


  //   // Generate 8 instances of test_pattern_generator
  //   logic [7:0] test_red;
  //   logic [7:0] test_green;
  //   logic [7:0] test_blue;

  //   test_pattern_generator #(
  //       .HRES(HRES),
  //       .VRES(VRES)
  //   ) pattern_gen (
  //       .sel_in(sw[15:14]),
  //       .hcount_in(hcount),
  //       .vcount_in(vcount),
  //       .red_out(test_red),
  //       .green_out(test_green),
  //       .blue_out(test_blue)
  //   );
  //   assign data = {test_red[7:3], test_green[7:2], test_blue[7:3]};

  logic        frame_buff_tvalid;
  logic        frame_buff_tready;
  logic [15:0] frame_buff_tdata;
  logic        frame_buff_tlast;
  logic [15:0] frame_buff_pixel;
  //   logic [15:0] hcount;
  //   logic [15:0] vcount;


  logic        frame_tester;
  //   always_ff @(posedge clk_100_passthrough) begin
  //     if (stacker_addr == 0) begin
  //       frame_tester <= !frame_tester;
  //     end
  //   end
  assign frame_tester = 1;


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
  logic [ 6:0] ss_c;

//   seven_segment_controller sevensegg (
//       .clk_in (clk_100_passthrough),
//       .rst_in (btn[0]),
//       .val_in (ssd_out),
//       .cat_out(ss_c),
//       .an_out ({ss0_an, ss1_an})
//   );
  assign ss0_c = ss_c;
  assign ss1_c = ss_c;

  logic [15:0] current_tri_vertex;
  logic [16:0] tri_id;
  logic signed [2:0][2:0][15:0] tri_vertices;
  logic tri_valid;

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


      //   11: ssd_out <= data;
      //   12: ssd_out <= frame_buff_pixel;
      //   13: ssd_out <= frame_buff_tvalid;
      //   14: ssd_out <= frame_buff_tready;
      //   15: ssd_out <= frame_buff_tdata;
    endcase
  end



  // TRIANGLE FETCH

//   tri_fetch tri_fetch_inst (
//       .clk_in(clk_100_passthrough),  //system clock
//       .rst_in(btn[0]),  //system reset
//       .ready_in(graphics_ready_out && btn_rising_edge),  // TODO: change this ot  //system reset
//       .valid_out(tri_valid),
//       //   .tri_vertices_out(tri_vertices),
//       .tri_id_out(tri_id)
//   );


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
  localparam Z_WIDTH = C_WIDTH + 1;

  logic signed [C_WIDTH-1:0] C;
  logic signed [2:0][15:0] u, v, n;

  //   assign C = 
  assign C = 54'b111100000000000000000000000000000000000110111011011010;
  assign u = 48'hc8930000e000;
  assign v = 48'h000040000000;
  assign n = 48'h20000000c893;

  assign tri_vertices = 144'h2000e000e0002000e0002000200020002000;
  // 0.5, 0.5, 0.5


  localparam HWIDTH = $clog2(HRES);
  localparam VWIDTH = $clog2(VRES);
  localparam XWIDTH = 18;
  localparam YWIDTH = 19;

  logic [HWIDTH-1:0] hcount_max, hcount_min;
  logic [VWIDTH-1:0] vcount_max, vcount_min;
  logic [XWIDTH-1:0] x_max, x_min;
  logic [YWIDTH-1:0] y_max, y_min;


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
      .NUM_TRI(12),
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
      //   .valid_in(tri_valid),
      .valid_in(1'b1),
      .ready_in(btn_rising_edge2),
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


  logic graphics_valid_out;
  logic graphics_last_pixel_out;
  logic graphics_last_tri_out;
  logic [26:0] graphics_addr_out;
  logic [15:0] graphics_color_out;
  logic [Z_WIDTH-1:0] graphics_depth_out;
  logic framebuffer_ready_out;
  logic graphics_ready_out;

endmodule  // top_level


`default_nettype wire



// e0002000e000e00020002000e000e0002000
// 2000e000e0002000e0002000200020002000
