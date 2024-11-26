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

  xilinx_true_dual_port_read_first_1_clock_ram #(
      .DATA_WIDTH(16),
      .ADDR_WIDTH($clog2(ENTRIES)),
      .RAM_PERFORMANCE("HIGH_PERFORMANCE"),  // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
      .INIT_FILE(
      `FPATH(FILENAME)
      )  // Specify name/location of RAM initialization file if using one (leave blank if not)
  ) triangles_ram (
      .clk(clk_in),
      .we(1'b0),
      .addr(x),
      .data_out(val_out)
  );

endmodule


`default_nettype wire

