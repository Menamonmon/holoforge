module lfsr_16 ( input wire clk_in, input wire rst_in,
                    input wire [15:0] seed_in,
                    output logic [15:0] q_out);

        always_ff@(posedge clk_in)begin
        if(rst_in)begin
            q_out[15]<=seed_in[15];
            q_out[14]<=seed_in[14];
            q_out[13]<=seed_in[13];
            q_out[12]<=seed_in[12];
            q_out[11]<=seed_in[11];
            q_out[10]<=seed_in[10];
            q_out[9]<=seed_in[9];
            q_out[8]<=seed_in[8];
            q_out[7]<=seed_in[7];
            q_out[6]<=seed_in[6];
            q_out[5]<=seed_in[5];
            q_out[4]<=seed_in[4];
            q_out[3]<=seed_in[3];
            q_out[2]<=seed_in[2];
            q_out[1]<=seed_in[1];
            q_out[0]<=seed_in[0];
        end else begin
            q_out[15]<=q_out[15] ^ q_out[14];
            q_out[14]<=q_out[13];
            q_out[13]<=q_out[12];
            q_out[12]<=q_out[11];
            q_out[11]<=q_out[10];
            q_out[10]<=q_out[9];
            q_out[9]<=q_out[8];
            q_out[8]<=q_out[7];
            q_out[7]<=q_out[6];
            q_out[6]<=q_out[5];
            q_out[5]<=q_out[4];
            q_out[4]<=q_out[3];
            q_out[3]<=q_out[2];
            q_out[2]<=q_out[1]^q_out[15];
            q_out[1]<=q_out[0];
            q_out[0]<=q_out[15];
        end
        end


endmodule





