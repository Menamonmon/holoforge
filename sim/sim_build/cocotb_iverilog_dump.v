module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/yabi/Documents/Schooly_Stuff/6.111/holoforge/sim/sim_build/camera_control.fst");
    $dumpvars(0, camera_control);
end
endmodule
