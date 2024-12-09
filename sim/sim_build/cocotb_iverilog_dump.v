module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/yabi/Documents/Schooly_Stuff/6.111/holoforge/sim/sim_build/pixel_stacker.fst");
    $dumpvars(0, pixel_stacker);
end
endmodule
