module counter #(
    parameter MAX_COUNT = 10
) (
    input wire clk_in,
    input wire rst_in,
    input wire [MAX_COUNT:0] period_in,
    output logic [$clog2(MAX_COUNT)-1:0] count_out
);

  //your code here
  always_ff @(posedge clk_in) begin
    if (rst_in == 1) begin
      count_out <= 0;
    end else begin
      if (count_out == period_in - 1) begin
        count_out <= count_out + 1;
      end else begin
        count_out <= 0;
      end
    end
  end
endmodule
