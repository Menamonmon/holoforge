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
    input wire [15:0] color_in,
    input wire [3:0] btn,
    //out to rasterizrer/vid src
    output logic rasterizer_rdy_out,
    //out casue we're the clock wizard
    input wire clk_100_passthrough,
    input wire clk_migref,
    input wire clk_pixel,
    input wire sys_rst_migref,
    //out to TMDS HDMI STUFF
    output logic frame_buff_tvalid,
    input wire frame_buff_tready,
    output logic [15:0] frame_buff_tdata,
    output logic frame_buff_tlast,

    input wire clear_sig,
    input wire frame_override,


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
    localparam DOUBLE_DEPTH=HRES*VRES*2;
    localparam CHUNK_DEPTH=(HRES*VRES)/8;
    localparam COMPLETE_CYCLES=10;

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
    logic stacker_rdy_out;
    logic clear_sig_piped;
    logic clk_ui;
    logic sys_rst_ui;
    logic frame;
    logic stacker_valid_out;
    //depth ram stuff
    logic [127:0] color_piped;
    logic valid_piped;
    logic [26:0] addr_piped;
    logic [Z_WIDTH-1:0] depth_piped;
    logic valid_depth_write;
    logic [Z_WIDTH-1:0] depth;
    logic freeze;
    assign freeze=!stacker_rdy_out;

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
    freezable_pipeline#(.STAGES(3),.DATA_WIDTH(1)) clear_pipe(
        .clk_in(clk_100_passthrough),
        .freeze,
        .data(clear_sig),
        .data_out(clear_sig_piped)
    );

    enum logic [1:0] {
        CONSUMING,
        COMPLETE,
        CLEARING
    } clearing_state;


    logic [26:0] actual_addr_in;
    logic [127:0] actual_color_in;
    logic actual_strobe_in;
    logic actual_valid_in;


    logic actual_depth;

    logic [$clog2(DEPTH)-1:0] clear_counter;
    logic [$clog2(COMPLETE_CYCLES)-1:0] complete_counter;
    logic clear_reset;

    evt_counter #(
        .MAX_COUNT(DEPTH)
    ) clearing_counter (
        .clk_in(clk_100_passthrough),
        .rst_in(sys_rst || clear_reset),
        .evt_in(stacker_rdy_out && clearing_state==CLEARING),
        .count_out(clear_counter)
    );
    evt_counter#(
        .MAX_COUNT(COMPLETE_CYCLES)
    )completing_counter(
        .clk_in(clk_100_passthrough),
        .rst_in(sys_rst),
        .evt_in(stacker_rdy_out && clearing_state==COMPLETE),
        .count_out(complete_counter)
    );

    //Clearing State Logic
    always_ff@(posedge clk_100_passthrough)begin
        if(sys_rst)begin
            clearing_state<=CLEARING;
            frame<=0;
        end
        if(clear_sig_piped )begin
            clearing_state<=COMPLETE;
        end 
        case(clearing_state)
        COMPLETE:begin
            if(complete_counter==9 && stacker_rdy_out)begin
                clearing_state<=CLEARING;
                clear_reset<=1;
                frame<=!frame;
            end
        end
        CLEARING:begin
            clear_reset<=0;
            if(clear_counter==DEPTH-1 && stacker_rdy_out)begin
                clearing_state<=CONSUMING;
            end
        end
        endcase
    end

    //Essentialy a bypass for our clearing signal
    always_comb begin
        case (clearing_state)
            CONSUMING:begin
                actual_addr_in=addr_piped;
                actual_color_in=color_piped;
                actual_valid_in=valid_piped;
                valid_depth_write=(valid_piped && depth_piped<=depth);
                actual_depth=depth_piped;
                rasterizer_rdy_out=stacker_rdy_out;
            end
            COMPLETE:begin
                actual_addr_in=16'b0;
                actual_color_in=128'hFFFF;
                actual_valid_in=1'b1;
                valid_depth_write=1'b0;
                actual_depth=1'b0;
                rasterizer_rdy_out=1'b0;
            end
            CLEARING:begin
                actual_color_in=16'b0;
                actual_addr_in=clear_counter;
                actual_depth={Z_WIDTH{1'b1}};
                actual_valid_in=1;
                valid_depth_write=1'b1;
                rasterizer_rdy_out=1'b0;
            end
            default:begin
                actual_addr_in=16'b0;
                actual_color_in=128'hFFFF;
                actual_valid_in=1'b1;
                valid_depth_write=1'b0;
                actual_depth=1'b0;
                rasterizer_rdy_out=1'b0;
            end
        endcase
    end
    

    //bram check


    logic last_frame_chunk;
    assign last_frame_chunk = read_addr == CHUNK_DEPTH - 1;
    // assign valid_depth_write=1'b1;
    xilinx_true_dual_port_read_first_1_clock_ram#(
        //IF WE GET ERROR CHANGE RAM WIDTH
        .RAM_WIDTH(Z_WIDTH),
        .RAM_DEPTH(DEPTH)
    ) depth_ram (
        //WRITING SIDE
        .addra(actual_addr_in), //pixels are stored using this math
        .clka(clk_100_passthrough),
        .rsta(sys_rst),
        .rstb(sys_rst),
        .wea(valid_depth_write),
        .dina(actual_depth),
        .ena(1'b1),
        .douta(), //never read from this side
        .addrb(addr_in),//transformed lookup pixel
        .web(1'b0),
        .enb(1'b1),
        .doutb(depth),
        .regcea(0),
        .regceb(!freeze)
    );
    //Pixel Stacker
    pixel_stacker #(
        .HRES(HRES),
        .VRES(VRES)
    ) rollled_stacker (
      .clk_in(clk_100_passthrough),
      .rst_in(sys_rst),
      .addr(actual_addr_in),
      .strobe_in(valid_depth_write),
      .ready_in(addr_fifo_ready_out && data_fifo_ready_out),
      .data_in(actual_color_in),
      .valid_in(actual_valid_in),
      .ready_out(stacker_rdy_out),
      .addr_out(write_addr),
      .data_out(write_data[143:16]),
      .strobe_out(write_data[15:0]),
      .valid_out(stacker_valid_out)
    );

    //DDR Talking to
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
    //   frame_in(frame && !frame_override),
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
    //Data going out to frame/tmds stuff
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
  //everything from here to 400 are debugging signals(prob violate timing)
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
      0:display_thing<=stacker_rdy_out;
      1:display_thing<=clearing_state;
      2:display_thing<=frame && !frame_override;
      3:display_thing<=frame;
      4:display_thing<=clear_counter;
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

