`timescale 1ns / 1ps

module projection_3d_to_2d #(
    parameter NDC_WIDTH=18,
    parameter FRAC_BITS = 14, // Percision 
    parameter RENORM_WIDTH=0,
    parameter N_WIDTH = 16,  //cam width
    parameter C_WIDTH=18,
    parameter VIEWPORT_W=1,
    parameter VIEWPORT_H=1,
    parameter TWO_OVER_V_H=2/3,
    parameter TWO_OVER_V_W=2/3
)(
    input wire clk_in,
    input wire rst_in,
    input wire valid_in,

    // NDC_x,Xdc_y,Xdc_z
    input logic signed [2:0] [DOT_PROD_WIDTH-1:0] ndc,  
    output logic valid_out,
    output logic signed [R_WIDTH-1:0] x_renorm,
    output logic signed [R_WIDTH-1:0] y_renorm,
    output logic signed [DOT_PROD_WIDTH-1:0] z,
    output logic ready_out
);
    //I don't believe in magic numbers
    localparam DOT_PROD_WIDTH=(C_WIDTH+N_WIDTH-FRAC_BITS)+2;
    localparam P_CAM_WIDTH=C_WIDTH+1;
    localparam R_WIDTH=2*DOT_PROD_WIDTH+1;
    localparam VP_H_WIDTH=$clog2(VIEWPORT_H);
    localparam VP_W_WIDTH=$clog2(VIEWPORT_W);

    logic div_done;
    logic div_x_done;
    logic div_y_done;
    logic div_x_done_stored;
    logic div_y_done_stored;
    logic signed [R_WIDTH-1:0] x_div;
    logic signed [R_WIDTH-1:0] y_div;
    logic div_won_x;
    logic div_won_y;
    enum logic {
        IDLE,
        COMPUTE
    } state;
    
    logic stop_x;
    logic stop_y;


    fixed_point_div#(.WIDTH(R_WIDTH)) x_renormalizing(
        .clk_in(clk_in),
        .rst_in(rst_in || stop_x),
        .valid_in(valid_in),
        .A(ndc[0]),
        .B(ndc[2]),
        .done(div_done),
        .busy(),
        .valid_out(div_won_x),
        .zerodiv(),
        .Q(x_div),
        .overflow()
    );
    fixed_point_div#(.WIDTH(R_WIDTH)) y_renormalization(
        .clk_in(clk_in),
        .rst_in(rst_in || stop_y),
        .valid_in(valid_in),
        .A(ndc[1]),
        .B(ndc[2]),
        .done(div_done),
        .busy(),
        .valid_out(div_won_y),
        .zerodiv(),
        .Q(y_div),
        .overflow()
    );

    //boundary check
    always_ff@(posedge clk_in)begin
        //state one ur in division
        if(rst_in)begin
            state<=0;
            stop_x<=0;
            stop_y<=0;
            div_x_done_stored<=0;
            valid_out<=0;
            div_y_done_stored<=0;
            x_renorm<=0;
            y_renorm<=0;
            ready_out<=1;
        end else begin
        case(state)
            IDLE: begin  
                stop_x<=0;
                stop_y<=0;
                div_x_done_stored<=0;
                valid_out<=0;
                div_y_done_stored<=0;
                if(valid_in)begin
                    state<=COMPUTE;
                    ready_out<=0;
                end
            end
            COMPUTE: begin
                if(div_x_done)begin
                    if(div_won_x)begin
                        div_x_done_stored<=1;
                    end else begin
                        stop_y<=1;
                        state<=IDLE;
                        ready_out<=1;
                    end
                end
                if(div_y_done)begin
                    if(div_won_y)begin
                        div_y_done<=1;
                    end else begin
                        stop_x<=1;
                        state<=IDLE;
                        ready_out<=1;
                    end
                end
                if(div_x_done_stored && div_y_done_stored)begin
                    state<=IDLE;
                    if(x_div>-TWO_OVER_V_W && x_div<TWO_OVER_V_W && y_div>-TWO_OVER_V_H && y_div<TWO_OVER_V_H)begin
                            valid_out<=1;
                            x_renorm<=x_div;
                            y_renorm<=y_div;
                            z<=ndc_z;
                            ready_out<=1;
                    end
                end
            end

        endcase
        end
    end



endmodule