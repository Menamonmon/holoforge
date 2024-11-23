`timescale 1ns / 1ps `default_nettype none

module spi_con #(
    parameter DATA_WIDTH = 8,
    parameter DATA_CLK_PERIOD = 100
) (
    input wire clk_in,  //system clock (100 MHz)
    input wire rst_in,  //reset in signal
    input wire [DATA_WIDTH-1:0] data_in,  //data to send
    input wire trigger_in,  //start a transaction
    output logic [DATA_WIDTH-1:0] data_out,  //data received!
    output logic data_valid_out,  //high when output data is present.

    output logic chip_data_out,  //(COPI)
    input  wire  chip_data_in,   //(CIPO)
    output logic chip_clk_out,   //(DCLK)
    output logic chip_sel_out    // (CS)
);
  //your code here

  // states:
  // 0: idle
  // 1: start
  // 3: done
  logic state = 0;
  logic [DATA_WIDTH-1:0] out_data_buffer;
  logic [DATA_WIDTH-1:0] in_data_buffer;
  logic [$clog2(DATA_WIDTH):0] count_transmitted;
  logic [$clog2(DATA_CLK_PERIOD)-1:0] clock_period_counter;

  logic msb_out;
  assign msb_out = out_data_buffer[DATA_WIDTH-1];


  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      state <= 0;
      count_transmitted <= 0;
      clock_period_counter <= 0;
      out_data_buffer <= 0;
      in_data_buffer <= 0;

      data_out <= 0;
      data_valid_out <= 0;
      chip_data_out <= 0;
      chip_clk_out <= 0;
      chip_sel_out <= 1;

    end else begin
      if (state == 0) begin
        if (trigger_in) begin
          // state -> trasmitting
          state <= 1;
          // out_data_buffer <= data_in;
          chip_sel_out <= 0;

          // send in the first bit right away
          chip_data_out <= data_in[DATA_WIDTH-1];
          out_data_buffer <= data_in << 1;
          clock_period_counter <= 0;
          count_transmitted <= 0;
          // end else begin
          // 	// state -> idle
          // 	state <= 0;
          // 	chip_sel_out <= 1;
        end
        data_valid_out <= 0;
      end else begin

        // 1- drive clk

        // clock counter

        if (clock_period_counter == DATA_CLK_PERIOD - 1) begin
          clock_period_counter <= 0;
        end else begin
          clock_period_counter <= clock_period_counter + 1;
        end

        if (clock_period_counter == DATA_CLK_PERIOD - 1) begin
          chip_clk_out <= 0;
          if (count_transmitted == DATA_WIDTH - 1) begin
            data_valid_out <= 1;
            state <= 0;
            data_out <= in_data_buffer;
            chip_sel_out <= 1;
          end else begin
            count_transmitted <= count_transmitted + 1;

            // keep ingesting data
            chip_data_out <= msb_out;
            out_data_buffer <= out_data_buffer << 1;

            // read in data
          end
        end else begin
          if (clock_period_counter == (DATA_CLK_PERIOD / 2) - 1) begin
            chip_clk_out   <= 1;
            in_data_buffer <= (in_data_buffer << 1) | chip_data_in;
          end
        end


      end
    end
  end

endmodule

`default_nettype wire
