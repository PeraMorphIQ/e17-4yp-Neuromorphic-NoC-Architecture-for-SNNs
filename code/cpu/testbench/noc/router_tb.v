`timescale 1ns/100ps

// Note: Include router.v when compiling, it includes all dependencies
// Testbench for Router - Tests 5x5 crossbar switching
module router_tb;

    // Parameters
    parameter ROUTER_ADDR_WIDTH = 4;
    parameter ROUTING_ALGORITHM = 0; // 0 = XY, 1 = YX
    parameter VC_DEPTH = 4;
    parameter CLK_PERIOD = 10; // 100MHz
    
    // Clock and Reset
    reg clk;
    reg rst_n;
    
    // Router address (position in mesh)
    reg [ROUTER_ADDR_WIDTH-1:0] router_addr;
    
    // North Port
    reg [31:0] north_in_packet;
    reg north_in_valid;
    wire north_in_ready;
    wire [31:0] north_out_packet;
    wire north_out_valid;
    reg north_out_ready;
    
    // South Port
    reg [31:0] south_in_packet;
    reg south_in_valid;
    wire south_in_ready;
    wire [31:0] south_out_packet;
    wire south_out_valid;
    reg south_out_ready;
    
    // East Port
    reg [31:0] east_in_packet;
    reg east_in_valid;
    wire east_in_ready;
    wire [31:0] east_out_packet;
    wire east_out_valid;
    reg east_out_ready;
    
    // West Port
    reg [31:0] west_in_packet;
    reg west_in_valid;
    wire west_in_ready;
    wire [31:0] west_out_packet;
    wire west_out_valid;
    reg west_out_ready;
    
    // Local Port
    reg [31:0] local_in_packet;
    reg local_in_valid;
    wire local_in_ready;
    wire [31:0] local_out_packet;
    wire local_out_valid;
    reg local_out_ready;
    
    // Instantiate Router
    router #(
        .ROUTER_ADDR_WIDTH(ROUTER_ADDR_WIDTH),
        .ROUTING_ALGORITHM(ROUTING_ALGORITHM),
        .VC_DEPTH(VC_DEPTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .router_addr(router_addr),
        .north_in_packet(north_in_packet),
        .north_in_valid(north_in_valid),
        .north_in_ready(north_in_ready),
        .north_out_packet(north_out_packet),
        .north_out_valid(north_out_valid),
        .north_out_ready(north_out_ready),
        .south_in_packet(south_in_packet),
        .south_in_valid(south_in_valid),
        .south_in_ready(south_in_ready),
        .south_out_packet(south_out_packet),
        .south_out_valid(south_out_valid),
        .south_out_ready(south_out_ready),
        .east_in_packet(east_in_packet),
        .east_in_valid(east_in_valid),
        .east_in_ready(east_in_ready),
        .east_out_packet(east_out_packet),
        .east_out_valid(east_out_valid),
        .east_out_ready(east_out_ready),
        .west_in_packet(west_in_packet),
        .west_in_valid(west_in_valid),
        .west_in_ready(west_in_ready),
        .west_out_packet(west_out_packet),
        .west_out_valid(west_out_valid),
        .west_out_ready(west_out_ready),
        .local_in_packet(local_in_packet),
        .local_in_valid(local_in_valid),
        .local_in_ready(local_in_ready),
        .local_out_packet(local_out_packet),
        .local_out_valid(local_out_valid),
        .local_out_ready(local_out_ready)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Test stimulus
    initial begin
        // Initialize signals
        rst_n = 0;
        router_addr = 4'b0101; // Router at (1,1) in 2x2 mesh
        
        north_in_packet = 0;
        north_in_valid = 0;
        north_out_ready = 1;
        
        south_in_packet = 0;
        south_in_valid = 0;
        south_out_ready = 1;
        
        east_in_packet = 0;
        east_in_valid = 0;
        east_out_ready = 1;
        
        west_in_packet = 0;
        west_in_valid = 0;
        west_out_ready = 1;
        
        local_in_packet = 0;
        local_in_valid = 0;
        local_out_ready = 1;
        
        // Reset
        #(CLK_PERIOD*5);
        rst_n = 1;
        #(CLK_PERIOD*2);
        
        $display("======================================");
        $display("Router Testbench Started");
        $display("Router Address: (%d, %d)", router_addr[3:2], router_addr[1:0]);
        $display("======================================");
        
        // Test Case 1: Packet from North to South
        $display("\n[TEST 1] North to South routing");
        test_routing("North", "South", 4'b1001, 16'h0001); // Dest: (2,1)
        
        // Test Case 2: Packet from West to East
        $display("\n[TEST 2] West to East routing");
        test_routing("West", "East", 4'b0110, 16'h0002); // Dest: (1,2)
        
        // Test Case 3: Packet from Local to North
        $display("\n[TEST 3] Local to North routing");
        test_routing("Local", "North", 4'b0001, 16'h0003); // Dest: (0,1)
        
        // Test Case 4: Packet to Local
        $display("\n[TEST 4] East to Local routing");
        test_routing("East", "Local", 4'b0101, 16'h0004); // Dest: (1,1) - same router
        
        // Test Case 5: Multiple simultaneous packets
        $display("\n[TEST 5] Multiple simultaneous packets");
        test_multiple_packets();
        
        // Test Case 6: Backpressure handling
        $display("\n[TEST 6] Backpressure handling");
        test_backpressure();
        
        #(CLK_PERIOD*50);
        $display("\n======================================");
        $display("All Router Tests Completed!");
        $display("======================================");
        $finish;
    end
    
    // Task to test routing from one port to another
    task test_routing;
        input [47:0] src_port;  // Source port name
        input [47:0] dst_port;  // Destination port name
        input [3:0] dest_addr;  // Destination router address
        input [15:0] neuron_addr; // Neuron address
        
        reg [31:0] packet;
        integer timeout;
        
        begin
            packet = {dest_addr, 12'h000, neuron_addr};
            timeout = 0;
            
            $display("  Sending packet: 0x%08h to %s port", packet, dst_port);
            $display("  Destination: Router(%d,%d), Neuron: 0x%04h", 
                     dest_addr[3:2], dest_addr[1:0], neuron_addr);
            
            // Inject packet based on source port
            case (src_port)
                "North": begin
                    north_in_packet = packet;
                    north_in_valid = 1;
                    @(posedge clk);
                    while (!north_in_ready && timeout < 100) begin
                        @(posedge clk);
                        timeout = timeout + 1;
                    end
                    north_in_valid = 0;
                end
                "South": begin
                    south_in_packet = packet;
                    south_in_valid = 1;
                    @(posedge clk);
                    while (!south_in_ready && timeout < 100) begin
                        @(posedge clk);
                        timeout = timeout + 1;
                    end
                    south_in_valid = 0;
                end
                "East": begin
                    east_in_packet = packet;
                    east_in_valid = 1;
                    @(posedge clk);
                    while (!east_in_ready && timeout < 100) begin
                        @(posedge clk);
                        timeout = timeout + 1;
                    end
                    east_in_valid = 0;
                end
                "West": begin
                    west_in_packet = packet;
                    west_in_valid = 1;
                    @(posedge clk);
                    while (!west_in_ready && timeout < 100) begin
                        @(posedge clk);
                        timeout = timeout + 1;
                    end
                    west_in_valid = 0;
                end
                "Local": begin
                    local_in_packet = packet;
                    local_in_valid = 1;
                    @(posedge clk);
                    while (!local_in_ready && timeout < 100) begin
                        @(posedge clk);
                        timeout = timeout + 1;
                    end
                    local_in_valid = 0;
                end
            endcase
            
            if (timeout >= 100) begin
                $display("  ERROR: Timeout waiting for ready signal!");
            end else begin
                $display("  Packet injected successfully");
            end
            
            // Wait for packet to arrive at destination
            timeout = 0;
            case (dst_port)
                "North": begin
                    while (!north_out_valid && timeout < 100) begin
                        @(posedge clk);
                        timeout = timeout + 1;
                    end
                    if (north_out_valid) begin
                        $display("  SUCCESS: Packet received at North port: 0x%08h", north_out_packet);
                        @(posedge clk);
                    end
                end
                "South": begin
                    while (!south_out_valid && timeout < 100) begin
                        @(posedge clk);
                        timeout = timeout + 1;
                    end
                    if (south_out_valid) begin
                        $display("  SUCCESS: Packet received at South port: 0x%08h", south_out_packet);
                        @(posedge clk);
                    end
                end
                "East": begin
                    while (!east_out_valid && timeout < 100) begin
                        @(posedge clk);
                        timeout = timeout + 1;
                    end
                    if (east_out_valid) begin
                        $display("  SUCCESS: Packet received at East port: 0x%08h", east_out_packet);
                        @(posedge clk);
                    end
                end
                "West": begin
                    while (!west_out_valid && timeout < 100) begin
                        @(posedge clk);
                        timeout = timeout + 1;
                    end
                    if (west_out_valid) begin
                        $display("  SUCCESS: Packet received at West port: 0x%08h", west_out_packet);
                        @(posedge clk);
                    end
                end
                "Local": begin
                    while (!local_out_valid && timeout < 100) begin
                        @(posedge clk);
                        timeout = timeout + 1;
                    end
                    if (local_out_valid) begin
                        $display("  SUCCESS: Packet received at Local port: 0x%08h", local_out_packet);
                        @(posedge clk);
                    end
                end
            endcase
            
            if (timeout >= 100) begin
                $display("  ERROR: Timeout waiting for packet at destination!");
            end
            
            #(CLK_PERIOD*5); // Wait between tests
        end
    endtask
    
    // Task to test multiple simultaneous packets
    task test_multiple_packets;
        integer timeout;
        begin
            $display("  Injecting packets from North, South, and West simultaneously");
            
            // North to South
            north_in_packet = {4'b1001, 12'h000, 16'h0010};
            north_in_valid = 1;
            
            // South to North
            south_in_packet = {4'b0001, 12'h000, 16'h0020};
            south_in_valid = 1;
            
            // West to East
            west_in_packet = {4'b0110, 12'h000, 16'h0030};
            west_in_valid = 1;
            
            @(posedge clk);
            
            // Wait for acceptance
            timeout = 0;
            while (!(north_in_ready && south_in_ready && west_in_ready) && timeout < 100) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            
            north_in_valid = 0;
            south_in_valid = 0;
            west_in_valid = 0;
            
            if (timeout < 100) begin
                $display("  All packets injected successfully");
            end else begin
                $display("  ERROR: Timeout during packet injection");
            end
            
            // Wait for outputs
            #(CLK_PERIOD*20);
            
            if (south_out_valid) $display("  Packet arrived at South: 0x%08h", south_out_packet);
            if (north_out_valid) $display("  Packet arrived at North: 0x%08h", north_out_packet);
            if (east_out_valid) $display("  Packet arrived at East: 0x%08h", east_out_packet);
            
            #(CLK_PERIOD*10);
        end
    endtask
    
    // Task to test backpressure
    task test_backpressure;
        integer i;
        begin
            $display("  Testing backpressure by disabling output ready");
            
            // Disable south output
            south_out_ready = 0;
            
            // Try to send packet from North to South
            north_in_packet = {4'b1001, 12'h000, 16'h0100};
            north_in_valid = 1;
            
            @(posedge clk);
            
            // Wait and observe
            for (i = 0; i < 20; i = i + 1) begin
                @(posedge clk);
                if (south_out_valid) begin
                    $display("  Packet waiting at South output (backpressure active)");
                end
            end
            
            // Re-enable output
            south_out_ready = 1;
            $display("  Re-enabled South output ready");
            
            // Wait for packet to be received
            for (i = 0; i < 20; i = i + 1) begin
                @(posedge clk);
                if (south_out_valid && south_out_ready) begin
                    $display("  SUCCESS: Packet transmitted after backpressure released");
                    i = 20; // Exit loop
                end
            end
            
            north_in_valid = 0;
            #(CLK_PERIOD*5);
        end
    endtask
    
    // Waveform dump
    initial begin
        $dumpfile("router_tb.vcd");
        $dumpvars(0, router_tb);
    end
    
    // Monitor packets
    always @(posedge clk) begin
        if (north_out_valid && north_out_ready)
            $display("  [%0t] North output: 0x%08h", $time, north_out_packet);
        if (south_out_valid && south_out_ready)
            $display("  [%0t] South output: 0x%08h", $time, south_out_packet);
        if (east_out_valid && east_out_ready)
            $display("  [%0t] East output: 0x%08h", $time, east_out_packet);
        if (west_out_valid && west_out_ready)
            $display("  [%0t] West output: 0x%08h", $time, west_out_packet);
        if (local_out_valid && local_out_ready)
            $display("  [%0t] Local output: 0x%08h", $time, local_out_packet);
    end

endmodule
