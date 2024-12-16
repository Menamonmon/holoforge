// this module holds a valid_out signal until a ready_in comes in (ABIDES BY AXI)
module graphics_pipeline_no_brom #(
    parameter C_WIDTH = 18,  // cam center width
    parameter P_WIDTH = 16,  // 3D pos width
    parameter V_WIDTH = 16,  // normal vector width
    parameter FRAC_BITS = 14,  // Percision 
    parameter VH_OVER_TWO_WIDTH = 10,
    parameter VW_OVER_TWO_WIDTH = 10,

    parameter signed [VH_OVER_TWO_WIDTH-1:0] VH_OVER_TWO = 0,
    parameter signed [VW_OVER_TWO_WIDTH-1:0] VW_OVER_TWO = 0,
    parameter VIEWPORT_H_POSITION_WIDTH = 18,
    parameter VIEWPORT_W_POSITION_WIDTH = 20,
    parameter NUM_TRI = 2048,
    parameter NUM_COLORS = 256,
    parameter N = 3,

    parameter FB_HRES = 320,
    parameter FB_VRES = 180,

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

    input wire valid_in,
    input wire ready_in,  // kinda ignored for now because rasterizer doesn't pause

    // 3D Point P
    input wire [$clog2(NUM_TRI)-1:0] tri_id_in,
    input wire signed [2:0][2:0][P_WIDTH-1:0] P,  // [P_x, P_y, P_z]
    // Camera position C
    input wire signed [2:0][C_WIDTH-1:0] C,  // [C_x, C_y, C_z]
    // Camera vectors u, v, n
    input wire signed [2:0][V_WIDTH-1:0] u,  // [u_x, u_y, u_z]
    input wire signed [2:0][V_WIDTH-1:0] v,  // [v_x, v_y, v_z]
    input wire signed [2:0][V_WIDTH-1:0] n,  // [n_x, n_y, n_z]
    // Outputs
    output logic valid_out,
    output logic ready_out,
    output logic last_pixel_out,
    output logic last_tri_out,
    output logic [$clog2(FB_HRES)-1:0] hcount_out,
    output logic [$clog2(FB_VRES)-1:0] vcount_out,
    output logic [ZWIDTH:0] z_out,
    output logic [$clog2(FB_HRES*FB_VRES)-1:0] addr_out,
    output logic [COLOR_WIDTH-1:0] color_out,

    // TODO: add debug here....
    output logic [XWIDTH-1:0] x_min_out,
    output logic [XWIDTH-1:0] x_max_out,
    output logic [YWIDTH-1:0] y_min_out,
    output logic [YWIDTH-1:0] y_max_out,
    output logic [HWIDTH-1:0] hcount_min_out,
    output logic [HWIDTH-1:0] hcount_max_out,
    output logic [VWIDTH-1:0] vcount_min_out,
    output logic [VWIDTH-1:0] vcount_max_out
);

  localparam HWIDTH = $clog2(FB_HRES);
  localparam VWIDTH = $clog2(FB_VRES);
  localparam XWIDTH = VIEWPORT_H_POSITION_WIDTH;
  localparam YWIDTH = VIEWPORT_W_POSITION_WIDTH;

  localparam COLOR_WIDTH = 16;
  localparam ZWIDTH = 1 + C_WIDTH;
  logic rasterizer_ready_out;
  logic rasterizer_valid_in;
  logic [2:0][VIEWPORT_H_POSITION_WIDTH-1:0] viewport_x_position, viewport_x_position_temp;
  logic [2:0][VIEWPORT_W_POSITION_WIDTH-1:0] viewport_y_position, viewport_y_position_temp;
  logic [2:0][ZWIDTH-1:0] z_depth;
  logic [COLOR_WIDTH-1:0] color_out_temp;

  pre_proc_shader #(
      .C_WIDTH(C_WIDTH),
      .P_WIDTH(P_WIDTH),
      .V_WIDTH(V_WIDTH),
      .ZWIDTH(ZWIDTH),
      .FRAC_BITS(FRAC_BITS),
      .VH_OVER_TWO_WIDTH(VH_OVER_TWO_WIDTH),
      .VW_OVER_TWO_WIDTH(VW_OVER_TWO_WIDTH),
      .VIEWPORT_H_POSITION_WIDTH(VIEWPORT_H_POSITION_WIDTH),
      .VIEWPORT_W_POSITION_WIDTH(VIEWPORT_W_POSITION_WIDTH),
      .VH_OVER_TWO(VH_OVER_TWO),
      .VW_OVER_TWO(VW_OVER_TWO),
      .NUM_TRI(NUM_TRI),
      .NUM_COLORS(NUM_COLORS)
  ) pre_proc_shader_inst (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .valid_in(valid_in),
      .ready_in(rasterizer_ready_out),
      .tri_id_in(tri_id_in),
      .glob_ready_in(ready_in),
      .P(P),
      .C(C),
      .u(u),
      .v(v),
      .n(n),
      .valid_out(rasterizer_valid_in),
      .ready_out(ready_out),
      .viewport_x_positions_out(viewport_x_position),
      .viewport_y_positions_out(viewport_y_position),
      .z_depth_out(z_depth),
      .last_pixel_out(sc_last_pixel_out),
      .color_out(color_out_temp)
  );

  logic sc_last_pixel_out;

  always_ff @(posedge clk_in) begin
    // something went into the rasterizer and it shall control
    if (rasterizer_valid_in && rasterizer_ready_out) begin
      // update the color to the new value
      color_out <= color_out_temp;
    end
  end

  assign last_pixel_out = sc_last_pixel_out || rast_last_pixel_out;

  logic rast_last_pixel_out;
  rasterizer #(
      .XWIDTH(VIEWPORT_H_POSITION_WIDTH),
      .YWIDTH(VIEWPORT_W_POSITION_WIDTH),
      .ZWIDTH(ZWIDTH),
      .XFRAC(FRAC_BITS),
      .YFRAC(FRAC_BITS),
      .ZFRAC(FRAC_BITS),
      .FB_HRES(FB_HRES),
      .FB_VRES(FB_VRES),
      .HRES_BY_VW(HRES_BY_VW),
      .VRES_BY_VH(VRES_BY_VH),
      .VW_BY_HRES(VW_BY_HRES),
      .VH_BY_VRES(VH_BY_VRES),
      .HRES_BY_VW_WIDTH(HRES_BY_VW_WIDTH),
      .VRES_BY_VH_WIDTH(VRES_BY_VH_WIDTH),
      .VW_BY_HRES_WIDTH(VW_BY_HRES_WIDTH),
      .VH_BY_VRES_WIDTH(VH_BY_VRES_WIDTH),
      .HRES_BY_VW_FRAC(HRES_BY_VW_FRAC),
      .VRES_BY_VH_FRAC(VRES_BY_VH_FRAC),
      .VW_BY_HRES_FRAC(VW_BY_HRES_FRAC),
      .VH_BY_VRES_FRAC(VH_BY_VRES_FRAC)
  ) rasterizer_inst (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .valid_in(rasterizer_valid_in),
      .ready_in(ready_in),
      .x(viewport_x_position),
      .y(viewport_y_position),
      .z(z_depth),
      .ready_out(rasterizer_ready_out),
      .valid_out(valid_out),
      .hcount_out(hcount_out),
      .vcount_out(vcount_out),
      .addr_out(addr_out),
      .z_out(z_out),
      .last_pixel(rast_last_pixel_out),
      // DEBUGGING VALUES
      .x_min_out(x_min_out),
      .x_max_out(x_max_out),
      .y_min_out(y_min_out),
      .y_max_out(y_max_out),
      .hcount_min_out(hcount_min_out),
      .hcount_max_out(hcount_max_out),
      .vcount_min_out(vcount_min_out),
      .vcount_max_out(vcount_max_out)
  );


  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      last_tri_out <= 0;
    end else begin
      if (valid_in && ready_out) begin
        last_tri_out <= tri_id_in == NUM_TRI - 1;
      end
    end
  end

endmodule
