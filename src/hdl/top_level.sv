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

  // parameters {'P_WIDTH': 16, 'C_WIDTH': 18, 'V_WIDTH': 16, 'FRAC_BITS': 14, 'VH_OVER_TWO': 12288, 'VH_OVER_TWO_WIDTH': 16, 'VW_OVER_TWO': 12288, 'VW_OVER_TWO_WIDTH': 16, 'VIEWPORT_H_POSITION_WIDTH': 18, 'VIEWPORT_W_POSITION_WIDTH': 18, 'NUM_TRI': 12, 'NUM_COLORS': 256, 'FB_HRES': 320, 'FB_VRES': 180, 'HRES_BY_VW_WIDTH': 23, 'HRES_BY_VW_FRAC': 14, 'VRES_BY_VH_WIDTH': 22, 'VRES_BY_VH_FRAC': 14, 'HRES_BY_VW': 3495253, 'VRES_BY_VH': 1966080, 'VW_BY_HRES_WIDTH': 23, 'VW_BY_HRES_FRAC': 14, 'VH_BY_VRES_WIDTH': 22, 'VH_BY_VRES_FRAC': 14, 'VW_BY_HRES': 77, 'VH_BY_VRES': 137}

  logic [2:0][15:0] P;
  logic [2:0][17:0] C;
  logic [2:0][15:0] u;
  logic [2:0][15:0] v;
  logic [2:0][15:0] n;
  logic valid_out;
  logic ready_out;
  logic last_pixel_out;
  logic [2:0][18:0] hcount_out;
  logic [2:0][18:0] vcount_out;
  logic [2:0][29:0] z_out;
  logic [8:0] color_out;

  random_noise #(
      .N(3 * 16),
      .LFSR_WIDTH(3 * 16)
  ) P_noise (
      .clk_in(clk_100mhz),
      .rst_in(1'b0),
      .noise (P)
  );

  random_noise #(
      .N(3 * 18),
      .LFSR_WIDTH(3 * 18)
  ) C_noise (
      .clk_in(clk_100mhz),
      .rst_in(1'b0),
      .noise (C)
  );

  random_noise #(
      .N(3 * 16),
      .LFSR_WIDTH(3 * 16)
  ) u_noise (
      .clk_in(clk_100mhz),
      .rst_in(1'b0),
      .noise (u)
  );

  random_noise #(
      .N(3 * 16),
      .LFSR_WIDTH(3 * 16)
  ) v_noise (
      .clk_in(clk_100mhz),
      .rst_in(1'b0),
      .noise (v)
  );

  random_noise #(
      .N(3 * 16),
      .LFSR_WIDTH(3 * 16)
  ) n_noise (
      .clk_in(clk_100mhz),
      .rst_in(1'b0),
      .noise (n)
  );



  graphics_pipeline_no_brom #(
      .C_WIDTH(18),
      .P_WIDTH(16),
      .V_WIDTH(16),
      .FRAC_BITS(14),
      .VH_OVER_TWO(12288),
      .VH_OVER_TWO_WIDTH(16),
      .VW_OVER_TWO(12288),
      .VW_OVER_TWO_WIDTH(16),
      .VIEWPORT_H_POSITION_WIDTH(18),
      .VIEWPORT_W_POSITION_WIDTH(18),
      .NUM_TRI(12),
      .NUM_COLORS(256),
      .FB_HRES(320),
      .FB_VRES(180),
      .HRES_BY_VW_WIDTH(23),
      .HRES_BY_VW_FRAC(14),
      .VRES_BY_VH_WIDTH(22),
      .VRES_BY_VH_FRAC(14),
      .HRES_BY_VW(3495253),
      .VRES_BY_VH(1966080),
      .VW_BY_HRES_WIDTH(23),
      .VW_BY_HRES_FRAC(14),
      .VH_BY_VRES_WIDTH(22),
      .VH_BY_VRES_FRAC(14),
      .VW_BY_HRES(77),
      .VH_BY_VRES(137)
  ) graphics_goes_brrrrrr (
      .clk_in(clk_100mhz),
      .rst_in(1'b0),
      .valid_in(1'b1),
      .ready_in(1'b1),
      .tri_id_in(4'b0),
      .P(P),
      .C(C),
      .u(u),
      .v(v),
      .n(n),
      .valid_out(valid_out),
      .ready_out(ready_out),
      .last_pixel_out(last_pixel_out),
      .hcount_out(hcount_out),
      .vcount_out(vcount_out),
      .z_out(z_out),
      .color_out(color_out)
  );

  assign led = color_out;
  assign ss0_an = hcount_out;
  assign ss1_an = vcount_out;
  assign ss0_c = z_out[0][7:0];
  assign ss1_c = z_out[0][15:8];

endmodule  // top_level


`default_nettype wire

