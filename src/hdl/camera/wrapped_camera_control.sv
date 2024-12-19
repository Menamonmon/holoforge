`timescale 1ns / 1ps `default_nettype none

module wrapped_camera_control #(
    parameter FRAC = 14,
    parameter SINCOS_WIDTH = 16,
    parameter MAG_WIDTH = 18,
    parameter POS_WIDTH = 18,
    parameter NORM_WIDTH = 16,
    parameter HRES = 320,
    parameter VRES = 180
) (
    input wire clk_in,
    input wire rst_in,
    input wire [HWIDTH-1:0] x_in,
    input wire [VWIDTH-1:0] y_in,
    input wire [AWIDTH-1:0] area_in,

    input wire valid_in,

    output logic signed [2:0][POS_WIDTH-1:0] C_out,
    output logic signed [2:0][SINCOS_WIDTH-1:0] u_out,
    output logic signed [2:0][SINCOS_WIDTH-1:0] v_out,
    output logic signed [2:0][SINCOS_WIDTH-1:0] n_out,
    output logic signed valid_out
);
  localparam HWIDTH = $clog2(HRES);
  localparam VWIDTH = $clog2(VRES);
  localparam AWIDTH = $clog2(HRES * VRES);

  logic signed [SINCOS_WIDTH-1:0] cos_phi_in;
  logic signed [SINCOS_WIDTH-1:0] cos_theta_in;
  logic signed [SINCOS_WIDTH-1:0] sin_phi_in;
  logic signed [SINCOS_WIDTH-1:0] sin_theta_in;

  logic signed [POS_WIDTH-1:0] mag, mag_in;

  // 2 cycle delay
  sincos_lookup_table #(
      .FILENAME("../../data/theta_sin_table.mem"),
      .ENTRIES (HRES)
  ) sin_theta_table (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .x(x_in),
      .val_out(sin_theta_in)
  );

  sincos_lookup_table #(
      .FILENAME("../../data/theta_cos_table.mem"),
      .ENTRIES (HRES)
  ) cos_theta_table (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .x(x_in),
      .val_out(cos_theta_in)
  );

  sincos_lookup_table #(
      .FILENAME("../../data/phi_sin_table.mem"),
      .ENTRIES (VRES)
  ) sin_phi_table (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .x(y_in),
      .val_out(sin_phi_in)
  );

  sincos_lookup_table #(
      .FILENAME("../../data/phi_cos_table.mem"),
      .ENTRIES (VRES)
  ) cos_phi_table (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .x(y_in),
      .val_out(cos_phi_in)
  );

  logic pvalid_in;

  pipeline #(
      .STAGES(2),
      .DATA_WIDTH(1)
  ) valid_in_pipe (
      .clk_in(clk_in),
      .data(valid_in),
      .data_out(pvalid_in)
  );

  pipeline #(
      .STAGES(2),
      .DATA_WIDTH(POS_WIDTH)
  ) mag_pipe (
      .clk_in(clk_in),
      .data(mag),
      .data_out(mag_in)
  );


  camera_control cam_control (
      .clk_in,
      .rst_in,
      .cos_phi_in,
      .cos_theta_in,
      .sin_phi_in,
      .sin_theta_in,
      .mag_in,
      .valid_in(pvalid_in),
      .pos_out (C_out),
      .u_out,
      .v_out,
      .n_out,
      .valid_out
  );
endmodule

`default_nettype wire
