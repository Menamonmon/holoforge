`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"../../data/X`"
`endif  /* ! SYNTHESIS */

module image_sprite1 #(
  parameter WIDTH=256, HEIGHT=256) (
  input wire pixel_clk_in,
  input wire rst_in,
  input wire pop_in,
  input wire [10:0] x_in, hcount_in,
  input wire [9:0]  y_in, vcount_in,
  output logic [7:0] red_out,
  output logic [7:0] green_out,
  output logic [7:0] blue_out
  );

  // calculate rom address
  logic [$clog2(WIDTH*512)-1:0] image_addr;
  assign image_addr =(pop_in)? (hcount_in - x_in) + ((vcount_in - y_in) * WIDTH)+(256*256):(hcount_in - x_in) + ((vcount_in - y_in) * WIDTH);

  logic in_sprite;     
  assign in_sprite = ((hcount_in >= x_in && hcount_in < (x_in + WIDTH)) &&
                      (vcount_in >= y_in && vcount_in < (y_in + HEIGHT)));
    
   logic [7:0] pixel_out;
   logic [23:0] pallete_out;
    
  // Modify the module below to use your BRAMs!

    xilinx_single_port_ram_read_first#(
            .RAM_WIDTH(8),                       // Specify RAM data width
            .RAM_DEPTH(256*512),                     // Specify RAM depth (number of entries)
            .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
            .INIT_FILE(`FPATH(image2.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) image_ram (
            .addra(image_addr),     // Address bus, width determined from RAM_DEPTH
            .dina(0),       // RAM input data, width determined from RAM_WIDTH
            .clka(pixel_clk_in),    // Clock
            .wea(0),         // Write enable
            .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
            .rsta(rst_in),       // Output reset (does not affect memory contents)
            .regcea(1),   // Output register enable
            .douta(pixel_out)      // RAM output data, width determined from RAM_WIDTH
        );

    xilinx_single_port_ram_read_first#(
            .RAM_WIDTH(24),                       // Specify RAM data width
            .RAM_DEPTH(256),                     // Specify RAM depth (number of entries)
            .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
            .INIT_FILE(`FPATH(palette2.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) pallete_ram (
            .addra(pixel_out),     // Address bus, width determined from RAM_DEPTH
            .dina(0),       // RAM input data, width determined from RAM_WIDTH
            .clka(pixel_clk_in),    // Clock
            .wea(0),         // Write enable
            .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
            .rsta(rst_in),       // Output reset (does not affect memory contents)
            .regcea(1),   // Output register enable
            .douta(pallete_out)      // RAM output data, width determined from RAM_WIDTH
        );
    assign red_out =    in_sprite ? pallete_out[23:16] : 0;
    assign green_out =  in_sprite ? pallete_out[15:8]: 0;
    assign blue_out =   in_sprite ? pallete_out[7:0]: 0;
endmodule






`default_nettype none