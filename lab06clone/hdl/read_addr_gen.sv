module read_addr_gen (
    input wire clk_in,
    input wire rst_in,
    input wire rdy_read_req,
    input wire valid_read_req,
    input wire rdy_read_resp,
    input wire valid_read_resp,

    output logic [26:0] read_request_address_out,
    output logic last_data
);

  logic [26:0] read_request_address;
  logic [26:0] read_response_address;

  always_comb begin
    read_request_address_out = read_request_address << 4;
    last_data = read_response_address == 115200 - 1;
  end

  evt_counter #(
      .MAX_COUNT(115200)
  ) read_req_addr (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .evt_in(rdy_read_req && valid_read_req),
      .count_out(read_request_address)
  );

  evt_counter #(
      .MAX_COUNT(115200)
  ) read_resp_addr (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .evt_in(rdy_read_resp && valid_read_resp),
      .count_out(read_response_address)
  );

endmodule
