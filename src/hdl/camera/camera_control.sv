`timescale 1ns / 1ps `default_nettype none

module camera_control #(
    parameter FRAC = 14,
    parameter SINCOS_WIDTH = 16,
    parameter MAG_WIDTH = 18,
    parameter POS_WIDTH = 18,
    parameter NORM_WIDTH = 16
) (
    input wire clk_in,
    input wire rst_in,
    input wire signed [SINCOS_WIDTH-1:0] cos_phi_in,
    input wire signed [SINCOS_WIDTH-1:0] cos_theta_in,
    input wire signed [SINCOS_WIDTH-1:0] sin_phi_in,
    input wire signed [SINCOS_WIDTH-1:0] sin_theta_in,
    input wire [POS_WIDTH-1:0] mag_in,
    input wire valid_in,
    output logic signed [2:0][POS_WIDTH-1:0] pos_out,
    output logic signed [2:0][SINCOS_WIDTH-1:0] u_out,
    output logic signed [2:0][SINCOS_WIDTH-1:0] v_out,
    output logic signed [2:0][SINCOS_WIDTH-1:0] n_out,
    output logic signed valid_out
);



  logic signed [POS_WIDTH-1:0] mag;
  logic signed [SINCOS_WIDTH-1:0] cos_phi_cos_theta;
  logic signed [SINCOS_WIDTH-1:0] sin_phi_sin_theta;
  logic signed [SINCOS_WIDTH-1:0] sin_phi_cos_theta;
  logic signed [SINCOS_WIDTH-1:0] sin_theta_cos_phi;

  logic signed [SINCOS_WIDTH-1:0] cos_phi;
  logic signed [SINCOS_WIDTH-1:0] cos_theta;
  logic signed [SINCOS_WIDTH-1:0] sin_phi;
  logic signed [SINCOS_WIDTH-1:0] sin_theta;
  logic signed [2:0][SINCOS_WIDTH-1:0] u;
  logic signed [2:0][SINCOS_WIDTH-1:0] v;
  logic signed [2:0][SINCOS_WIDTH-1:0] n;
  logic signed [2:0][POS_WIDTH-1:0] pos;


  logic piped_2;
  logic pvalid_in;



  //pipe_2
  pipeline #(
      .STAGES(2),
      .DATA_WIDTH(1)
  ) pipe_2 (
      .clk_in(clk_in),
      .data(valid_in),
      .data_out(piped_2)
  );
  //pipe_4
  pipeline #(
      .STAGES(4),
      .DATA_WIDTH(1)
  ) valid_pipe (
      .clk_in(clk_in),
      .data(valid_in),
      .data_out(pvalid_in)
  );

  assign cos_phi = valid_in ? cos_phi_in : cos_phi;
  assign cos_theta = valid_in ? cos_theta_in : cos_theta;
  assign sin_phi = valid_in ? sin_phi_in : sin_phi;
  assign sin_theta = valid_in ? sin_theta_in : sin_theta;
  assign mag = valid_in ? mag_in : mag;


  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      u <= 0;
      v <= 0;
      n <= 0;
      valid_out <= 0;
    end else begin
      if (piped_2) begin
        // pipeline to sync with camera pos calc (valid_out will be set based on both of these and the pipelining of valid in)
        u[0] <= -sin_phi;
        u[1] <= cos_phi;
        u[2] <= 0;

        v[0] <= cos_phi_cos_theta;
        v[1] <= sin_phi_cos_theta;
        v[2] <= -sin_theta;

        n[0] <= -sin_theta_cos_phi;
        n[1] <= -sin_phi_sin_theta;
        n[2] <= -cos_theta;
      end

      if (pvalid_in) begin
        valid_out <= 1;
        u_out <= u;
        v_out <= v;
        n_out <= n;
        pos_out <= pos;
      end
    end
  end

  //sin(phi)cos(theta)
  fixed_point_mult #(
      .A_WIDTH(SINCOS_WIDTH),
      .A_FRAC_BITS(FRAC),
      .B_WIDTH(SINCOS_WIDTH),
      .B_FRAC_BITS(FRAC),
      .P_FRAC_BITS(FRAC)
  ) sinphicos (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A(sin_phi),
      .B(cos_theta),
      .P(sin_phi_cos_theta)
  );

  //sin(theta)cos(phi)
  fixed_point_mult #(
      .A_WIDTH(SINCOS_WIDTH),
      .A_FRAC_BITS(FRAC),
      .B_WIDTH(SINCOS_WIDTH),
      .B_FRAC_BITS(FRAC),
      .P_FRAC_BITS(FRAC)
  ) sinthetacos (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A(sin_theta),
      .B(cos_phi),
      .P(sin_theta_cos_phi)
  );

  //cos(phi)cos(theta)
  fixed_point_mult cos_cos (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A(cos_phi),
      .B(cos_theta),
      .P(cos_phi_cos_theta)
  );

  //sin(phi)sin(theta)
  fixed_point_mult sin_sin (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A(sin_phi),
      .B(sin_theta),
      .P(sin_phi_sin_theta)
  );

  //A
  fixed_point_mult #(
      .A_WIDTH(POS_WIDTH),
      .A_FRAC_BITS(FRAC),
      .B_WIDTH(SINCOS_WIDTH),
      .B_FRAC_BITS(FRAC),
      .P_FRAC_BITS(FRAC)
  ) pos_x (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A(mag),
      .B(sin_theta_cos_phi),
      .P(pos[0])
  );


  //B
  fixed_point_mult #(
      .A_WIDTH(POS_WIDTH),
      .A_FRAC_BITS(FRAC),
      .B_WIDTH(SINCOS_WIDTH),
      .B_FRAC_BITS(FRAC),
      .P_FRAC_BITS(FRAC)
  ) pos_y (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A(mag),
      .B(sin_phi_sin_theta),
      .P(pos[1])
  );

  //C
  fixed_point_mult #(
      .A_WIDTH(POS_WIDTH),
      .A_FRAC_BITS(FRAC),
      .B_WIDTH(SINCOS_WIDTH),
      .B_FRAC_BITS(FRAC),
      .P_FRAC_BITS(FRAC)
  ) pos_z (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A(mag),
      .B(cos_theta),
      .P(pos[2])
  );



endmodule

`default_nettype wire
