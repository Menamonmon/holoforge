module rasterizer #(
    FWIDTH = 16,
    FFRAC = 14,
    N = 3,
    FB_HRES = 320,
    FB_VRES = 180
) (
    input wire clk_in,
    input wire rst_in,
    input wire valid_in, // whether or not we got a new valid input (should never be true if ready_out is false)
    input wire ready_in,  // whether or not the following stage is ready

    input wire signed [N-1:0][FWIDTH-1:0] x,
    input wire signed [N-1:0][FWIDTH-1:0] y,
    input wire signed [N-1:0][FWIDTH-1:0] z,

    output logic valid_out,  // pixel single cycle output for shader to process the pixel
    output logic ready_out,  // busy

    output logic [$clog2(FB_HRES)-1:0] hcount,
    output logic [$clog2(FB_VRES)-1:0] vcount,
    output logic signed [FWIDTH-1:0] z_out
);

  logic signed [N-1:0][FWIDTH-1:0] xv, yv, zv;

  /*
	FSM:
	- IDLE: valid_in => BBOX GEN
	- BBOX GEN => BBOX GEN READY => RASTERIZE
	- RASTERIZE
	- BACK TO IDLE
	*/


  inv_area #() inv_area_inst (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .valid_in(valid_in),
      .x(x),
      .y(y),
      .done(),
      .valid_out(),
      .iarea()
  );

  enum {
    IDLE,
    BBOX_GEN,
    RASTERIZE
  } state;

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      {hcount, vcount} <= 0;
      {xv, yv, zv} <= 0;
      valid_out <= 0;
      ready_out <= 1;
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
        end

        RASTERIZE: begin
        end
      endcase
    end
  end
  assign ready_in = state == IDLE;


endmodule
