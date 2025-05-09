`timescale 1ns / 1ps

module FetchStage_tb;

    // Inputs
    reg clk;
    reg stall;
    reg flush;
    reg R0w;
    reg [15:0] R0d;

    // Outputs
    wire [15:0] I1;
    wire [15:0] I2;
    wire I1V;
    wire I2V;
    wire I1P;
    wire I2P;
	wire [15:0] I1PC;
	wire [15:0] I2PC;

    // Instantiate the FetchStage module
    FetchStage uut (
        .clk(clk),
        .stall(stall),
        .flush(flush),
        .R0w(R0w),
        .R0d(R0d),
        .I1(I1),
        .I2(I2),
        .I1V(I1V),
        .I2V(I2V),
        .I1P(I1P),
        .I2P(I2P),
		.I1PC(I1PC),
		.I2PC(I2PC)
    );

    // Clock Generation
    always begin
        #5 clk = ~clk;  // Clock period of 10 time units
    end

    // Initial block
    initial begin
        // Initialize signals
        clk = 0;
        stall = 0;
        flush = 0;
        R0w = 0;
        R0d = 16'd0;

        // Test 1: Reset the FetchStage
        flush = 1;  // Assert reset (flush)
        #40;
        flush = 0;  // Deassert reset
        
        #100; // Wait for some time to observe behavior

        // Test 2: External R0 update (R0w = 1)
        R0w = 1;
        R0d = 16'd004;  // Set R0 to a specific value
        #10;
        R0w = 0;  // Disable external update

        #100;  // Wait for some time to observe behavior

        // Test 3: Simulate a stall condition
        R0w = 1;
        R0d = 16'd000;
        #10;
        R0w = 0;  // Disable external update
        stall = 1;
        #100;
        stall = 0;  // Release stall

        // Test 5: Test with flush and external R0 update again
        flush = 1;
        #10;
        flush = 0;
        #10;

        // Test 6: Fetch from the updated R0 address
        stall = 0;
        R0d = 16'd200;  // Fetch from address 200
        #10;

        // Test 7: Test with a series of sequential fetches (no stall or flush)
        R0d = 16'd300;
        #10;
        R0d = 16'd400;
        #10;

        // Finish the test
        $finish;
    end

    // Monitor outputs
    initial begin
        $monitor("At time %t, R0 = %h, I1 = %h, I2 = %h, I1V = %b, I2V = %b, I1P = %b, I2P = %b",
                 $time, R0d, I1, I2, I1V, I2V, I1P, I2P);
    end

endmodule
