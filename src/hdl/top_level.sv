`timescale 1ns / 1ps `default_nettype none

module top_level (
    input  wire         clk_100mhz,
    output logic [15:0] led,
    // camera bus
	
	input wire [3:0] btn,
    output logic [ 3:0] ss0_an,      //anode control for upper four digits of seven-seg display
    output logic [ 3:0] ss1_an,      //anode control for lower four digits of seven-seg display
    output logic [ 6:0] ss0_c,       //cathode controls for the segments of upper four digits
    output logic [ 6:0] ss1_c        //cathod controls for the segments of lower four digits
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


  logic signed [31:0] P;
  logic signed [31:0] A;
  logic signed [31:0] B;
  logic [4:0] outs;

  assign A = 32'sd0;
  assign B = 32'sd0;

  fixed_point_div #(
      .WIDTH(32),
      .FRAC_BITS(14)
  ) test_div (
      .clk_in(clk_100mhz),
      .rst_in(1'b0),
      .valid_in(1'b1),
      .A(btn[0]),
      .B(btn[1]),
      .done(outs[0]),
      .busy(outs[1]),
      .valid_out(outs[2]),
      .zerodiv(outs[3]),
      .overflow(outs[4]),
      .Q(P)
  );
  assign led = P[15:0];

endmodule  // top_level


`default_nettype wire

