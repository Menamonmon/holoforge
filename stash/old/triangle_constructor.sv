`default_nettype none

typedef logic signed [15:0] vfixed_t;
typedef vfixed_t vertex_t[3];
typedef vfixed_t normal_t[3];
typedef logic [7:0] color_id_t;
typedef color_id_t vcolor_t[3];


`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else  /* ! SYNTHESIS */
`define FPATH(X) `"../../data/X`"
`endif  /* ! SYNTHESIS */

module triangle_constructor #(
    parameter MAX_COUNT = 1024
) (
    input wire clk_in,  //system clock
    input wire rst_in,  //system reset

    input wire ready,

    output vertex_t tri_vertices_out[3],
    output logic [$clog2(MAX_COUNT)-1:0] tri_id_out,
    output logic valid
);
  localparam DATA_WIDTH = 16 * 3 * 3;
  logic [DATA_WIDTH-1:0] vertices_out;

  xilinx_true_dual_port_read_first_1_clock_ram #(
      .DATA_WIDTH(DATA_WIDTH),
      .ADDR_WIDTH($clog2(MAX_COUNT)),
      .RAM_PERFORMANCE("HIGH_PERFORMANCE"),  // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
      .INIT_FILE(
      `FPATH(mesh.mem)
      )  // Specify name/location of RAM initialization file if using one (leave blank if not)
  ) triangles_ram (
      .clk(clk_in),
      .we(1'b0),
      .addr(tri_id_out),
      .data_out(vertices_out)
  );


  evt_counter #(
      .COUNT(MAX_COUNT)
  ) counter (
      .clk  (clk_in),
      .rst  (rst_in),
      .ready(ready),
      .valid(valid),
      .count(tri_id_out)
  );

  always_comb begin
    tri_vertices_out[0][0] = vertices_out[15:0];
    tri_vertices_out[0][1] = vertices_out[31:16];
    tri_vertices_out[0][2] = vertices_out[47:32];

    tri_vertices_out[1][0] = vertices_out[63:48];
    tri_vertices_out[1][1] = vertices_out[79:64];
    tri_vertices_out[1][2] = vertices_out[95:80];

    tri_vertices_out[2][0] = vertices_out[111:96];
    tri_vertices_out[2][1] = vertices_out[127:112];
    tri_vertices_out[2][2] = vertices_out[143:128];
  end

endmodule


`default_nettype wire

