module video_sig_gen #(
    parameter ACTIVE_H_PIXELS = 1280,
    parameter H_FRONT_PORCH = 110,
    parameter H_SYNC_WIDTH = 40,
    parameter H_BACK_PORCH = 220,
    parameter ACTIVE_LINES = 720,
    parameter V_FRONT_PORCH = 5,
    parameter V_SYNC_WIDTH = 5,
    parameter V_BACK_PORCH = 20,
    parameter FPS = 60
) (
    input wire pixel_clk_in,
    input wire rst_in,
    output logic [$clog2(LINE_WIDTH)-1:0] hcount_out,
    output logic [$clog2(FRAME_HEIGHT)-1:0] vcount_out,
    output logic vs_out,  //vertical sync out
    output logic hs_out,  //horizontal sync out
    output logic ad_out,
    output logic nf_out,  //single cycle enable signal
    output logic [5:0] fc_out
);  //frame

  localparam LINE_WIDTH = ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH + H_BACK_PORCH;
  localparam FRAME_HEIGHT = ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH + V_BACK_PORCH;

  // horizontal pixel counter
  evt_counter #(
      .MAX_COUNT(LINE_WIDTH)
  ) hcount_counter (
      .clk_in(pixel_clk_in),
      .rst_in(rst_in),
      .evt_in(1'b1),
      .count_out(hcount_out)
  );


  // vertical line counter
  evt_counter #(
      .MAX_COUNT(FRAME_HEIGHT)
  ) vcount_counter (
      .clk_in(pixel_clk_in),
      .rst_in(rst_in),
      .evt_in(hcount_out == LINE_WIDTH - 1),
      .count_out(vcount_out)
  );

  // frame counter
  evt_counter #(
      .MAX_COUNT(FPS)
  ) frame_counter (
      .clk_in(pixel_clk_in),
      .rst_in(rst_in),
      .evt_in(nf_out),
      .count_out(fc_out)
  );

  // active display
  assign ad_out = hcount_out < ACTIVE_H_PIXELS && vcount_out < ACTIVE_LINES;
  assign nf_out = hcount_out == ACTIVE_H_PIXELS && vcount_out == ACTIVE_LINES;
  assign hs_out = hcount_out >= ACTIVE_H_PIXELS + H_FRONT_PORCH && hcount_out < ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH;
  assign vs_out = vcount_out >= ACTIVE_LINES + V_FRONT_PORCH && vcount_out < ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH;

endmodule
