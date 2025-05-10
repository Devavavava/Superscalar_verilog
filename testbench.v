`timescale 1ns / 1ps

module Full_tb;

    // Inputs
    reg clk;
    reg stall;
    reg flush;
    reg reset;



    // Instantiate the assembled_superscalar module
    Assembled_Superscalar #(
        .SB_SIZE(5),
        .ROB_SIZE(7),
        .RRF_SIZE(7),
        .R_CZ_SIZE(8),
        .RS_AL_ENTRY_SIZE(145),
        .RS_LS_ENTRY_SIZE(75),
        .ROB_ENTRY_SIZE(51)
    ) uut (
        .clk(clk),
        .stall(stall),
        .flush(flush),
        .reset(reset)
    );

    // Clock Generation
    always begin
        #5 clk = ~clk;  // Clock period of 10 time units
    end

    // Initial block
    initial begin
        // Initialize Inputs
        clk = 0;
        stall = 0;
        flush = 1;
        reset = 1; // Start with reset

        // Wait for a few clock cycles
        #30
        reset = 0; // Release reset after 10 time units
        flush = 0; // Release flush after 10 time units

        #30
        reset = 1;
        flush = 1;

        #20
        reset = 0; // Release reset after 10 time units
        flush = 0; // Release flush after 10 time units
        
        #500 $finish;
    end

endmodule
