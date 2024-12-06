module uart_receive #(
    parameter INPUT_CLOCK_FREQ = 100_000_000,
    parameter BAUD_RATE = 100
) (
    input wire clk_in,
    input wire rst_in,
    input wire rx_wire_in,
    output logic [7:0] data_byte_out,
    output logic new_data_out
);


  localparam PERIOD = INPUT_CLOCK_FREQ / BAUD_RATE;
  localparam HALF_PERIOD = PERIOD / 2;
  localparam QUARTER_PERIOD = PERIOD / 4;
  // logic [2:0] state; // 0 -> idle, 1 start, 2 data
  enum logic [2:0] {
    IDLE,
    START,
    DATA,
    STOP,
    INVALID_STOP,
    TRANSMIT
  } state;
  logic [7:0] receive_buffer;
  logic [3:0] bit_counter;
  logic [$clog2(INPUT_CLOCK_FREQ / BAUD_RATE):0] baud_counter;

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      bit_counter <= 0;
      baud_counter <= 0;
      new_data_out <= 0;
      state <= IDLE;
      receive_buffer <= 0;
      data_byte_out <= 0;
    end else begin
      if (state != IDLE) begin
        if (baud_counter == PERIOD - 1) baud_counter <= 0;
        else baud_counter <= baud_counter + 1;
      end else baud_counter <= 0;

      case (state)
        IDLE: begin
          new_data_out <= 0;
          if (rx_wire_in == 0) begin
            state <= START;
            bit_counter <= 0;
            receive_buffer <= 0;
          end
        end
        START: begin
          if (baud_counter == HALF_PERIOD - 1) begin
            // first bit verified successfully
            receive_buffer <= 0;
            bit_counter <= 0;
            if (rx_wire_in == 0) state <= DATA;
            else state <= IDLE;
            //   end else begin
            // 	if (rx_wire_in == 1) state <= IDLE;
          end else begin
            if (rx_wire_in == 1) state <= IDLE;
          end
        end
        DATA: begin
          if (baud_counter == HALF_PERIOD - 1) begin
            bit_counter <= bit_counter + 1;
            receive_buffer[bit_counter] <= rx_wire_in;
            if (bit_counter == 7) state <= STOP;
          end
        end
        STOP: begin
          if (baud_counter == HALF_PERIOD - 1) begin
            state <= (rx_wire_in == 1) ? TRANSMIT : INVALID_STOP;
          end
          // only transition to transmit when 0.5-0.75 baud period is all ones
          // if (baud_counter == HALF_PERIOD + QUARTER_PERIOD - 1) begin
          // 	if (rx_wire_in == 1) state <= TRANSMIT;
          // 	else state <= INVALID_STOP;
          // end else begin
          // 	if (rx_wire_in == 1) state <= INVALID_STOP;
          // end
        end
        INVALID_STOP: begin
          if (rx_wire_in == 1) state <= IDLE;
        end
        TRANSMIT: begin
          new_data_out <= 1;
          data_byte_out <= receive_buffer;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule

`default_nettype wire
