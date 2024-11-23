module crc32_mpeg2 (
    input wire clk_in,
    input wire rst_in,
    input wire data_valid_in,
    input wire data_in,
    output logic [31:0] data_out
);

  lfsr crc_lfsr (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .seed_in(32'hFFFF_FFFF),
      .inp(data_in),
      .evt(data_valid_in),
      .q_out(data_out)
  );
endmodule

module lfsr #(
    parameter SIZE = 32
) (
    input wire clk_in,
    input wire rst_in,
    input wire [SIZE-1:0] seed_in,
    input wire inp,
    input wire evt,
    output logic [SIZE-1:0] q_out
);
  logic head;

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      q_out <= seed_in;
    end else begin
      // x^32 + x^26 + x^23 + x^22 + x^16 + x^12 + x^11 + x^10 + x^8 + x^7 + x^5 + x^4 + x^2 + x + 1
      if (evt) begin
        head = inp ^ q_out[31];
		// 1 ^ 0 = 1
		// 0 ^ 0 = 0
		q_out <= {q_out[30:0], 1'b0} ^ (head ? 32'h04C11DB7 : 32'h00000000);
      end
    end
  end
endmodule
