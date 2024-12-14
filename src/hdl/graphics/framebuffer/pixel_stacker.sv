module pixel_stacker #(
    parameter HRES = 1280,
    parameter VRES = 720
) (
    input wire clk_in,
    input wire rst_in,
    input wire [15:0] data_in,
    input wire strobe_in,
    input wire ready_in,  //coming from out_fifo
    input wire valid_in,  //coming from rasterizer
    input wire [addr_width-1:0] addr,
    //output logic
    output logic ready_out,  //back propagating rdy_in from out_fifo
    output logic [chunk_addr_width-1:0] addr_out,
    output logic [7:0][15:0] data_out,
    output logic [15:0] strobe_out,
    output logic valid_out
);
  localparam addr_width = $clog2((HRES * VRES));
  localparam chunk_addr_width = $clog2((HRES * VRES) / 8);
  localparam hres_width = $clog2(HRES);
  localparam vres_width = $clog2(VRES);
  localparam addr_out_width = 27;
  localparam addr_left_over = 27 - (addr_width + 1 + 1);

  //data tracking sigs
  logic temp_valid_in;
  logic [addr_width-1:0] temp_addr;
  logic [15:0] temp_data;
  logic temp_strobe;

  logic [7:0][15:0] data;
  logic [15:0] strobe;
  logic [addr_width-1:0] prev_addr;

  //ready_signals
  logic data_full;
  logic will_be_ready;
  logic [2:0] index;
  logic [26:0] addr_adding;

  always_comb begin
    data_full = (((addr[addr_width-1:3]) != (prev_addr[addr_width-1:3])));
    // ready_out = !data_full;
    ready_out = will_be_ready;
    will_be_ready = (!valid_out) || (ready_in);
    index = addr[2:0];
  end
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      data <= 128'b0;
      data_out <= 128'b0;
      valid_out <= 0;
      prev_addr <= 0;
      temp_addr <= 0;
      temp_valid_in <= 0;
      temp_data <= 0;
      temp_addr <= 0;
      strobe <= 0;
      strobe_out <= 0;
      addr_out <= 0;
      temp_strobe <= 0;


    end else begin

      if (valid_out && ready_in) begin
        valid_out <= 0;
      end

      if (will_be_ready && data_full) begin
        //out sigs
        data_out <= data;
        strobe_out <= strobe;
        //chunk(sanity check)
        addr_out <= prev_addr[addr_width-1:3];
        valid_out <= strobe != 0;
        data <= 128'b0;
        strobe <= 16'b0;
        prev_addr <= 0;
      end

      if (valid_in) begin
        if (ready_out) begin
          //consume data and stack
          data[addr[2:0]] <= data_in;
          strobe[{addr[2:0], 1'b0}+1] <= strobe_in;
          strobe[{addr[2:0], 1'b0}] <= strobe_in;
          prev_addr <= addr;
        end
      end

    end

  end


endmodule
