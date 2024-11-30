`timescale 1ns / 1ps
module mig_write_req_generator #(
    parameter HRES=320,
    parameter VRES=180
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
    //one +1 for read write buffer, another +1 for left shit by 1 to represent bytes, not 16 bits
    localparam addr_left_over=27-(addr_width+1+1);
    enum logic [1:0] {
        STACKING,
        HOLD
    }state;

    logic [7:0][15:0] data;
    logic [addr_width-1:0] addr;
    logic [15:0] strobe;
    //buffer for hold state
    logic currently_stacking;
    logic [addr_width-1:0] next_addr;
    logic [127:0]zero_padding;
    logic [3:0] index;
    logic meow;

    always_comb begin
        addr=hcount+(hcount*vcount);
        rdy_out=(index==7 || addr!=next_addr) && !rdy_in;
    end
    always_ff@(posedge clk_in)begin
        if (rst_in)begin 
            data<=128'b0;
            addr<=0;
            strobe<=15'b0;
            currently_stacking<=0;
            next_addr<=128'b0;
            index<=4'b0;
            valid_out<=0;
            data_out<=128'b0;
            state<=STACKING;
            meow<=0;
        end else begin
        if(valid_in)begin
            case(state)
            STACKING: begin
                if(!currently_stacking)begin
                    //first value checks
                    //check if its alligend
                    //move to currently stacking aftering beggining the proc
                    index<=addr[2:0]+1;
                    next_addr<=addr+1;
                    
                    //copy pasting the code cause its just better
                    currently_stacking<=1;
                    //alligning the strobe
                    case(addr[2:0])
                        0:begin
                            strobe[0]<=1;  
                        end
                        1:begin
                            strobe[1:0]<={1'b1,1'b0};
                        end
                        2:begin
                            strobe[2:0]<={1'b1,2'b0};
                        end
                        3:begin
                            strobe[3:0]<={1'b1,3'b0};
                        end
                        4:begin
                            strobe[4:0]<={1'b1,4'b0};
                        end
                        5:begin
                            strobe[5:0]<={1'b1,5'b0};
                        end
                        6:begin
                            strobe[6:0]<={1'b1,6'b0};
                        end
                        7:begin
                            strobe[7:0]<={1'b1,7'b0};
                        end
                    endcase

                end
                if(currently_stacking)begin
                    //we're currently proccessining a new stack
                    if(addr==next_addr)begin
                        //this means we're correctly alligned
                        index<=index+1;
                        next_addr<=addr+1;
                        data[index]<=color;
                        meow<=1;
                        strobe[index]<=(mask_zero) ?1'b0:1'b1;
                        if(index==7)begin
                            data_out<={color,data[6:0]};
                            valid_out<=1;
                            if(!rdy_in)begin
                                state<=HOLD;
                            end

                        end
                    end

                    end else begin
                        //this means we aren't alligned 
                        valid_out<=1;
                        if(rdy_in)begin 
                            //if fifo good send out our data start proccessining it
                            index<=addr[2:0]+1;
                            next_addr<=addr+1;
                            //sending out data
                            //figuring out data_out
                            case(index)
                            0:begin
                                //this shouldn't happpen cause we wouldn't be currently_stacking
                            end
                            1:begin
                                data_out<={112'b0,data[0]};
                                strobe_out<={14'b0,{2{strobe[0]}}};
                            end
                            2:begin
                                data_out <= {96'b0, data[1:0]};
                                strobe_out <= {12'b0, {2{strobe[1]}}, {2{strobe[0]}}};
                            end
                            3: begin
                                data_out <= {80'b0, data[2:0]};
                                strobe_out <= {10'b0, {2{strobe[2]}}, {2{strobe[1]}}, {2{strobe[0]}}};
                            end
                            4: begin
                                data_out <= {64'b0, data[3:0]};
                                strobe_out <= {8'b0, {2{strobe[3]}}, {2{strobe[2]}}, {2{strobe[1]}}, {2{strobe[0]}}};
                            end
                            5: begin
                                data_out <= {48'b0, data[4:0]};
                                strobe_out <= {6'b0, {2{strobe[4]}}, {2{strobe[3]}}, {2{strobe[2]}}, {2{strobe[1]}}, {2{strobe[0]}}};
                            end
                            6: begin
                                data_out <= {32'b0, data[5:0]};
                                strobe_out <= {4'b0, {2{strobe[5]}}, {2{strobe[4]}}, {2{strobe[3]}}, {2{strobe[2]}}, {2{strobe[1]}}, {2{strobe[0]}}};
                            end
                            7: begin
                                data_out <= {16'b0, data[6:0]};
                                strobe_out <= {2'b0, {2{strobe[6]}}, {2{strobe[5]}}, {2{strobe[4]}}, {2{strobe[3]}}, {2{strobe[2]}}, {2{strobe[1]}}, {2{strobe[0]}}};
                            end
                            endcase

                            //alligning bit(padding it properly)
                            data[addr[2:0]]<=color;

                            case(addr[2:0])
                            0:begin
                              strobe[0]<=1;  
                            end
                            1:begin
                              strobe[1:0]<={1'b1,1'b0};
                            end
                            2:begin
                              strobe[2:0]<={1'b1,2'b0};
                            end
                            3:begin
                              strobe[3:0]<={1'b1,3'b0};
                            end
                            4:begin
                              strobe[4:0]<={1'b1,4'b0};
                            end
                            5:begin
                              strobe[5:0]<={1'b1,5'b0};
                            end
                            6:begin
                              strobe[6:0]<={1'b1,6'b0};
                            end
                            7:begin
                              strobe[7:0]<={1'b1,7'b0};
                            end
                            endcase
                            //im praying to god the dynamic conctation works
                        end else begin
                            //if fifo is full, and our data is misalligned we have to go into hold to be safe(giving ourselves a buffer)
                            state<=HOLD;
                        end
                        
                    end

                end
            HOLD: begin 
                valid_out<=1;
                if(rdy_in)begin
                    state<=STACKING;
                    if(index==7)begin
                        currently_stacking<=0;
                        //we're not currently stacking something

                    end else begin
                        //we are currently stacking something
                        currently_stacking<=1;

                    end
                end
            end
            endcase
        end
        end
    end
endmodule