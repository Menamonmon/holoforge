`timescale 1ns / 1ps
module mig_write_req_generator #(
    parameter HRES=64,
    parameter VRES=36
    )(
    input wire clk_in,
    input wire rst_in,
    input wire [hres_width-1:0] hcount,
    input wire [vres_width-1:0] vcount,
    input wire [15:0] color,
    input wire frame,
    input wire mask_zero,
    input wire rdy_in,//coming from out_fifo
    input wire valid_in,//coming from rasterizer
    //output logic
    output logic rdy_out,//back propagating rdy_in from out_fifo
    output logic [addr_width]addr_out,
    output logic [7:0][15:0]data_out,
    output logic [15:0]strobe_out,
    output logic valid_out
);
    localparam addr_width=$clog2((HRES+(HRES*VRES))/2);
    localparam hres_width=$clog2(HRES);
    localparam vres_width=$clog2(VRES);
    localparam addr_out_width=27;
    localparam addr_left_over=27-(addr_width+1+1);

    enum logic [1:0]{
        IDLE,
        STACKING,
        HOLD
    } state;

    enum logic {
        NEXT_IDLE,
        NEXT_STACKING
    }   prev_state;
    
    //internal var
    logic [7:0][15:0] data;
    logic [addr_width-1:0] addr;
    logic [15:0] strobe;
    logic [3:0] index;
    logic [3:0] prev_index;
    logic [addr_width-1:0] next_addr;
    logic currently_stacking;
    logic [3:0] strobe_index;
    logic will_be_ready;
    logic [7:0] emergen_c_data;
    logic [25:0] emergen_c_add;
    logic next_state;
    logic [addr_width:0] prev_addr;


    always_comb begin
        addr=hcount+(HRES*vcount);
        index=addr[2:0];
        strobe_index=index<<1;
        //need to be done
        will_be_ready=(!valid_out || (rdy_in));
        rdy_out=will_be_ready;
    end

    always_ff@(posedge clk_in)begin
        if (rst_in)begin
            data<=128'b0;
            strobe<=16'b0;
            prev_index<=4'b0;
            currently_stacking<=0;
            next_addr<=128'b0;
            valid_out<=0;
            data_out<=128'b0;
            state<=STACKING;
            addr_out<=0;
            strobe_out<=0;
            prev_state<=0;
        end else begin
        if(rdy_in && valid_out)begin
            valid_out<=0;
        end
        case(state)
        IDLE:begin
            if(valid_in && rdy_out)begin
                next_addr<=addr+1;
                prev_index<=index;
                data[addr[2:0]]<=color;
                prev_addr<=addr;
                case(index)
                    0:begin
                        strobe[1:0]<=2'b11;  
                    end
                    1:begin
                        strobe[3:0]<={2'b11,2'b0};
                    end
                    2:begin
                        strobe[5:0]<={2'b11,4'b0};
                    end
                    3:begin
                        strobe[7:0]<={2'b11,6'b0};
                    end
                    4:begin
                        strobe[9:0]<={2'b11,8'b0};
                    end
                    5:begin
                        strobe[11:0]<={2'b11,10'b0};
                    end
                    6:begin
                        strobe[13:0]<={2'b11,12'b0};
                    end
                    7:begin
                        strobe[15:0]<={2'b11,14'b0};
                    end
                endcase
                if(index==7)begin
                    valid_out<=1;
                    data_out<={color,data[6:0]};
                    strobe_out<={{2{!mask_zero}},14'b0};
                    addr_out<={frame,addr<<4};
                    if(will_be_ready)begin
                        state<=IDLE;
                    end else begin
                        state<=HOLD;
                        next_state<=NEXT_IDLE;
                    end 
                end else begin
                    state<=STACKING;
                end 

            end
        end

        STACKING:begin
            if(valid_in && rdy_out)begin
                if(addr==next_addr)begin
                    next_addr<=addr+1;
                    data[index]<=color;
                    strobe[strobe_index]<=(mask_zero)? 1'b0:1'b1;
                    strobe[strobe_index+1]<= (mask_zero)? 1'b0:1'b1;
                    prev_index<=index;
                    prev_addr<=addr;
                    if(index==7)begin
                        data_out<={color,data[6:0]};
                        valid_out<=1;
                        strobe_out<={{2{!mask_zero}},strobe[13:0]};
                        addr_out<={frame,addr<<4};
                        if(will_be_ready)begin
                            state<=IDLE;
                        end else begin
                            state<=HOLD;
                            next_state<=NEXT_STACKING;
                        end
                    end
                end else begin
                    //we're missalligned
                    if(!will_be_ready)begin
                        state<=HOLD;
                        next_state=NEXT_STACKING;
                    end
                    valid_out<=1;
                    addr_out<={frame,prev_addr<<4};
                    prev_addr<=addr;
                    case(prev_index)
                            0:begin
                                data_out<={112'b0,data[0]};
                                strobe_out<={14'b0,strobe[1:0]};
                            end
                            1:begin
                                data_out <= {96'b0, data[1:0]};
                                strobe_out<={12'b0,strobe[3:0]};
                            end
                            2: begin
                                data_out <= {80'b0, data[2:0]};
                                strobe_out <= {10'b0, strobe[5:0]};
                            end
                            3: begin
                                data_out <= {64'b0, data[3:0]};
                                strobe_out <= {8'b0, strobe[7:0]};
                            end
                            4: begin
                                data_out <= {48'b0, data[4:0]};
                                strobe_out <= {6'b0,strobe[9:0]}; 
                            end
                            5: begin
                                data_out <= {32'b0, data[5:0]};
                                strobe_out <= {4'b0, strobe[11:0]};
                            end
                            6: begin
                                data_out <= {16'b0, data[6:0]};
                                strobe_out <= {2'b0, strobe[13:0]};
                            end
                            7:begin
                                data_out<=data;
                                strobe_out<=strobe;
                            end
                    endcase
                    //we have new data in need to allign it
                    prev_index<=index;
                    next_addr<=addr+1;
                    case(addr[2:0])
                        0:begin
                            data[0]<=color;
                            strobe[1:0]<=2'b11;  
                        end
                        1:begin
                            data[1:0]<={color,16'b0};
                            strobe[3:0]<={2'b11,2'b0};
                        end
                        2:begin
                            data[2:0]<={color,32'b0};
                            strobe[5:0]<={2'b11,4'b0};
                        end
                        3:begin
                            data[3:0]<={color,48'b0};
                            strobe[7:0]<={2'b11,6'b0};
                        end
                        4:begin
                            data[4:0]<={color,64'b0};
                            strobe[9:0]<={2'b11,8'b0};
                        end
                        5:begin
                            data[5:0]<={color,80'b0};
                            strobe[11:0]<={2'b11,10'b0};
                        end
                        6:begin
                            data[6:0]<={color,96'b0};
                            strobe[13:0]<={2'b11,12'b0};
                        end
                        7:begin
                            data<={color,112'b0};
                            strobe[15:0]<={2'b11,14'b0};
                        end
                    endcase
                end
            end
        end

        HOLD:begin
            if(rdy_in)begin
                if(next_state==NEXT_STACKING)begin
                    state<=STACKING;
                end else begin
                    state<=IDLE;
                end
            end 
        end
        endcase
        //other logic
 
        end
    end
endmodule