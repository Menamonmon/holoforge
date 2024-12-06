//vary the packed width based on signal
//vary the unpacked width based on pipelining depth needed
module ps #(parameter WIDTH=9,PIPES=3)(
    input wire clk_in,
    input wire [WIDTH-1:0] ps1_r,
    output logic [WIDTH-1:0] r_piped [PIPES-1:0]
);

always_ff @(posedge clk_in)begin
  r_piped[0] <= ps1_r;
  for (int i=1; i<PIPES; i = i+1)begin
    r_piped[i] <= r_piped[i-1];
  end
end
endmodule
