module random_noise #(
    parameter N          = 8,  // Number of output bits
    parameter LFSR_WIDTH = 16  // Width of the LFSR
) (
    input  logic         clk_in,  // Clock input
    input  logic         rst_in,  // Reset signal
    output logic [N-1:0] noise    // N-bit random noise output
);

  // LFSR register and feedback wire
  logic [LFSR_WIDTH-1:0] lfsr;
  logic feedback;

  // Feedback taps for maximal-length LFSR (x^16 + x^14 + x^13 + x^11 + 1)
  // Modify the taps for different LFSR widths as needed
  assign feedback = lfsr[LFSR_WIDTH-1] ^ lfsr[LFSR_WIDTH-3] ^ 
                      lfsr[LFSR_WIDTH-4] ^ lfsr[LFSR_WIDTH-6];

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      // Initialize LFSR with a non-zero value
      lfsr <= {LFSR_WIDTH{1'b1}};
    end else begin
      // Shift LFSR and apply feedback
      lfsr <= {lfsr[LFSR_WIDTH-2:0], feedback};
    end
  end

  // Output the lower N bits of the LFSR
  always_ff @(posedge clk_in) begin
    noise <= lfsr[N-1:0];
  end

endmodule
