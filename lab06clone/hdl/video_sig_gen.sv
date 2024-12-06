

module video_sig_gen
#(
  parameter ACTIVE_H_PIXELS = 1280,
  parameter H_FRONT_PORCH = 110,
  parameter H_SYNC_WIDTH = 40,
  parameter H_BACK_PORCH = 220,
  parameter ACTIVE_LINES = 720,
  parameter V_FRONT_PORCH = 5,
  parameter V_SYNC_WIDTH = 5,
  parameter V_BACK_PORCH = 20,
  parameter FPS = 60)
(
  input wire pixel_clk_in,
  input wire rst_in,
  output logic [$clog2(ACTIVE_H_PIXELS+H_FRONT_PORCH+H_SYNC_WIDTH+H_BACK_PORCH)-1:0] hcount_out,
  output logic [$clog2(ACTIVE_LINES+V_FRONT_PORCH+V_SYNC_WIDTH+V_BACK_PORCH)-1:0] vcount_out,
  output logic vs_out, //vertical sync out
  output logic hs_out, //horizontal sync out
  output logic ad_out,
  output logic nf_out, //single cycle enable signal
  output logic [5:0] fc_out); //frame

  //wait ima try and do this with event counters
  localparam TOTAL_PIXELS = ACTIVE_H_PIXELS+H_FRONT_PORCH+H_SYNC_WIDTH+H_BACK_PORCH; //figure this out
  localparam TOTAL_LINES = ACTIVE_LINES+V_FRONT_PORCH+V_SYNC_WIDTH+V_BACK_PORCH; //figure this out


  evt_counter#(.MAX_COUNT(TOTAL_PIXELS)) pixel_counter(.clk_in(pixel_clk_in),
                                        .rst_in(rst_in),
                                        .evt_in(1'b1),
                                        .count_out(hcount_out));


  evt_counter#(.MAX_COUNT(TOTAL_LINES)) line_counter(.clk_in(pixel_clk_in),
                                        .rst_in(rst_in),
                                        .evt_in((hcount_out==TOTAL_PIXELS-1)),
                                        .count_out(vcount_out));


  evt_counter#(.MAX_COUNT(FPS)) frame_counter(.clk_in(pixel_clk_in),
                                                   .rst_in(rst_in),
                                                  .evt_in(hcount_out==ACTIVE_H_PIXELS-1 && vcount_out==ACTIVE_LINES-1),
                                                  .count_out(fc_out));
  //the rest of this can be comb logic based of the nums

  // assign ad_out=(hcount_out<ACTIVE_H_PIXELS) && (vcount_out<ACTIVE_LINES);
  // assign nf_out=(hcount_out==ACTIVE_H_PIXELS) && (vcount_out==ACTIVE_LINES);
  // assign hs_out=(hcount_out>=ACTIVE_H_PIXELS+H_FRONT_PORCH) && (hcount_out<ACTIVE_H_PIXELS+H_FRONT_PORCH+H_SYNC_WIDTH);
  // assign vs_out=(vcount_out>=ACTIVE_LINES+V_FRONT_PORCH) && (vcount_out<ACTIVE_LINES+V_FRONT_PORCH+V_SYNC_WIDTH);
  always_comb begin
      ad_out=(hcount_out<ACTIVE_H_PIXELS) && (vcount_out<ACTIVE_LINES);
      nf_out=(hcount_out==ACTIVE_H_PIXELS) && (vcount_out==ACTIVE_LINES);
      hs_out=(hcount_out>=ACTIVE_H_PIXELS+H_FRONT_PORCH) && (hcount_out<ACTIVE_H_PIXELS+H_FRONT_PORCH+H_SYNC_WIDTH);
      vs_out=(vcount_out>=ACTIVE_LINES+V_FRONT_PORCH) && (vcount_out<ACTIVE_LINES+V_FRONT_PORCH+V_SYNC_WIDTH);
  end






  //without event counters
  //logic v_writing_sig;
  // always_ff@(posedge pixel_clk_in)begin
  //   if(rst_in)begin
  //     hcount_out<=0;
  //     vcount_out<=0;
  //     vs_out<=0;
  //     hs_out<=0;
  //     ad_out<=0;
  //     nf_out<=0;
  //     fc_out<=0;
  //   //i like going from specific case down to general case so i'll do that
  //   //Vertical Line

  //   //last vertical blanking period and blanking horizontal period are over time to display 0,0 again
  //   end else if(vcount_out>=TOTAL_PIXELS-1 && hcount_out>=TOTAL_PIXELS-1)begin
  //     ad_out<=1;
  //     hcount_out<=0;
  //     vcount_out<=0;
  //   //frame switch lolz
  //   end else begin

  //     //handle horizantal logic

  //     //writing period
  //     if(hcount_out<ACTIVE_H_PIXELS-1)begin
  //       hcount_out<=hcount_out+1;
  //       ad_out<=1 && v_writing_sig;
  //     //front_porch
  //     end else if(hcount_out>=ACTIVE_H_PIXELS-1 && hcount_out<ACTIVE_H_PIXELS+H_FRONT_PORCH-1)begin
  //       hcount_out<=hcount_out+1;
  //       ad_out<=0;
  //     end else if(hcount_out>=ACTIVE_H_PIXELS+H_FRONT_PORCH-1 && hcount_out<ACTIVE_H_PIXELS+H_FRONT_PORCH+H_SYNC_WIDTH-1)begin
  //     //sync signal
  //       hcount_out<=hcount_out+1;
  //       ad_out<=0;
  //       hs_out<=1;
  //     //back porch
  //     end else if(hcount_out>=ACTIVE_H_PIXELS+H_FRONT_PORCH+H_SYNC_WIDTH-1 && hcount_out<ACTIVE_H_PIXELS-1)begin
  //       hcount_out<=hcount_out+1;
  //       ad_out<=0;
  //       hs_out<=0;
  //     end else if(hcount_out>=ACTIVE_H_PIXELS-1)begin
  //       //vertical line logic

  //       //writing
  //       if(vcount_out<=ACTIVE_LINES-1)begin
  //         vcount_out<=vcount_out+1;
  //         hcount_out<=0;
  //         v_writing_sig<=1;
  //       end else begin
  //         if(vcount_out>=ACTIVE_LINES-1 && vcount_out<ACTIVE_LINES+V_FRONT_PORCH-1)begin
  //           vcount_out<=vcount_out+1;
  //           hcount_out<=0;
  //           v_writing_sig<=0;
  //         end else if (vcount_out>=ACTIVE_LINES+V_FRONT_PORCH-1 && vcount_out<ACTIVE_LINES+V_FRONT_PORCH+V_SYNC_WIDTH-1)begin
  //           vcount_out<=vcount_out+1;
  //           v_writing_sig<=0;
  //           hcount_out<=0;
  //           hs_out<=1;
  //         end else if(vcount_out>=ACTIVE_H_PIXELS+V_FRONT_PORCH+V_SYNC_WIDTH-1) begin
  //           vcount_out<=vcount_out+1;
  //           v_writing_sig<=0;
  //           hcount_out<=0;
  //           hs_out<=0;
  //         end
  //     end
  //     end
  //   end
  // //your code here
  // end
endmodule
