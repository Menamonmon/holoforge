`timescale 1ns / 1ps

module v_to_ndc #(
    parameter C_WIDTH = 18,  //cam width
    parameter P_WIDTH = 16,  //pos width
    parameter V_WIDTH = 16,  //vector width
    parameter FRAC_BITS = 14,  // Percision 
    parameter TWO_OVER_V_H = 0,
    parameter TWO_OVER_V_W = 0,
    parameter VIEWPORT_WIDTH = 16
) (
    input wire clk,
    input wire rst,
    input wire valid_in,

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
    output logic signed [DOT_PROD_WIDTH-1:0] NDC_y,
    output logic signed [DOT_PROD_WIDTH-1:0] NDC_x,
    output logic signed [DOT_PROD_WIDTH-1:0] NDC_z
);
  //I don't believe in magic numbers
  localparam P_CAM_WIDTH = C_WIDTH + 1;
  localparam DOT_PROD_WIDTH = (P_CAM_WIDTH + V_WIDTH - FRAC_BITS) + 2;
//   localparam NDC_WIDTH = DOT_PROD_WIDTH + VIEWPORT_WIDTH - FRAC_BITS;

  //P_cam = P - C
  //wait this is sick i can just set it like this just need to make sure it obeys the pipeline

  logic signed [P_CAM_WIDTH-1:0] P_cam_x;
  logic signed [P_CAM_WIDTH-1:0] P_cam_y;
  logic signed [P_CAM_WIDTH-1:0] P_cam_z;

  assign P_cam_x = $signed(P[0]) - $signed(C[0]);
  assign P_cam_y = $signed(P[1]) - $signed(C[1]);
  assign P_cam_z = $signed(P[2]) - $signed(C[2]);

  logic valid_in_piped;

  pipeline #(
      .STAGES(3),
      .DATA_WIDTH(1)
  ) valid_pipe (
      .clk_in(clk),
      .data(valid_in),
      .data_out(valid_in_piped)
  );

  //dot product and neccesary piping of z 
  logic signed [DOT_PROD_WIDTH-1:0] p_dot_x;
  logic signed [DOT_PROD_WIDTH-1:0] p_dot_y;
  logic signed [DOT_PROD_WIDTH-1:0] p_dot_z;

  fixed_point_fast_dot #(
      .A_WIDTH(P_CAM_WIDTH),
      .B_WIDTH(V_WIDTH)
  ) dp_u (
      .clk_in(clk),
      .rst_in(rst),
      .A({P_cam_z, P_cam_y, P_cam_x}),
      .B(u),
      .D(p_dot_x)
  );

  fixed_point_fast_dot #(
      .A_WIDTH(P_CAM_WIDTH),
      .B_WIDTH(V_WIDTH)
  ) dp_v (
      .clk_in(clk),
      .rst_in(rst),
      .A({P_cam_z, P_cam_y, P_cam_x}),
      .B(v),
      .D(p_dot_y)
  );

  fixed_point_fast_dot #(
      .A_WIDTH(P_CAM_WIDTH),
      .B_WIDTH(V_WIDTH)
  ) dp_n (
      .clk_in(clk),
      .rst_in(rst),
      .A({P_cam_z, P_cam_y, P_cam_x}),
      .B(n),
      .D(p_dot_z)
  );

  always_ff @(posedge clk) begin
    if (rst) begin
      NDC_x <= 0;
      NDC_y <= 0;
      NDC_z <= 0;
      valid_out <= 1;

    end
    if (valid_in_piped) begin
      //only connect the wire if valid in was piped right
      NDC_x <= p_dot_x;
      NDC_y <= p_dot_y;
      NDC_z <= p_dot_z;
      valid_out <= 1;
    end else begin
      valid_out <= 0;
    end
  end
endmodule
