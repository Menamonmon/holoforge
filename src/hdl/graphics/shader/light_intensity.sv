module light_intensity #(
    NORM_WIDTH = 16,
    NORM_FRAC  = 14
) (
    // fully pipelined module, no valid in and out signals
    input wire clk_in,
    input wire rst_in,
    input wire signed [2:0][NORM_WIDTH-1:0] tri_norm,
    input wire signed [2:0][NORM_WIDTH-1:0] cam_norm,
    output logic signed [NORM_WIDTH-1:0] light_intensity_out,
    output logic valid_out
);

  // ASSUMES THE LIGHT IS THE CAMERA SOURCE
  // needs to be called i times for i lights
  // returns a positive scalar value that represents the light intensity
  // valid out check is used for backface culling 
  localparam FULL_VAL_WIDTH = 2 + (2 * NORM_WIDTH) - NORM_FRAC;
  logic signed [FULL_VAL_WIDTH-1:0] light_intensity_out_full;
  logic signed prst_in;

  pipeline #(
      .STAGES(4),
      .DATA_WIDTH(1)
  ) pipe_norms (
      .clk_in(clk_in),
      .data(!rst_in),
      .data_out(prst_in)
  );

  fixed_point_fast_dot #(
      .A_WIDTH(NORM_WIDTH),
      .A_FRAC_BITS(NORM_FRAC),
      .B_WIDTH(NORM_WIDTH),
      .B_FRAC_BITS(NORM_FRAC),
      .P_FRAC_BITS(NORM_FRAC)
  ) dot_prod (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A(tri_norm),
      .B(cam_norm),
      .P(light_intensity_out_full)
  );

  assign valid_out = prst_in & (light_intensity_out_full <= 0);
  assign light_intensity_out = -light_intensity_out_full[NORM_WIDTH-1:0]; // check for clipping with this
endmodule
