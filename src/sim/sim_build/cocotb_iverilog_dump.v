module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/yabi/Documents/Schooly_Stuff/6.111/holoforge/src/sim/sim_build/fixed_point_mult.fst");
    $dumpvars(0, fixed_point_mult);
end
endmodule
