module write_addr_gen (
    input wire clk_in,
    input wire rst_in,
    input wire valid_wr,
    input wire rdy_wr,
    input wire last_wr,
    output logic [26:0] write_address_out
);

  logic [26:0] write_address;

always_comb begin
    write_address_out=write_address<<4;
end
evt_counter#(.MAX_COUNT(115200)) write_req_addr(.clk_in(clk_in),
                                .rst_in(valid_wr && rdy_wr && last_wr),
                                .evt_in(valid_wr && rdy_wr),
                                .count_out(write_address));

endmodule