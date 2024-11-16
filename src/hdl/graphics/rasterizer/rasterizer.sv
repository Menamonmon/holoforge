module rasterizer #(
    parameter XWIDTH = 16,
    parameter YWIDTH = 16,
    parameter ZWIDTH = 16,
    parameter XFRAC = 14,
    parameter YFRAC = 14,
    parameter ZFRAC = 14,
    parameter N = 3,
    parameter    FB_HRES = 320,
    parameter    FB_VRES = 180
) (
    input wire clk_in,
    input wire rst_in,
    input wire valid_in, // whether or not we got a new valid input (should never be true if ready_out is false)
    input wire ready_in,  // whether or not the following stage is ready

    // unsigned since it's normalized screen coordinates.....
    input wire signed [N-1:0][XWIDTH-1:0] x,
    input wire signed [N-1:0][YWIDTH-1:0] y,
    input wire signed [N-1:0][ZWIDTH-1:0] z,

    output logic valid_out,  // pixel single cycle output for shader to process the pixel
    output logic ready_out,  // busy

    output logic [$clog2(FB_HRES)-1:0] hcount_out,
    output logic [$clog2(FB_VRES)-1:0] vcount_out,
    output logic signed [ZWIDTH-1:0] z_out
);

  localparam MAX_FRAC = XFRAC > YFRAC ? (XFRAC > ZFRAC ? XFRAC : ZFRAC) : (YFRAC > ZFRAC ? YFRAC : ZFRAC);
  localparam INV_FRAC = MAX_FRAC;
  localparam INV_WIDTH = 2 * MAX_FRAC + 1;
  localparam HWIDTH = $clog2(FB_HRES);
  localparam VWIDTH = $clog2(FB_VRES);
  localparam X_INCREM = 1;
  localparam Y_INCREM = 1;

  logic signed [2:0][XWIDTH-1:0] xv;
  logic signed [2:0][YWIDTH-1:0] yv;
  logic signed [2:0][ZWIDTH-1:0] zv;

  logic signed [XWIDTH-1:0] x_min, x_max, x_curr;
  logic signed [YWIDTH-1:0] y_min, y_max, y_curr;
  logic inv_area_done, inv_area_valid_out;
  logic signed [INV_WIDTH-1:0] iarea_out;
  logic signed [INV_WIDTH-1:0] iarea;
  logic [HWIDTH-1:0] hcount_min, hcount_max;
  logic [VWIDTH-1:0] vcount_min, vcount_max;
  logic [HWIDTH-1:0] hcount;
  logic [VWIDTH-1:0] vcount;


  /*
	FSM:
	- IDLE
	- BBOX GEN
	- INV AREA CALC
	- RASTERIZE
	- BACK TO IDLE
	*/

  enum {
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
      .iarea(iarea)
  );

  boundary_counter #(
      .MAX_COUNT(FB_HRES)
  ) hcount_counter (
      .clk_in(clk_in),
      .rst_in(rst_in || state != RASTERIZE),
      .max(hcount_max),
      .min(hcount_min),
      .count_out(hcount)
  );

  boundary_counter #(
      .MAX_COUNT(FB_VRES)
  ) vcount_counter (
      .clk_in(clk_in),
      .rst_in(rst_in || state != RASTERIZE),
      .max(vcount_max),
      .min(vcount_min),
      .count_out(vcount)
  );

  pipeline #(
      .STAGES(6),  // TODO: check stage count
      .DATA_WIDTH(HWIDTH)
  ) pipe_hcount (
      .clk_in(clk_in),
      .data(hcount),
      .data_out(hcount_out)
  );

  pipeline #(
      .STAGES(6),  // TODO: check stage count
      .DATA_WIDTH(VWIDTH)
  ) pipe_vcount (
      .clk_in(clk_in),
      .data(vcount),
      .data_out(vcount_out)
  );

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
      .vals_in(zv),
      .iarea_in(iarea),
      .x_in(x_curr),
      .y_in(y_curr),
      .x_tri(xv),
      .y_tri(yv),
      .inter_val_out(z_out),
      .valid_out(valid_out)
  );



  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      {hcount, vcount} <= 0;
      {xv, yv, zv} <= 0;
      state <= IDLE;
    end else begin
      case (state)
        IDLE: begin
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
              hcount_min <= x_min;  // TODO: add scaling
              hcount_max <= x_max;  // TODO: add scaling
              vcount_min <= y_min;  // TODO: add scaling
              vcount_max <= y_max;  // TODO: add scaling
              x_curr <= x_min;
              y_curr <= y_min;
            end
          end

        end

        RASTERIZE: begin
          if (hcount == hcount_max && vcount == vcount_max) begin
            state <= IDLE;
          end else begin
            // TODO: increment the x and y values
            x_curr <= x_curr + X_INCREM;
            y_curr <= y_curr + Y_INCREM;
          end
        end
      endcase
    end
  end
  assign ready_out = state == IDLE;


endmodule
