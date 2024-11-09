module fixed_point_slow_dot #(
    parameter A_WIDTH = 16,  // Width of input A
    parameter A_FRAC_BITS = 14,  // Fractional bits of A
    parameter B_WIDTH = 16,  // Width of input B
    parameter B_FRAC_BITS = 14,  // Fractional bits of B
    // control the precision of the output
    parameter P_WIDTH = 16,  // Width of output P
    parameter P_FRAC_BITS = 14  // Fractional bits of P
) (
    input signed [2:0][A_WIDTH-1:0] A,  // Qm1.n1 format
    input signed [2:0][B_WIDTH-1:0] B,  // Qm2.n2 format
    output signed [P_WIDTH-1:0] P  // Qp.np format
);
  localparam PRODUCT_WIDTH = A_WIDTH + B_WIDTH;
  localparam TOTAL_FRAC_BITS = A_FRAC_BITS + B_FRAC_BITS;

endmodule

