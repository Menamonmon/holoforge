`timescale 1ns / 1ps `default_nettype none

module evt_counter #(
    MAX_COUNT = 1000
) (
    input wire clk_in,
    input wire rst_in,
    input wire evt_in,
    output logic [$clog2(MAX_COUNT)-1:0] count_out
);

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      count_out <= 0;
    end else if (evt_in) begin
      if (count_out == MAX_COUNT - 1) begin
        count_out <= 0;  // Wrap around
      end else begin
        count_out <= count_out + 1;
      end
    end
  end

endmodule
`default_nettype wire
