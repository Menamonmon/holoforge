`timescale 1ns / 1ps
`default_nettype none

module tmds_encoder(
  input wire clk_in,
  input wire rst_in,
  input wire [7:0] data_in,  // video data (red, green or blue)
  input wire [1:0] control_in, //for blue set to {vs,hs}, else will be 0
  input wire ve_in,  // video data enable, to choose between control or video signal
  output logic [9:0] tmds_out
);

  logic [8:0] q_m;
  //you can assume a functioning (version of tm_choice for you.)
  tm_choice mtm(
    .data_in(data_in),
    .qm_out(q_m));

  //your code here.
  logic [4:0]  tally;
  logic [3:0] amt_ones;
  logic [3:0] amt_zero;
  always_ff@(posedge clk_in)begin
    // do lame system checks first ig
    if(rst_in)begin
      tally<=5'b0;
      tmds_out<=10'b0;
    end else if(!ve_in)begin
      tally<=5'b0;
      case(control_in)
      2'b00: tmds_out<=10'b1101010100;
      2'b01: tmds_out<=10'b0010101011;
      2'b10: tmds_out<=10'b0101010100;
      2'b11: tmds_out=10'b1010101011;
      endcase
    end else begin
    //first check which way to invert
    amt_ones=q_m[0]+q_m[1]+q_m[2]+q_m[3]+q_m[4]+q_m[5]+q_m[6]+q_m[7];
    amt_zero=8-amt_ones;
    //if tally is zero or we have an equal amount of 1's and zeroes we good
    if(tally==0 || amt_ones==4)begin
      //theres work to be done here
      tmds_out[9]<=!q_m[8];
      tmds_out[8]<=q_m[8];
      tmds_out[7:0]<=(q_m[8])?  q_m[7:0]:~(q_m[7:0]);
      tally<=(!q_m[8])? tally+(amt_zero-amt_ones):tally+(amt_ones-amt_zero);
    end else begin
      //mindlesslsey follownig logic
      if((tally[4]==0 && amt_ones>amt_zero) || (tally[4]==1 && amt_zero>amt_ones))begin
        tmds_out[9]<=1;
        tmds_out[8]<=q_m[8];
        tmds_out[7:0]<=~(q_m[7:0]);
        tally<=tally+(q_m[8]<<1)+(amt_zero-amt_ones);

      end else begin
        tmds_out[9]<=0;
        tmds_out[8]<=q_m[8];
        tmds_out[7:0]<=q_m[7:0];
        tally<= tally-(!q_m[8]<<1)+(amt_ones-amt_zero);
      end
    end
  end
  end

endmodule //end tmds_encoder
`default_nettype wire
