module framebuffer#(
    Z_WIDTH=15,
    HRES=320,
    VRES=180
)(

    input wire clk_100mhz,
    input wire sys_rst,

    //in from rasterizer/vid src
    input wire valid_in,
    input wire [26:0] addr_in,
    input wire [Z_WIDTH-1:0] depth_in,
    input wire frame,
    input wire [15:0] color_in,
    input wire [3:0] btn,
    //out to rasterizrer/vid src
    output wire rasterizer_rdy_out,
    //out casue we're the clock wizard
    input wire clk_100_passthrough,
    input wire clk_migref,
    input wire clk_pixel,
    input wire sys_rst_migref,
    //out to TMDS HDMI STUFF
    output wire frame_buff_tvalid,
    input wire frame_buff_tready,
    output wire [15:0] frame_buff_tdata,
    output wire frame_buff_tlast,

    //ddr stuff
    inout  wire [15:0] ddr3_dq,
    inout  wire [ 1:0] ddr3_dqs_n,
    inout  wire [ 1:0] ddr3_dqs_p,
    output wire [12:0] ddr3_addr,
    output wire [ 2:0] ddr3_ba,
    output wire        ddr3_ras_n,
    output wire        ddr3_cas_n,
    output wire        ddr3_we_n,
    output wire        ddr3_reset_n,
    output wire        ddr3_ck_p,
    output wire        ddr3_ck_n,
    output wire        ddr3_cke,
    output wire [ 1:0] ddr3_dm,
    output wire        ddr3_odt,


    output wire [3:0]ss0_an,
    output wire [3:0]ss1_an,
    output wire [6:0]ss0_c,
    output wire [6:0] ss1_c,
    input wire [15:0] sw

);
    localparam DEPTH=HRES*VRES;
    localparam CHUNK_DEPTH=(HRES*VRES)/8;
    //ddr_whisperer signals
    logic [143:0] write_data;
    logic data_fifo_valid_in;
    logic data_fifo_ready_out;
    logic addr_fifo_valid_in;
    logic addr_fifo_ready_out;
    logic [26:0] write_addr;
    logic s_axi_arvalid;
    assign s_axi_arvalid = 1'b1;
    logic         s_axi_arready;
    logic [ 26:0] s_axi_araddr;
    logic [ 26:0] read_addr;
    logic         s_axi_rready;
    logic         s_axi_rvalid;

    logic [127:0] display_axis_tdata;
    logic         display_axis_tlast;
    logic         display_axis_tready;
    logic         display_axis_tvalid;
    logic         display_axis_prog_empty;
    logic stacker_last;


    //clking stuff
    // logic sys_rst_camera;
    // logic sys_rst_pixel;

    // logic clk_migref;
    // logic sys_rst_migref;
    logic clk_ui;
    logic sys_rst_ui;

    logic stacker_valid_out;
    // assign sys_rst_migref=sys_rst;
    // assign sys_rst_pixel=sys_rst;
    // assign sys_rst_camera=sys_rst;

    // cw_fast_clk_wiz wizard_migcam (
    //   .clk_in1(clk_100mhz),
    //   .clk_camera(clk_camera),
    //   .clk_mig(clk_migref),
    //   .clk_xc(clk_xc),
    //   .clk_100(clk_100_passthrough),
    //   .reset(0)
    // );


    // cw_hdmi_clk_wiz wizard_hdmi (
    //   .sysclk(clk_100_passthrough),
    //   .clk_pixel(clk_pixel),
    //   .clk_tmds(clk_5x),
    //   .reset(0)
    // );




    //depth ram stuff
    logic [127:0] color_piped;
    logic valid_piped;
    logic [26:0] addr_piped;
    logic [Z_WIDTH-1:0] depth_piped;
    logic valid_depth_write;
    logic [Z_WIDTH-1:0] depth;

    logic freeze;
    assign freeze=!rasterizer_rdy_out;
    freezable_pipeline#(.STAGES(2),.DATA_WIDTH(1)) valid_pipe(
        .clk_in(clk_100_passthrough),
        .freeze,
        .data(valid_in),
        .data_out(valid_piped)
    );
    freezable_pipeline#(.STAGES(2),.DATA_WIDTH(27)) addr_pip(

        .clk_in(clk_100_passthrough),
        .freeze,
        .data(addr_in),
        .data_out(addr_piped)
    );
    freezable_pipeline#(.STAGES(2),.DATA_WIDTH(128)) data_pipe(
        .clk_in(clk_100_passthrough),
        .freeze,
        .data(color_in),
        .data_out(color_piped)
    );
    freezable_pipeline#(.STAGES(2),.DATA_WIDTH(Z_WIDTH)) depth_pipe(
        .clk_in(clk_100_passthrough),
        .freeze,
        .data(depth_in),
        .data_out(depth_piped)
    );

    // assign valid_depth_write=(valid_piped && depth_piped<=depth);
    logic last_frame_chunk;
    assign last_frame_chunk = read_addr == CHUNK_DEPTH - 1;
    assign valid_depth_write=1'b1;
    xilinx_true_dual_port_read_first_1_clock_ram#(
        //IF WE GET ERROR CHANGE RAM WIDTH
        .RAM_WIDTH(Z_WIDTH),
        .RAM_DEPTH(DEPTH)
    ) depth_ram (
        //WRITING SIDE
        .addra(addr_piped), //pixels are stored using this math
        .clka(clk_100_passthrough),
        .rsta(sys_rst),
        .rstb(sys_rst),
        .wea(valid_depth_write),
        .dina(depth_piped),
        .ena(1'b1),
        .douta(), //never read from this side
        .addrb(addr_in),//transformed lookup pixel
        .web(1'b0),
        .enb(1'b1),
        .doutb(depth),
        .regcea(0),
        .regceb(!freeze)
    );
    //pixel_sstacker_time
    pixel_stacker #(
        .HRES(HRES),
        .VRES(VRES)
    ) rollled_stacker (
      .clk_in(clk_100_passthrough),
      .rst_in(sys_rst),
      .addr(addr_in),
      .strobe_in(1'b1),
      .ready_in(addr_fifo_ready_out && data_fifo_ready_out),
      .data_in(color_in),
      .valid_in(valid_in),
      .ready_out(rasterizer_rdy_out),
      .addr_out(write_addr),
      .data_out(write_data[143:16]),
      .strobe_out(write_data[15:0]),
      .valid_out(stacker_valid_out)
    );

    //ddr whisperer time
    evt_counter #(
        .MAX_COUNT(CHUNK_DEPTH)
    ) read_req_addr (
        .clk_in(clk_ui),
        .rst_in(sys_rst_ui),
        .evt_in(s_axi_arready && s_axi_arvalid),
        .count_out(s_axi_araddr)
    );

    evt_counter #(
      .MAX_COUNT(CHUNK_DEPTH)
    ) read_resp_addr (
        .clk_in(clk_ui),
        .rst_in(sys_rst_ui),
        .evt_in(s_axi_rready && s_axi_rvalid),
        .count_out(read_addr)
    );
  ddr_whisperer ddr_time (
      .ddr3_dq(ddr3_dq),
      .ddr3_dqs_n(ddr3_dqs_n),
      .ddr3_dqs_p(ddr3_dqs_p),
      .ddr3_addr(ddr3_addr),
      .ddr3_ba(ddr3_ba),
      .ddr3_ras_n(ddr3_ras_n),
      .ddr3_cas_n(ddr3_cas_n),
      .ddr3_we_n(ddr3_we_n),
      .ddr3_reset_n(ddr3_reset_n),
      .ddr3_ck_p(ddr3_ck_p),
      .ddr3_ck_n(ddr3_ck_n),
      .ddr3_cke(ddr3_cke),
      .ddr3_dm(ddr3_dm),
      .ddr3_odt(ddr3_odt),
      .frame_in(frame),

      .input_data_clk_in(clk_100_passthrough),
      .input_data_rst(sys_rst),
      .output_data_clk_in(clk_pixel),
      .output_data_rst_in(sys_rst_pixel),

      .clk_migref(clk_migref),
      .sys_rst_migref(sys_rst_migref),

      .write_data(write_data),
      .last_write(stacker_last),

      .data_fifo_valid_in (stacker_valid_out),
      .data_fifo_ready_out(data_fifo_ready_out),

      .addr_fifo_valid_in (stacker_valid_out),
      .addr_fifo_ready_out(addr_fifo_ready_out),

      .write_addr(write_addr),

      .s_axi_arvalid(s_axi_arvalid),
      .s_axi_arready(s_axi_arready),
      .s_axi_araddr (s_axi_araddr),

      .s_axi_rready(s_axi_rready),
      .s_axi_rvalid(s_axi_rvalid),

      .data_reciever_rdy  (display_axis_tready),
      .data_reciever_valid(display_axis_tvalid),
      .data_reciever_last (display_axis_tlast),
      .data_reciever_data (display_axis_tdata),

      .last_frame_chunk(last_frame_chunk),
      .clk_ui(clk_ui),
      .sys_rst_ui(sys_rst_ui)

  );
    //unstacker
    unstacker unstacker_inst (
      .clk_in(clk_pixel),
      .rst_in(sys_rst_pixel),
      .chunk_tvalid(display_axis_tvalid),
      .chunk_tready(display_axis_tready),
      .chunk_tdata(display_axis_tdata),
      .chunk_tlast(display_axis_tlast),
      .pixel_tvalid(frame_buff_tvalid),
      .pixel_tready(frame_buff_tready),
      .pixel_tdata(frame_buff_tdata),
      .pixel_tlast(frame_buff_tlast)
  );
    //seven seg time
  logic [ 6:0] ss_c;
  logic [31:0] display_thing;
  logic [12:0] county;
  evt_counter #(
      .MAX_COUNT(10000)
  ) clkkkky (
      .clk_in(clk_100_passthrough),
      .rst_in(sys_rst),
      .evt_in(1'b1),
      .count_out(county)
  );

  always_ff @(posedge clk_100_passthrough) begin
    if (county == 0) begin
      case(sw[3:0])
      0:display_thing<=s_axi_araddr;
      1:display_thing<=read_addr;
      2:display_thing<=addr_in;
      3:display_thing<=color_in;
      4:display_thing<=frame_buff_tdata;
      endcase

    end
  end

  seven_segment_controller sevensegg (
      .clk_in (clk_100_passthrough),
      .rst_in (sys_rst),
      .val_in (display_thing),
      .cat_out(ss_c),
      .an_out ({ss0_an, ss1_an})
  );
  assign ss0_c = ss_c;
  assign ss1_c = ss_c;



endmodule

