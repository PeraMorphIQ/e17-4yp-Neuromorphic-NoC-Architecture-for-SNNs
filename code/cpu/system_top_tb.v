`timescale 1ns/1ps
`include "system_top.v"

module system_top_tb;

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
    
    // External access interface
    reg [7:0] ext_node_select;
    reg [7:0] ext_addr;
    reg ext_write_en;
    reg ext_read_en;
    reg [31:0] ext_write_data;
    wire [31:0] ext_read_data;
    wire ext_ready;
    
    // Debug outputs
    wire [NUM_NODES-1:0] node_interrupts;
    wire [NUM_NODES-1:0] node_spike_detected;
    wire [31:0] debug_router_00_north_out_packet;
    wire debug_router_00_north_out_valid;
    
    // DUT
    system_top #(
        .MESH_SIZE_X(MESH_SIZE_X),
        .MESH_SIZE_Y(MESH_SIZE_Y),
        .NUM_NEURONS_PER_BANK(NUM_NEURONS_PER_BANK)
    ) dut (
        .cpu_clk(cpu_clk),
        .net_clk(net_clk),
        .rst_n(rst_n),
        .ext_node_select(ext_node_select),
        .ext_addr(ext_addr),
        .ext_write_en(ext_write_en),
        .ext_read_en(ext_read_en),
        .ext_write_data(ext_write_data),
        .ext_read_data(ext_read_data),
        .ext_ready(ext_ready),
        .node_interrupts(node_interrupts),
        .node_spike_detected(node_spike_detected),
        .debug_router_00_north_out_packet(debug_router_00_north_out_packet),
        .debug_router_00_north_out_valid(debug_router_00_north_out_valid)
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
    
    // Tasks
    task write_neuron_register;
        input [3:0] node_x;
        input [3:0] node_y;
        input [7:0] addr;
        input [31:0] data;
    begin
        @(posedge cpu_clk);
        ext_node_select = {node_x, node_y};
        ext_addr = addr;
        ext_write_data = data;
        ext_write_en = 1;
        ext_read_en = 0;
        @(posedge cpu_clk);
        wait(ext_ready);
        @(posedge cpu_clk);
        ext_write_en = 0;
    end
    endtask
    
    task read_neuron_register;
        input [3:0] node_x;
        input [3:0] node_y;
        input [7:0] addr;
        output [31:0] data;
    begin
        @(posedge cpu_clk);
        ext_node_select = {node_x, node_y};
        ext_addr = addr;
        ext_write_en = 0;
        ext_read_en = 1;
        @(posedge cpu_clk);
        wait(ext_ready);
        @(posedge cpu_clk);
        data = ext_read_data;
        ext_read_en = 0;
    end
    endtask
    
    task inject_current;
        input [3:0] node_x;
        input [3:0] node_y;
        input [3:0] neuron_id;
        input [31:0] current;
    begin
        write_neuron_register(node_x, node_y, 8'h80 + (neuron_id * 4), current);
    end
    endtask
    
    task configure_neuron;
        input [3:0] node_x;
        input [3:0] node_y;
        input [3:0] neuron_id;
        input [31:0] threshold;
        input [31:0] leak;
        input [31:0] reset_potential;
    begin
        // Configure threshold (offset 0x00)
        write_neuron_register(node_x, node_y, (neuron_id * 8) + 8'h00, threshold);
        // Configure leak (offset 0x01)
        write_neuron_register(node_x, node_y, (neuron_id * 8) + 8'h01, leak);
        // Configure reset potential (offset 0x02)
        write_neuron_register(node_x, node_y, (neuron_id * 8) + 8'h02, reset_potential);
    end
    endtask
    
    task enable_neuron;
        input [3:0] node_x;
        input [3:0] node_y;
        input [3:0] neuron_id;
    begin
        // Write to control register (offset 0x06) to enable neuron
        write_neuron_register(node_x, node_y, (neuron_id * 8) + 8'h06, 32'h00000001);
    end
    endtask
    
    // Test stimulus
    integer i;
    reg [31:0] read_val;
    
    initial begin
        $dumpfile("system_top_tb.vcd");
        $dumpvars(0, system_top_tb);
        
        // Initialize
        rst_n = 0;
        ext_node_select = 0;
        ext_addr = 0;
        ext_write_en = 0;
        ext_read_en = 0;
        ext_write_data = 0;
        
        // Reset
        repeat(5) @(posedge cpu_clk);
        rst_n = 1;
        repeat(5) @(posedge cpu_clk);
        
        $display("=== System Top Testbench ===");
        $display("Time: %0t - Reset released", $time);
        
        // Configure neurons in node (0,0)
        $display("Time: %0t - Configuring neuron 0 in node (0,0)", $time);
        configure_neuron(0, 0, 0, 32'h41200000, 32'h3F000000, 32'h00000000); // threshold=10.0, leak=0.5, reset=0.0
        enable_neuron(0, 0, 0);
        
        // Configure neurons in node (1,0)
        $display("Time: %0t - Configuring neuron 0 in node (1,0)", $time);
        configure_neuron(1, 0, 0, 32'h41200000, 32'h3F000000, 32'h00000000);
        enable_neuron(1, 0, 0);
        
        // Inject current to trigger spikes
        $display("Time: %0t - Injecting current to node (0,0) neuron 0", $time);
        inject_current(0, 0, 0, 32'h41A00000); // 20.0
        
        // Wait for neuron processing
        repeat(50) @(posedge cpu_clk);
        
        // Check for spikes
        if (node_spike_detected[0]) begin
            $display("Time: %0t - Spike detected on node (0,0)", $time);
        end
        
        // Inject current to another node
        $display("Time: %0t - Injecting current to node (1,0) neuron 0", $time);
        inject_current(1, 0, 0, 32'h41A00000); // 20.0
        
        // Wait for processing
        repeat(50) @(posedge cpu_clk);
        
        // Read back membrane potential from node (0,0) neuron 0
        read_neuron_register(0, 0, 8'h03, read_val);
        $display("Time: %0t - Node (0,0) neuron 0 membrane potential: %h", $time, read_val);
        
        // Wait for network activity
        repeat(100) @(posedge cpu_clk);
        
        $display("Time: %0t - Test completed", $time);
        $finish;
    end
    
    // Timeout
    initial begin
        #100000;
        $display("TIMEOUT!");
        $finish;
    end
    
    // Monitor interrupts and spikes
    always @(posedge cpu_clk) begin
        if (|node_interrupts) begin
            $display("Time: %0t - Interrupt detected: %b", $time, node_interrupts);
        end
        if (|node_spike_detected) begin
            $display("Time: %0t - Spikes detected: %b", $time, node_spike_detected);
        end
    end

endmodule
