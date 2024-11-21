module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/yabi/Documents/Schooly_Stuff/6.111/holoforge/sim/sim_build/v_to_ndc.fst");
    $dumpvars(0, v_to_ndc);
end
endmodule
