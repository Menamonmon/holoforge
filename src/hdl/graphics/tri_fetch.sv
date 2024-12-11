`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else  /* ! SYNTHESIS */
`define FPATH(X) `"../../data/X`"
`endif  /* ! SYNTHESIS */

module tri_fetch #(
    parameter MAX_COUNT = 1024
) (
    input wire clk_in,  //system clock
    input wire rst_in,  //system reset

    input wire ready_in,

    output wire valid_out,

    output logic [2:0][2:0][15:0] tri_vertices_out,
    output logic last_tri_out,
    output logic [TRI_ID_WIDTH-1:0] tri_id_out
);
  localparam DATA_WIDTH = 16 * 3 * 3;
  localparam TRI_COUNT = 12;
  localparam TRI_ID_WIDTH = $clog2(TRI_COUNT);
  logic [DATA_WIDTH-1:0] vertices_out;
  logic [TRI_ID_WIDTH-1:0] tri_id;
  logic freeze;

  assign freeze = !ready_in;

  brom #(
      .RAM_DEPTH(MAX_COUNT),
      .RAM_WIDTH(DATA_WIDTH),
      .RAM_PERFORMANCE("HIGH_PERFORMANCE"),  // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
      .INIT_FILE(
      `FPATH(mesh.mem)
      )  // Specify name/location of RAM initialization file if using one (leave blank if not)
  ) triangles_ram (
      .clka(clk_in),
      .rsta(rst_in),
      .wea(1'b0),
      .ena(1'b1),
      .regcea(!freeze),
      .addra(tri_id),
      .douta(vertices_out),
      .dina(0)
  );

  // freeze pipeline the tri_id address to that it's consistent with the fetched triangle
  freezable_pipeline #(
      .STAGES(1),
      .DATA_WIDTH(TRI_ID_WIDTH)
  ) tri_id_pipeline (
      .clk_in(clk_in),
      .freeze,
      .data(tri_id),
      .data_out(tri_id_out)
  );
  assign valid_out = (0 <= tri_id_out && tri_id_out < TRI_COUNT) && state == INCREMENTING;
  assign last_tri_out = tri_id_out == TRI_COUNT - 1;

  localparam int PAUSE_AMOUNT = 1000;
  logic [$clog2(PAUSE_AMOUNT)-1:0] pause_counter;

  evt_counter #(
      .MAX_COUNT(PAUSE_AMOUNT)
  ) counter (
      .clk_in,
      .rst_in(rst_in || state == INCREMENTING),
      .evt_in(state == PAUSING),
      .count_out(pause_counter)
  );

  evt_counter #(
      .MAX_COUNT(TRI_COUNT)
  ) tri_counter (
      .clk_in,
      .rst_in,
      .evt_in(state == INCREMENTING && ready_in),  // only increment when a handshake happens
      .count_out(tri_id)
  );

  enum logic [1:0] {
    INCREMENTING,
    PAUSING
  } state;

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      state <= INCREMENTING;
    end else begin
      case (state)
        INCREMENTING: begin
          // only go to pausing when the last triangle has been handshaked...
          if (valid_out && ready_in) begin
            if (tri_id_out == TRI_COUNT - 1) begin
              state <= PAUSING;
            end
          end
        end

        PAUSING: begin
          if (pause_counter == PAUSE_AMOUNT - 1) begin
            state <= INCREMENTING;
          end
        end
      endcase
    end
  end

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

