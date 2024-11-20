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
    input wire signed [2:0][VAL_WIDTH-1:0] vals_in,
    input wire signed [AINV_WIDTH-1:0] iarea_in,
    input wire signed [XWIDTH-1:0] x_in,
    input wire signed [YWIDTH-1:0] y_in,
    input wire signed [2:0][XWIDTH-1:0] x_tri,
    input wire signed [2:0][YWIDTH-1:0] y_tri,
    output logic signed [VAL_WIDTH-1:0] inter_val_out,
    output logic valid_out  // tells me whether x, y values are in the triangle
);

  localparam SUB_WIDTH = YWIDTH + 1;
  localparam A_WIDTH = 2 + (XWIDTH + SUB_WIDTH) - FRAC;
  localparam INV_AREA_INTPART = AINV_WIDTH - AINV_FRAC;
  localparam SCALED_AREA_WIDTH = A_WIDTH + INV_AREA_INTPART;
  localparam FULL_VAL_WIDTH = 2 + (VAL_WIDTH) + (A_WIDTH - FRAC);

  logic signed [2:0][2:0][SUB_WIDTH-1:0] ysubs;
  logic signed [2:0][VAL_WIDTH-1:0] vals;
  logic signed [2:0][2:0][XWIDTH-1:0] xs;
  logic signed [2:0][2:0][XWIDTH-1:0] xsp;
  logic signed [2:0][2:0][SUB_WIDTH-1:0] ysubsp;
  logic signed [AINV_WIDTH-1:0] iarea;
  logic signed [2:0][A_WIDTH-1:0] areas;
  logic signed [A_WIDTH-1:0] a1, a2, a3;
  logic signed [2:0][SCALED_AREA_WIDTH-1:0] scaled_areas;
  logic [2:0][A_WIDTH-1:0] scaled_areas_trunc;
  logic signed [FULL_VAL_WIDTH-1:0] inter_val_out_full;
  logic in_tri;

  //   always_ff @(posedge clk_in) begin
  //     scaled_areas_trunc[0] <= scaled_areas[0][FRAC + 1:0]; // assumes that the fraction is between -1 and 1
  //     scaled_areas_trunc[1] <= scaled_areas[1][FRAC + 1:0]; // assumes that the fraction is between -1 and 1
  //     scaled_areas_trunc[2] <= scaled_areas[2][FRAC + 1:0]; // assumes that the fraction is between -1 and 1
  //   end
  assign scaled_areas_trunc[0] = scaled_areas[0][FRAC + 1:0]; // assumes that the fraction is between -1 and 1
  assign scaled_areas_trunc[1] = scaled_areas[1][FRAC + 1:0]; // assumes that the fraction is between -1 and 1
  assign scaled_areas_trunc[2] = scaled_areas[2][FRAC + 1:0]; // assumes that the fraction is between -1 and 1

  assign a1 = areas[0];
  assign a2 = areas[1];
  assign a3 = areas[2];

  // REMOVE LATER
  pipeline #(
      .STAGES(8),  // TODO: check stage count
      .DATA_WIDTH(3 * 3 * XWIDTH)
  ) pipe_xsp (
      .clk_in(clk_in),
      .data(rst_in ? 0 : xs),
      .data_out(xsp)
  );

  pipeline #(
      .STAGES(8),  // TODO: check stage count
      .DATA_WIDTH(3 * 3 * SUB_WIDTH)
  ) pipe_ysubsp (
      .clk_in(clk_in),
      .data(rst_in ? 0 : ysubs),
      .data_out(ysubsp)
  );
  // REMOVE LATER


  // stage 1: init two sides for pipelined dot product
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      // put negative values for everything to give invalid values
      //   iarea <= {AINV_WIDTH{1'b1}};
      //   vals <= 0;
      ysubs <= 0;
      xs <= 0;
    end else begin
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

      //   iarea <= iarea_in;

      //   vals <= vals_in;
    end
  end

  pipeline #(
      .STAGES(6),  // TODO: check stage count
      .DATA_WIDTH(3 * VAL_WIDTH)
  ) pipe_vals (
      .clk_in(clk_in),
      .data(rst_in ? 0 : vals_in),
      .data_out(vals)
  );

  pipeline #(
      .STAGES(4),  // TODO: check stage count
      .DATA_WIDTH(AINV_WIDTH)
  ) pipe_xs (
      .clk_in(clk_in),
      .data(rst_in ? {AINV_WIDTH{1'b1}} : iarea_in),
      .data_out(iarea)
  );

  // stage 2: calculate the areas (4 cycles)
  fixed_point_fast_dot #(
      .A_WIDTH(XWIDTH),
      .A_FRAC_BITS(FRAC),
      .B_WIDTH(SUB_WIDTH),
      .B_FRAC_BITS(FRAC),
      .P_FRAC_BITS(FRAC)
  ) area_0 (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A(xs[0]),
      .B(ysubs[0]),
      .D(areas[0])
  );

  fixed_point_fast_dot #(
      .A_WIDTH(XWIDTH),
      .A_FRAC_BITS(FRAC),
      .B_WIDTH(SUB_WIDTH),
      .B_FRAC_BITS(FRAC),
      .P_FRAC_BITS(FRAC)
  ) area_1 (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A(xs[1]),
      .B(ysubs[1]),
      .D(areas[1])
  );

  fixed_point_fast_dot #(
      .A_WIDTH(XWIDTH),
      .A_FRAC_BITS(FRAC),
      .B_WIDTH(SUB_WIDTH),
      .B_FRAC_BITS(FRAC),
      .P_FRAC_BITS(FRAC)
  ) area_2 (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A(xs[2]),
      .B(ysubs[2]),
      .D(areas[2])
  );

  // stage 3: scale areas by inverse total area (might need more precision to have better fractions here)
  fixed_point_mult #(
      .A_WIDTH(A_WIDTH),
      .A_FRAC_BITS(FRAC),
      .B_WIDTH(AINV_WIDTH),
      .B_FRAC_BITS(AINV_FRAC),
      .P_FRAC_BITS(FRAC)
  ) scale_0 (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A(areas[0]),
      .B(iarea),
      .P(scaled_areas[0])
  );

  fixed_point_mult #(
      .A_WIDTH(A_WIDTH),
      .A_FRAC_BITS(FRAC),
      .B_WIDTH(AINV_WIDTH),
      .B_FRAC_BITS(AINV_FRAC),
      .P_FRAC_BITS(FRAC)
  ) scale_1 (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A(areas[1]),
      .B(iarea),
      .P(scaled_areas[1])
  );

  fixed_point_mult #(
      .A_WIDTH(A_WIDTH),
      .A_FRAC_BITS(FRAC),
      .B_WIDTH(AINV_WIDTH),
      .B_FRAC_BITS(AINV_FRAC),
      .P_FRAC_BITS(FRAC)
  ) scale_2 (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A(areas[2]),
      .B(iarea),
      .P(scaled_areas[2])
  );

  // stage 4: dot product of vals and scaled areas
  // TODO: can manually do this since we know what the values would be and if overflow happens we automatically send invalid
  fixed_point_fast_dot #(
      .A_WIDTH(VAL_WIDTH),
      .A_FRAC_BITS(VAL_FRAC),
      .B_WIDTH(A_WIDTH),
      .B_FRAC_BITS(FRAC),
      .P_FRAC_BITS(VAL_FRAC)
  ) inter_val (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A(vals),
      .B(scaled_areas_trunc),
      .D(inter_val_out_full)
  );

  // stage 4b: check if the point is in the triangle
  assign in_tri = (scaled_areas[0] >= 0) && (scaled_areas[1] >= 0) && (scaled_areas[2] >= 0);
  assign inter_val_out = inter_val_out_full[VAL_WIDTH-1:0]; // truncate the value (at this point val_out should be scaled by a fraction and cannot be bigger than a fp number of VAL_WIDTH width)

  pipeline #(
      .STAGES(4),  // TODO:.check stage count
      .DATA_WIDTH(1)
  ) pipe_tri (
      .clk_in(clk_in),
      .data(in_tri),
      .data_out(valid_out)
  );

endmodule
