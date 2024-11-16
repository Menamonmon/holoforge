module fixed_point_mult #(
    parameter A_WIDTH = 16,  // Width of input A
    parameter A_FRAC_BITS = 14,  // Fractional bits of A
    parameter B_WIDTH = 16,  // Width of input B
    parameter B_FRAC_BITS = 14,  // Fractional bits of B
    parameter P_FRAC_BITS = 14  // Fractional bits of P
) (
    input wire clk_in,
    input wire rst_in,
    input  signed [A_WIDTH-1:0] A,  // Qm1.n1 format
    input  signed [B_WIDTH-1:0] B,  // Qm2.n2 format
    output logic signed [P_WIDTH-1:0] P   // Qp.np format
);
  localparam PRODUCT_WIDTH = A_WIDTH + B_WIDTH;
  localparam TOTAL_FRAC_BITS = A_FRAC_BITS + B_FRAC_BITS;
  localparam EXTRA_FRAC_BITS = TOTAL_FRAC_BITS - P_FRAC_BITS;
  localparam P_WIDTH = A_WIDTH+B_WIDTH-EXTRA_FRAC_BITS;


  logic signed [PRODUCT_WIDTH-1:0] pre_shift_product;
  always_ff @(posedge clk_in)begin
    if(rst_in)begin
        pre_shift_product<=0;
        P<=0;
    end else begin
    pre_shift_product<=$signed(A)*$signed(B);
    P<=$signed(pre_shift_product)>>>EXTRA_FRAC_BITS;
    end
  end

endmodule
