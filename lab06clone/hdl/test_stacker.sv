`timescale 1ns / 1ps `default_nettype none

/*
 * stacker
 * 
 * AXI-Stream (approximately) module that takes in serialized 16-bit messages
 * and stacks them together into 128-bit messages. Least-significant bytes
 * received first.
 */

module test_stacker (
    input wire clk_in,
    input wire rst_in,

    input wire addr_fifo_ready_in,
    input wire data_fifo_ready_in,
    input wire [1:0] pattern_sel_in,

    output logic addr_fifo_valid_in,
    output logic data_fifo_valid_in,
    output logic [26:0] addr_fifo_data_in,
    output logic [127:0] data_fifo_data_in,
    output logic last_out
);

  localparam int HRES = 1280 / 8;
  localparam int VRES = 720;

  // Internal signals
  logic [15:0] data[7:0];  // Each entry holds {red, green, blue} = ?????????? 24 bits
  logic [26:0] addr;
  logic next_data_ready;
  logic [$clog2(HRES)-1:0] hcount;
  logic [$clog2(VRES)-1:0] vcount;

  // Compute next_data_ready based on FIFO readiness
  assign next_data_ready = addr_fifo_ready_in && data_fifo_ready_in;

  // Horizontal counter
  evt_counter #(
      .MAX_COUNT(HRES)
  ) hcounter (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .evt_in(next_data_ready),
      .count_out(hcount)
  );

  // Vertical counter
  evt_counter #(
      .MAX_COUNT(VRES)
  ) vcounter (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .evt_in((hcount == HRES - 1) && next_data_ready),
      .count_out(vcount)
  );

  // Address calculation
  assign addr = (vcount << 7) + (vcount << 5) + hcount;  // Address in terms of 128-bit blocks

  // Adjusted horizontal count for 8 subpixels
  logic [10:0] raw_hcount;
  assign raw_hcount = hcount << 3;
  assign last_out   = (hcount == HRES - 1) && (vcount == VRES - 1);

  // Generate 8 instances of test_pattern_generator
  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : data_gen
      wire [10:0] adjusted_hcount = raw_hcount + i;
      wire [ 7:0] red;
      wire [ 7:0] green;
      wire [ 7:0] blue;
      test_pattern_generator pattern_gen (
          .sel_in(pattern_sel_in),
          .hcount_in(adjusted_hcount),
          .vcount_in(vcount),
          .red_out(red),
          .green_out(green),
          .blue_out(blue)
      );
      assign data[i] = {red[7:3], green[7:2], blue[7:3]};
    end
  endgenerate

  // FIFO outputs
  assign addr_fifo_valid_in = next_data_ready;
  assign data_fifo_valid_in = next_data_ready;

  // Address FIFO data
  assign addr_fifo_data_in = addr << 4;

  // Data FIFO data assembly
  assign data_fifo_data_in = {
    data[7], data[6], data[5], data[4], data[3], data[2], data[1], data[0]
  };
  //   assign data_fifo_data_in  = 128'hFF00_0F0F_00FF_F0F0_FF00_0F0F_00FF_F0F0;

endmodule

module basic_stacker (
    input wire clk_in,
    input wire rst_in,

    input wire data_fifo_ready_in,
    input wire [1:0] pattern_sel_in,

    output logic data_fifo_valid_in,
    output logic [26:0] addr_fifo_data_in,
    output logic [127:0] data_fifo_data_in,
    output logic last_out
);

  localparam int HRES = 160;
  localparam int VRES = 720;

  // Internal signals
  logic [15:0] data[7:0];  // Each entry holds {red, green, blue} = 24 bits
  logic [26:0] addr;
  logic next_data_ready;
  logic [$clog2(HRES)-1:0] hcount;
  logic [$clog2(VRES)-1:0] vcount;

  // Compute next_data_ready based on FIFO readiness
  assign next_data_ready = data_fifo_ready_in;

  // Horizontal counter
  evt_counter #(
      .MAX_COUNT(HRES)
  ) hcounter (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .evt_in(next_data_ready),
      .count_out(hcount)
  );

  // Vertical counter
  evt_counter #(
      .MAX_COUNT(VRES)
  ) vcounter (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .evt_in((hcount == HRES - 1) && next_data_ready),
      .count_out(vcount)
  );

  // Address calculation
  assign addr = (vcount << 7) + (vcount << 5) + hcount;  // Address in terms of 128-bit blocks

  // Adjusted horizontal count for 8 subpixels
  logic [10:0] raw_hcount;
  assign raw_hcount = hcount << 3;
  assign last_out   = (hcount == HRES - 1) && (vcount == VRES - 1);

  // Generate 8 instances of test_pattern_generator
  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : data_gen
      wire [10:0] adjusted_hcount = raw_hcount + i;
      wire [ 7:0] red;
      wire [ 7:0] green;
      wire [ 7:0] blue;
      test_pattern_generator pattern_gen (
          .sel_in(pattern_sel_in),
          .hcount_in(adjusted_hcount),
          .vcount_in(vcount),
          .red_out(red),
          .green_out(green),
          .blue_out(blue)
      );
      assign data[i] = {red[7:3], green[7:2], blue[7:3]};
    end
  endgenerate

  // FIFO outputs
  //   assign addr_fifo_valid_in = next_data_ready;
  //   assign data_fifo_valid_in = next_data_ready;
  // always ready and only increment when a handshake happens (i.e. ready goes high)
  assign data_fifo_valid_in = 1'b1;

  // Address FIFO data
  assign addr_fifo_data_in = addr;

  // Data FIFO data assembly
  assign data_fifo_data_in = {
    data[7], data[6], data[5], data[4], data[3], data[2], data[1], data[0]
  };
  //   assign data_fifo_data_in  = 128'hFF00_0F0F_00FF_F0F0_FF00_0F0F_00FF_F0F0;

endmodule


`default_nettype wire
module test_pattern_generator #(
    HRES = 1280,
    VRES = 720
) (
    input  logic [ 1:0] sel_in,
    input  logic [10:0] hcount_in,
    input  logic [ 9:0] vcount_in,
    output logic [ 7:0] red_out,
    output logic [ 7:0] green_out,
    output logic [ 7:0] blue_out
);

  localparam int HALF_HRES = HRES / 2;
  localparam int HALF_VRES = VRES / 2;
  always_comb begin
    case (sel_in)
      2'b00: begin
        red_out   = 8'd255;
        green_out = 8'd0;
        blue_out  = 8'd255;
      end
      2'b01: begin
        if (vcount_in == HALF_VRES || hcount_in == HALF_HRES) begin
          red_out   = 8'hFF;
          green_out = 8'hFF;
          blue_out  = 8'hFF;
        end else begin
          red_out   = 8'h00;
          green_out = 8'h00;
          blue_out  = 8'h00;
        end
      end
      2'b10: begin
        red_out   = hcount_in[7:0];
        green_out = hcount_in[7:0];
        blue_out  = hcount_in[7:0];
      end
      2'b11: begin
        red_out   = hcount_in[7:0];
        green_out = vcount_in[7:0];
        blue_out  = (hcount_in[7:0] + vcount_in[7:0]);
      end
    endcase
  end

endmodule

