`include "neuron/neuron.v"
`timescale 1ns/100ps

module neuron_tb;
    parameter CLOCK_PERIOD = 10;

    // Convert floating point to Q16.16 fixed point
    function [31:0] float_to_fixed;
        input real f;
        begin
            float_to_fixed = $rtoi(f * 65536.0);  // Multiply by 2^16
        end
    endfunction

    // Convert Q16.16 fixed point to floating point
    function real fixed_to_float;
        input [31:0] fixed;
        begin
            fixed_to_float = $itor($signed(fixed)) / 65536.0;
        end
    endfunction

    // Inputs
    reg CLK, RESET;
    reg signed [31:0] I, a, b, c, d;
    
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
    real v_real, u_real;
    
    initial begin
        $display("========================================");
        $display("   Izhikevich Neuron Model Testbench");
        $display("   (Fixed-Point Q16.16 Implementation)");
        $display("========================================\n");

        // Initialize
        RESET = 1'b0;
        I = 32'd0;
        a = 32'd0;
        b = 32'd0;
        c = 32'd0;
        d = 32'd0;
        cycle = 0;

        // Wait for initial setup
        #5;

        $display("Test 1: Regular Spiking (RS) Neuron");
        $display("Parameters: a=0.02, b=0.2, c=-65, d=8");
        $display("Input current: I=10");
        $display("----------------------------------------");
        
        // Regular Spiking parameters (converted to Q16.16)
        a = float_to_fixed(0.02);   // 0.02
        b = float_to_fixed(0.2);    // 0.2
        c = float_to_fixed(-65.0);  // -65.0
        d = float_to_fixed(8.0);    // 8.0
        I = float_to_fixed(10.0);   // 10.0

        // Reset neuron
        RESET = 1'b1;
        #CLOCK_PERIOD;
        RESET = 1'b0;

        // Simulate for 100 cycles
        for (cycle = 0; cycle < 100; cycle = cycle + 1) begin
            #CLOCK_PERIOD;
            v_real = fixed_to_float(dut.V);
            u_real = fixed_to_float(dut.U);
            
            if (SPIKED) begin
                $display("Cycle %3d: SPIKE! V=%f, U=%f", cycle, v_real, u_real);
            end
            else if (cycle % 10 == 0) begin
                $display("Cycle %3d: V=%f, U=%f", cycle, v_real, u_real);
            end
        end

        $display("\nTest 2: Fast Spiking (FS) Neuron");
        $display("Parameters: a=0.1, b=0.2, c=-65, d=2");
        $display("Input current: I=10");
        $display("----------------------------------------");
        
        // Fast Spiking parameters
        a = float_to_fixed(0.1);
        b = float_to_fixed(0.2);
        c = float_to_fixed(-65.0);
        d = float_to_fixed(2.0);
        I = float_to_fixed(10.0);

        // Reset neuron
        RESET = 1'b1;
        #CLOCK_PERIOD;
        RESET = 1'b0;

        // Simulate for 100 cycles
        for (cycle = 0; cycle < 100; cycle = cycle + 1) begin
            #CLOCK_PERIOD;
            v_real = fixed_to_float(dut.V);
            u_real = fixed_to_float(dut.U);
            
            if (SPIKED) begin
                $display("Cycle %3d: SPIKE! V=%f, U=%f", cycle, v_real, u_real);
            end
            else if (cycle % 10 == 0) begin
                $display("Cycle %3d: V=%f, U=%f", cycle, v_real, u_real);
            end
        end

        $display("\nTest 3: Chattering (CH) Neuron");
        $display("Parameters: a=0.02, b=0.2, c=-50, d=2");
        $display("Input current: I=10");
        $display("----------------------------------------");
        
        // Chattering parameters
        a = float_to_fixed(0.02);
        b = float_to_fixed(0.2);
        c = float_to_fixed(-50.0);
        d = float_to_fixed(2.0);
        I = float_to_fixed(10.0);

        // Reset neuron
        RESET = 1'b1;
        #CLOCK_PERIOD;
        RESET = 1'b0;

        // Simulate for 100 cycles
        for (cycle = 0; cycle < 100; cycle = cycle + 1) begin
            #CLOCK_PERIOD;
            v_real = fixed_to_float(dut.V);
            u_real = fixed_to_float(dut.U);
            
            if (SPIKED) begin
                $display("Cycle %3d: SPIKE! V=%f, U=%f", cycle, v_real, u_real);
            end
            else if (cycle % 10 == 0) begin
                $display("Cycle %3d: V=%f, U=%f", cycle, v_real, u_real);
            end
        end

        $display("\nTest 4: Low-Threshold Spiking (LTS) Neuron");
        $display("Parameters: a=0.02, b=0.25, c=-65, d=2");
        $display("Input current: I=5");
        $display("----------------------------------------");
        
        // LTS parameters
        a = float_to_fixed(0.02);
        b = float_to_fixed(0.25);
        c = float_to_fixed(-65.0);
        d = float_to_fixed(2.0);
        I = float_to_fixed(5.0);

        // Reset neuron
        RESET = 1'b1;
        #CLOCK_PERIOD;
        RESET = 1'b0;

        // Simulate for 100 cycles
        for (cycle = 0; cycle < 100; cycle = cycle + 1) begin
            #CLOCK_PERIOD;
            v_real = fixed_to_float(dut.V);
            u_real = fixed_to_float(dut.U);
            
            if (SPIKED) begin
                $display("Cycle %3d: SPIKE! V=%f, U=%f", cycle, v_real, u_real);
            end
            else if (cycle % 10 == 0) begin
                $display("Cycle %3d: V=%f, U=%f", cycle, v_real, u_real);
            end
        end

        $display("\nTest 5: Variable Input Current");
        $display("Parameters: a=0.02, b=0.2, c=-65, d=8");
        $display("Ramping input current from 0 to 15");
        $display("----------------------------------------");
        
        // Regular Spiking parameters
        a = float_to_fixed(0.02);
        b = float_to_fixed(0.2);
        c = float_to_fixed(-65.0);
        d = float_to_fixed(8.0);
        I = float_to_fixed(0.0);

        // Reset neuron
        RESET = 1'b1;
        #CLOCK_PERIOD;
        RESET = 1'b0;

        // Ramp input current
        for (cycle = 0; cycle < 150; cycle = cycle + 1) begin
            // Linearly increase input current every 10 cycles
            if (cycle % 10 == 0) begin
                I = I + float_to_fixed(1.0);
                $display("Cycle %3d: I increased to %f", cycle, fixed_to_float(I));
            end
            #CLOCK_PERIOD;
            v_real = fixed_to_float(dut.V);
            u_real = fixed_to_float(dut.U);
            
            if (SPIKED) begin
                $display("Cycle %3d: SPIKE! V=%f, U=%f, I=%f", cycle, v_real, u_real, fixed_to_float(I));
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
