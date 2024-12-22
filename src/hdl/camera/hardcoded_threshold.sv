`timescale 1ns / 1ps
`default_nettype none

//module takes in a 8 bit pixel and given two threshold values it:
//produces a 1 bit output indicating if the pixel is between (inclusive)
//those two threshold values
module hardcoded_threshold(
  input wire clk_in,
  input wire rst_in,
  input wire [7:0] pixel_in,
  output logic mask_out
);
  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      mask_out <= 0;
    end else begin
      mask_out <= (pixel_in > 8'b10010000) && (pixel_in <= 8'b11110000);
    end
  end
endmodule


`default_nettype wire
