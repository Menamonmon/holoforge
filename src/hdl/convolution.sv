`timescale 1ns / 1ps `default_nettype none


module convolution (
    input wire clk_in,
    input wire rst_in,
    input wire [KERNEL_SIZE-1:0][15:0] data_in,
    input wire [10:0] hcount_in,
    input wire [9:0] vcount_in,
    input wire data_valid_in,
    output logic data_valid_out,
    output logic [10:0] hcount_out,
    output logic [9:0] vcount_out,
    output logic [15:0] line_out
);

  parameter K_SELECT = 0;
  localparam KERNEL_SIZE = 3;

  logic signed [2:0][2:0][7:0] coeffs;
  logic signed [7:0] shift;
  kernels #(
      .K_SELECT(K_SELECT)
  ) kernels_inst (
      .rst_in(rst_in),
      .coeffs(coeffs),
      .shift (shift)
  );

  logic [KERNEL_SIZE-1:0][KERNEL_SIZE-1:0][15:0] buffer;
  logic signed [KERNEL_SIZE-1:0][KERNEL_SIZE-1:0][13:0] mult_buffer_r;
  logic signed [KERNEL_SIZE-1:0][KERNEL_SIZE-1:0][14:0] mult_buffer_g;
  logic signed [KERNEL_SIZE-1:0][KERNEL_SIZE-1:0][13:0] mult_buffer_b;

  logic signed [17:0] total_r;
  logic signed [18:0] total_g;
  logic signed [17:0] total_b;

  // @ hcount_in we start the calculation for the hcount_in-1 block since we now have a full kernel for that pixel
  // stages of the pipeline:
  // 1. complete 3x3 unsigned buffer
  // 2. complete 3x3 signed buffer
  // 3. complete 3x3 signed buffer with coeffcients multiplied
  // 4. complete 3x3 signed buffer with coeffcients multiplied and summed
  // 5. complete 3x3 signed buffer with coeffcients multiplied and summed with shift
  genvar i, j;  // Declare genvar variables for constant indexing
  generate
    for (i = 0; i < KERNEL_SIZE; i = i + 1) begin : row_loop
      for (j = 0; j < KERNEL_SIZE; j = j + 1) begin : col_loop
        always_ff @(posedge clk_in) begin
          // Perform signed multiplication and store result in mult_buffer
          mult_buffer_r[i][j] <= $signed({1'b0, buffer[i][j][15:11]}) * $signed(coeffs[i][j]);
          mult_buffer_g[i][j] <= $signed({1'b0, buffer[i][j][10:5]}) * $signed(coeffs[i][j]);
          mult_buffer_b[i][j] <= $signed({1'b0, buffer[i][j][4:0]}) * $signed(coeffs[i][j]);
        end
      end
    end
  endgenerate

  logic [4:0] trunc_r;
  logic [5:0] trunc_g;
  logic [4:0] trunc_b;

  // Perform the shift operation and clip the result in another block
  logic signed [2:0][15:0] total_rr;
  logic signed [2:0][16:0] total_gr;
  logic signed [2:0][15:0] total_br;

  always_ff @(posedge clk_in) begin
    total_rr[0] = ($signed(mult_buffer_r[0][0]) + $signed(mult_buffer_r[0][1]) +
                   $signed(mult_buffer_r[0][2]));

    total_rr[1] = ($signed(mult_buffer_r[1][0]) + $signed(mult_buffer_r[1][1]) +
                   $signed(mult_buffer_r[1][2]));

    total_rr[2] = ($signed(mult_buffer_r[2][0]) + $signed(mult_buffer_r[2][1]) +
                   $signed(mult_buffer_r[2][2]));
    total_r = ($signed(total_rr[0]) + $signed(total_rr[1]) + $signed(total_rr[2])) >>> shift;

    total_gr[0] = ($signed(mult_buffer_g[0][0]) + $signed(mult_buffer_g[0][1]) +
                   $signed(mult_buffer_g[0][2]));

    total_gr[1] = ($signed(mult_buffer_g[1][0]) + $signed(mult_buffer_g[1][1]) +
                   $signed(mult_buffer_g[1][2]));

    total_gr[2] = ($signed(mult_buffer_g[2][0]) + $signed(mult_buffer_g[2][1]) +
                   $signed(mult_buffer_g[2][2]));

    total_g = ($signed(total_gr[0]) + $signed(total_gr[1]) + $signed(total_gr[2])) >>> shift;

    total_br[0] = ($signed(mult_buffer_b[0][0]) + $signed(mult_buffer_b[0][1]) +
                   $signed(mult_buffer_b[0][2]));

    total_br[1] = ($signed(mult_buffer_b[1][0]) + $signed(mult_buffer_b[1][1]) +
                   $signed(mult_buffer_b[1][2]));

    total_br[2] = ($signed(mult_buffer_b[2][0]) + $signed(mult_buffer_b[2][1]) +
                   $signed(mult_buffer_b[2][2]));

    total_b = ($signed(total_br[0]) + $signed(total_br[1]) + $signed(total_br[2])) >>> shift;

  end

  assign trunc_r  = total_r[17] == 1 ? 5'b00000 : (total_r > 5'b11111 ? 5'b11111 : total_r[4:0]);
  assign trunc_g  = total_g[18] == 1 ? 6'b000000 : (total_g > 6'b111111 ? 6'b111111 : total_g[5:0]);
  assign trunc_b  = total_b[17] == 1 ? 5'b00000 : (total_b > 5'b11111 ? 5'b11111 : total_b[4:0]);
  assign line_out = {trunc_r, trunc_g, trunc_b};

  always @(posedge clk_in) begin
    if (rst_in) begin
      buffer <= 0;
    end else begin
      if (data_valid_in) begin
        // shift the last two rows to the first two spots and add in the last spot
        buffer[0] <= buffer[1];
        buffer[1] <= buffer[2];
        buffer[2] <= data_in;
		
      end
    end
  end

  // hcount pipeline 

  pipeline #(
      .STAGES(3),
      .DATA_WIDTH(10)
  ) hcount_pipeline (
      .clk_in(clk_in),
      .data(hcount_in - 1),
      .data_out(hcount_out)
  );

  // vcount pipeline
  pipeline #(
      .STAGES(3),
      .DATA_WIDTH(9)
  ) vcount_pipeline (
      .clk_in(clk_in),
      .data(vcount_in),
      .data_out(vcount_out)
  );

  // data valid pipeline
  pipeline #(
      .STAGES(3),
      .DATA_WIDTH(1)
  ) data_valid_pipeline (
      .clk_in(clk_in),
      .data(data_valid_in && !rst_in),
      .data_out(data_valid_out)
  );


  /* Note that the coeffs output of the kernels module
     * is packed in all dimensions, so coeffs should be
     * defined as `logic signed [2:0][2:0][7:0] coeffs`
     *
     * This is because iVerilog seems to be weird about passing
     * signals between modules that are unpacked in more
     * than one dimension - even though this is perfectly
     * fine Verilog.
     */


  // always_ff @(posedge clk_in) begin
  //   // Make sure to have your output be set with registered logic!
  //   // Otherwise you'll have timing violations.
  // end
endmodule

`default_nettype wire

