module barycentric_coeffs #(
    AINV_WIDTH = 16,
    AINV_FRAC = 14,
    XWIDTH = 16,
    YWIDTH = 16,
    FRAC = 14
) (
    // fully pipelined module, no valid in and out signals
    input wire clk_in,
    input wire rst_in,
    input wire freeze,
    input wire signed [AINV_WIDTH-1:0] iarea_in,
    input wire signed [XWIDTH-1:0] x_in,
    input wire signed [YWIDTH-1:0] y_in,
    input wire signed [2:0][XWIDTH-1:0] x_tri,
    input wire signed [2:0][YWIDTH-1:0] y_tri,
    output logic signed [2:0][A_WIDTH-1:0] coeffs_out,
    output logic valid_out  // tells me whether x, y values are in the triangle
);
  // LATENCTY: 6-cycle latency

  localparam SUB_WIDTH = YWIDTH + 1;
  localparam A_WIDTH = 2 + (XWIDTH + SUB_WIDTH) - FRAC;
  localparam INV_AREA_INTPART = AINV_WIDTH - AINV_FRAC;
  localparam SCALED_AREA_WIDTH = A_WIDTH + INV_AREA_INTPART;

  logic signed [2:0][2:0][SUB_WIDTH-1:0] ysubs;
  logic signed [2:0][2:0][XWIDTH-1:0] xs;
  logic signed [AINV_WIDTH-1:0] iarea;
  logic signed [2:0][A_WIDTH-1:0] areas;
  logic signed [2:0][SCALED_AREA_WIDTH-1:0] scaled_areas;
  logic in_tri;
  logic invalidate;

  assign in_tri = ($signed(
      scaled_areas[0]
  ) >= 0) && ($signed(
      scaled_areas[1]
  ) >= 0) && ($signed(
      scaled_areas[2]
  ) >= 0);
  assign valid_out = in_tri && !invalidate;

  assign coeffs_out[0] = scaled_areas[0][FRAC + 1:0]; // assumes that the fraction is between -1 and 1
  assign coeffs_out[1] = scaled_areas[1][FRAC + 1:0]; // assumes that the fraction is between -1 and 1
  assign coeffs_out[2] = scaled_areas[2][FRAC + 1:0]; // assumes that the fraction is between -1 and 1

  freezable_pipeline #(
      .STAGES(4),  // TODO: check stage count
      .DATA_WIDTH(AINV_WIDTH)
  ) pipe_xs (
      .clk_in(clk_in),
      .data(rst_in ? {AINV_WIDTH{1'b1}} : iarea_in),
      .freeze(freeze),
      .data_out(iarea)
  );

  // stage 1: init two sides for pipelined dot product
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      // put negative values for everything to give invalid values
      invalidate <= 1;
    end else begin
      // ASK: add freeze around this....
      if (!freeze) begin
        invalidate <= 0;
        ysubs[0][0] <= ($signed(y_tri[1]) - $signed(y_tri[2]));
        ysubs[0][1] <= ($signed(y_tri[2]) - $signed(y_in));
        ysubs[0][2] <= ($signed(y_in) - $signed(y_tri[1]));

        ysubs[1][0] <= ($signed(y_in) - $signed(y_tri[2]));
        ysubs[1][1] <= ($signed(y_tri[2]) - $signed(y_tri[0]));
        ysubs[1][2] <= ($signed(y_tri[0]) - $signed(y_in));

        ysubs[2][0] <= ($signed(y_tri[1]) - $signed(y_in));
        ysubs[2][1] <= ($signed(y_in) - $signed(y_tri[0]));
        ysubs[2][2] <= ($signed(y_tri[0]) - $signed(y_tri[1]));

        xs[0][0] <= x_in;
        xs[0][1] <= x_tri[1];
        xs[0][2] <= x_tri[2];

        xs[1][0] <= x_tri[0];
        xs[1][1] <= x_in;
        xs[1][2] <= x_tri[2];

        xs[2][0] <= x_tri[0];
        xs[2][1] <= x_tri[1];
        xs[2][2] <= x_in;
      end
    end
  end

  // stage 2: calculate the areas (4 cycles)
  freezable_fixed_point_fast_dot #(
      .A_WIDTH(XWIDTH),
      .A_FRAC_BITS(FRAC),
      .B_WIDTH(SUB_WIDTH),
      .B_FRAC_BITS(FRAC),
      .P_FRAC_BITS(FRAC)
  ) area_0 (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .freeze(freeze),
      .A(xs[0]),
      .B(ysubs[0]),
      .D(areas[0])
  );

  freezable_fixed_point_fast_dot #(
      .A_WIDTH(XWIDTH),
      .A_FRAC_BITS(FRAC),
      .B_WIDTH(SUB_WIDTH),
      .B_FRAC_BITS(FRAC),
      .P_FRAC_BITS(FRAC)
  ) area_1 (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .freeze(freeze),
      .A(xs[1]),
      .B(ysubs[1]),
      .D(areas[1])
  );

  freezable_fixed_point_fast_dot #(
      .A_WIDTH(XWIDTH),
      .A_FRAC_BITS(FRAC),
      .B_WIDTH(SUB_WIDTH),
      .B_FRAC_BITS(FRAC),
      .P_FRAC_BITS(FRAC)
  ) area_2 (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .freeze(freeze),
      .A(xs[2]),
      .B(ysubs[2]),
      .D(areas[2])
  );

  // stage 3: scale areas by inverse total area (might need more precision to have better fractions here)
  freezable_fixed_point_mult #(
      .A_WIDTH(A_WIDTH),
      .A_FRAC_BITS(FRAC),
      .B_WIDTH(AINV_WIDTH),
      .B_FRAC_BITS(AINV_FRAC),
      .P_FRAC_BITS(FRAC)
  ) scale_0 (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .freeze(freeze),
      .A(areas[0]),
      .B(iarea),
      .P(scaled_areas[0])
  );

  freezable_fixed_point_mult #(
      .A_WIDTH(A_WIDTH),
      .A_FRAC_BITS(FRAC),
      .B_WIDTH(AINV_WIDTH),
      .B_FRAC_BITS(AINV_FRAC),
      .P_FRAC_BITS(FRAC)
  ) scale_1 (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .freeze(freeze),
      .A(areas[1]),
      .B(iarea),
      .P(scaled_areas[1])
  );

  freezable_fixed_point_mult #(
      .A_WIDTH(A_WIDTH),
      .A_FRAC_BITS(FRAC),
      .B_WIDTH(AINV_WIDTH),
      .B_FRAC_BITS(AINV_FRAC),
      .P_FRAC_BITS(FRAC)
  ) scale_2 (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .freeze(freeze),
      .A(areas[2]),
      .B(iarea),
      .P(scaled_areas[2])
  );

endmodule
