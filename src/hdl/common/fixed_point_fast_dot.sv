module fixed_point_fast_dot #(
    parameter A_WIDTH = 16,  // Width of input A
    parameter A_FRAC_BITS = 14,  // Fractional bits of A
    parameter B_WIDTH = 16,  // Width of input B
    parameter B_FRAC_BITS = 14,  // Fractional bits of B
    // control the precision of the output
    parameter P_FRAC_BITS = 14  // Fractional bits of P
) (
    input clk_in,
    input rst_in,
    input signed [2:0][A_WIDTH-1:0] A,  // Qm1.n1 format
    input signed [2:0][B_WIDTH-1:0] B,  // Qm2.n2 format
    output logic signed [D_WIDTH-1:0] D  // Qp.np format
);
  localparam PRODUCT_WIDTH = A_WIDTH + B_WIDTH;
  localparam TOTAL_FRAC_BITS = A_FRAC_BITS + B_FRAC_BITS;
  localparam EXTRA_FRAC_BITS = TOTAL_FRAC_BITS - P_FRAC_BITS;
  localparam P_WIDTH = A_WIDTH + B_WIDTH - EXTRA_FRAC_BITS;
  localparam D_WIDTH = P_WIDTH + 2;

  logic signed [A_WIDTH-1:0] A_1;
  logic signed [A_WIDTH-1:0] A_2;
  logic signed [A_WIDTH-1:0] A_3;

  logic signed [B_WIDTH-1:0] B_1;
  logic signed [B_WIDTH-1:0] B_2;
  logic signed [B_WIDTH-1:0] B_3;

  logic signed [PRODUCT_WIDTH-1:0] P_1;
  logic signed [PRODUCT_WIDTH-1:0] P_2;
  logic signed [PRODUCT_WIDTH-1:0] P_3;

  //3 cycles initally then outputs a res every cycle
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      A_1 <= 0;
      A_2 <= 0;
      A_3 <= 0;
      B_1 <= 0;
      B_2 <= 0;
      B_3 <= 0;
      P_1 <= 0;
      P_2 <= 0;
      P_3 <= 0;
      D   <= 0;
    end else begin
      //first pipe putting inputs in register
      A_1 <= A[0];
      A_2 <= A[1];
      A_3 <= A[2];
      B_1 <= B[0];
      B_2 <= B[1];
      B_3 <= B[2];
      //second pipe putting in muls
      P_1 <= $signed(A_1) * $signed(B_1);
      P_2 <= $signed(A_2) * $signed(B_2);
      P_3 <= $signed(A_3) * $signed(B_3);
      //third pipe adding them all then shifting it
      // TODO: can be broken up into 2 stages to reduce PD
      D   <= ($signed(P_1) + $signed(P_2) + $signed(P_3)) >>> EXTRA_FRAC_BITS;

    end
  end
endmodule

module freezable_fixed_point_fast_dot #(
    parameter A_WIDTH = 16,  // Width of input A
    parameter A_FRAC_BITS = 14,  // Fractional bits of A
    parameter B_WIDTH = 16,  // Width of input B
    parameter B_FRAC_BITS = 14,  // Fractional bits of B
    // control the precision of the output
    parameter P_FRAC_BITS = 14  // Fractional bits of P
) (
    input clk_in,
    input rst_in,
    input signed [2:0][A_WIDTH-1:0] A,  // Qm1.n1 format
    input signed [2:0][B_WIDTH-1:0] B,  // Qm2.n2 format
    input wire freeze,
    output logic signed [D_WIDTH-1:0] D  // Qp.np format
);
  localparam PRODUCT_WIDTH = A_WIDTH + B_WIDTH;
  localparam TOTAL_FRAC_BITS = A_FRAC_BITS + B_FRAC_BITS;
  localparam EXTRA_FRAC_BITS = TOTAL_FRAC_BITS - P_FRAC_BITS;
  localparam P_WIDTH = A_WIDTH + B_WIDTH - EXTRA_FRAC_BITS;
  localparam D_WIDTH = P_WIDTH + 2;

  logic signed [A_WIDTH-1:0] A_1;
  logic signed [A_WIDTH-1:0] A_2;
  logic signed [A_WIDTH-1:0] A_3;

  logic signed [B_WIDTH-1:0] B_1;
  logic signed [B_WIDTH-1:0] B_2;
  logic signed [B_WIDTH-1:0] B_3;

  logic signed [PRODUCT_WIDTH-1:0] P_1;
  logic signed [PRODUCT_WIDTH-1:0] P_2;
  logic signed [PRODUCT_WIDTH-1:0] P_3;

  //3 cycles initally then outputs a res every cycle
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      A_1 <= 0;
      A_2 <= 0;
      A_3 <= 0;
      B_1 <= 0;
      B_2 <= 0;
      B_3 <= 0;
      P_1 <= 0;
      P_2 <= 0;
      P_3 <= 0;
      D   <= 0;
    end  //first pipe putting inputs in register
    else begin
      if (!freeze) begin
        A_1 <= A[0];
        A_2 <= A[1];
        A_3 <= A[2];
        B_1 <= B[0];
        B_2 <= B[1];
        B_3 <= B[2];
        //second pipe putting in muls
        P_1 <= $signed(A_1) * $signed(B_1);
        P_2 <= $signed(A_2) * $signed(B_2);
        P_3 <= $signed(A_3) * $signed(B_3);
        //third pipe adding them all then shifting it
        // TODO: can be broken up into 2 stages to reduce PD
        D   <= ($signed(P_1) + $signed(P_2) + $signed(P_3)) >>> EXTRA_FRAC_BITS;
      end
    end
  end



endmodule
