module vertex_pre_proc #(
    parameter C_WIDTH = 18,  // cam center width
    parameter P_WIDTH = 16,  // 3D pos width
    parameter V_WIDTH = 16,  // normal vector width
    parameter ZWIDTH = 16,
    parameter FRAC_BITS = 14,  // Percision 
    parameter VH_OVER_TWO_WIDTH = 10,
    parameter VW_OVER_TWO_WIDTH = 10,

    parameter signed [VH_OVER_TWO_WIDTH-1:0] VH_OVER_TWO = 0,
    parameter signed [VW_OVER_TWO_WIDTH-1:0] VW_OVER_TWO = 0,
    parameter VIEWPORT_H_POSITION_WIDTH = 18,
    parameter VIEWPORT_W_POSITION_WIDTH = 20
) (
    input wire clk_in,
    input wire rst_in,

    input wire valid_in,
    input wire ready_in,

    // 3D Point P
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
    output logic short_circuit,
    output logic signed [2:0][VIEWPORT_H_POSITION_WIDTH-1:0] viewport_x_position,
    output logic signed [2:0][VIEWPORT_W_POSITION_WIDTH-1:0] viewport_y_position,
    output logic [2:0][ZWIDTH-1:0] z_depth  // max depth is 2 * camera radius
);

  logic [2:0] short_circuits;
  logic [2:0] ready_outs;
  logic [2:0] valid_outs;

  logic short_circuit_any;

  assign short_circuit_any = short_circuits[0] | short_circuits[1] | short_circuits[2];
  assign short_circuit = short_circuit_any;
  assign ready_out = ready_outs[0] & ready_outs[1] & ready_outs[2];
  assign valid_out = valid_outs[0] & valid_outs[1] & valid_outs[2]; // assumes a valid output would take exactly the same number of cycles across all 3 vertices
  project_vertex_to_viewport #(
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
  ) project_first_vertex (
      .clk_in(clk_in),
      .rst_in(rst_in | short_circuit_any),
      .valid_in(valid_in),
      .ready_in(ready_in),
      .P(P[0]),
      .C(C),
      .u(u),
      .v(v),
      .n(n),
      .valid_out(valid_outs[0]),
      .ready_out(ready_outs[0]),
      .short_circuit(short_circuits[0]),
      .viewport_x_position(viewport_x_position[0]),
      .viewport_y_position(viewport_y_position[0]),
      .z_depth(z_depth[0])
  );

  project_vertex_to_viewport #(
      .C_WIDTH(C_WIDTH),
      .P_WIDTH(P_WIDTH),
      .V_WIDTH(V_WIDTH),
      .ZWIDTH(ZWIDTH),
      .FRAC_BITS(FRAC_BITS),
      .VH_OVER_TWO_WIDTH(VH_OVER_TWO_WIDTH),
      .VW_OVER_TWO_WIDTH(VW_OVER_TWO_WIDTH),
      .VIEWPORT_H_POSITION_WIDTH(VIEWPORT_H_POSITION_WIDTH),
      .VIEWPORT_W_POSITION_WIDTH(VIEWPORT_W_POSITION_WIDTH),
      .VH_OVER_TWO(VH_OVER_TWO),
      .VW_OVER_TWO(VW_OVER_TWO)
  ) project_second_vertex (
      .clk_in(clk_in),
      .rst_in(rst_in | short_circuit_any),
      .valid_in(valid_in),
      .ready_in(ready_in),
      .P(P[1]),
      .C(C),
      .u(u),
      .v(v),
      .n(n),
      .valid_out(valid_outs[1]),
      .ready_out(ready_outs[1]),
      .short_circuit(short_circuits[1]),
      .viewport_x_position(viewport_x_position[1]),
      .viewport_y_position(viewport_y_position[1]),
      .z_depth(z_depth[1])
  );

  project_vertex_to_viewport #(
      .C_WIDTH(C_WIDTH),
      .P_WIDTH(P_WIDTH),
      .V_WIDTH(V_WIDTH),
      .ZWIDTH(ZWIDTH),
      .FRAC_BITS(FRAC_BITS),
      .VH_OVER_TWO_WIDTH(VH_OVER_TWO_WIDTH),
      .VW_OVER_TWO_WIDTH(VW_OVER_TWO_WIDTH),
      .VIEWPORT_H_POSITION_WIDTH(VIEWPORT_H_POSITION_WIDTH),
      .VIEWPORT_W_POSITION_WIDTH(VIEWPORT_W_POSITION_WIDTH),
      .VH_OVER_TWO(VH_OVER_TWO),
      .VW_OVER_TWO(VW_OVER_TWO)
  ) project_third_vertex (
      .clk_in(clk_in),
      .rst_in(rst_in | short_circuit_any),
      .valid_in(valid_in),
      .ready_in(ready_in),
      .P(P[2]),
      .C(C),
      .u(u),
      .v(v),
      .n(n),
      .valid_out(valid_outs[2]),
      .ready_out(ready_outs[2]),
      .short_circuit(short_circuits[2]),
      .viewport_x_position(viewport_x_position[2]),
      .viewport_y_position(viewport_y_position[2]),
      .z_depth(z_depth[2])
  );



endmodule
