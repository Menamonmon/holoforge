module bto7s (
    input  wire  [3:0] x_in,
    output logic [6:0] s_out
);

  // your code here!
  logic [15:0] num;
  // assign num[0] = ~x_in[3] && ~x_in[2] && ~x_in[1] && ~x_in[0];
  // assign num[1] = ~x_in[3] && ~x_in[2] && ~x_in[1] && x_in[0];

  // you do the rest...
  assign num[0] = (x_in == 4'd0);
  assign num[1] = (x_in == 4'd1);
  assign num[2] = (x_in == 4'd2);
  assign num[3] = (x_in == 4'd3);
  assign num[4] = (x_in == 4'd4);
  assign num[5] = (x_in == 4'd5);
  assign num[6] = (x_in == 4'd6);
  assign num[7] = (x_in == 4'd7);
  assign num[8] = (x_in == 4'd8);
  assign num[9] = (x_in == 4'd9);
  assign num[10] = (x_in == 4'd10);
  assign num[11] = (x_in == 4'd11);
  assign num[12] = (x_in == 4'd12);
  assign num[13] = (x_in == 4'd13);
  assign num[14] = (x_in == 4'd14);
  assign num[15] = (x_in == 4'd15);

  //now make your sum:
  /* assign the seven output segments, sa through sg, using a "sum of products"
         * approach and the diagram above.
         */
  assign sa = num[0] || num[2] || num[3] || num[5] || num[6] || num[7] || num[8] || num[9] || num[10] || num[12] || num[14] || num[15];
  assign sb = num[0] || num[1] || num[2] || num[3] || num[4] || num[7] || num[8] || num[9] || num[10] || num[13];
  assign sc = num[0] || num[1] || num[3] || num[4] || num[5] || num[6] || num[7] || num[8] || num[9] || num[10] || num[11] || num[13];
  assign sd = num[0] || num[2] || num[3] || num[5] || num[6] || num[8] || num[9] || num[11] || num[12] || num[13] || num[14];
  assign se = num[0] || num[2] || num[6] || num[8] || num[10] || num[11] || num[12] || num[13] || num[14] || num[15];
  assign sf = num[0] || num[4] || num[5] || num[6] || num[8] || num[9] || num[10] || num[11] || num[12] || num[14] || num[15];
  assign sg = num[2] || num[3] || num[4] || num[5] || num[6] || num[8] || num[9] || num[10] || num[11] || num[13] || num[14] || num[15];

  assign s_out[0] = sa;
  assign s_out[1] = sb;
  assign s_out[2] = sc;
  assign s_out[3] = sd;
  assign s_out[4] = se;
  assign s_out[5] = sf;
  assign s_out[6] = sg;
endmodule

