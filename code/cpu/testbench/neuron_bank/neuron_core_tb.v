`timescale 1ns/100ps

`include "neuron_bank/neuron_core.v"

// Testbench for Neuron Core - Tests both LIF and Izhikevich models
module neuron_core_tb;

    // Parameters
    parameter CLK_PERIOD = 10; // 100MHz
    
    // Clock and Reset
    reg clk;
    reg rst_n;
    
    // Configuration signals
    reg config_enable;
    reg [31:0] config_data;
    reg [2:0] config_addr;
    
    // Control signals
    reg start;
    reg spike_resolved;
    wire spike_detected;
    wire busy;
    
    // Input/Output
    reg [31:0] input_current;
    wire [31:0] v_out;
    wire [31:0] u_out;
    
    // Instantiate neuron core
    neuron_core uut (
        .clk(clk),
        .rst_n(rst_n),
        .config_enable(config_enable),
        .config_data(config_data),
        .config_addr(config_addr),
        .start(start),
        .spike_resolved(spike_resolved),
        .spike_detected(spike_detected),
        .busy(busy),
        .input_current(input_current),
        .v_out(v_out),
        .u_out(u_out)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Helper function to convert IEEE 754 to real (for display purposes)
    function real ieee754_to_real;
        input [31:0] ieee754;
        reg sign;
        reg [7:0] exponent;
        reg [22:0] mantissa;
        real value;
        integer exp_value;
        begin
            sign = ieee754[31];
            exponent = ieee754[30:23];
            mantissa = ieee754[22:0];
            
            if (exponent == 0) begin
                value = 0.0;
            end else begin
                exp_value = exponent - 127;
                value = (1.0 + mantissa / 8388608.0) * (2.0 ** exp_value);
                if (sign) value = -value;
            end
            
            ieee754_to_real = value;
        end
    endfunction
    
    // Test stimulus
    initial begin
        // Initialize signals
        rst_n = 0;
        config_enable = 0;
        config_data = 0;
        config_addr = 0;
        start = 0;
        spike_resolved = 0;
        input_current = 0;
        
        // Reset
        #(CLK_PERIOD*5);
        rst_n = 1;
        #(CLK_PERIOD*2);
        
        $display("======================================");
        $display("Neuron Core Testbench Started");
        $display("======================================");
        
        // ==================== Test LIF Neuron ====================
        $display("\n========== Testing LIF Neuron ==========");
        configure_lif_neuron();
        test_lif_behavior();
        
        // ==================== Test Izhikevich Neuron ====================
        $display("\n========== Testing Izhikevich Neuron ==========");
        configure_izhikevich_neuron();
        test_izhikevich_behavior();
        
        // ==================== Test Spike Detection ====================
        $display("\n========== Testing Spike Detection ==========");
        test_spike_detection();
        
        #(CLK_PERIOD*50);
        $display("\n======================================");
        $display("All Neuron Core Tests Completed!");
        $display("======================================");
        $finish;
    end
    
    // Task to configure LIF neuron
    task configure_lif_neuron;
        begin
            $display("\n[CONFIG] Configuring LIF Neuron");
            
            // Set neuron type to LIF (0)
            config_addr = 3'd0;
            config_data = 32'h00000000; // type = 0 (LIF)
            config_enable = 1;
            @(posedge clk);
            config_enable = 0;
            $display("  Neuron type set to LIF");
            
            // Set threshold v_th = 10.0
            config_addr = 3'd1;
            config_data = 32'h41200000; // 10.0 in IEEE 754
            config_enable = 1;
            @(posedge clk);
            config_enable = 0;
            $display("  Threshold v_th = %f", ieee754_to_real(config_data));
            
            // Set parameter a = 0.95 (decay factor)
            config_addr = 3'd2;
            config_data = 32'h3F733333; // 0.95 in IEEE 754
            config_enable = 1;
            @(posedge clk);
            config_enable = 0;
            $display("  Parameter a = %f", ieee754_to_real(config_data));
            
            // Set parameter b = 0.1 (input weight)
            config_addr = 3'd3;
            config_data = 32'h3DCCCCCD; // 0.1 in IEEE 754
            config_enable = 1;
            @(posedge clk);
            config_enable = 0;
            $display("  Parameter b = %f", ieee754_to_real(config_data));
            
            #(CLK_PERIOD*2);
        end
    endtask
    
    // Task to test LIF behavior
    task test_lif_behavior;
        integer i;
        begin
            $display("\n[TEST] LIF Neuron Behavior");
            $display("  Testing membrane potential accumulation with constant input");
            
            // Apply constant input current I = 5.0
            input_current = 32'h40A00000; // 5.0 in IEEE 754
            $display("  Input current I = %f", ieee754_to_real(input_current));
            
            // Run multiple updates
            for (i = 0; i < 10; i = i + 1) begin
                start = 1;
                @(posedge clk);
                start = 0;
                
                // Wait for computation to complete
                wait (!busy);
                @(posedge clk);
                
                $display("  Step %0d: v = %f", i+1, ieee754_to_real(v_out));
                
                if (spike_detected) begin
                    $display("    SPIKE DETECTED!");
                    spike_resolved = 1;
                    @(posedge clk);
                    spike_resolved = 0;
                    wait (!busy);
                    $display("    After reset: v = %f", ieee754_to_real(v_out));
                end
                
                #(CLK_PERIOD*5);
            end
            
            $display("  LIF test completed");
        end
    endtask
    
    // Task to configure Izhikevich neuron
    task configure_izhikevich_neuron;
        begin
            $display("\n[CONFIG] Configuring Izhikevich Neuron (Regular Spiking)");
            
            // Set neuron type to Izhikevich (1)
            config_addr = 3'd0;
            config_data = 32'h00000001; // type = 1 (Izhikevich)
            config_enable = 1;
            @(posedge clk);
            config_enable = 0;
            $display("  Neuron type set to Izhikevich");
            
            // Set threshold v_th = 30.0
            config_addr = 3'd1;
            config_data = 32'h41F00000; // 30.0 in IEEE 754
            config_enable = 1;
            @(posedge clk);
            config_enable = 0;
            $display("  Threshold v_th = %f", ieee754_to_real(config_data));
            
            // Set parameter a = 0.02
            config_addr = 3'd2;
            config_data = 32'h3CA3D70A; // 0.02 in IEEE 754
            config_enable = 1;
            @(posedge clk);
            config_enable = 0;
            $display("  Parameter a = %f", ieee754_to_real(config_data));
            
            // Set parameter b = 0.2
            config_addr = 3'd3;
            config_data = 32'h3E4CCCCD; // 0.2 in IEEE 754
            config_enable = 1;
            @(posedge clk);
            config_enable = 0;
            $display("  Parameter b = %f", ieee754_to_real(config_data));
            
            // Set parameter c = -65.0 (reset voltage)
            config_addr = 3'd4;
            config_data = 32'hC2820000; // -65.0 in IEEE 754
            config_enable = 1;
            @(posedge clk);
            config_enable = 0;
            $display("  Parameter c = %f", ieee754_to_real(config_data));
            
            // Set parameter d = 8.0 (reset recovery)
            config_addr = 3'd5;
            config_data = 32'h41000000; // 8.0 in IEEE 754
            config_enable = 1;
            @(posedge clk);
            config_enable = 0;
            $display("  Parameter d = %f", ieee754_to_real(config_data));
            
            #(CLK_PERIOD*2);
        end
    endtask
    
    // Task to test Izhikevich behavior
    task test_izhikevich_behavior;
        integer i;
        begin
            $display("\n[TEST] Izhikevich Neuron Behavior");
            $display("  Testing regular spiking pattern with constant input");
            
            // Apply constant input current I = 10.0
            input_current = 32'h41200000; // 10.0 in IEEE 754
            $display("  Input current I = %f", ieee754_to_real(input_current));
            
            // Run multiple updates to observe spiking
            for (i = 0; i < 20; i = i + 1) begin
                start = 1;
                @(posedge clk);
                start = 0;
                
                // Wait for computation to complete
                wait (!busy);
                @(posedge clk);
                
                $display("  Step %0d: v = %f, u = %f", 
                         i+1, ieee754_to_real(v_out), ieee754_to_real(u_out));
                
                if (spike_detected) begin
                    $display("    SPIKE DETECTED!");
                    spike_resolved = 1;
                    @(posedge clk);
                    spike_resolved = 0;
                    wait (!busy);
                    $display("    After reset: v = %f, u = %f", 
                             ieee754_to_real(v_out), ieee754_to_real(u_out));
                end
                
                #(CLK_PERIOD*5);
            end
            
            $display("  Izhikevich test completed");
        end
    endtask
    
    // Task to test spike detection threshold
    task test_spike_detection;
        begin
            $display("\n[TEST] Spike Detection Threshold");
            
            // Configure LIF with low threshold
            configure_lif_neuron();
            
            // Set low threshold
            config_addr = 3'd1;
            config_data = 32'h3F800000; // 1.0 in IEEE 754
            config_enable = 1;
            @(posedge clk);
            config_enable = 0;
            $display("  Set low threshold v_th = %f", ieee754_to_real(config_data));
            
            // Apply large input to force immediate spike
            input_current = 32'h41200000; // 10.0
            $display("  Applying large input I = %f", ieee754_to_real(input_current));
            
            start = 1;
            @(posedge clk);
            start = 0;
            
            wait (!busy);
            @(posedge clk);
            
            if (spike_detected) begin
                $display("  SUCCESS: Spike detected as expected");
                $display("  Membrane potential v = %f", ieee754_to_real(v_out));
            end else begin
                $display("  ERROR: Spike not detected when expected");
            end
            
            #(CLK_PERIOD*5);
        end
    endtask
    
    // Waveform dump
    initial begin
        $dumpfile("neuron_core_tb.vcd");
        $dumpvars(0, neuron_core_tb);
    end
    
    // Monitor state changes
    always @(posedge clk) begin
        if (spike_detected && !spike_resolved) begin
            $display("  [%0t] SPIKE EVENT: v=%f, u=%f", 
                     $time, ieee754_to_real(v_out), ieee754_to_real(u_out));
        end
    end

endmodule
