module inv_area #(
    parameter XWIDTH = 16,
    parameter YWIDTH = 16,
    parameter FRAC = 14,
    parameter N = 3
) (
    input wire clk_in,
    input wire rst_in,
    input wire valid_in,

    input wire signed [N-1:0][XWIDTH-1:0] x,
    input wire signed [N-1:0][YWIDTH-1:0] y,

    output logic done,
    output logic valid_out,
    output logic [INV_WIDTH-1:0] iarea  // always positive
);
  localparam SUB_WIDTH = YWIDTH + 1;
  localparam DOT_FRAC = FRAC;
  localparam DOT_WIDTH = $clog2(N) + (XWIDTH - FRAC) + (SUB_WIDTH - FRAC) + DOT_FRAC;
  localparam DOT_INT = DOT_WIDTH - DOT_FRAC;
  localparam MAX_INV_PART = DOT_INT > DOT_FRAC ? DOT_INT : DOT_FRAC;
  localparam INV_WIDTH = 2 * MAX_INV_PART + 1;

  logic signed [N-1:0][XWIDTH-1:0] xv;
  logic signed [N-1:0][SUB_WIDTH-1:0] sub_out;
  logic signed [DOT_WIDTH-1:0] dot_out;
  logic dot_valid_out;
  logic signed [INV_WIDTH-1:0] inv_out;
  logic inv_valid_out, inv_done, inv_busy, inv_zerodiv, inv_overflow, dot_valid_in;


  /*
	FSM:
	- IDLE: valid_in (sub and go to DOT)
	- DOT
	- DIV
	- 
	*/

  enum {
    IDLE,
    DOT,
    DIV
  } state;

  fixed_point_fast_dot #(
      .A_WIDTH(XWIDTH),
      .A_FRAC_BITS(FRAC),
      .B_WIDTH(SUB_WIDTH),
      .B_FRAC_BITS(FRAC),
      .P_FRAC_BITS(FRAC)
  ) dot (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .A(xv),
      .B(sub_out),
      .D(dot_out)
  );

  pipeline #(
      .DATA_WIDTH (1),
      .STAGES(4)   // check for correctness
  ) pipe (
      .clk_in(clk_in),
      .data(state == IDLE && valid_in),
      .data_out(dot_valid_out)
  );


  fixed_point_div #(
      .WIDTH(INV_WIDTH),
      .FRAC_BITS(FRAC + FRAC)
  ) div (
      .clk_in(clk_in),
      .rst_in(rst_in),
      .valid_in(dot_valid_out),
      //   .A({{(INV_WIDTH - 1) {1'b0}}, 1'b1}),
      .A(1),
      .B(dot_out),
      .Q(inv_out),
      .valid_out(inv_valid_out),
      .done(inv_done),
      .busy(inv_busy),
      .zerodiv(inv_zerodiv),
      .overflow(inv_overflow)
  );

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      xv <= 0;
      valid_out <= 0;
      done <= 0;
      state <= IDLE;
    end else begin
      case (state)
        IDLE: begin
          if (valid_in) begin
            state <= DOT;
            xv <= x;
            sub_out[0] <= ($signed(y[1]) - $signed(y[2]));
            sub_out[1] <= ($signed(y[2]) - $signed(y[0]));
            sub_out[2] <= ($signed(y[0]) - $signed(y[1]));
            // dot_valid_in <= 1;
          end else begin
            valid_out <= 0;
            done <= 0;
            iarea <= 0;
          end
        end

        DOT: begin
          //   dot_valid_in <= 0;
          if (dot_valid_out) begin
            state <= DIV;
          end
        end

        DIV: begin
          if (inv_done) begin
            valid_out <= inv_valid_out;
            iarea <= inv_out;
            done <= 1;
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule
