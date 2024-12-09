// `timescale 1ns / 1ps
// module mig_write_req_generator #(
//     parameter HRES=320,
//     parameter VRES=180
//     )(
//     input wire clk_in,
//     input wire rst_in,
//     input wire [hres_width-1:0] hcount,
//     input wire [vres_width-1:0] vcount,
//     input wire [15:0] color,
//     input wire frame,
//     input wire mask_zero,
//     input wire rdy_in,//coming from out_fifo
//     input wire valid_in,//coming from rasterizer
//     //output logic
//     output logic rdy_out,//back propagating rdy_in from out_fifo
//     output logic [addr_width]addr_out,
//     output logic [7:0][15:0]data_out,
//     output logic [15:0]strobe_out,
//     output logic valid_out
// );
//     localparam addr_width=$clog2((HRES+(HRES*VRES))/2);
//     localparam hres_width=$clog2(HRES);
//     localparam vres_width=$clog2(VRES);
//     localparam addr_out_width=27;
//     localparam addr_left_over=27-(addr_width+1+1);
//     enum logic [1:0]{
//         STACKING,
//         HOLD
//     } state;
    
//     //internal var
//     logic [7:0][15:0] data;
//     logic [addr_width-1:0] addr;
//     logic [15:0] strobe;
//     logic [3:0] index;
//     logic [3:0] prev_index;
//     logic [addr_width-1:0] next_addr;
//     logic currently_stacking;
//     logic [15:0] strobe_index;

//     always_comb begin
//         addr=hcount+(HRES*vcount);
//         index=addr[2:0];
//         rdy_out=((prev_index==7 && valid_in)|| (addr!=next_addr && valid_in)) && rdy_in;
//         strobe_index=index<<1;
//     end

//     always_ff@(posedge clk_in)begin
//         if(rst_in)begin
//             data<=128'b0;
//             strobe<=16'b0;
//             prev_index<=4'b0;
//             currently_stacking<=0;
//             next_addr<=128'b0;
//             valid_out<=0;
//             data_out<=128'b0;
//             state<=STACKING;
//             addr_out<=0;
//             strobe_out<=0;
//         end else begin if(valid_in)begin

//             if(valid_out && rdy_in)begin
//                 valid_out<=0;
//             end

//             if(state<=STACKING)begin
//                 rdy_out<=1;
//             end

//             case(state)
//                 STACKING:begin
//                     if(!currently_stacking)begin
//                         //if we're not currently accumlaating

//                         //addressing
//                         next_addr<=addr+1;
                        
//                         //allign the strobe
//                         case(addr[2:0])
//                             0:begin
//                                 strobe[1:0]<=2'b11;  
//                             end
//                             1:begin
//                                 strobe[2:0]<={2'b11,2'b0};
//                             end
//                             2:begin
//                                 strobe[2:0]<={2'b11,4'b0};
//                             end
//                             3:begin
//                                 strobe[3:0]<={2'b11,6'b0};
//                             end
//                             4:begin
//                                 strobe[4:0]<={2'b11,8'b0};
//                             end
//                             5:begin
//                                 strobe[5:0]<={2'b11,10'b0};
//                             end
//                             6:begin
//                                 strobe[6:0]<={2'b11,12'b0};
//                             end
//                             7:begin
//                                 strobe[7:0]<={2'b11,14'b0};
//                             end
//                         endcase

//                         data[addr[2:0]]<=color;
//                         prev_index<=index;
                        
//                         //handle state transition properly if we're at index 7
//                         if(index==7)begin
//                             valid_out<=1;
//                             data_out<={color,data[6:0]};
//                             strobe_out<={{2{mask_zero}},14'b0};
//                             if(!rdy_in)begin
//                                 state<=HOLD;
//                             end
//                         end else begin
//                             // valid_out<=0;
//                             currently_stacking<=1;
//                         end

//                     end else begin 
//                         //we're stacking
//                         if(addr==next_addr)begin
//                             //if we're alligned
//                             next_addr<=addr+1;
//                             data[index]<=color;
//                             strobe[strobe_index]<= (mask_zero)? 1'b0:1'b1;
//                             strobe[strobe_index+1]<= (mask_zero)? 1'b0:1'b1;
//                             prev_index<=index;
//                             if(index==7)begin
//                                 data_out<={color,data[6:0]};
//                                 valid_out<=1;
//                                 strobe_out<={{2{!mask_zero}},strobe[13:0]};
//                                 currently_stacking<=0;
//                                 if(!rdy_in)begin
//                                     state<=HOLD;
//                                 end
//                             end else begin
//                                 // valid_out<=0;    
//                             end
                            
