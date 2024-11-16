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

  //your code here
  always_ff @(posedge clk_in) begin
    if (rst_in == 1) begin
      count_out <= min;
    end else begin
      if (count_out == max) begin
        count_out <= min;
      end else begin
        count_out <= count_out + 1;
      end
    end
  end
endmodule
