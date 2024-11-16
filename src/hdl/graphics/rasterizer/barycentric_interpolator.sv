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
	input wire [AINV_WIDTH-1:0] iarea_in,
	input wire [XWIDTH-1:0] x_in,
	input wire [YWIDTH-1:0] y_in,
    input wire signed [2:0][XWIDTH-1:0] x_tri,
    input wire signed [2:0][YWIDTH-1:0] y_tri,
    output logic signed [VAL_WIDTH-1:0] inter_val_out
);

	localparam SUB_WIDTH = YWIDTH + 1;
	localparam A_WIDTH = 2 + (XWIDTH + YWIDTH) - FRAC;

	logic signed [2:0][2:0][SUB_WIDTH-1:0] ysubs;
	logic signed [2:0][VAL_WIDTH-1:0] vals;
	logic signed [2:0][2:0][XWIDTH-1:0] xs;
	logic signed [AINV_WIDTH-1:0] iarea;
	logic signed [2:0][A_WIDTH-1:0] areas;
	logic signed [2:0][A_WIDTH-1:0] scaled_areas;

	// stage 1: init two sides for pipelined dot product
	always_ff @(posedge clk_in) begin
		ysubs[0][0] <= (y_tri[1] - y_tri[2]);
		ysubs[0][1] <= (y_tri[2] - y_in);
		ysubs[0][2] <= (y_in - y_tri[1]);

		ysubs[1][0] <= (y_in - y_tri[2]);
		ysubs[1][1] <= (y_tri[2] - y_tri[0]);
		ysubs[1][2] <= (y_tri[0] - y_in);

		ysubs[2][0] <= (y_tri[1] - y_in);
		ysubs[2][1] <= (y_in - y_tri[0]);
		ysubs[2][2] <= (y_tri[0] - y_tri[1]);

		xs[0][0] <= x_in;
		xs[0][1] <= x_tri[1];
		xs[0][2] <= x_tri[2];

		xs[1][0] <= x_tri[0];
		xs[1][1] <= x_in;
		xs[1][2] <= x_tri[2];

		xs[2][0] <= x_tri[0];
		xs[2][1] <= x_tri[1];
		xs[2][2] <= x_in;

		iarea <= iarea_in;

		vals <= vals_in;
	end

	pipeline #(
		.STAGES(6), // check stage count
		.DATA_WIDTH(VAL_WIDTH)
	) pipe_vals (
		.clk_in(clk_in),
		.data(vals),
		.data_out(vals)
	);

	pipeline #(
		.STAGES(4), // check stage count
		.DATA_WIDTH(AINV_WIDTH)
	) pipe_xs (
		.clk_in(clk_in),
		.data(iarea_in),
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
		.B(scaled_areas),
		.D(inter_val_out)
	);


endmodule
