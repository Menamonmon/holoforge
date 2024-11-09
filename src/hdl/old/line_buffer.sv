`default_nettype none

module line_buffer #(
    parameter HRES = 1280,
    parameter VRES = 720
) (
    input wire clk_in,  //system clock
    input wire rst_in,  //system reset

    input wire [10:0] hcount_in,  //current hcount being read
    input wire [9:0] vcount_in,  //current vcount being read
    input wire [PIXEL_SIZE - 1:0] pixel_data_in,  //incoming pixel
    input wire data_valid_in,  //incoming  valid data signal

    output logic [KERNEL_SIZE-1:0][PIXEL_SIZE-1:0] line_buffer_out,  //output pixels of data
    output logic [10:0] hcount_out,  //current hcount being read
    output logic [9:0] vcount_out,  //current vcount being read
    output logic data_valid_out  //valid data out signal
);

  localparam KERNEL_SIZE = 3;
  localparam PIXEL_SIZE = 16;

  logic [1:0] buff_sel;
  logic [KERNEL_SIZE:0][15:0] all_data;

  pipeline #(
      .STAGES(2),
      .DATA_WIDTH(1)
  ) data_valid_out_pipeline (
      .clk_in(clk_in),
      .data(data_valid_in && !rst_in),
      .data_out(data_valid_out)
  );

  pipeline #(
      .STAGES(2),
      .DATA_WIDTH(11)
  ) hcount_pipeline (
      .clk_in(clk_in),
      .data(hcount_in),
      .data_out(hcount_out)
  );

  pipeline #(
      .STAGES(2),
      .DATA_WIDTH(10)
  ) vcount_pipelin (
      .clk_in(clk_in),
      .data(vcount_in >= 2 ? vcount_in - 2 : vcount_in + (VRES - 2)),
      .data_out(vcount_out)
  );

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      buff_sel <= 0;
      line_buffer_out <= 0;
    end else begin
      case (buff_sel)
        0: begin
          line_buffer_out[0] <= all_data[1];
          line_buffer_out[1] <= all_data[2];
          line_buffer_out[2] <= all_data[3];
        end
        1: begin
          line_buffer_out[0] <= all_data[2];
          line_buffer_out[1] <= all_data[3];
          line_buffer_out[2] <= all_data[0];
        end
        2: begin
          line_buffer_out[0] <= all_data[3];
          line_buffer_out[1] <= all_data[0];
          line_buffer_out[2] <= all_data[1];
        end
        3: begin
          line_buffer_out[0] <= all_data[0];
          line_buffer_out[1] <= all_data[1];
          line_buffer_out[2] <= all_data[2];
        end
      endcase
      if (data_valid_in) begin
        // increment to use the next BRAM config
        if (hcount_in == HRES - 1) begin
          buff_sel <= buff_sel + 1;
        end
      end
    end
  end

  generate
    genvar i;
    for (i = 0; i < 4; i = i + 1) begin
      xilinx_true_dual_port_read_first_1_clock_ram #(
          .RAM_WIDTH(16),
          .RAM_DEPTH(HRES),
          .RAM_PERFORMANCE("HIGH_PERFORMANCE")
      ) line_buffer_i_ram (
          .clka(clk_in),  // Clock
          //writing port:
          .addra(hcount_in),  // Port A address bus,
          .dina(pixel_data_in),  // Port A RAM input data
          .wea(data_valid_in && buff_sel == i),  // Port A write enable
          //reading port:
          .addrb(hcount_in),  // Port B address bus,
          .doutb(all_data[i]),  // Port B RAM output data,
          .douta(),  // Port A RAM output data, width determined from RAM_WIDTH
          .dinb(0),  // Port B RAM input data, width determined from RAM_WIDTH
          .web(1'b0),  // Port B write enable
          .ena(1'b1),  // Port A RAM Enable
          .enb(1'b1),  // Port B RAM Enable,
          .rsta(1'b0),  // Port A output reset
          .rstb(1'b0),  // Port B output reset
          .regcea(1'b1),  // Port A output register enable
          .regceb(1'b1)  // Port B output register enable
      );
    end
  endgenerate
endmodule


`default_nettype wire

