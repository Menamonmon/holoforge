module pipeline #(
    parameter STAGES,
    parameter DATA_WIDTH
) (
    input wire clk_in,
    input wire [DATA_WIDTH-1:0] data,
    output wire [DATA_WIDTH-1:0] data_out
);

  logic [STAGES-1:0][DATA_WIDTH-1:0] stages;

  //pipeline stages
  always_ff @(posedge clk_in) begin
    stages[0] <= data;
    for (int i = 1; i < STAGES; i++) begin
      stages[i] <= stages[i-1];
    end
  end

  assign data_out = stages[STAGES-1];

endmodule


`default_nettype wire


module freezable_pipeline #(
    parameter STAGES,
    parameter DATA_WIDTH
) (
    input wire clk_in,
    input wire freeze,
    input wire [DATA_WIDTH-1:0] data,
    output wire [DATA_WIDTH-1:0] data_out
);

  logic [STAGES-1:0][DATA_WIDTH-1:0] stages;

  //pipeline stages
  always_ff @(posedge clk_in) begin
    if (!freeze) begin
      stages[0] <= data;
      for (int i = 1; i < STAGES; i++) begin
        stages[i] <= stages[i-1];
      end
    end
  end

  assign data_out = stages[STAGES-1];

endmodule


`default_nettype wire
