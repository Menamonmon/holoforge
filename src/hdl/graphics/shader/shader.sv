// assumes shader takes a ready 16-bit rgb color

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else  /* ! SYNTHESIS */
`define FPATH(X) `"../../../data/X`"
`endif  /* ! SYNTHESIS */

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
    output logic ready_out,  // is shader busy?
    output logic short_circuit
);
  // breakdown
  // 2 cycles (fetch normals & colors)
  // 4 cycles (calculate light intensity)
  // 2 cycles (scale the colors with the intensity)
  // valid out depending on intensity values coming from light_intensity module

  localparam COLOR_WIDTH = 16;
  localparam COLOR_ID_WIDTH = $clog2(NUM_COLORS);
  localparam NORMAL_WIDTH = 16;
  localparam NORMAL_FRAC = 14;
  localparam SCALED_COLOR_WIDTH = NORMAL_WIDTH - NORMAL_FRAC + 6;


  logic [COLOR_WIDTH-1:0] raw_color, praw_color;
  logic signed [2:0][NORMAL_WIDTH-1:0] raw_normal, pcam_normal;
  logic [COLOR_WIDTH-1:0] scaled_color;
  logic signed [SCALED_COLOR_WIDTH-1:0] scaled_r;
  logic signed [SCALED_COLOR_WIDTH:0] scaled_g;
  logic signed [SCALED_COLOR_WIDTH-1:0] scaled_b;
  logic [2:0][COLOR_ID_WIDTH-1:0] color_ids;
  logic [COLOR_ID_WIDTH-1:0] color_id;
  logic signed [NORMAL_WIDTH-1:0] intensity;
  logic pvalid_in;
  logic [1:0] accepted_valids;
  logic [2:0] cycle_count;
  logic dont_cull_backface;

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
    HOLD
  } state;

  logic valid_in_activate;

  // BIG TODO: check AXI logic

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      state <= IDLE;
      valid_out <= 0;
      short_circuit <= 0;
      ready_out <= 1;
    end else begin
      case (state)
        IDLE: begin
          short_circuit <= 0;
          if (valid_in) begin
            valid_in_activate <= 1;
            state <= FETCH;
            ready_out <= 0;
          end else begin
            valid_in_activate <= 0;
            ready_out <= 1;
            valid_out <= 0;
          end
        end

        FETCH: begin
          valid_in_activate <= 0;
          state <= INTENSITY_CALC; // at this point directly wired output of the pipeline should be valid
          cycle_count <= 0;
        end

        INTENSITY_CALC: begin
          // count 6 cycles in this stage
          // if at any point dont_cull_backface is false we short circuit and take in a new input
          if (cycle_count == 6) begin
            state <= HOLD;
            color_out <= {scaled_r[4:0], scaled_g[5:0], scaled_b[4:0]};
            // color_out <= 0;
          end else begin
            if (cycle_count == 3 && !dont_cull_backface) begin
              state <= IDLE;
              ready_out <= 1;
              short_circuit <= 1;
            end else begin
              cycle_count <= cycle_count + 1;
            end
          end
        end
        // TODO: double check this
        HOLD: begin
          if (ready_in) begin
            valid_out <= 1;
            ready_out <= 1;
            state <= IDLE;
          end
        end
        default: state <= IDLE;

      endcase
    end
  end

  localparam COLOR_NORM_BROM_WIDTH = 3 * NORMAL_WIDTH + 3 * COLOR_ID_WIDTH;
  logic [COLOR_NORM_BROM_WIDTH-1:0] colornorm_brom_out;
  brom #(
      .RAM_WIDTH(COLOR_NORM_BROM_WIDTH),
      .RAM_DEPTH(NUM_TRI),
      .RAM_PERFORMANCE("HIGH_PERFORMANCE"),  // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
      .INIT_FILE(
      `FPATH(normal_color_lookup.mem)
      )  // Specify name/location of RAM initialization file if using one (leave blank if not)
  ) color_ids_and_norms_ram (
      .clka(clk_in),
      .rsta(rst_in),
      .wea(1'b0),
      .ena(1'b1),
      .regcea(1'b1),
      .addra(tri_id_in),
      .douta(colornorm_brom_out),
      .dina(0)
  );

  assign color_ids  = colornorm_brom_out[COLOR_NORM_BROM_WIDTH-1:3*NORMAL_WIDTH];
  assign raw_normal = colornorm_brom_out[3*NORMAL_WIDTH-1 : 0];

  brom #(
      .RAM_WIDTH(COLOR_WIDTH),
      .RAM_DEPTH(NUM_COLORS),
      .RAM_PERFORMANCE("HIGH_PERFORMANCE"),  // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
      .INIT_FILE(
      `FPATH(texture_palette.mem)
      )  // Specify name/location of RAM initialization file if using one (leave blank if not)
  ) color_palette_ram (
      .clka(clk_in),
      .rsta(rst_in),
      .wea(1'b0),
      .ena(1'b1),
      .regcea(1'b1),
      .addra(color_id),
      .douta(raw_color),
      .dina(0)
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
      .valid_out(dont_cull_backface)
  );

  fixed_point_mult #(
      .A_WIDTH(6),
      .A_FRAC_BITS(0),
      .B_WIDTH(NORMAL_WIDTH),
      .B_FRAC_BITS(NORMAL_FRAC),
      .P_FRAC_BITS(0)
  ) red_scale (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A({1'b0, praw_color[15:11]}),
      .B(intensity),
      .P(scaled_r)
  );

  fixed_point_mult #(
      .A_WIDTH(7),
      .A_FRAC_BITS(0),
      .B_WIDTH(NORMAL_WIDTH),
      .B_FRAC_BITS(NORMAL_FRAC),
      .P_FRAC_BITS(0)
  ) green_scale (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A({1'b0, praw_color[10:5]}),
      .B(intensity),
      .P(scaled_g)
  );

  fixed_point_mult #(
      .A_WIDTH(6),
      .A_FRAC_BITS(0),
      .B_WIDTH(NORMAL_WIDTH),
      .B_FRAC_BITS(NORMAL_FRAC),
      .P_FRAC_BITS(0)
  ) blue_scale (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A({1'b0, praw_color[4:0]}),
      .B(intensity),
      .P(scaled_b)
  );

endmodule
