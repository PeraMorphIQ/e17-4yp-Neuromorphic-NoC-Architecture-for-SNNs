`timescale 1ns/1ps
`include "system_top_with_cpu.v"

module system_top_with_cpu_tb;

    // Parameters
    parameter MESH_SIZE_X = 2;
    parameter MESH_SIZE_Y = 2;
    parameter NUM_NEURONS_PER_BANK = 4;
    parameter NUM_NODES = MESH_SIZE_X * MESH_SIZE_Y;
    
    parameter CPU_CLK_PERIOD = 20;  // 50 MHz
    parameter NET_CLK_PERIOD = 10;  // 100 MHz
    
    // Signals
    reg cpu_clk;
    reg net_clk;
    reg rst_n;
    
    reg [NUM_NODES-1:0] prog_load_enable;
    reg [31:0] prog_load_addr;
    reg [31:0] prog_load_data;
    reg [NUM_NODES-1:0] prog_load_write;
    
    reg [7:0]  ext_node_select;
    reg [7:0]  ext_neuron_id;
    reg [31:0] ext_input_current;
    reg        ext_input_valid;
    
    wire [NUM_NODES-1:0] cpu_interrupt;
    wire [NUM_NODES*NUM_NEURONS_PER_BANK-1:0] spike_out;
    wire [NUM_NODES*5-1:0] router_input_valid;
    wire [NUM_NODES*5-1:0] router_input_ready;
    wire [NUM_NODES*5-1:0] router_output_valid;
    wire [NUM_NODES*5-1:0] router_output_ready;
    
    integer i;

    // DUT
    system_top_with_cpu #(
        .MESH_SIZE_X(MESH_SIZE_X),
        .MESH_SIZE_Y(MESH_SIZE_Y),
        .NUM_NEURONS_PER_BANK(NUM_NEURONS_PER_BANK)
    ) dut (
        .cpu_clk(cpu_clk),
        .net_clk(cpu_clk), // Using same clock for simplicity or as per original
        .rst_n(rst_n),
        .prog_load_enable(prog_load_enable),
        .prog_load_addr(prog_load_addr),
        .prog_load_data(prog_load_data),
        .prog_load_write(prog_load_write),
        .ext_node_select(ext_node_select),
        .ext_neuron_id(ext_neuron_id),
        .ext_input_current(ext_input_current),
        .ext_input_valid(ext_input_valid),
        .cpu_interrupt(cpu_interrupt),
        .spike_out(spike_out),
        .router_input_valid(router_input_valid),
        .router_input_ready(router_input_ready),
        .router_output_valid(router_output_valid),
        .router_output_ready(router_output_ready)
    );
    
    // Clocks
    initial begin
        cpu_clk = 0;
        forever #(CPU_CLK_PERIOD/2) cpu_clk = ~cpu_clk;
    end
    
    initial begin
        net_clk = 0;
        forever #(NET_CLK_PERIOD/2) net_clk = ~net_clk;
    end

    // VCD
    initial begin
        $dumpfile("system_top_with_cpu_tb.vcd");
        $dumpvars(0, system_top_with_cpu_tb);
    end

    // Helper Tasks (Simplified, no prints)
    task load_instruction;
        input [1:0] node_id;
        input [31:0] addr;
        input [31:0] instruction;
    begin
        @(posedge cpu_clk);
        prog_load_enable = (1 << node_id);
        prog_load_addr = addr;
        prog_load_data = instruction;
        prog_load_write = (1 << node_id);
        @(posedge cpu_clk);
        prog_load_write = 0;
        prog_load_enable = 0;
    end
    endtask

    task inject_current;
        input [3:0] node_x;
        input [3:0] node_y;
        input [3:0] neuron_id;
        input [31:0] current;
    begin
        @(posedge cpu_clk);
        ext_node_select = {node_y, node_x};
        ext_neuron_id = {4'h0, neuron_id};
        ext_input_current = current;
        ext_input_valid = 1;
        @(posedge cpu_clk);
        ext_input_valid = 0;
    end
    endtask

    task trigger_neuron;
        input [3:0] node_x;
        input [3:0] node_y;
        input [3:0] neuron_id;
    begin
        @(posedge cpu_clk);
        ext_node_select = {node_y, node_x};
        ext_neuron_id = (neuron_id * 8) + 8'h06;
        ext_input_current = 32'h00000001;
        ext_input_valid = 1;
        @(posedge cpu_clk);
        ext_input_valid = 0;
    end
    endtask

    // Main Test Sequence
    initial begin
        // Initialize signals
        rst_n = 0;
        prog_load_enable = 0;
        prog_load_addr = 0;
        prog_load_data = 0;
        prog_load_write = 0;
        ext_node_select = 0;
        ext_neuron_id = 0;
        ext_input_current = 0;
        ext_input_valid = 0;

        $display("Starting System Top Testbench...");

        // Reset
        #100;
        rst_n = 1;
        #100;

        // 1. Load Programs to all nodes
        // Simple NOP program for basic testing
        for (i = 0; i < NUM_NODES; i = i + 1) begin
            load_instruction(i[1:0], 32'h00000000, 32'h00000013); // NOP
            load_instruction(i[1:0], 32'h00000004, 32'h00000013); // NOP
            load_instruction(i[1:0], 32'h00000008, 32'h00000013); // NOP
            load_instruction(i[1:0], 32'h0000000C, 32'h0000006F); // Loop
        end
        
        // 2. Configure Node 0 Neuron 0 via CPU (Simulated by direct memory load for speed)
        // We will just use external configuration for this simplified test to avoid complex assembly in TB
        
        // 3. Inject Current to Node 0, Neuron 0
        #100;
        inject_current(4'h0, 4'h0, 4'h0, 32'h42C80000); // 100.0
        trigger_neuron(4'h0, 4'h0, 4'h0);

        // 4. Inject Current to Node 1, Neuron 1
        #100;
        inject_current(4'h1, 4'h0, 4'h1, 32'h42C80000); // 100.0
        trigger_neuron(4'h1, 4'h0, 4'h1);

        // 5. Wait and Observe
        #2000;

        // 6. Mass Injection
        for (i = 0; i < NUM_NEURONS_PER_BANK; i = i + 1) begin
            inject_current(4'h0, 4'h0, i[3:0], 32'h43960000); // 300.0
            trigger_neuron(4'h0, 4'h0, i[3:0]);
        end

        #5000;
        
        $display("Simulation completed.");
        $finish;
    end

endmodule