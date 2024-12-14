// this module holds a valid_out signal until a ready_in comes in (ABIDES BY AXI)
module pre_proc_shader #(
    parameter C_WIDTH = 18,  // cam center width
    parameter P_WIDTH = 16,  // 3D pos width
    parameter V_WIDTH = 16,  // normal vector width
    parameter ZWIDTH = 16,
    parameter FRAC_BITS = 14,  // Percision 
    parameter VH_OVER_TWO_WIDTH = 10,
    parameter VW_OVER_TWO_WIDTH = 10,

    parameter VH_OVER_TWO = 0,
    parameter VW_OVER_TWO = 0,
    parameter VIEWPORT_H_POSITION_WIDTH = 18,
    parameter VIEWPORT_W_POSITION_WIDTH = 20,
    parameter NUM_TRI = 2048,
    parameter NUM_COLORS = 256
) (
    input wire clk_in,
    input wire rst_in,

    input wire valid_in,
    input wire ready_in,

    // 3D Point P
    input wire [$clog2(NUM_TRI)-1:0] tri_id_in,
    input wire signed [2:0][2:0][P_WIDTH-1:0] P,  // [P_x, P_y, P_z]
    // Camera position C
    input wire signed [2:0][C_WIDTH-1:0] C,  // [C_x, C_y, C_z]
    // Camera vectors u, v, n
    input wire signed [2:0][V_WIDTH-1:0] u,  // [u_x, u_y, u_z]
    input wire signed [2:0][V_WIDTH-1:0] v,  // [v_x, v_y, v_z]
    input wire signed [2:0][V_WIDTH-1:0] n,  // [n_x, n_y, n_z]
    // Outputs
    output logic valid_out,
    output logic ready_out,
    output logic signed [2:0][VIEWPORT_H_POSITION_WIDTH-1:0] viewport_x_positions_out,
    output logic signed [2:0][VIEWPORT_W_POSITION_WIDTH-1:0] viewport_y_positions_out,
    output logic [2:0][ZWIDTH-1:0] z_depth_out,  // max depth is 2 * camera radius
    output logic [COLOR_WIDTH-1:0] color_out
);

  localparam COLOR_WIDTH = 16;
  logic signed [2:0][VIEWPORT_H_POSITION_WIDTH-1:0] viewport_x_positions_out_temp;
  logic signed [2:0][VIEWPORT_W_POSITION_WIDTH-1:0] viewport_y_positions_out_temp;
  logic [2:0][ZWIDTH-1:0] z_depth_out_temp;  // max depth is 2 * camera radius
  logic [COLOR_WIDTH-1:0] color_out_temp;

  logic vertex_pre_proc_done, shader_done;
  logic vertex_pre_proc_valid_out, shader_valid_out;
  logic vertex_pre_proc_ready_out, shader_ready_out;
  logic vertex_pre_proc_short_circuit, shader_short_circuit;
  logic vertex_pre_proc_control, shader_control;

  logic [ZWIDTH-1:0] z1, z2, z3;
  assign z1 = z_depth_out[0];
  assign z2 = z_depth_out[1];
  assign z3 = z_depth_out[2];


  vertex_pre_proc #(
      .C_WIDTH(C_WIDTH),
      .P_WIDTH(P_WIDTH),
      .V_WIDTH(V_WIDTH),
      .FRAC_BITS(FRAC_BITS),
      .ZWIDTH(ZWIDTH),
      .VH_OVER_TWO_WIDTH(VH_OVER_TWO_WIDTH),
      .VW_OVER_TWO_WIDTH(VW_OVER_TWO_WIDTH),
      .VIEWPORT_H_POSITION_WIDTH(VIEWPORT_H_POSITION_WIDTH),
      .VIEWPORT_W_POSITION_WIDTH(VIEWPORT_W_POSITION_WIDTH),
      .VH_OVER_TWO(VH_OVER_TWO),
      .VW_OVER_TWO(VW_OVER_TWO)
  ) vertex_pre_proc_inst (
      .clk_in(clk_in),
      .rst_in(rst_in | shader_short_circuit),
      .valid_in(vertex_pre_proc_control),
      .ready_in(1),
      .P(P),
      .C(C),
      .u(u),
      .v(v),
      .n(n),
      .valid_out(vertex_pre_proc_valid_out),
      .ready_out(vertex_pre_proc_ready_out),
      .short_circuit(vertex_pre_proc_short_circuit),
      .viewport_x_position(viewport_x_positions_out_temp),
      .viewport_y_position(viewport_y_positions_out_temp),
      .z_depth(z_depth_out_temp)
  );


  shader #(
      .NUM_TRI(NUM_TRI),
      .NUM_COLORS(NUM_COLORS)
  ) shader_inst (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .valid_in(shader_control),
      .ready_in(1),
      .tri_id_in(tri_id_in),
      .cam_normal_in(n),
      .color_out(color_out_temp),
      .valid_out(shader_valid_out),
      .short_circuit(shader_short_circuit),
      .ready_out(shader_ready_out)
  );

  //   assign shader_valid_out = 1'b1;
  //   assign shader_short_circuit = 1'b0;

  enum logic [1:0] {
    IDLE,
    PROCESSING,
    HOLD
  } state;

  assign ready_out = state == IDLE;

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      state <= IDLE;
      valid_out <= 0;
      vertex_pre_proc_control <= 0;
      shader_control <= 0;
      //   ready_out <= 1;
    end else begin
      case (state)
        IDLE: begin
          valid_out <= 0;
          vertex_pre_proc_done <= 0;
          shader_done <= 0;
          if (valid_in) begin
            state <= PROCESSING;
            // ready_out <= 0;
            vertex_pre_proc_control <= 1;
            shader_control <= 1;
          end
        end

        PROCESSING: begin
          vertex_pre_proc_control <= 0;
          shader_control <= 0;

          if (vertex_pre_proc_short_circuit) begin
            viewport_x_positions_out <= 0;
            viewport_y_positions_out <= 0;
            z_depth_out <= 0;
            state <= IDLE;
            // ready_out <= 1;
          end

          if (shader_short_circuit) begin
            viewport_x_positions_out <= 0;
            viewport_y_positions_out <= 0;
            z_depth_out <= 0;
            state <= IDLE;
            // ready_out <= 1;
          end

          // flash the outputs into the fifo as soon as they're ready
          if (vertex_pre_proc_valid_out && !vertex_pre_proc_done) begin
            vertex_pre_proc_done <= 1;
            viewport_x_positions_out <= viewport_x_positions_out_temp;
            viewport_y_positions_out <= viewport_y_positions_out_temp;
            z_depth_out <= z_depth_out_temp;
          end

          if (shader_valid_out && !shader_done) begin
            shader_done <= 1;
            color_out   <= color_out_temp;
          end

          if (vertex_pre_proc_done && shader_done) begin
            vertex_pre_proc_done <= 0;
            shader_done <= 0;
            // ready_out <= 1;
            state <= HOLD;
            valid_out <= 1;
          end
        end

        HOLD: begin
          if (ready_in) begin
            // ready_out <= 1;
            valid_out <= 0;
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule
