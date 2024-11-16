module barycentric_interpolator #(

) (
    input wire clk_in,
    input wire rst_in,
	
);

  // Internal parameters
  localparam PRODUCT_WIDTH = A_WIDTH + B_WIDTH;
  localparam EXTRA_FRAC_BITS = A_FRAC_BITS + B_FRAC_BITS - P_FRAC_BITS;
  localparam ACC_WIDTH = PRODUCT_WIDTH + $clog2(N);
  localparam P_WIDTH = A_WIDTH + B_WIDTH - EXTRA_FRAC_BITS;
  // Accumulator and loop index
  logic signed [ACC_WIDTH-1:0] accumulator;
  logic [$clog2(N)-1:0] i;

  always_ff @(posedge clk_in or posedge rst_in) begin
    if (rst_in) begin
      accumulator <= 0;
      i <= 0;
      valid_out <= 0;
    end else begin
      if (i == 0) begin
        if (valid_in) begin
          i <= 1;
          accumulator <= $signed(A[0]) * $signed(B[0]);
        end
        valid_out <= 0;
      end else if (i < N) begin
        accumulator <= accumulator + $signed(A[i]) * $signed(B[i]);
        if (i == N - 1) begin
          valid_out <= 1;
          i <= 0;
        end else begin
          i <= i + 1;
        end
      end
    end
  end

  // Adjust accumulator for fractional bits
  assign P = accumulator >>> EXTRA_FRAC_BITS;

endmodule