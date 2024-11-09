`timescale 1ns / 1ps `default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else  /* ! SYNTHESIS */
`define FPATH(X) `"../../data/X`"
`endif  /* ! SYNTHESIS */

module image_sprite_2 #(
    parameter WIDTH = 256,
    HEIGHT = 256
) (
    input wire pixel_clk_in,
    input wire rst_in,
    input wire pop_in,
    input wire [10:0] x_in,
    hcount_in,
    input wire [9:0] y_in,
    vcount_in,
    output logic [7:0] red_out,
    output logic [7:0] green_out,
    output logic [7:0] blue_out
);

  localparam IMG_ENCODED_PIXEL_WIDTH = 8;
  localparam IMG_DEPTH = WIDTH * HEIGHT * 2;
  // calculate rom address
  logic [$clog2(WIDTH*HEIGHT)-1:0] image_addr;
  assign image_addr = ((hcount_in - x_in) + ((vcount_in - y_in)) * WIDTH);

  logic in_sprite;
  assign in_sprite = ((hcount_in >= x_in && hcount_in < (x_in + WIDTH)) &&
                      (vcount_in >= y_in && vcount_in < (y_in + HEIGHT)));

  logic in_sprite_p;
  pipeline #(
      .DATA_WIDTH(1),
      .STAGES(4)
  ) p10 (
      .clk_in(pixel_clk_in),
      .data(in_sprite),
      .data_out(in_sprite_p)
  );

  logic [IMG_ENCODED_PIXEL_WIDTH-1:0] encoded_color;
  logic [23:0] decoded_color;



  xilinx_single_port_ram_read_first #(
      .RAM_WIDTH(IMG_ENCODED_PIXEL_WIDTH),  // Specify RAM data width
      .RAM_DEPTH(IMG_DEPTH),  // Specify RAM depth (number of entries)
      .RAM_PERFORMANCE("HIGH_PERFORMANCE"),  // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
      .INIT_FILE(
      `FPATH(image2.mem)
      )  // Specify name/location of RAM initialization file if using one (leave blank if not)
  ) image_mem (
      .addra(image_addr + (!pop_in ? WIDTH * WIDTH : 0)),     // Address bus, width determined from RAM_DEPTH
      .dina(0),  // RAM input data, width determined from RAM_WIDTH
      .clka(pixel_clk_in),  // Clock
      .wea(0),  // Write enable
      .ena(1),  // RAM Enable, for additional power savings, disable port when not in use
      .rsta(rst_in),  // Output reset (does not affect memory contents)
      .regcea(1),  // Output register enable
      .douta(encoded_color)  // RAM output data, width determined from RAM_WIDTH
  );

  xilinx_single_port_ram_read_first #(
      .RAM_WIDTH(24),  // Specify RAM data width
      .RAM_DEPTH(2 ** IMG_ENCODED_PIXEL_WIDTH),  // Specify RAM depth (number of entries)
      .RAM_PERFORMANCE("HIGH_PERFORMANCE"),  // Select "HIGH_PERFORMANCE" or "LOW_LATENCY"
      .INIT_FILE(
      `FPATH(palette2.mem)
      )  // Specify name/location of RAM initialization file if using one (leave blank if not)
  ) palette_mem (
      .addra(encoded_color),  // Address bus, width determined from RAM_DEPTH
      .dina(0),  // RAM input data, width determined from RAM_WIDTH
      .clka(pixel_clk_in),  // Clock
      .wea(0),  // Write enable
      .ena(1),  // RAM Enable, for additional power savings, disable port when not in use
      .rsta(rst_in),  // Output reset (does not affect memory contents)
      .regcea(1),  // Output register enable
      .douta(decoded_color)  // RAM output data, width determined from RAM_WIDTH
  );

  assign red_out   = in_sprite_p ? decoded_color[23:16] : 0;
  assign green_out = in_sprite_p ? decoded_color[15:8] : 0;
  assign blue_out  = in_sprite_p ? decoded_color[7:0] : 0;

  // Modify the module below to use your BRAMs!
  //   assign red_out =    in_sprite ? 8'hF0 : 0;
  //   assign green_out =  in_sprite ? 8'hF0 : 0;
  //   assign blue_out =   in_sprite ? 8'hF0 : 0;
endmodule






`default_nettype none
