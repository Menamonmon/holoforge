`timescale 1ns / 1ps `default_nettype none

module top_level (
    input  wire         clk_100mhz,
    output logic [15:0] led
    // camera bus
);

  localparam A_WIDTH = 18;
  localparam A_FRAC_BITS = 14;
  localparam B_WIDTH = 25;
  localparam B_FRAC_BITS = 14;
  localparam P_FRAC_BITS = 14;
  localparam N = 3;

  localparam P_WIDTH = A_WIDTH + B_WIDTH - A_FRAC_BITS - B_FRAC_BITS + P_FRAC_BITS;
  logic signed [P_WIDTH - 1:0] P;
  logic signed [N-1:0][A_WIDTH-1:0] A;
  logic signed [N-1:0][B_WIDTH-1:0] B;
  logic done;

  fixed_point_slow_dot #(
      .A_WIDTH(18),
      .B_WIDTH(25),
      .A_FRAC_BITS(14),
      .B_FRAC_BITS(14),
      .P_FRAC_BITS(14)
  ) test_slow_dot (
      .clk_in(clk_100mhz),
      .rst_in(1'b0),
      .A(A),
      .B(B),
      .valid_in(1'b1),
      .valid_out(done),
      .P(P)
  );
  assign led = P[15:0];
  
endmodule  // top_level


`default_nettype wire

