`timescale 1ns / 1ps

module projection_3d_to_2d #(
    parameter NDC_WIDTH=18,
    parameter FRAC_BITS = 14, // Percision 
    parameter RENORM_WIDTH=0,
    parameter VIEWPORT_W=1,
    parameter VIEWPORT_H=1,
    parameter TWO_OVER_VIEWPORT_H=2,
    parameter TWO_OVER_VIEWPORT_W=2
)(
    input wire clk_in,
    input wire rst_in,
    input wire valid_in,

    // NDC_x,Xdc_y,Xdc_z
    input wire signed [V_WIDTH:0] ndc_x,  
    input wire signed [V_WIDTH:0] ndc_y,  
    input wire signed [V_WIDTH:0] ndc_z,  
    // Outputs
    output reg valid_out,
    output reg signed [31:0] x_renorm,
    output reg signed [31:0] y_renorm
    output logic signed [16:0] z
);
    //I don't believe in magic numbers
    localparam DOT_PROD_WIDTH=(C_WIDTH+P_WIDTH-FRAC_BITS)+2;
    localparam P_CAM_WIDTH=C_WIDTH+1;
    localparam R_WIDTH=2*V_WIDTH+1;

    logic div_done;
    logic div_won;
    logic div_won_y;
    logic div_won_x;
    logic signed [R_WIDTH-1:0] x_div;
    logic signed [R_WIDTH-1:0] y_div;
    assign div_won=div_won_y && div_won_x;

    fixed_point_div#(.WIDTH(V_WIDTH)) x_renorm(
        .clk_in(clk),
        .rst_in(rst),
        .valid_in(valid_in),
        .A(ndc_x),
        .B(ndc_z),
        .done(div_done),
        .busy(),
        .valid_out(div_won_x),
        .zerodiv(),
        .Q(x_div)
        .overflow
    );
    fixed_point_div#(.WIDTH(V_WIDTH)) y_renorm(
        .clk_in(clk),
        .rst_in(rst),
        .valid_in(valid_in),
        .A(ndc_y),
        .B(ndc_z),
        .done(div_done),
        .busy(),
        .valid_out(div_won_y),
        .zerodiv(),
        .Q(y_div)
        .overflow
    );
    //boundary check
    always_ff@(posedge clk_in)begin
        if(div_won) begin
            if(x_div>-TWO_OVER_V_W && x_div<TWO_OVER_V_W && y_div>-TWO_OVER_V_H && y_div<TWO_OVER_V_H)begin
                valid_out<=1;
                x_renorm<=x_div;
                y__renorm<=y_div;
                z<=ndc_z;

        end
        end else begin
            valid_out<=0;
        end


    end



endmodule