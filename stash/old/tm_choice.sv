module tm_choice (
    input  wire  [7:0] data_in,
    output logic [8:0] qm_out
);

  logic [3:0] one_count;
  logic ith_d, ith_q, ival;
  always_comb begin
    one_count = $countones(data_in);
    qm_out = data_in & 1;
    if (one_count > 4 || (one_count == 4 && (data_in & 1) == 0)) begin
      // option 2
      for (int i = 1; i < 8; i++) begin
        ith_d  = (data_in >> i) & 1;
        ith_q  = (qm_out >> (i - 1)) & 1;
        ival   = ~(ith_d ^ ith_q);
        qm_out = qm_out | (ival << i);
      end
      qm_out = qm_out & (~(1 << 8));
    end else begin
      // option 1
      for (int i = 1; i < 8; i++) begin
        ith_d  = (data_in >> i) & 1;
        ith_q  = (qm_out >> (i - 1)) & 1;
        ival   = ith_d ^ ith_q;
        qm_out = qm_out | (ival << i);
      end
      qm_out = qm_out | (1 << 8);
    end
  end


endmodule
