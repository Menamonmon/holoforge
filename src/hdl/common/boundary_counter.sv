// count the values inclusive of of min and max
module boundary_counter #(
    parameter MAX_COUNT = 10
) (
    input wire clk_in,
    input wire rst_in,
    input wire [$clog2(MAX_COUNT)-1:0] max,
    input wire [$clog2(MAX_COUNT)-1:0] min,
    output logic [$clog2(MAX_COUNT)-1:0] count_out
);
  // NOTE: the min and max boundaries should be kept stable through the whole counting process
  // NOTE: the min and max boundaries can only change when a reset signal is put in....
  // NOTE: when using this synchronize the change min and max with a change in rst
  // NOTE: the min value will be availbe on the cycle after the reset signal is switched back to 0 not on that same cycle

  logic last_reset;

  always_ff @(posedge clk_in) begin
    if (rst_in == 1) begin
      count_out <= min;
    end else begin
      if (last_reset == 1) begin
        count_out <= min;
      end else begin
        if (count_out == max) begin
          count_out <= min;
        end else begin
          count_out <= count_out + 1;
        end
      end
    end
    last_reset <= rst_in;
  end
endmodule
