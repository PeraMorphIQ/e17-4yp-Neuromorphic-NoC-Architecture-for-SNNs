w`include "neuron/neuron.v"
`timescale 1ns/100ps

module neuron_tb;
    parameter CLOCK_PERIOD = 10;

    // Inputs
    reg CLK, RESET;
    reg [31:0] I, a, b, c, d;
    
    // Outputs
    wire SPIKED;

    // Instantiate the neuron
    neuron dut (
        .CLK(CLK),
        .RESET(RESET),
        .SPIKED(SPIKED),
        .I(I),
        .a(a),
        .b(b),
        .c(c),
        .d(d)
    );

    // Clock generation
    initial begin
        CLK = 1'b0;
        forever #(CLOCK_PERIOD/2) CLK = ~CLK;
    end

    // VCD dump for waveform viewing
    initial begin
        $dumpfile("neuron_tb.vcd");
        $dumpvars(0, dut);
    end

    // Test stimulus
    integer cycle;
    initial begin
        $display("========================================");
        $display("   Izhikevich Neuron Model Testbench");
        $display("========================================\n");

        // Initialize
        RESET = 1'b0;
        I = 32'h00000000;  // 0.0
        a = 32'h3d23d70a;  // 0.04
        b = 32'h3e4ccccd;  // 0.2
        c = 32'hc2480000;  // -50.0
        d = 32'h40000000;  // 2.0
        cycle = 0;

        // Wait for initial setup
        #5;

        $display("Test 1: Regular Spiking (RS) Neuron");
        $display("Parameters: a=0.02, b=0.2, c=-65, d=8");
        $display("Input current: I=10");
        $display("----------------------------------------");
        
        // Regular Spiking parameters
        a = 32'h3ca3d70a;  // 0.02
        b = 32'h3e4ccccd;  // 0.2
        c = 32'hc2820000;  // -65.0
        d = 32'h41000000;  // 8.0
        I = 32'h41200000;  // 10.0

        // Reset neuron
        RESET = 1'b1;
        #CLOCK_PERIOD;
        RESET = 1'b0;

        // Simulate for 100 cycles
        for (cycle = 0; cycle < 100; cycle = cycle + 1) begin
            #CLOCK_PERIOD;
            if (SPIKED) begin
                $display("Cycle %3d: SPIKE! V=%h, U=%h", cycle, dut.V, dut.U);
            end
        end

        $display("\nTest 2: Fast Spiking (FS) Neuron");
        $display("Parameters: a=0.1, b=0.2, c=-65, d=2");
        $display("Input current: I=10");
        $display("----------------------------------------");
        
        // Fast Spiking parameters
        a = 32'h3dcccccd;  // 0.1
        b = 32'h3e4ccccd;  // 0.2
        c = 32'hc2820000;  // -65.0
        d = 32'h40000000;  // 2.0
        I = 32'h41200000;  // 10.0

        // Reset neuron
        RESET = 1'b1;
        #CLOCK_PERIOD;
        RESET = 1'b0;

        // Simulate for 100 cycles
        for (cycle = 0; cycle < 100; cycle = cycle + 1) begin
            #CLOCK_PERIOD;
            if (SPIKED) begin
                $display("Cycle %3d: SPIKE! V=%h, U=%h", cycle, dut.V, dut.U);
            end
        end

        $display("\nTest 3: Chattering (CH) Neuron");
        $display("Parameters: a=0.02, b=0.2, c=-50, d=2");
        $display("Input current: I=10");
        $display("----------------------------------------");
        
        // Chattering parameters
        a = 32'h3ca3d70a;  // 0.02
        b = 32'h3e4ccccd;  // 0.2
        c = 32'hc2480000;  // -50.0
        d = 32'h40000000;  // 2.0
        I = 32'h41200000;  // 10.0

        // Reset neuron
        RESET = 1'b1;
        #CLOCK_PERIOD;
        RESET = 1'b0;

        // Simulate for 100 cycles
        for (cycle = 0; cycle < 100; cycle = cycle + 1) begin
            #CLOCK_PERIOD;
            if (SPIKED) begin
                $display("Cycle %3d: SPIKE! V=%h, U=%h", cycle, dut.V, dut.U);
            end
        end

        $display("\nTest 4: Low-Threshold Spiking (LTS) Neuron");
        $display("Parameters: a=0.02, b=0.25, c=-65, d=2");
        $display("Input current: I=5");
        $display("----------------------------------------");
        
        // LTS parameters
        a = 32'h3ca3d70a;  // 0.02
        b = 32'h3e800000;  // 0.25
        c = 32'hc2820000;  // -65.0
        d = 32'h40000000;  // 2.0
        I = 32'h40a00000;  // 5.0

        // Reset neuron
        RESET = 1'b1;
        #CLOCK_PERIOD;
        RESET = 1'b0;

        // Simulate for 100 cycles
        for (cycle = 0; cycle < 100; cycle = cycle + 1) begin
            #CLOCK_PERIOD;
            if (SPIKED) begin
                $display("Cycle %3d: SPIKE! V=%h, U=%h", cycle, dut.V, dut.U);
            end
        end

        $display("\nTest 5: Variable Input Current");
        $display("Parameters: a=0.02, b=0.2, c=-65, d=8");
        $display("Ramping input current from 0 to 15");
        $display("----------------------------------------");
        
        // Regular Spiking parameters
        a = 32'h3ca3d70a;  // 0.02
        b = 32'h3e4ccccd;  // 0.2
        c = 32'hc2820000;  // -65.0
        d = 32'h41000000;  // 8.0

        // Reset neuron
        RESET = 1'b1;
        #CLOCK_PERIOD;
        RESET = 1'b0;

        // Ramp input current
        for (cycle = 0; cycle < 150; cycle = cycle + 1) begin
            // Linearly increase input current every 10 cycles
            if (cycle % 10 == 0) begin
                I = I + 32'h3f800000;  // Add 1.0
                $display("Cycle %3d: I increased to ~%0d", cycle, (cycle/10));
            end
            #CLOCK_PERIOD;
            if (SPIKED) begin
                $display("Cycle %3d: SPIKE! V=%h, U=%h", cycle, dut.V, dut.U);
            end
        end

        $display("\n========================================");
        $display("   Testbench completed successfully");
        $display("========================================");
        
        #(CLOCK_PERIOD * 10);
        $finish;
    end

    // Monitor for debugging
    initial begin
        $monitor("Time=%0t CLK=%b RESET=%b I=%h SPIKED=%b V=%h U=%h", 
                 $time, CLK, RESET, I, SPIKED, dut.V, dut.U);
    end

endmodule
