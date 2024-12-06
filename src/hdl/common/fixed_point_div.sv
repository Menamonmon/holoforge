module fixed_point_div #(
    parameter WIDTH = 16,  // Width of inputs and outputs
    parameter FRAC_BITS = 14  // Fractional bits
) (
    input wire clk_in,
    input wire rst_in,
    input valid_in,
    input wire signed [WIDTH-1:0] A,  // Dividend in Qm1.n1 format
    input wire signed [WIDTH-1:0] B,  // Divisor in Qm2.n2 format

    output logic done,
    output logic busy,
    output logic valid_out,
    output logic zerodiv,
    output logic overflow,

    output logic signed [WIDTH-1:0] Q  // Quotient in Qp.np format
);

  localparam WIDTHU = WIDTH - 1;
  localparam FRAC_BITS_SW = (FRAC_BITS == 0) ? 1 : FRAC_BITS;

  // need to do WIDTH + FRAC to represent fraction division
  localparam ITERS = WIDTHU + FRAC_BITS_SW;

  localparam SMALLEST = {1'b1, {WIDTHU{1'b0}}};

  logic signed [WIDTH-1:0] accumulator, accumulator_next;
  logic [WIDTHU-1:0] AU, BU, QU, QU_next;
  logic [$clog2(ITERS)-1:0] i;


  // QU is initially assigned to be A to save registers

  // algorithm
  always_comb begin
    if (accumulator >= BU) begin
      // subtract BU from accumulator
      accumulator_next = accumulator - BU;
      // shift the next bit from Q to the accumulator and add 1
      {accumulator_next, QU_next} = {accumulator_next[WIDTH-2:0], QU, 1'b1};
    end else begin
      {accumulator_next, QU_next} = {accumulator[WIDTH-2:0], QU, 1'b0};
    end
  end

  // state machine

  enum {
    IDLE,
    INIT,
    CALC,
    ROUND,
    SIGN
  } state;

  logic asign, bsign, diffsign;

  always_comb begin
    asign = A[WIDTHU];
    bsign = B[WIDTHU];
  end

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      accumulator <= 0;
      Q <= 0;
      done <= 0;
      busy <= 0;
      valid_out <= 0;
      zerodiv <= 0;
      overflow <= 0;
	  state <= IDLE;
      i <= 0;
    end else begin
      done <= 0;
      case (state)
        IDLE: begin
          if (valid_in) begin
            // division by zero
            valid_out <= 0;
            if (B == 0) begin
              zerodiv <= 1;
              done <= 1;
              overflow <= 0;
              busy <= 0;
              state <= IDLE;
            end else if (A == SMALLEST || B == SMALLEST) begin
              zerodiv <= 0;
              done <= 1;
              overflow <= 1;
              busy <= 0;
              state <= IDLE;
            end else begin
              zerodiv <= 0;
              done <= 0;
              overflow <= 0;
              busy <= 1;
              state <= INIT;
              diffsign <= asign ^ bsign;
              AU = asign ? -A[WIDTHU-1:0] : A[WIDTHU-1:0];
              BU = bsign ? -B[WIDTHU-1:0] : B[WIDTHU-1:0];
            end
          end
        end
        INIT: begin
          {accumulator, QU} <= {{WIDTHU{1'b0}}, AU, 1'b0};
          i <= 0;
          state <= CALC;
        end
        CALC: begin
          if (i == WIDTHU - 1 && QU_next[WIDTHU-1:WIDTHU-FRAC_BITS_SW] != 0) begin
              zerodiv <= 0;
              done <= 1;
              overflow <= 1;
              busy <= 0;
              state <= IDLE;
          end else begin
            // iterate to the next stage
            i <= i + 1;
            accumulator <= accumulator_next;
            QU <= QU_next;
            if (i == ITERS - 1) begin
              state <= ROUND;
            end
          end
        end
        ROUND: begin
          // no rounding for now
          state <= SIGN;

          // gaussian rounding
          if (QU_next[0] == 1'b1) begin
            if (QU[0] == 1'b1 || accumulator_next[WIDTHU:1] != 0) QU <= QU + 1;
          end
        end
        SIGN: begin
          done  <= 1;
          busy  <= 0;
          valid_out <= 1;
          if (QU != 0) begin
            Q <= diffsign ? {1'b1, -QU} : {1'b0, QU};
          end
          state <= IDLE;
        end
      endcase
    end
  end

endmodule
