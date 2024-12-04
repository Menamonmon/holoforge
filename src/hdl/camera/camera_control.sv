`timescale 1ns / 1ps
`default_nettype none

module camera_control(
    input wire clk_in,
    input wire rst_in,
    input wire signed [15:0] cos_phi_in,
    input wire signed [15:0] cos_theta_in,
    input wire signed [15:0] sin_phi_in,
    input wire signed [15:0] sin_theta_in,
    input logic [2:0] mag_int,
    input logic valid_in,
    output logic signed [2:0][17:0] pos,
    output logic signed [2:0][17:0] u,
    output logic  signed [2:0][17:0] v,
    output logic  signed [2:0][15:0] n,
    output logic signed valid_out
);

logic signed [17:0] mag;
logic signed [17:0] coscos;
logic signed [17:0] sinsin;
logic signed [17:0] sin_phicos;
logic signed [17:0] sin_thetacos;

logic signed [15:0] cos_phi;
logic signed [15:0] cos_theta;
logic signed [15:0] sin_phi;
logic signed [15:0] sin_theta;


logic piped_2;



//pipe_2
pipeline #(
      .STAGES(3),
      .DATA_WIDTH(1)
) pipe_2 (
      .clk_in(clk_in),
      .data(valid_in),
      .data_out(piped_2)
  );
//pipe_4
pipeline #(
      .STAGES(5),
      .DATA_WIDTH(1)
  ) valid_pipe (
      .clk_in(clk_in),
      .data(valid_in),
      .data_out(valid_out)
  );

always_ff@(posedge clk_in)begin
    if(rst_in)begin
        mag<=18'b0;
        cos_phi<=16'b0;
        cos_theta<=16'b0;
        sin_phi<=16'b0;
        sin_theta<=16'b0;
        u<=48'b0;
        v<=48'b0;
        n<=48'b0;

    end else begin
        if(valid_in)begin
            cos_phi<=cos_phi_in;
            sin_phi<=cos_phi_in;
            sin_theta<=sin_theta_in;
            cos_theta<=cos_theta_in;
        end 
            if(piped_2)begin
                u<={16'b0,sinsin[17:2],-sinsin[17:2]};
                v<={-sin_theta[17:2],sin_theta[17:2],-coscos[17:2]};
                n<={sin_phi[17:2],sinsin[17:2],sin_phicos[17:2]};
            end
    end
end


//sin(phi)(cos)
fixed_point_mult sinphicos(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .A(sin_phi),
    .B(cos_theta),
    .P(sin_phicos)
);
//sin(theta)cos(phi)
fixed_point_mult sinthetacos(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .A(sin_theta),
    .B(cos_phi),
    .P(sin_thetacos)
);
//cos(phi)cos(theta)
fixed_point_mult cos_cos(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .A(cos_phi),
    .B(cos_theta),
    .P(coscos)
);
//sinsin
fixed_point_mult sin_sin(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .A(sin_phi),
    .B(sin_theta),
    .P(sinsin)
);

//A
fixed_point_mult#(.A_WIDTH(18)) pos_x(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .A(mag),
    .B(sin_phicos[17:2]),
    .P(pos[0])
);


//B
fixed_point_mult#(.A_WIDTH(18)) pos_y(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .A(mag),
    .B(sinsin[17:2]),
    .P(pos[1])
);

//C
fixed_point_mult#(.A_WIDTH(18)) pos_z(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .A(mag),
    .B(sin_phi[17:2]),
    .P(pos[2])
);



endmodule

`default_nettype wire