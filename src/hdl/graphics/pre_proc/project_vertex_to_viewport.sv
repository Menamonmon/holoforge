`timescale 1ns / 1ps

module project_vertex_to_viewport #(
    parameter C_WIDTH = 18,  // cam center width
    parameter P_WIDTH = 16,  // 3D pos width
    parameter V_WIDTH = 16,  // normal vector width
    parameter FRAC_BITS = 14,  // Percision 
    parameter TWO_OVER_V_H = 0,
    parameter TWO_OVER_V_W = 0,
    parameter VIEWPORT_WIDTH = 16,
    parameter VIEWPORT_H_POSITION_WIDTH = 18,
    parameter VIEWPORT_W_POSITION_WIDTH = 20
) (
    input wire clk_in,
    input wire rst_in,
    input wire valid_in,
    input wire ready_in,

    // 3D Point P
    input wire signed [2:0][P_WIDTH-1:0] P,  // [P_x, P_y, P_z]
    // Camera position C
    input wire signed [2:0][C_WIDTH-1:0] C,  // [C_x, C_y, C_z]
    // Camera vectors u, v, n
    input wire signed [2:0][V_WIDTH-1:0] u,  // [u_x, u_y, u_z]
    input wire signed [2:0][V_WIDTH-1:0] v,  // [v_x, v_y, v_z]
    input wire signed [2:0][V_WIDTH-1:0] n,  // [n_x, n_y, n_z]
    // Outputs
    output logic valid_out,
    output logic ready_out,
    output logic signed [VIEWPORT_H_POSITION_WIDTH-1:0] viewport_x_position,
    output logic signed [VIEWPORT_W_POSITION_WIDTH-1:0] viewport_y_position,
    output logic signed [C_WIDTH:0] z_depth  // max depth is 2 * camera radius
    // output logic signed [DOT_PROD_WIDTH-1:0] NDC_y,
    // output logic signed [DOT_PROD_WIDTH-1:0] NDC_x,
    // output logic signed [DOT_PROD_WIDTH-1:0] NDC_z
);
  //I don't believe in magic numbers
  localparam P_SUB_CAM_WIDTH = C_WIDTH + 1;
  localparam DOT_PROD_WIDTH = (P_SUB_CAM_WIDTH + V_WIDTH - FRAC_BITS) + 2;
  localparam DOT_PROD_FRAC = FRAC_BITS;
  localparam RENORM_WIDTH = 2 * DOT_PROD_FRAC + 1;

  logic signed [P_SUB_CAM_WIDTH-1:0] P_cam_x;
  logic signed [P_SUB_CAM_WIDTH-1:0] P_cam_y;
  logic signed [P_SUB_CAM_WIDTH-1:0] P_cam_z;

  assign P_cam_x = $signed(P[0]) - $signed(C[0]);
  assign P_cam_y = $signed(P[1]) - $signed(C[1]);
  assign P_cam_z = $signed(P[2]) - $signed(C[2]);

  logic valid_in_activate;
  logic valid_in_piped;

  pipeline #(
      .STAGES(3),
      .DATA_WIDTH(1)
  ) valid_pipe (
      .clk_in(clk_in),
      .data(valid_in_activate),
      .data_out(valid_in_piped)
  );

  //dot product and neccesary piping of z 
  logic signed [DOT_PROD_WIDTH-1:0] p_dot_x;
  logic signed [DOT_PROD_WIDTH-1:0] p_dot_y;
  logic signed [DOT_PROD_WIDTH-1:0] p_dot_z;
  logic signed [RENORM_WIDTH-1:0] x_renorm, x_renorm_completed;
  logic signed [RENORM_WIDTH-1:0] y_renorm, y_renorm_completed;
  //   logic signed [VIEWPORT_H_POSITION_WIDTH-1:0] viewport_x_position;
  //   logic signed [VIEWPORT_W_POSITION_WIDTH-1:0] viewport_y_position;

  logic x_renorm_done, y_renorm_done, x_renorm_valid, y_renorm_valid;

  assign viewport_x_position = x_renorm_completed[VIEWPORT_H_POSITION_WIDTH-1:0]; // truncate the division extra bits (by this point the value should be in the range of the viewport width)
  assign viewport_y_position = y_renorm_completed[VIEWPORT_W_POSITION_WIDTH-1:0]; // truncate the division extra bits (by this point the value should be in the range of the viewport height)
  assign z_depth = p_dot_z[C_WIDTH:0];  // a depth can never by further than the camera radius

  fixed_point_fast_dot #(
      .A_WIDTH(P_SUB_CAM_WIDTH),
      .B_WIDTH(V_WIDTH),
      .P_FRAC_BITS(DOT_PROD_FRAC)
  ) dp_u (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A({P_cam_z, P_cam_y, P_cam_x}),
      .B(u),
      .D(p_dot_x)
  );

  fixed_point_fast_dot #(
      .A_WIDTH(P_SUB_CAM_WIDTH),
      .B_WIDTH(V_WIDTH),
      .P_FRAC_BITS(DOT_PROD_FRAC)
  ) dp_v (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A({P_cam_z, P_cam_y, P_cam_x}),
      .B(v),
      .D(p_dot_y)
  );

  fixed_point_fast_dot #(
      .A_WIDTH(P_SUB_CAM_WIDTH),
      .B_WIDTH(V_WIDTH),
      .P_FRAC_BITS(DOT_PROD_FRAC)
  ) dp_n (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A({P_cam_z, P_cam_y, P_cam_x}),
      .B(n),
      .D(p_dot_z)
  );

  fixed_point_div #(
      .WIDTH(RENORM_WIDTH)
  ) x_renormalization (
      .clk_in(clk_in),
      .rst_in(rst_in || stop_x),
      .valid_in(valid_in_piped),
      .A(p_dot_x),
      .B(p_dot_z),
      .done(x_renorm_done),
      .busy(),
      .valid_out(x_renorm_valid),
      .zerodiv(),
      .Q(x_renorm),
      .overflow()
  );

  fixed_point_div #(
      .WIDTH(RENORM_WIDTH)
  ) y_renormalization (
      .clk_in(clk_in),
      .rst_in(rst_in || stop_y),
      .valid_in(valid_in_piped),
      .A(p_dot_y),
      .B(p_dot_z),
      .done(y_renorm_done),
      .busy(),
      .valid_out(y_renorm_valid),
      .zerodiv(),
      .Q(y_renorm),
      .overflow()
  );

  /*
	FSM:
	- IDLE: wait for a valid in signal (if valid in, put it in the pipeline to start computation)
	- COMPUTE: (accounts for dot products and divisions) (if x and y are done AND VALID move to HOLD)
	- HOLD: stay in this state until ready in is true and set valid out as soon as ready_in is true and transition back to IDLE
	*/
  enum logic [1:0] {
    IDLE,
    COMPUTE,
    HOLD
  } state;

  logic x_renorm_complete, y_renorm_complete;

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      valid_out <= 0;
      ready_out <= 1;
      state <= IDLE;
    end else begin
      case (state)
        IDLE: begin
          if (valid_in) begin
            valid_in_activate <= 1;
            state <= COMPUTE;
            x_renorm_complete <= 0;
            y_renorm_complete <= 0;
            ready_out <= 0;  // can't proecess two conesucutive inputs at the same time
          end else begin
            ready_out <= 1;
            valid_out <= 0;
          end
        end

        COMPUTE: begin
          if (x_renorm_done) begin
            x_renorm_completed <= x_renorm;
            x_renorm_complete  <= 1;
          end

          if (y_renorm_done) begin
            y_renorm_completed <= y_renorm;
            y_renorm_complete  <= 1;
          end

          if (x_renorm_complete && y_renorm_complete) begin
            state <= HOLD;
          end
        end

        HOLD: begin
          if (ready_in) begin
            valid_out <= 1;
            ready_out <= 1;  // ready out stays at invalid as long as the pipeline is not empty
            state <= IDLE;
          end
        end
      endcase
    end
  end
endmodule
