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

  logic [2:0][16:0] x;
  logic [2:0][16:0] y;
  logic [2:0][28:0] z;

  random_noise #(
      .N(3 * 17),
      .LFSR_WIDTH(3 * 17)
  ) noisex (
      .clk_in(clk_100mhz),
      .rst_in(1'b0),
      .noise (x)
  );

  random_noise #(
      .N(3 * 17),
      .LFSR_WIDTH(3 * 17)
  ) noisey (
      .clk_in(clk_100mhz),
      .rst_in(1'b0),
      .noise (y)
  );

  random_noise #(
      .N(3 * 29),
      .LFSR_WIDTH(3 * 29)
  ) noisez (
      .clk_in(clk_100mhz),
      .rst_in(1'b0),
      .noise (z)
  );

  rasterizer #(
      .XWIDTH(17),
      .YWIDTH(17),
      .ZWIDTH(29),
      .XFRAC(14),
      .YFRAC(14),
      .ZFRAC(14),
      .FB_HRES(320),
      .FB_VRES(180),
      .VH(3),
      .VW(3),
      .VW_BY_HRES_WIDTH(22),
      .VW_BY_HRES_FRAC(14),
      .VH_BY_VRES_WIDTH(21),
      .VH_BY_VRES_FRAC(14),
      .VW_BY_HRES(154),
      .VH_BY_VRES(273),
      .HRES_BY_VW_WIDTH(21),
      .HRES_BY_VW_FRAC(14),
      .VRES_BY_VH_WIDTH(21),
      .VRES_BY_VH_FRAC(14),
      .HRES_BY_VW(1747627),
      .VRES_BY_VH(983040)
  ) el_rasterizer (
      .clk_in(clk_100mhz),
      .rst_in(1'b0),
      .valid_in(1'b1),
      .ready_in(1'b1),
      .x(x),
      .y(y),
      .z(z),
      .valid_out(led[0]),
      .ready_out(led[1]),
      .hcount_out(led[2]),
      .vcount_out(led[3]),
      .z_out(led[5])
  );

endmodule  // top_level


`default_nettype wire

