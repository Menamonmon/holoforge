`default_nettype none
module center_of_mass (
                         input wire clk_in,
                         input wire rst_in,
                         input wire [10:0] x_in,
                         input wire [9:0]  y_in,
                         input wire valid_in,
                         input wire tabulate_in,
                         output logic [10:0] x_out,
                         output logic [9:0] y_out,
                         output logic valid_out);
	 // your code here
    logic [1:0] state;
    logic [31:0] x_sum;
    logic [31:0] y_sum;
    logic [31:0] counting;
    logic divide_time;
    logic x_done;
    logic y_done;
    logic x_busy;
    logic y_busy;
    logic [10:0] x_final_val;
    logic [9:0] y_final_val;
    logic x_hold_done;
    logic y_hold_done;

    logic x_error;
    logic y_error;
    logic x_rem;
    logic y_rem;
//		
    
    divider Div_x(
                    .clk_in(clk_in),
                    .rst_in(rst_in),
                    .data_valid_in(divide_time),
                    .dividend_in(x_sum),
                    .divisor_in(counting),
                    .quotient_out(x_final_val),
                    .remainder_out(x_rem),
                    .data_valid_out(x_done),
                    .error_out(x_error),
                    .busy_out(x_busy));
    divider Div_y(
                    .clk_in(clk_in),
                    .rst_in(rst_in),
                    .data_valid_in(divide_time),
                    .dividend_in(y_sum),
                    .divisor_in(counting),
                    .quotient_out(y_final_val),
                    .remainder_out(y_rem),
                    .data_valid_out(y_done),
                    .error_out(y_error),
                    .busy_out(y_busy));
    typedef enum logic[1:0]
     {  STEADY=2'b00,
        TABULATE=2'b01,
        CRUNCHING=2'b10,
        DONE=2'b11} state_enum;
    always_ff@(posedge clk_in)begin
        
        if(rst_in)begin

            state<='0;
            x_sum<='0;
            y_sum<='0;
            counting<=32'b0;
            divide_time<='0;
            valid_out<=0;
            x_out<='0;
            y_out<='0;
            x_hold_done<=0;
            y_hold_done<=0;

        end else begin
        case(state)
            STEADY:begin
                if(valid_in)begin
                    x_sum<=x_sum+x_in;
                    y_sum<=y_sum+y_in;
                    counting<=counting+1;
                end
                if(tabulate_in)begin
                    if(counting>0)begin
                        state<=CRUNCHING;
                        divide_time<=1;
                    end
                end
            end
            CRUNCHING:begin
                if(x_done)begin
                    x_hold_done<=1;
                end
                if(y_done)begin
                    y_hold_done<=1;
                end
                if(x_hold_done && y_hold_done)begin
                    state<=DONE;
                    valid_out<=1;
                    x_out<=x_final_val;
                    y_out<=y_final_val;
                end
            end
            DONE:begin
                state<=STEADY;
                valid_out<=0;
                x_sum<='0;
                y_sum<='0;
                x_hold_done<=0;
                y_hold_done<=0;
                counting<='0;
            end
            endcase
        end
    end
endmodule

`default_nettype wire
