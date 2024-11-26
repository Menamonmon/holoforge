module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/yabi/Documents/Schooly_Stuff/6.111/holoforge/sim/sim_build/renorm.fst");
    $dumpvars(0, renorm);
end
endmodule
