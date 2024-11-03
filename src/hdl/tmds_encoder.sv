`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)
module tmds_encoder (
    input wire clk_in,
    input wire rst_in,
    input wire [7:0] data_in,  // video data (red, green or blue)
    input wire [1:0] control_in,  //for blue set to {vs,hs}, else will be 0
    input wire ve_in,  // video data enable, to choose between control or video signal
    output logic [9:0] tmds_out
);
  logic [8:0] q_m;

  tm_choice mtm (
      .data_in(data_in),
      .qm_out (q_m)
  );
  logic [4:0] cnt;
  logic [8:0] zcount;
  logic [8:0] ocount;
  assign ocount = $countbits(q_m[7:0], '1);
  assign zcount = $countbits(q_m[7:0], '0);
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      cnt <= 0;
      tmds_out <= 0;
    end else begin
      if (ve_in) begin
        if (cnt == 0 || (ocount == zcount)) begin
          tmds_out <= {~q_m[8], q_m[8], (q_m[8] ? q_m[7:0] : ~q_m[7:0])};
          if (q_m[8] == 0) begin
            cnt <= cnt + (zcount - ocount);
          end else begin
            cnt <= cnt + (ocount - zcount);
          end
        end else begin
          if (((cnt[4] == 0) && (ocount > zcount)) || ((cnt[4] == 1) && (zcount > ocount))) begin
            tmds_out <= {1'b1, q_m[8], ~q_m[7:0]};
            cnt <= cnt + (2'd2 * q_m[8]) + (zcount - ocount);
          end else begin
            tmds_out <= {1'b0, q_m[8], q_m[7:0]};
            cnt <= cnt - (2'd2 * (!q_m[8])) + (ocount - zcount);
          end
        end
      end else begin
        cnt <= 0;
        case (control_in)
          2'b00: tmds_out <= 10'b1101010100;
          2'b01: tmds_out <= 10'b0010101011;
          2'b10: tmds_out <= 10'b0101010100;
          2'b11: tmds_out <= 10'b1010101011;
        endcase
      end
    end
  end
endmodule
`default_nettype wire
