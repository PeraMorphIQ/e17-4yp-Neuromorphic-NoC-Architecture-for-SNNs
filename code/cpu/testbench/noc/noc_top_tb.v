`timescale 1ns/100ps

`include "noc/router.v"

// Testbench for NoC Top - Tests full 2x2 mesh with multi-hop routing
module noc_top_tb;

    // Parameters
    parameter MESH_SIZE_X = 2;
    parameter MESH_SIZE_Y = 2;
    parameter CLK_PERIOD_CPU = 10;  // 100MHz
    parameter CLK_PERIOD_NET = 14;  // ~71MHz
    
    // Clock and Reset
    reg cpu_clk;
    reg net_clk;
    reg rst_n;
    
    // Test signals for packet injection
    reg [31:0] test_packet;
    reg test_valid;
    wire test_ready;
    
    // Instantiate NoC Top (simplified for testing - we'll focus on network)
    // Note: Full noc_top.v includes CPUs and neuron banks
    // This testbench tests the interconnected routers
    
    // Router signals for 2x2 mesh
    // Router (0,0)
    wire [31:0] r00_north_out, r00_south_out, r00_east_out, r00_west_out, r00_local_out;
    wire r00_north_out_valid, r00_south_out_valid, r00_east_out_valid, r00_west_out_valid, r00_local_out_valid;
    wire r00_north_in_ready, r00_south_in_ready, r00_east_in_ready, r00_west_in_ready, r00_local_in_ready;
    reg [31:0] r00_north_in, r00_south_in, r00_east_in, r00_west_in, r00_local_in;
    reg r00_north_in_valid, r00_south_in_valid, r00_east_in_valid, r00_west_in_valid, r00_local_in_valid;
    wire r00_north_out_ready, r00_south_out_ready, r00_east_out_ready, r00_west_out_ready, r00_local_out_ready;
    
    // Router (0,1)
    wire [31:0] r01_north_out, r01_south_out, r01_east_out, r01_west_out, r01_local_out;
    wire r01_north_out_valid, r01_south_out_valid, r01_east_out_valid, r01_west_out_valid, r01_local_out_valid;
    wire r01_north_in_ready, r01_south_in_ready, r01_east_in_ready, r01_west_in_ready, r01_local_in_ready;
    reg [31:0] r01_north_in, r01_south_in, r01_east_in, r01_west_in, r01_local_in;
    reg r01_north_in_valid, r01_south_in_valid, r01_east_in_valid, r01_west_in_valid, r01_local_in_valid;
    wire r01_north_out_ready, r01_south_out_ready, r01_east_out_ready, r01_west_out_ready, r01_local_out_ready;
    
    // Router (1,0)
    wire [31:0] r10_north_out, r10_south_out, r10_east_out, r10_west_out, r10_local_out;
    wire r10_north_out_valid, r10_south_out_valid, r10_east_out_valid, r10_west_out_valid, r10_local_out_valid;
    wire r10_north_in_ready, r10_south_in_ready, r10_east_in_ready, r10_west_in_ready, r10_local_in_ready;
    reg [31:0] r10_north_in, r10_south_in, r10_east_in, r10_west_in, r10_local_in;
    reg r10_north_in_valid, r10_south_in_valid, r10_east_in_valid, r10_west_in_valid, r10_local_in_valid;
    wire r10_north_out_ready, r10_south_out_ready, r10_east_out_ready, r10_west_out_ready, r10_local_out_ready;
    
    // Router (1,1)
    wire [31:0] r11_north_out, r11_south_out, r11_east_out, r11_west_out, r11_local_out;
    wire r11_north_out_valid, r11_south_out_valid, r11_east_out_valid, r11_west_out_valid, r11_local_out_valid;
    wire r11_north_in_ready, r11_south_in_ready, r11_east_in_ready, r11_west_in_ready, r11_local_in_ready;
    reg [31:0] r11_north_in, r11_south_in, r11_east_in, r11_west_in, r11_local_in;
    reg r11_north_in_valid, r11_south_in_valid, r11_east_in_valid, r11_west_in_valid, r11_local_in_valid;
    wire r11_north_out_ready, r11_south_out_ready, r11_east_out_ready, r11_west_out_ready, r11_local_out_ready;
    
    // Instantiate routers
    router #(.ROUTER_ADDR_WIDTH(4), .ROUTING_ALGORITHM(0), .VC_DEPTH(4)) router_00 (
        .clk(net_clk), .rst_n(rst_n), .router_addr(4'b0000),
        .north_in_packet(r00_north_in), .north_in_valid(r00_north_in_valid), .north_in_ready(r00_north_in_ready),
        .north_out_packet(r00_north_out), .north_out_valid(r00_north_out_valid), .north_out_ready(r00_north_out_ready),
        .south_in_packet(r00_south_in), .south_in_valid(r00_south_in_valid), .south_in_ready(r00_south_in_ready),
        .south_out_packet(r00_south_out), .south_out_valid(r00_south_out_valid), .south_out_ready(r00_south_out_ready),
        .east_in_packet(r00_east_in), .east_in_valid(r00_east_in_valid), .east_in_ready(r00_east_in_ready),
        .east_out_packet(r00_east_out), .east_out_valid(r00_east_out_valid), .east_out_ready(r00_east_out_ready),
        .west_in_packet(r00_west_in), .west_in_valid(r00_west_in_valid), .west_in_ready(r00_west_in_ready),
        .west_out_packet(r00_west_out), .west_out_valid(r00_west_out_valid), .west_out_ready(r00_west_out_ready),
        .local_in_packet(r00_local_in), .local_in_valid(r00_local_in_valid), .local_in_ready(r00_local_in_ready),
        .local_out_packet(r00_local_out), .local_out_valid(r00_local_out_valid), .local_out_ready(r00_local_out_ready)
    );
    
    router #(.ROUTER_ADDR_WIDTH(4), .ROUTING_ALGORITHM(0), .VC_DEPTH(4)) router_01 (
        .clk(net_clk), .rst_n(rst_n), .router_addr(4'b0001),
        .north_in_packet(r01_north_in), .north_in_valid(r01_north_in_valid), .north_in_ready(r01_north_in_ready),
        .north_out_packet(r01_north_out), .north_out_valid(r01_north_out_valid), .north_out_ready(r01_north_out_ready),
        .south_in_packet(r01_south_in), .south_in_valid(r01_south_in_valid), .south_in_ready(r01_south_in_ready),
        .south_out_packet(r01_south_out), .south_out_valid(r01_south_out_valid), .south_out_ready(r01_south_out_ready),
        .east_in_packet(r01_east_in), .east_in_valid(r01_east_in_valid), .east_in_ready(r01_east_in_ready),
        .east_out_packet(r01_east_out), .east_out_valid(r01_east_out_valid), .east_out_ready(r01_east_out_ready),
        .west_in_packet(r01_west_in), .west_in_valid(r01_west_in_valid), .west_in_ready(r01_west_in_ready),
        .west_out_packet(r01_west_out), .west_out_valid(r01_west_out_valid), .west_out_ready(r01_west_out_ready),
        .local_in_packet(r01_local_in), .local_in_valid(r01_local_in_valid), .local_in_ready(r01_local_in_ready),
        .local_out_packet(r01_local_out), .local_out_valid(r01_local_out_valid), .local_out_ready(r01_local_out_ready)
    );
    
    router #(.ROUTER_ADDR_WIDTH(4), .ROUTING_ALGORITHM(0), .VC_DEPTH(4)) router_10 (
        .clk(net_clk), .rst_n(rst_n), .router_addr(4'b0100),
        .north_in_packet(r10_north_in), .north_in_valid(r10_north_in_valid), .north_in_ready(r10_north_in_ready),
        .north_out_packet(r10_north_out), .north_out_valid(r10_north_out_valid), .north_out_ready(r10_north_out_ready),
        .south_in_packet(r10_south_in), .south_in_valid(r10_south_in_valid), .south_in_ready(r10_south_in_ready),
        .south_out_packet(r10_south_out), .south_out_valid(r10_south_out_valid), .south_out_ready(r10_south_out_ready),
        .east_in_packet(r10_east_in), .east_in_valid(r10_east_in_valid), .east_in_ready(r10_east_in_ready),
        .east_out_packet(r10_east_out), .east_out_valid(r10_east_out_valid), .east_out_ready(r10_east_out_ready),
        .west_in_packet(r10_west_in), .west_in_valid(r10_west_in_valid), .west_in_ready(r10_west_in_ready),
        .west_out_packet(r10_west_out), .west_out_valid(r10_west_out_valid), .west_out_ready(r10_west_out_ready),
        .local_in_packet(r10_local_in), .local_in_valid(r10_local_in_valid), .local_in_ready(r10_local_in_ready),
        .local_out_packet(r10_local_out), .local_out_valid(r10_local_out_valid), .local_out_ready(r10_local_out_ready)
    );
    
    router #(.ROUTER_ADDR_WIDTH(4), .ROUTING_ALGORITHM(0), .VC_DEPTH(4)) router_11 (
        .clk(net_clk), .rst_n(rst_n), .router_addr(4'b0101),
        .north_in_packet(r11_north_in), .north_in_valid(r11_north_in_valid), .north_in_ready(r11_north_in_ready),
        .north_out_packet(r11_north_out), .north_out_valid(r11_north_out_valid), .north_out_ready(r11_north_out_ready),
        .south_in_packet(r11_south_in), .south_in_valid(r11_south_in_valid), .south_in_ready(r11_south_in_ready),
        .south_out_packet(r11_south_out), .south_out_valid(r11_south_out_valid), .south_out_ready(r11_south_out_ready),
        .east_in_packet(r11_east_in), .east_in_valid(r11_east_in_valid), .east_in_ready(r11_east_in_ready),
        .east_out_packet(r11_east_out), .east_out_valid(r11_east_out_valid), .east_out_ready(r11_east_out_ready),
        .west_in_packet(r11_west_in), .west_in_valid(r11_west_in_valid), .west_in_ready(r11_west_in_ready),
        .west_out_packet(r11_west_out), .west_out_valid(r11_west_out_valid), .west_out_ready(r11_west_out_ready),
        .local_in_packet(r11_local_in), .local_in_valid(r11_local_in_valid), .local_in_ready(r11_local_in_ready),
        .local_out_packet(r11_local_out), .local_out_valid(r11_local_out_valid), .local_out_ready(r11_local_out_ready)
    );
    
    // Mesh interconnections
    // R00 South <-> R10 North
    assign r00_south_in = r10_north_out;
    assign r00_south_in_valid = r10_north_out_valid;
    assign r10_north_out_ready = r00_south_in_ready;
    assign r10_north_in = r00_south_out;
    assign r10_north_in_valid = r00_south_out_valid;
    assign r00_south_out_ready = r10_north_in_ready;
    
    // R00 East <-> R01 West
    assign r00_east_in = r01_west_out;
    assign r00_east_in_valid = r01_west_out_valid;
    assign r01_west_out_ready = r00_east_in_ready;
    assign r01_west_in = r00_east_out;
    assign r01_west_in_valid = r00_east_out_valid;
    assign r00_east_out_ready = r01_west_in_ready;
    
    // R01 South <-> R11 North
    assign r01_south_in = r11_north_out;
    assign r01_south_in_valid = r11_north_out_valid;
    assign r11_north_out_ready = r01_south_in_ready;
    assign r11_north_in = r01_south_out;
    assign r11_north_in_valid = r01_south_out_valid;
    assign r01_south_out_ready = r11_north_in_ready;
    
    // R10 East <-> R11 West
    assign r10_east_in = r11_west_out;
    assign r10_east_in_valid = r11_west_out_valid;
    assign r11_west_out_ready = r10_east_in_ready;
    assign r11_west_in = r10_east_out;
    assign r11_west_in_valid = r10_east_out_valid;
    assign r10_east_out_ready = r11_west_in_ready;
    
    // Boundary connections (tie off unused ports)
    assign r00_north_in = 32'h0;
    assign r00_north_in_valid = 1'b0;
    assign r00_north_out_ready = 1'b1;
    assign r00_west_in = 32'h0;
    assign r00_west_in_valid = 1'b0;
    assign r00_west_out_ready = 1'b1;
    
    assign r01_north_in = 32'h0;
    assign r01_north_in_valid = 1'b0;
    assign r01_north_out_ready = 1'b1;
    assign r01_east_in = 32'h0;
    assign r01_east_in_valid = 1'b0;
    assign r01_east_out_ready = 1'b1;
    
    assign r10_south_in = 32'h0;
    assign r10_south_in_valid = 1'b0;
    assign r10_south_out_ready = 1'b1;
    assign r10_west_in = 32'h0;
    assign r10_west_in_valid = 1'b0;
    assign r10_west_out_ready = 1'b1;
    
    assign r11_south_in = 32'h0;
    assign r11_south_in_valid = 1'b0;
    assign r11_south_out_ready = 1'b1;
    assign r11_east_in = 32'h0;
    assign r11_east_in_valid = 1'b0;
    assign r11_east_out_ready = 1'b1;
    
    // Local port ready signals (always ready for this test)
    assign r00_local_out_ready = 1'b1;
    assign r01_local_out_ready = 1'b1;
    assign r10_local_out_ready = 1'b1;
    assign r11_local_out_ready = 1'b1;
    
    // Clock generation
    initial begin
        cpu_clk = 0;
        forever #(CLK_PERIOD_CPU/2) cpu_clk = ~cpu_clk;
    end
    
    initial begin
        net_clk = 0;
        forever #(CLK_PERIOD_NET/2) net_clk = ~net_clk;
    end
    
    // Test stimulus
    initial begin
        // Initialize signals
        rst_n = 0;
        r00_local_in = 0;
        r00_local_in_valid = 0;
        r01_local_in = 0;
        r01_local_in_valid = 0;
        r10_local_in = 0;
        r10_local_in_valid = 0;
        r11_local_in = 0;
        r11_local_in_valid = 0;
        
        // Reset
        #(CLK_PERIOD_NET*10);
        rst_n = 1;
        #(CLK_PERIOD_NET*5);
        
        $display("======================================");
        $display("NoC Full Mesh Testbench Started");
        $display("2x2 Mesh Topology with XY Routing");
        $display("======================================");
        
        // Test Case 1: Single-hop routing (R00 to R01)
        $display("\n[TEST 1] Single-hop: R(0,0) to R(0,1)");
        inject_packet(0, 0, 4'b0001, 16'h0001);
        #(CLK_PERIOD_NET*50);
        
        // Test Case 2: Single-hop routing (R00 to R10)
        $display("\n[TEST 2] Single-hop: R(0,0) to R(1,0)");
        inject_packet(0, 0, 4'b0100, 16'h0002);
        #(CLK_PERIOD_NET*50);
        
        // Test Case 3: Diagonal routing (R00 to R11)
        $display("\n[TEST 3] Diagonal: R(0,0) to R(1,1) [Multi-hop]");
        inject_packet(0, 0, 4'b0101, 16'h0003);
        #(CLK_PERIOD_NET*100);
        
        // Test Case 4: Opposite corner routing (R01 to R10)
        $display("\n[TEST 4] Cross-diagonal: R(0,1) to R(1,0) [Multi-hop]");
        inject_packet(0, 1, 4'b0100, 16'h0004);
        #(CLK_PERIOD_NET*100);
        
        // Test Case 5: Multiple simultaneous packets
        $display("\n[TEST 5] Multiple simultaneous packets");
        test_multi_inject();
        #(CLK_PERIOD_NET*200);
        
        // Test Case 6: Broadcast test (same destination from all nodes)
        $display("\n[TEST 6] Convergence test - all nodes to R(1,1)");
        test_convergence();
        #(CLK_PERIOD_NET*200);
        
        $display("\n======================================");
        $display("All NoC Mesh Tests Completed!");
        $display("======================================");
        $finish;
    end
    
    // Task to inject packet from specific router
    task inject_packet;
        input [1:0] src_x, src_y;
        input [3:0] dest_addr;
        input [15:0] neuron_addr;
        
        reg [31:0] packet;
        begin
            packet = {dest_addr, 12'h000, neuron_addr};
            $display("  Injecting packet 0x%08h from R(%0d,%0d) to R(%0d,%0d)", 
                     packet, src_x, src_y, dest_addr[3:2], dest_addr[1:0]);
            
            case ({src_x, src_y})
                4'b0000: begin // R00
                    r00_local_in = packet;
                    r00_local_in_valid = 1;
                    @(posedge net_clk);
                    wait (r00_local_in_ready);
                    @(posedge net_clk);
                    r00_local_in_valid = 0;
                end
                4'b0001: begin // R01
                    r01_local_in = packet;
                    r01_local_in_valid = 1;
                    @(posedge net_clk);
                    wait (r01_local_in_ready);
                    @(posedge net_clk);
                    r01_local_in_valid = 0;
                end
                4'b0100: begin // R10
                    r10_local_in = packet;
                    r10_local_in_valid = 1;
                    @(posedge net_clk);
                    wait (r10_local_in_ready);
                    @(posedge net_clk);
                    r10_local_in_valid = 0;
                end
                4'b0101: begin // R11
                    r11_local_in = packet;
                    r11_local_in_valid = 1;
                    @(posedge net_clk);
                    wait (r11_local_in_ready);
                    @(posedge net_clk);
                    r11_local_in_valid = 0;
                end
            endcase
            
            $display("  Packet injected successfully");
        end
    endtask
    
    // Task to inject multiple packets simultaneously
    task test_multi_inject;
        begin
            $display("  Injecting 4 packets simultaneously from all nodes");
            
            fork
                begin
                    r00_local_in = {4'b0101, 12'h000, 16'h0100};
                    r00_local_in_valid = 1;
                    @(posedge net_clk);
                    wait (r00_local_in_ready);
                    @(posedge net_clk);
                    r00_local_in_valid = 0;
                end
                begin
                    r01_local_in = {4'b0100, 12'h000, 16'h0200};
                    r01_local_in_valid = 1;
                    @(posedge net_clk);
                    wait (r01_local_in_ready);
                    @(posedge net_clk);
                    r01_local_in_valid = 0;
                end
                begin
                    r10_local_in = {4'b0001, 12'h000, 16'h0300};
                    r10_local_in_valid = 1;
                    @(posedge net_clk);
                    wait (r10_local_in_ready);
                    @(posedge net_clk);
                    r10_local_in_valid = 0;
                end
                begin
                    r11_local_in = {4'b0000, 12'h000, 16'h0400};
                    r11_local_in_valid = 1;
                    @(posedge net_clk);
                    wait (r11_local_in_ready);
                    @(posedge net_clk);
                    r11_local_in_valid = 0;
                end
            join
            
            $display("  All packets injected");
        end
    endtask
    
    // Task to test convergence (all to one destination)
    task test_convergence;
        begin
            $display("  All nodes sending to R(1,1)");
            
            fork
                inject_packet(0, 0, 4'b0101, 16'h1000);
                inject_packet(0, 1, 4'b0101, 16'h2000);
                inject_packet(1, 0, 4'b0101, 16'h3000);
            join
        end
    endtask
    
    // Waveform dump
    initial begin
        $dumpfile("noc_top_tb.vcd");
        $dumpvars(0, noc_top_tb);
    end
    
    // Monitor packet arrivals at local ports
    always @(posedge net_clk) begin
        if (r00_local_out_valid) 
            $display("  [%0t] Packet arrived at R(0,0) local: 0x%08h", $time, r00_local_out);
        if (r01_local_out_valid) 
            $display("  [%0t] Packet arrived at R(0,1) local: 0x%08h", $time, r01_local_out);
        if (r10_local_out_valid) 
            $display("  [%0t] Packet arrived at R(1,0) local: 0x%08h", $time, r10_local_out);
        if (r11_local_out_valid) 
            $display("  [%0t] Packet arrived at R(1,1) local: 0x%08h", $time, r11_local_out);
    end
    
    // Track packet hops through the mesh
    always @(posedge net_clk) begin
        // R00 outputs
        if (r00_south_out_valid && r00_south_out_ready)
            $display("  [HOP] R(0,0)->South: 0x%08h", r00_south_out);
        if (r00_east_out_valid && r00_east_out_ready)
            $display("  [HOP] R(0,0)->East: 0x%08h", r00_east_out);
            
        // R01 outputs
        if (r01_south_out_valid && r01_south_out_ready)
            $display("  [HOP] R(0,1)->South: 0x%08h", r01_south_out);
        if (r01_west_out_valid && r01_west_out_ready)
            $display("  [HOP] R(0,1)->West: 0x%08h", r01_west_out);
            
        // R10 outputs
        if (r10_north_out_valid && r10_north_out_ready)
            $display("  [HOP] R(1,0)->North: 0x%08h", r10_north_out);
        if (r10_east_out_valid && r10_east_out_ready)
            $display("  [HOP] R(1,0)->East: 0x%08h", r10_east_out);
            
        // R11 outputs
        if (r11_north_out_valid && r11_north_out_ready)
            $display("  [HOP] R(1,1)->North: 0x%08h", r11_north_out);
        if (r11_west_out_valid && r11_west_out_ready)
            $display("  [HOP] R(1,1)->West: 0x%08h", r11_west_out);
    end

endmodule
