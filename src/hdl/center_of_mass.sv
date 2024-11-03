module center_of_mass (
    input  wire         clk_in,
    input  wire         rst_in,
    input  wire  [10:0] x_in,         // horizontal pixel position
    input  wire  [ 9:0] y_in,         // vertical pixel position
    input  wire         valid_in,     // indicates valid pixel
    input  wire         tabulate_in,  // trigger calculation
    output logic [10:0] x_out,        // calculated average x position
    output logic [ 9:0] y_out,        // calculated average y position
    output logic        valid_out     // valid output indicator
);

  // Internal logic for sums and pixel count
  logic [31:0] x_sum, y_sum;  // Accumulated x and y sums
  logic [31:0] pixel_count;  // Total number of valid pixels

  // FSM States
  typedef enum logic [1:0] {
    IDLE,
    DIVIDE,
    DONE
  } state_t;

  logic [1:0] state;

  // Divider input and output logic
  logic [31:0] quotient_x, quotient_y;
  logic [31:0] quotient_x_buf, quotient_y_buf;
  logic [31:0] remainder_x, remainder_y;
  logic x_div_valid, y_div_valid;
  logic x_error, y_error;
  logic x_busy, y_busy;
  logic x_done, y_done;

  // Divider instantiations
  divider #(32) div_x (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .dividend_in(x_sum),
      .divisor_in(pixel_count),
      .data_valid_in(state == DIVIDE),  // trigger the division in DIVIDE state
      .quotient_out(quotient_x),
      .remainder_out(remainder_x),
      .data_valid_out(x_div_valid),
      .error_out(x_error),
      .busy_out(x_busy)
  );

  divider #(32) div_y (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .dividend_in(y_sum),
      .divisor_in(pixel_count),
      .data_valid_in(state == DIVIDE),  // trigger the division in DIVIDE state
      .quotient_out(quotient_y),
      .remainder_out(remainder_y),
      .data_valid_out(y_div_valid),
      .error_out(y_error),
      .busy_out(y_busy)
  );

  // FSM to control accumulation and division
  always_ff @(posedge clk_in or posedge rst_in) begin
    if (rst_in) begin
      state <= IDLE;
      x_sum <= 0;
      y_sum <= 0;
      pixel_count <= 0;
      valid_out <= 0;
      x_out <= 0;
      y_out <= 0;
      x_done <= 0;
      y_done <= 0;
    end else begin
      case (state)
        IDLE: begin
          valid_out <= 0;
          x_done <= 0;
          y_done <= 0;
          if (valid_in) begin
            x_sum <= x_sum + x_in;
            y_sum <= y_sum + y_in;
            pixel_count <= pixel_count + 1;
          end
          if (tabulate_in && pixel_count > 0) begin
            state <= DIVIDE;
          end
        end
        DIVIDE: begin
          // Wait for both x and y divisions to complete
          if (x_done && y_done) begin
            if (x_error || y_error) begin
              state <= IDLE;
            end else begin
              x_out <= quotient_x[10:0];  // Cast to 11 bits
              y_out <= quotient_y[9:0];  // Cast to 10 bits
              state <= DONE;
            end
          end

          if (!x_done && x_div_valid) begin
            quotient_x_buf <= quotient_x;
            x_done <= 1;
          end

          if (!y_done && y_div_valid) begin
            quotient_y_buf <= quotient_y;
            y_done <= 1;
          end
        end
        DONE: begin
          valid_out <= 1;
          state <= IDLE;
          x_done <= 0;
          y_done <= 0;
          x_sum <= 0;
          y_sum <= 0;
          pixel_count <= 0;
        end
      endcase
    end
  end

endmodule
