module pixel_reconstruct #(
    parameter HCOUNT_WIDTH = 11,
    parameter VCOUNT_WIDTH = 10
) (
    input wire clk_in,
    input wire rst_in,
    input wire camera_pclk_in,
    input wire camera_hs_in,
    input wire camera_vs_in,
    input wire [7:0] camera_data_in,
    output logic pixel_valid_out,
    output logic [HCOUNT_WIDTH-1:0] pixel_hcount_out,
    output logic [VCOUNT_WIDTH-1:0] pixel_vcount_out,
    output logic [15:0] pixel_data_out
);

  // your code here! and here's a handful of logics that you may find helpful to utilize.

  // previous value of PCLK
  logic pclk_prev;

  // can be assigned combinationally:
  //  true when pclk transitions from 0 to 1
  logic camera_sample_valid;
  assign camera_sample_valid = !pclk_prev && camera_pclk_in;  // TODO: fix this assign

  // previous value of camera data, from last valid sample!
  // should NOT update on every cycle of clk_in, only
  // when samples are valid.
  logic last_sampled_hs;
  logic [7:0] last_sampled_data;

  // flag indicating whether the last byte has been transmitted or not.
  logic parity;

  evt_counter #(
      .MAX_COUNT(2 ** HCOUNT_WIDTH)
  ) hcount (
      .clk_in(clk_in),
      .rst_in(rst_in || !camera_hs_in),
      .evt_in(pixel_valid_out),
      .count_out(pixel_hcount_out)
  );

  evt_counter #(
      .MAX_COUNT(2 ** VCOUNT_WIDTH)
  ) vcount (
      .clk_in(clk_in),
      .rst_in(rst_in || !camera_vs_in),
      .evt_in(last_sampled_hs && !camera_hs_in),
      .count_out(pixel_vcount_out)
  );


  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      pclk_prev <= 0;
      last_sampled_hs <= 0;
      last_sampled_data <= 0;
      parity <= 0;
      pixel_valid_out <= 0;
      // pixel_hcount_out <= 0;
      // pixel_vcount_out <= 0;
      pixel_data_out <= 0;
    end else begin
      pclk_prev <= camera_pclk_in;
      last_sampled_hs <= camera_hs_in;

      if (camera_sample_valid) begin
        if (camera_hs_in && camera_vs_in) begin
          // load depending on the parity
          if (parity) begin
            pixel_data_out[7:0] <= camera_data_in;
            pixel_valid_out <= 1;
          end else begin
            pixel_data_out[15:8] <= camera_data_in;
            pixel_valid_out <= 0;
          end
          parity <= ~parity;
        end else begin
          pixel_valid_out <= 0;
          parity <= 0;
        end
      end else begin
        pixel_valid_out <= 0;
      end

    end
  end

endmodule

`default_nettype wire



// `default_nettype none // prevents system from inferring an undeclared logic (good practice)
// module pixel_reconstruct #(HCOUNT_WIDTH = 100, VCOUNT_WIDTH = 100) (
// 	//  input wire clk_in,
// 	 input wire camera_pclk_in,
// 	 input wire camera_hs_in,
// 	 input wire camera_vs_in,
// 	 input wire [7:0] camera_data_in,
// 	 output logic pixel_valid_out,
// 	 output logic [HCOUNT_WIDTH-1:0] pixel_hcount_out,
// 	 output logic [VCOUNT_WIDTH-1:0] pixel_vcount_out,
// 	 output logic [15:0] pixel_data_out
//   );

// 	logic parity;

// 	evt_counter #(.MAX_COUNT(2**HCOUNT_WIDTH)) hcount (
// 		.clk_in(camera_pclk_in),
// 		.rst_in(!camera_hs_in),
// 		.evt_in(pixel_valid_out),
// 		.count_out(pixel_hcount_out)
// 	);

// 	evt_counter #(.MAX_COUNT(2**VCOUNT_WIDTH)) vcount (
// 		.clk_in(camera_pclk_in),
// 		.rst_in(!camera_vs_in),
// 		.evt_in(pixel_valid_out && (pixel_hcount_out == HCOUNT_WIDTH - 1)),
// 		.count_out(pixel_vcount_out)
// 	);

// 	always_ff @(posedge camera_pclk_in) begin

// 		if (camera_hs_in && camera_vs_in) begin
// 			// load depending on the parity
// 			if (parity) begin
// 				pixel_data_out[7:0] <= camera_data_in;
// 				pixel_valid_out <= 1;
// 			end else begin
// 				pixel_data_out[15:8] <= camera_data_in;
// 				pixel_valid_out <= 0;
// 			end
// 			parity <= ~parity;
// 		end else begin
// 			pixel_valid_out <= 0;
// 			parity <= 0;
// 		end
// 	end

// endmodule
// `default_nettype wire


// module evt_counter #(MAX_COUNT = 1000) (
// 	input wire clk_in,
// 	input wire rst_in,
// 	input wire evt_in,
// 	output logic [$clog2(MAX_COUNT)-1:0] count_out
// );

// always_ff @(posedge clk_in) begin
// 	if (rst_in) begin
// 		count_out <= 0;
// 	end else if (evt_in) begin
// 		if (count_out == MAX_COUNT - 1) begin
// 			count_out <= 0; // Wrap around
// 		end else begin
// 			count_out <= count_out + 1;
// 		end
// 	end
// end

// endmodule


// module evt_counter #(MAX_COUNT = 1000) (
//     input wire clk_in,
//     input wire rst_in,
//     input wire evt_in,
//     output logic [$clog2(MAX_COUNT)-1:0] count_out
// );

// always_ff @(posedge clk_in) begin
//     if (rst_in) begin
//         count_out <= 0;
//     end else if (evt_in) begin
//         if (count_out == MAX_COUNT - 1) begin
//             count_out <= 0; // Wrap around
//         end else begin
//             count_out <= count_out + 1;
//         end
//     end
// end

// endmodule
