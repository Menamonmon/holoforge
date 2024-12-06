module uart_transmit #(
    parameter INPUT_CLOCK_FREQ = 8,
    parameter BAUD_RATE = 100
) (
    input wire clk_in,
    input wire rst_in,
    input wire [7:0] data_byte_in,
    input wire trigger_in,
    output logic busy_out,
    output logic tx_wire_out
);



  logic [9:0] transmission_buffer;
  logic [3:0] counter = 0;
  logic [$clog2(INPUT_CLOCK_FREQ / BAUD_RATE):0] baud_counter = 0;
  logic baud_clock = 0;

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      counter <= 0;
      baud_counter <= 0;
      tx_wire_out <= 1;
      busy_out <= 0;
    end else begin
      if (busy_out == 0) begin
        // idle, keep checking for trigger
        if (trigger_in) begin
          counter <= 0;
          transmission_buffer <= {1'b1, data_byte_in};
          baud_counter <= 0;
          busy_out <= 1;
          tx_wire_out <= 0;  // start bit
        end else begin
          tx_wire_out <= 1;
          busy_out <= 0;
        end
      end else begin
        // baud counter
        if (baud_counter == (INPUT_CLOCK_FREQ / BAUD_RATE) - 1) begin
          baud_counter <= 0;
          counter <= counter + 1;
          if (counter >= 9) begin
            busy_out <= 0;
            tx_wire_out <= 1;
          end else begin
            tx_wire_out <= transmission_buffer[0];
            transmission_buffer <= transmission_buffer >> 1;
          end
        end else begin
          baud_counter <= baud_counter + 1;
        end

        // transmitting
        if (counter != 9) begin
          busy_out <= 1;
        end
      end
    end
  end

endmodule

`default_nettype wire
