`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else  /* ! SYNTHESIS */
`define FPATH(X) `"../../data/X`"
`endif  /* ! SYNTHESIS */

module sincos_lookup_table #(
    parameter FILENAME = "mesh.mem",
    parameter ENTRIES  = 1024
) (
    input wire clk_in,  //system clock
    input wire rst_in,  //system reset

    input wire [$clog2(ENTRIES)-1:0] x,
    output logic signed [15:0] val_out  // always a 16-bit number since [-1, 1]
);

  brom #(
      .RAM_WIDTH(16),
      .RAM_DEPTH(ENTRIES),
      .RAM_PERFORMANCE("HIGH_PERFORMANCE"),  // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
      .INIT_FILE(
      FILENAME
      )  // Specify name/location of RAM initialization file if using one (leave blank if not)
  ) triangles_ram (
      .clka(clk_in),
      .rsta(rst_in),
      .wea(1'b0),
      .ena(1'b1),
      .regcea(1'b1),
      .addra(x),
      .douta(val_out),
      .dina(0)
  );

endmodule


`default_nettype wire

