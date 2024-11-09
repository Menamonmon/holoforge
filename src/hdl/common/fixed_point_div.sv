module fixed_point_divide #(
    parameter A_WIDTH = 16,
    parameter A_FRAC_BITS = 14,
    parameter B_WIDTH = 16,
    parameter B_FRAC_BITS = 14,
    parameter Q_WIDTH = 16,
    parameter Q_FRAC_BITS = 14
) (
    input  signed [A_WIDTH-1:0] A,  // Dividend in Qm1.n1 format
    input  signed [B_WIDTH-1:0] B,  // Divisor in Qm2.n2 format
    output signed [Q_WIDTH-1:0] Q   // Quotient in Qp.np format
);

endmodule
