
`define FLOOR_LOG2(x) ((x) <= 1 ? 0 : 1 + `FLOOR_LOG2((x) >> 1))


module rasterizer #(
    parameter XWIDTH = 16,
    parameter YWIDTH = 16,
    parameter ZWIDTH = 16,
    parameter XFRAC = 14,
    parameter YFRAC = 14,
    parameter ZFRAC = 14,
    parameter N = 3,

    parameter FB_HRES = 320,
    parameter FB_VRES = 180,
    // parameter VW = 3,
    // parameter VH = 3,

    parameter HRES_BY_VW_WIDTH = 7,
    parameter HRES_BY_VW_FRAC  = 0,
    parameter VRES_BY_VH_WIDTH = 6,
    parameter VRES_BY_VH_FRAC  = 0,

    parameter [HRES_BY_VW_WIDTH-1:0] HRES_BY_VW = 1,
    parameter [VRES_BY_VH_WIDTH-1:0] VRES_BY_VH = 1,

    parameter VW_BY_HRES_WIDTH = 6,
    parameter VW_BY_HRES_FRAC  = 0,
    parameter VH_BY_VRES_WIDTH = 7,
    parameter VH_BY_VRES_FRAC  = 0,

    parameter [VW_BY_HRES_WIDTH-1:0] VW_BY_HRES = 1,
    parameter [VH_BY_VRES_WIDTH-1:0] VH_BY_VRES = 1
) (
    input wire clk_in,
    input wire rst_in,
    input wire valid_in, // whether or not we got a new valid input (should never be true if ready_out is false)
    input wire ready_in,  // whether or not the following stage is ready

    // unsigned since it's normalized screen coordinates.....
    // these values should be 0 to w and 0 to h with z being arbitrarily big
    input wire [N-1:0][XWIDTH-1:0] x,
    input wire [N-1:0][YWIDTH-1:0] y,
    input wire [N-1:0][ZWIDTH-1:0] z,

    output logic valid_out,  // pixel single cycle output for shader to process the pixel
    output logic ready_out,  // busy

    output logic [HWIDTH-1:0] hcount_out,
    output logic [VWIDTH-1:0] vcount_out,
    output logic [ZWIDTH-1:0] z_out,
    output logic [PIXEL_ADDR_WIDTH-1:0] addr_out,
    output logic last_pixel,


    // DEBUG VALUES
    output logic [XWIDTH-1:0] x_min_out,
    output logic [XWIDTH-1:0] x_max_out,
    output logic [YWIDTH-1:0] y_min_out,
    output logic [YWIDTH-1:0] y_max_out,
    output logic [HWIDTH-1:0] hcount_min_out,
    output logic [HWIDTH-1:0] hcount_max_out,
    output logic [VWIDTH-1:0] vcount_min_out,
    output logic [VWIDTH-1:0] vcount_max_out

);

  localparam MAX_FRAC = XFRAC > YFRAC ? (XFRAC > ZFRAC ? XFRAC : ZFRAC) : (YFRAC > ZFRAC ? YFRAC : ZFRAC);
  localparam INV_FRAC = MAX_FRAC;
  localparam INV_WIDTH = 2 * MAX_FRAC + 1;
  localparam HWIDTH = $clog2(FB_HRES);
  localparam VWIDTH = $clog2(FB_VRES);
  localparam X_INCREM = VW_BY_HRES;
  localparam Y_INCREM = VH_BY_VRES;
  localparam PIXEL_ADDR_WIDTH = $clog2(FB_HRES * FB_VRES);
  localparam int HRES_FIRST_COMPONENT = FB_HRES % (1 << ($clog2(FB_HRES) - 1));
  localparam int HRES_SECOND_COMPONENT = FB_HRES - HRES_FIRST_COMPONENT;
  localparam int HRES_COMP1 = $clog2(HRES_FIRST_COMPONENT);
  localparam int HRES_COMP2 = $clog2(HRES_SECOND_COMPONENT);

  logic [HWIDTH-1:0] ahcount;
  logic [VWIDTH-1:0] avcount;

  logic [2:0][XWIDTH-1:0] xv;
  logic [2:0][YWIDTH-1:0] yv;
  logic [2:0][ZWIDTH-1:0] zv;

  logic [XWIDTH-1:0] x_min, x_max, x_curr, x_incremented;
  logic [YWIDTH-1:0] y_min, y_max, y_curr, y_incremented;
  logic inv_area_done, inv_area_valid_out;
  logic signed [INV_WIDTH-1:0] iarea_out;
  logic signed [INV_WIDTH-1:0] iarea;
  logic [HWIDTH-1:0] hcount_min, hcount_max;
  logic [VWIDTH-1:0] vcount_min, vcount_max;
  logic [HWIDTH-1:0] hcount;
  logic [VWIDTH-1:0] vcount;

  logic [XWIDTH + HRES_BY_VW_WIDTH-1:0] x_min_scaled, x_max_scaled;
  logic [YWIDTH + VRES_BY_VH_WIDTH-1:0] y_min_scaled, y_max_scaled;
  logic bary_valid_out;


  always_comb begin
    x_min_scaled = x_min * HRES_BY_VW;  // avoid overflow
    x_max_scaled = x_max * HRES_BY_VW;
    y_min_scaled = y_min * VRES_BY_VH;
    y_max_scaled = y_max * VRES_BY_VH;
  end


  // TODO: update FSM to take into account backpressure from the shader and the frame buffer
  /*
	FSM:
	- IDLE
	- BBOX GEN
	- INV AREA CALC
	- RASTERIZE
	- BACK TO IDLE
	*/

  enum logic [1:0] {
    IDLE,
    BBOX_GEN,
    INV_AREA_CALC,
    RASTERIZE
  } state;

  inv_area #(
      .XWIDTH(XWIDTH),
      .YWIDTH(YWIDTH),
      .FRAC(MAX_FRAC),
      .N(N)
  ) inv_area_inst (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .valid_in(valid_in),
      .x(x),
      .y(y),
      .done(inv_area_done),
      .valid_out(inv_area_valid_out),
      .iarea(iarea_out)
  );

  logic freeze;
  assign freeze = !ready_in && state == RASTERIZE; // freeze signal for freezing components of the pipeline to make sure we're not losing data

  // TODO: check bit width....
  boundary_evt_counter #(
      .MAX_COUNT(FB_HRES)
  ) hcount_counter (
      .clk_in(clk_in),
      .rst_in(rst_in || state != RASTERIZE),
      .evt(!freeze),
      .max(hcount_max),
      .min(hcount_min),
      .count_out(hcount)
  );

  boundary_evt_counter #(
      .MAX_COUNT(FB_VRES)
  ) vcount_counter (
      .clk_in(clk_in),
      .rst_in(rst_in || state != RASTERIZE),
      .evt((hcount == hcount_max) && !freeze),
      .max(vcount_max),
      .min(vcount_min),
      .count_out(vcount)
  );

  freezable_pipeline #(
      .STAGES(10),
      .DATA_WIDTH(HWIDTH)
  ) pipe_hcount (
      .clk_in(clk_in),
      .data(hcount),
      .freeze(freeze),
      .data_out(hcount_out)
  );

  freezable_pipeline #(
      .STAGES(10),
      .DATA_WIDTH(VWIDTH)
  ) pipe_vcount (
      .clk_in(clk_in),
      .data(vcount),
      .freeze(freeze),
      .data_out(vcount_out)
  );

  freezable_pipeline #(
      .STAGES(9),
      .DATA_WIDTH(HWIDTH)
  ) addr_hcount_pipe (
      .clk_in(clk_in),
      .data(hcount),
      .freeze(freeze),
      .data_out(ahcount)
  );

  freezable_pipeline #(
      .STAGES(7),
      .DATA_WIDTH(VWIDTH)
  ) addr_vcount_pipe (
      .clk_in(clk_in),
      .data(vcount),
      .freeze(freeze),
      .data_out(avcount)
  );

  logic [1:0][PIXEL_ADDR_WIDTH-1:0] scaled_vcount;
  logic [PIXEL_ADDR_WIDTH-1:0] scaled_vcount_sum;

  always_ff @(posedge clk_in) begin
    if (!freeze) begin
      scaled_vcount[0] <= avcount << HRES_COMP1;
      scaled_vcount[1] <= avcount << HRES_COMP2;
      scaled_vcount_sum <= scaled_vcount[0] + scaled_vcount[1];
      addr_out <= scaled_vcount_sum + ahcount;
    end
  end

  barycentric_interpolator #(  // TDOO: calc the n cycles for the interpolator
      .VAL_WIDTH(ZWIDTH),
      .VAL_FRAC(ZFRAC),
      .AINV_WIDTH(INV_WIDTH),
      .AINV_FRAC(INV_FRAC),
      .XWIDTH(XWIDTH),
      .YWIDTH(YWIDTH),
      .FRAC(ZFRAC)
  ) barycentric_interpolator_inst (
      .clk_in(clk_in),
      .rst_in(rst_in || state != RASTERIZE),
      .freeze(freeze),
      .vals_in(zv),
      .iarea_in(iarea),
      .x_in(x_curr),
      .y_in(y_curr),
      .x_tri(xv),
      .y_tri(yv),
      .inter_val_out(z_out),
      .valid_out(bary_valid_out)
  );

  assign valid_out = !rst_in && bary_valid_out && state == RASTERIZE;

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      //   {hcount, vcount} <= 0;
      {xv, yv, zv} <= 0;
      state <= IDLE;
    end else begin
      case (state)
        IDLE: begin
          last_pixel <= 0;
          if (valid_in) begin
            state <= BBOX_GEN;
            xv <= x;
            yv <= y;
            zv <= z;
          end
        end

        BBOX_GEN: begin
          // find bbox
          // i get positions in screen space, convert them to pixel space 	
          state <= INV_AREA_CALC;
          if (xv[0] < xv[1]) begin
            if (xv[0] < xv[2]) begin
              x_min <= xv[0];
            end else begin
              x_min <= xv[2];
            end
            if (xv[1] > xv[2]) begin
              x_max <= xv[1];
            end else begin
              x_max <= xv[2];
            end
          end else begin
            if (xv[1] < xv[2]) begin
              x_min <= xv[1];
            end else begin
              x_min <= xv[2];
            end
            if (xv[0] > xv[2]) begin
              x_max <= xv[0];
            end else begin
              x_max <= xv[2];
            end
          end

          if (yv[0] < yv[1]) begin
            if (yv[0] < yv[2]) begin
              y_min <= yv[0];
            end else begin
              y_min <= yv[2];
            end
            if (yv[1] > yv[2]) begin
              y_max <= yv[1];
            end else begin
              y_max <= yv[2];
            end
          end else begin
            if (yv[1] < yv[2]) begin
              y_min <= yv[1];
            end else begin
              y_min <= yv[2];
            end
            if (yv[0] > yv[2]) begin
              y_max <= yv[0];
            end else begin
              y_max <= yv[2];
            end
          end
        end

        INV_AREA_CALC: begin
          if (inv_area_done) begin
            if (!inv_area_valid_out) begin
              state <= IDLE;
            end else begin
              state <= RASTERIZE;
              // rescale the x and y boundaries to be in the pixel space from the screen space 

              hcount_min <= x_min_scaled[XWIDTH + HRES_BY_VW_WIDTH - 1:((XWIDTH + HRES_BY_VW_WIDTH) - ((XWIDTH - XFRAC) + (HRES_BY_VW_WIDTH - HRES_BY_VW_FRAC)))]; // take the integer part of x
              hcount_max <= x_max_scaled[XWIDTH + HRES_BY_VW_WIDTH - 1:((XWIDTH + HRES_BY_VW_WIDTH) - ((XWIDTH - XFRAC) + (HRES_BY_VW_WIDTH - HRES_BY_VW_FRAC)))]; // take the integer part of x  	   
              vcount_min <= y_min_scaled[YWIDTH + VRES_BY_VH_WIDTH - 1:((YWIDTH + VRES_BY_VH_WIDTH) - ((YWIDTH - YFRAC) + (VRES_BY_VH_WIDTH - VRES_BY_VH_FRAC)))]; // take the integer part of y
              vcount_max <= y_max_scaled[YWIDTH + VRES_BY_VH_WIDTH - 1:((YWIDTH + VRES_BY_VH_WIDTH) - ((YWIDTH - YFRAC) + (VRES_BY_VH_WIDTH - VRES_BY_VH_FRAC)))]; // take the integer part of y

              x_curr <= x_min;
              y_curr <= y_min;
              iarea <= iarea_out;
            end
          end

        end

        RASTERIZE: begin
          if (!freeze) begin
            if (hcount_out == hcount_max && vcount_out == vcount_max) begin
              state <= IDLE;
              last_pixel <= 1;
            end else begin
              if (hcount == hcount_max) begin
                x_curr <= x_min;
                y_curr <= y_incremented;
              end else begin
                x_curr <= x_incremented;
              end
            end
          end
        end
      endcase
    end
  end
  assign ready_out = state == IDLE;

  assign x_min_out = x_min;
  assign x_max_out = x_max;
  assign y_min_out = y_min;
  assign y_max_out = y_max;
  assign hcount_min_out = hcount_min;
  assign hcount_max_out = hcount_max;
  assign vcount_min_out = vcount_min;
  assign vcount_max_out = vcount_max;

  fixed_adder #(
      .WIDTH1(XWIDTH),
      .FRAC1 (XFRAC),
      .WIDTH2(VW_BY_HRES_WIDTH),
      .FRAC2 (VW_BY_HRES_FRAC)
  ) x_increm (
      .u(x_curr),
      .v(VW_BY_HRES),
      .result(x_incremented)
  );

  fixed_adder #(
      .WIDTH1(YWIDTH),
      .FRAC1 (YFRAC),
      .WIDTH2(VH_BY_VRES_WIDTH),
      .FRAC2 (VH_BY_VRES_FRAC)
  ) y_increm (
      .u(y_curr),
      .v(VH_BY_VRES),
      .result(y_incremented)
  );

endmodule
