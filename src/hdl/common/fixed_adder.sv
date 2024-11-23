module fixed_adder #(
    parameter int WIDTH1 = 16,
    parameter int FRAC1  = 8,
    parameter int WIDTH2 = 16,
    parameter int FRAC2  = 8
) (
    input logic signed [WIDTH1-1:0] u,  // First fixed-point number
    input logic signed [WIDTH2-1:0] v,  // Second fixed-point number
    output logic signed [WIDTH1-1:0] result  // Result of addition and truncation
);
  localparam int n1 = WIDTH1 - FRAC1;
  localparam int m1 = FRAC1;
  localparam int n2 = WIDTH2 - FRAC2;
  localparam int m2 = FRAC2;

  // Temporary variable to hold the extended result
  logic signed [n1+m1-1:0] sum_extended;

  always_comb begin
    // Step 1: Align the fractional parts
    if (m1 > m2) begin
      // Shift v to match fractional bits of u
      sum_extended = u + (v <<< (m1 - m2));
    end else if (m2 > m1) begin
      // Shift u to match fractional bits of v
      sum_extended = (u <<< (m2 - m1)) + v;
    end else begin
      // No shift needed
      sum_extended = u + v;
    end

    // Step 2: Truncate the result to the desired width (n1 + m1)
    result = sum_extended[n1+m1-1:0];
  end
endmodule
