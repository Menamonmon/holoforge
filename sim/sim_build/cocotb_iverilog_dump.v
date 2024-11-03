module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/menaf/Downloads/dev/mit/classes/fa24/6.2050/labs/lab05/sim/sim_build/image_sprite.fst");
    $dumpvars(0, image_sprite);
end
endmodule
