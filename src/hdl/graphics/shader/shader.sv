// assumes shader takes a ready 16-bit rgb color

module shader #(
    NUM_TRI = 2048,
    NUM_COLORS = 256
    // INTENSITY_WIDTH = 16, // NUMBER CAN NEVER BE HIGHER THAN 1
    // INTENSITY_FRAC = 14,
) (
    // fully pipelined module, no valid in and out signals
    input wire clk_in,
    input wire rst_in,
    input wire valid_in,  // did i get a valid input
    input wire ready_in,  // is the frame buffer to take on a next shader?

    input wire [$clog2(NUM_TRI)-1:0] tri_id_in,
    input wire [2:0][NORMAL_WIDTH-1:0] cam_normal_in,

    output logic [15:0] color_out,
    output logic valid_out,  // did i get a valid hcount vcount pixel with depth from rasterizer??
    output logic ready_out  // is shader busy?
);
  // breakdown
  // 2 cycles (fetch normals & colors)
  // 4 cycles (calculate light intensity)
  // 2 cycles (scale the colors with the intensity)
  // valid out depending on intensity values coming from light_intensity module

  localparam COLOR_WIDTH = 16;
  localparam COLOR_ID_WIDTH = $clog2(NUM_COLORS);
  localparam NORMAL_WIDTH = 16;
  localparam NORMAL_FRAC = 16;

  logic [COLOR_WIDTH-1:0] raw_color, praw_color;
  logic signed [2:0][NORMAL_WIDTH-1:0] raw_normal, pcam_normal;
  logic [2:0][COLOR_ID_WIDTH-1:0] color_ids;
  logic [COLOR_ID_WIDTH-1:0] color_id;
  logic signed [NORMAL_WIDTH-1:0] intensity;
  logic internal_done;
  logic pvalid_in;
  logic [1:0] accepted_valids;
  logic [1:0] cycle_count;
  logic cull_backface;

  assign color_id = color_ids[0];
  /*
	FSM:
	- IDLE: ready_out = 1, valid_out = 0
	- FETCH: ready_out = 0, valid_out = 0
	- INTENSITY_CALC: ready_out = 0, valid_out = 0
	- SCALE: ready_out = 0, valid_out = 0
	- DONE: ready_out = 1, valid_out = 1
  */


  pipeline #(
      .STAGES(2),
      .DATA_WIDTH(3 * NORMAL_WIDTH)
  ) cam_normal_pipe (
      .clk_in(clk_in),
      .data(cam_normal_in),
      .data_out(pcam_normal)
  );

  enum logic [2:0] {
    IDLE,
    FETCH,
    INTENSITY_CALC,
    SCALE,
    DONE
  } state;


  // BIG TODO: check AXI logic

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      state <= IDLE;
      internal_done <= 0;
      done <= 0;
      valid_out <= 0;
      ready_out <= 1;
    end else begin
      if (ready_in) begin
        ready_out <= 0;
      end else begin
        ready_out <= 1;
      end
      case (state)
        IDLE: begin
          // assume the valid ins are well formed
          if (!ready_in || !internal_done) begin
            if (valid_in) begin  // valid in would be processed truly if we're ready
              state <= FETCH;  // 1 more cycle until the norm is ready
            end
          end
        end
        FETCH: begin
          state <= INTENSITY_CALC; // at this point directly wired output of the pipeline should be valid
          cycle_count <= 0;
        end
        INTENSITY_CALC: begin
          state <= DONE;
        end
        // TODO: double check this
        DONE: begin
          if (ready_in) begin
            state <= IDLE;
          end
        end
        default: state <= IDLE;

      endcase
    end
  end

  xilinx_true_dual_port_read_first_1_clock_ram #(
      .DATA_WIDTH(3 * COLOR_ID_WIDTH + NORMAL_WIDTH),
      .ADDR_WIDTH($clog2(NUM_TRI)),
      .RAM_PERFORMANCE("HIGH_PERFORMANCE"),  // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
      .INIT_FILE(
      `FPATH(normal_color_lookup.mem)
      )  // Specify name/location of RAM initialization file if using one (leave blank if not)
  ) color_ids_and_norms_ram (
      .clk(clk_in),
      .we(1'b0),
      .addr(tri_id_in),
      .data_out({color_ids, raw_normal})
  );

  xilinx_true_dual_port_read_first_1_clock_ram #(
      .DATA_WIDTH(COLOR_WIDTH),
      .ADDR_WIDTH($clog2(NUM_COLORS)),
      .RAM_PERFORMANCE("HIGH_PERFORMANCE"),  // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
      .INIT_FILE(
      `FPATH(texture_palette.mem)
      )  // Specify name/location of RAM initialization file if using one (leave blank if not)
  ) color_palette_ram (
      .clk(clk_in),
      .we(1'b0),
      .addr(color_id),
      .data_out(raw_color)
  );

  pipeline #(
      .STAGES(2),
      .DATA_WIDTH(COLOR_WIDTH)
  ) raw_color_pipe (
      .clk_in(clk_in),
      .data(raw_color),
      .data_out(praw_color)
  );

  pipeline #(
      .STAGES(4),
      .DATA_WIDTH(1)
  ) valid_pipe (
      .clk_in(clk_in),
      .data(!rst_in && state == INTENSITY_CALC),
      .data_out(pvalid_in)
  );


  light_intensity #(
      .NORM_WIDTH(NORMAL_WIDTH),
      .NORM_FRAC (NORMAL_FRAC)
  ) light_intensity_inst (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .tri_norm(raw_normal),
      .cam_norm(pcam_normal),
      .light_intensity_out(intensity),
      .valid_out(cull_backface)
  );

  fixed_point_mult #(
      .A_WIDTH(5),
      .A_FRAC_BITS(0),
      .B_WIDTH(NORMAL_WIDTH),
      .B_FRAC_BITS(NORMAL_FRAC),
      .P_FRAC_BITS(0)
  ) red_scale (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .a(praw_color[15:11]),
      .b(intensity),
      .p(color_out[15:11])
  );

  fixed_point_mult #(
      .A_WIDTH(6),
      .A_FRAC_BITS(0),
      .B_WIDTH(NORMAL_WIDTH),
      .B_FRAC_BITS(NORMAL_FRAC),
      .P_FRAC_BITS(0)
  ) green_scale (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .a(praw_color[10:5]),
      .b(intensity),
      .p(color_out[10:5])
  );

  fixed_point_mult #(
      .A_WIDTH(5),
      .A_FRAC_BITS(0),
      .B_WIDTH(NORMAL_WIDTH),
      .B_FRAC_BITS(NORMAL_FRAC),
      .P_FRAC_BITS(0)
  ) blue_scale (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .a(praw_color[4:0]),
      .b(intensity),
      .p(color_out[4:0])
  );


  // pipeline the valid_out with the combination of cullbackface and pvalidin

  pipeline #(
      .STAGES(2),
      .DATA_WIDTH(1)
  ) valid_out_pipe (
      .clk_in(clk_in),
      .data(cull_backface && pvalid_in),
      .data_out(valid_out)
  );


endmodule
