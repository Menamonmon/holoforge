module lfsr_4 (
    input wire clk_in,
    input wire rst_in,
    input wire [3:0] seed_in,
    output logic [3:0] q_out
);
  logic [3:0] q;
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      q <= seed_in;
    end else begin
      q <= {q[2:0], q[3] ^ q[1]};
    end
  end

endmodule
