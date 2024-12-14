
module zoom_counter #(
    parameter ROW_COUNT = 320,
    parameter COL_COUNT = 180,
    parameter SCALE_FACTOR = 4
) (
    input wire clk_in,
    input wire rst_in,
    input wire evt_in,
    output logic [$clog2(MAX_COUNT)-1:0] count_out,
    output logic last_out
);
  localparam MAX_COUNT = ROW_COUNT * COL_COUNT;
  logic [$clog2(ROW_COUNT)-1:0] row;
  logic [$clog2(COL_COUNT)-1:0] col;
  logic [$clog2(SCALE_FACTOR)-1:0] cscale;
  logic [$clog2(MAX_COUNT)-1:0] row_start;
  logic [$clog2(MAX_COUNT)-1:0] row_end;
  assign last_out = count_out == MAX_COUNT - 1 && cscale == SCALE_FACTOR - 1;

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      count_out <= 0;
      cscale <= 0;
      row <= 0;
      col <= 0;
    end else if (evt_in) begin
      // end condition
      if (count_out == MAX_COUNT - 1 && cscale == SCALE_FACTOR - 1) begin
        count_out <= 0;  // Wrap around
        row <= 0;
        col <= 0;
        cscale <= 0;
      end else begin
        if (row == ROW_COUNT - 1) begin
          // reaching end of row, increment the zoom counter
          row <= 0;
          row_end <= count_out;
          if (cscale == SCALE_FACTOR - 1) begin
            col <= col + 1;
            cscale <= 0;
            count_out <= row_end + 1;
          end else begin
            cscale <= cscale + 1;
            count_out <= row_start;
          end
        end else begin
          if (row == 0) begin
            row_start <= count_out;
          end
          count_out <= count_out + 1;
          row <= row + 1;
        end
      end
    end
  end

endmodule
