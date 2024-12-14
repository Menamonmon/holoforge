module barycentric_interpolator #(
    VAL_WIDTH = 16,
    VAL_FRAC = 14,
    AINV_WIDTH = 16,
    AINV_FRAC = 14,
    XWIDTH = 16,
    YWIDTH = 16,
    FRAC = 14
) (
    // fully pipelined module, no valid in and out signals
    input wire clk_in,
    input wire rst_in,
    input wire signed [AINV_WIDTH-1:0] iarea_in,
    input wire signed [XWIDTH-1:0] x_in,
    input wire signed [YWIDTH-1:0] y_in,
    input wire signed [2:0][VAL_WIDTH-1:0] vals_in,
    input wire signed [2:0][XWIDTH-1:0] x_tri,
    input wire signed [2:0][YWIDTH-1:0] y_tri,
    input wire freeze,
    output logic signed [VAL_WIDTH-1:0] inter_val_out,
    output logic valid_out  // tells me whether x, y values are in the triangle
);
  // LATENCTY: 10-cycle
  localparam SUB_WIDTH = YWIDTH + 1;
  localparam FULL_VAL_WIDTH = 2 + (VAL_WIDTH) + (A_WIDTH - FRAC);
  localparam A_WIDTH = 2 + (XWIDTH + SUB_WIDTH) - FRAC;
  logic signed [2:0][VAL_WIDTH-1:0] vals;
  logic signed [2:0][A_WIDTH-1:0] coeffs;
  logic signed [FULL_VAL_WIDTH-1:0] inter_val_out_full;
  logic in_tri;

  barycentric_coeffs #(
      .AINV_WIDTH(AINV_WIDTH),
      .AINV_FRAC(AINV_FRAC),
      .XWIDTH(XWIDTH),
      .YWIDTH(YWIDTH),
      .FRAC(FRAC)
  ) bary_coeffs (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .iarea_in(iarea_in),
      .freeze(freeze),
      .x_in(x_in),
      .y_in(y_in),
      .x_tri(x_tri),
      .y_tri(y_tri),
      .coeffs_out(coeffs),
      .valid_out(in_tri)
  );

  freezable_pipeline #(
      .STAGES(6),  // TODO: check stage count
      .DATA_WIDTH(3 * VAL_WIDTH)
  ) pipe_vals (
      .clk_in(clk_in),
      .data(rst_in ? 0 : vals_in),
      .freeze(freeze),
      .data_out(vals)
  );
  // stage 4: dot product of vals and scaled areas
  // TODO: can manually do this since we know what the values would be and if overflow happens we automatically send invalid
  freezable_fixed_point_fast_dot #(
      .A_WIDTH(VAL_WIDTH),
      .A_FRAC_BITS(VAL_FRAC),
      .B_WIDTH(A_WIDTH),
      .B_FRAC_BITS(FRAC),
      .P_FRAC_BITS(VAL_FRAC)
  ) inter_val (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .freeze(freeze),
      .A(vals),
      .B(coeffs),
      .D(inter_val_out_full)
  );

  assign inter_val_out = inter_val_out_full[VAL_WIDTH-1:0]; // truncate the value (at this point val_out should be scaled by a fraction and cannot be bigger than a fp number of VAL_WIDTH width)

  freezable_pipeline #(
      .STAGES(3),  // TODO:.check stage count
      .DATA_WIDTH(1)
  ) pipe_tri (
      .clk_in(clk_in),
      .data(in_tri),
      .freeze(freeze),
      .data_out(valid_out)
  );

endmodule
