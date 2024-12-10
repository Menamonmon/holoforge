module test_pattern_generator #(
    HRES = 1280,
    VRES = 720
) (
    input logic [1:0] sel_in,
    input logic [$clog2(HRES)-1:0] hcount_in,
    input logic [$clog2(VRES)-1:0] vcount_in,
    output logic [7:0] red_out,
    output logic [7:0] green_out,
    output logic [7:0] blue_out
);

  localparam int HALF_HRES = HRES / 2;
  localparam int HALF_VRES = VRES / 2;
  always_comb begin
    case (sel_in)
      2'b00: begin
        red_out   = 8'd255;
        green_out = 8'd0;
        blue_out  = 8'd255;
      end
      2'b01: begin
        if (vcount_in == HALF_VRES || hcount_in == HALF_HRES) begin
          red_out   = 8'hFF;
          green_out = 8'hFF;
          blue_out  = 8'hFF;
        end else begin
          red_out   = 8'h00;
          green_out = 8'h00;
          blue_out  = 8'h00;
        end
      end
      2'b10: begin
        red_out   = {hcount_in[5:0],2'b0};
        green_out = {hcount_in[5:0],2'b0};
        blue_out  = {hcount_in[5:0],2'b0};
      end
      2'b11: begin
        red_out   = {hcount_in[5:0],2'b0};
        green_out = {vcount_in[5:0],2'b0};
        blue_out  = {(hcount_in[5:0] + vcount_in[5:0]),2'b0};
      end
    endcase
  end

endmodule
