`timescale 1ns / 1ps
`default_nettype none

module pixel_reconstruct
	#(
	 parameter HCOUNT_WIDTH = 11,
	 parameter VCOUNT_WIDTH = 10
	 )
	(
	 input wire 										 clk_in,
	 input wire 										 rst_in,
	 input wire 										 camera_pclk_in,
	 input wire 										 camera_hs_in,
	 input wire 										 camera_vs_in,
	 input wire [7:0] 							 camera_data_in,
	 output logic 									 pixel_valid_out,
	 output logic [HCOUNT_WIDTH-1:0] pixel_hcount_out,
	 output logic [VCOUNT_WIDTH-1:0] pixel_vcount_out,
	 output logic [15:0] 						 pixel_data_out
	 );

	 // your code here! and here's a handful of logics that you may find helpful to utilize.
	 
	 // previous value of PCLK
	 logic 													 pclk_prev;

	 // can be assigned combinationally:
	 //  true when pclk transitions from 0 to 1
	 logic 													 camera_sample_valid;
	 assign camera_sample_valid = camera_pclk_in && !pclk_prev; // TODO: fix this assign
	 
	 // previous value of camera data, from last valid sample!
	 // should NOT update on every cycle of clk_in, only
	 // when samples are valid.
	 logic 													 last_sampled_hs;
	 logic [7:0] 										 last_sampled_data;

	 // flag indicating whether the last byte has been transmitted or not.
	 logic 													 half_pixel_ready;
	 logic last_sample_hsync;
	 logic last_sample_vsync;
	 logic start;

	 always_ff@(posedge clk_in) begin
			if (rst_in) begin
				pclk_prev<='0;
				last_sample_hsync<='0;
				last_sample_vsync<='0;
				start<=1;
				last_sampled_data<='0;
				half_pixel_ready<=0;
				pixel_hcount_out<='0;
				pixel_vcount_out<='0;
			end else begin
				pclk_prev<=camera_pclk_in;
				pixel_valid_out<=0;
				if(camera_sample_valid) begin
					last_sample_hsync<=camera_hs_in;
					last_sample_vsync<=camera_vs_in;
					half_pixel_ready<='0;
					//a lot of things to handle so lets comment out the different things to tr:ack
					//if v sync is on a rising edge
					if(camera_vs_in)begin
						if(camera_hs_in)begin
							if(half_pixel_ready)begin
								half_pixel_ready<=0;
								pixel_valid_out<=1;
								pixel_data_out<={last_sampled_data,camera_data_in};
								if(start)begin
									start<=0;
									pixel_hcount_out<=0;
								end	else begin
									pixel_hcount_out<=pixel_hcount_out+1;
								end
							end else begin
								half_pixel_ready<=1;
								pixel_valid_out<=0;
								last_sampled_data<=camera_data_in;
							end
						end 
							//covering my ass
						if(!camera_hs_in && last_sample_hsync)begin
							half_pixel_ready<='0;
							pixel_vcount_out<=pixel_vcount_out+1;
							pixel_hcount_out<='0;
							start<=1;
						end
					end
					if(!camera_vs_in && last_sample_vsync)begin
						pixel_vcount_out<='0;
						pixel_hcount_out<='0;
						half_pixel_ready<=0;
						//I REFUSE FOR THIS VARIABLE TO SCREW ME OVER I CAN SEE
						//IM SEEING THE FUTURE
						//I SEE THE FUTURE WHERE I SPENT HOURS DEBUGGING CAUSE THIS DAMN 
						//VARIABLE FAILS A EDGE CASE, I SEE ALL THE TIME LINES
						//AND THIS IS THE ONE FOR MY VICTORY
						pixel_valid_out<=0;
						start<=1;
					end 

				 end
				 
			end
	 end

endmodule

`default_nettype wire