//                         end else begin 
//                             //if we're not alligned

//                             //regardless if we're ready or not we have to annull
//                             //the current code and set valid_out high
//                             valid_out<=1;

//                             //annulling prev data
//                             case(prev_index)
//                                 //if we're anulling and we're currently 
//                                 0:begin
//                                     data_out<={112'b0,data[0]};
//                                     strobe_out<={14'b0,{2{strobe[0]}}};
//                                 end
//                                 1:begin
//                                     data_out <= {96'b0, data[1:0]};
//                                     strobe_out <= {12'b0, {2{strobe[1]}}, {2{strobe[0]}}};
//                                 end
//                                 2: begin
//                                     data_out <= {80'b0, data[2:0]};
//                                     strobe_out <= {10'b0, {2{strobe[2]}}, {2{strobe[1]}}, {2{strobe[0]}}};
//                                 end
//                                 3: begin
//                                     data_out <= {64'b0, data[3:0]};
//                                     strobe_out <= {8'b0, {2{strobe[3]}}, {2{strobe[2]}}, {2{strobe[1]}}, {2{strobe[0]}}};
//                                 end
//                                 4: begin
//                                     data_out <= {48'b0, data[4:0]};
//                                     strobe_out <= {6'b0, {2{strobe[4]}}, {2{strobe[3]}}, {2{strobe[2]}}, {2{strobe[1]}}, {2{strobe[0]}}};
//                                 end
//                                 5: begin
//                                     data_out <= {32'b0, data[5:0]};
//                                     strobe_out <= {4'b0, {2{strobe[5]}}, {2{strobe[4]}}, {2{strobe[3]}}, {2{strobe[2]}}, {2{strobe[1]}}, {2{strobe[0]}}};
//                                 end
//                                 6: begin
//                                     data_out <= {16'b0, data[6:0]};
//                                     strobe_out <= {2'b0, {2{strobe[6]}}, {2{strobe[5]}}, {2{strobe[4]}}, {2{strobe[3]}}, {2{strobe[2]}}, {2{strobe[1]}}, {2{strobe[0]}}};
//                                 end
//                                 7: begin
//                                     data_out<=data;
//                                     strobe_pout<=strobe_out;
//                                 end

                    
//                                 //if our prev_index is 7 we should be done
//                             endcase


//                             data<=128'b0;
//                             data[addr[2:0]]<=color;
//                             //allinging cur data
//                             data[addr[2:0]]<=color;
//                             prev_index<=index;
//                             next_addr<=addr+1;
//                             case(addr[2:0])
//                                 0:begin
//                                     data[0]<=color;
//                                     strobe[1:0]<=2'b11;  
//                                 end
//                                 1:begin
//                                     data[1:0]<={color,16'b0};
//                                     strobe[3:0]<={2'b11,2'b0};
//                                 end
//                                 2:begin
//                                     data[2:0]<={color,32'b0};
//                                     strobe[5:0]<={2'b11,4'b0};
//                                 end
//                                 3:begin
//                                     data[3:0]<={color,48'b0};
//                                     strobe[7:0]<={2'b11,6'b0};
//                                 end
//                                 4:begin
//                                     data[4:0]<={color,64'b0};
//                                     strobe[9:0]<={2'b11,8'b0};
//                                 end
//                                 5:begin
//                                     data[5:0]<={color,80'b0};
//                                     strobe[11:0]<={2'b11,10'b0};
//                                 end
//                                 6:begin
//                                     data[6:0]<={color,96'b0};
//                                     strobe[13:0]<={2'b11,12'b0};
//                                 end
//                                 7:begin
//                                     data_out<={color,112'b0};
//                                     strobe[15:0]<={2'b11,14'b0};
                                    
//                                 end
//                             endcase
                            
//                             //state transition in this case
//                             if(!rdy_in)begin
//                                 state<=HOLD;
//                             end 
//                         end
//                     end
//                 end

//                 HOLD:begin
//                     if(rdy_in)begin
//                         valid_out<=0;
//                         state<=STACKING;
//                         if(prev_index==7)begin
//                             currently_stacking<=0;
//                         end else begin
//                             currently_stacking<=1;  
//                         end
//                     end
//                 end
//     endcase 
//     end
//     end
//     end

// endmodule