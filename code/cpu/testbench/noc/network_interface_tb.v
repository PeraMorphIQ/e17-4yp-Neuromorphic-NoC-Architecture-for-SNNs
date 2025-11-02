`timescale 1ns/100ps

module network_interface_tb;

    // Clock and reset
    reg cpu_clk, net_clk;
    reg cpu_rst_n, net_rst_n;
    
    // AXI4-Lite signals
    reg [31:0] axi_awaddr;
    reg axi_awvalid;
    wire axi_awready;
    
    reg [31:0] axi_wdata;
    reg [3:0] axi_wstrb;
    reg axi_wvalid;
    wire axi_wready;
    
    wire [1:0] axi_bresp;
    wire axi_bvalid;
    reg axi_bready;
    
    reg [31:0] axi_araddr;
    reg axi_arvalid;
    wire axi_arready;
    
    wire [31:0] axi_rdata;
    wire [1:0] axi_rresp;
    wire axi_rvalid;
    reg axi_rready;
    
    // Network interface
    wire [31:0] net_tx_packet;
    wire net_tx_valid;
    reg net_tx_ready;
    
    reg [31:0] net_rx_packet;
    reg net_rx_valid;
    wire net_rx_ready;
    
    wire cpu_interrupt;
    
    // Instantiate DUT
    network_interface #(
        .ROUTER_ADDR_WIDTH(4),
        .NEURON_ADDR_WIDTH(12),
        .FIFO_DEPTH(4)
    ) dut (
        .cpu_clk(cpu_clk),
        .cpu_rst_n(cpu_rst_n),
        .net_clk(net_clk),
        .net_rst_n(net_rst_n),
        .axi_awaddr(axi_awaddr),
        .axi_awvalid(axi_awvalid),
        .axi_awready(axi_awready),
        .axi_wdata(axi_wdata),
        .axi_wstrb(axi_wstrb),
        .axi_wvalid(axi_wvalid),
        .axi_wready(axi_wready),
        .axi_bresp(axi_bresp),
        .axi_bvalid(axi_bvalid),
        .axi_bready(axi_bready),
        .axi_araddr(axi_araddr),
        .axi_arvalid(axi_arvalid),
        .axi_arready(axi_arready),
        .axi_rdata(axi_rdata),
        .axi_rresp(axi_rresp),
        .axi_rvalid(axi_rvalid),
        .axi_rready(axi_rready),
        .net_tx_packet(net_tx_packet),
        .net_tx_valid(net_tx_valid),
        .net_tx_ready(net_tx_ready),
        .net_rx_packet(net_rx_packet),
        .net_rx_valid(net_rx_valid),
        .net_rx_ready(net_rx_ready),
        .cpu_interrupt(cpu_interrupt)
    );
    
    // Clock generation
    initial begin
        cpu_clk = 0;
        forever #5 cpu_clk = ~cpu_clk;  // 100 MHz
    end
    
    initial begin
        net_clk = 0;
        forever #7 net_clk = ~net_clk;  // ~71 MHz
    end
    
    // Test sequence
    initial begin
        // Initialize
        cpu_rst_n = 0;
        net_rst_n = 0;
        axi_awvalid = 0;
        axi_wvalid = 0;
        axi_bready = 1;
        axi_arvalid = 0;
        axi_rready = 1;
        net_tx_ready = 1;
        net_rx_valid = 0;
        axi_wstrb = 4'hF;
        
        // Reset release
        #50;
        cpu_rst_n = 1;
        net_rst_n = 1;
        #50;
        
        // Test 1: Write packet to network (SWNET operation)
        $display("Test 1: Writing packet to network interface");
        axi_write(32'h00000000, 32'h12345678);
        #100;
        
        // Test 2: Inject packet from network
        $display("Test 2: Receiving packet from network");
        @(posedge net_clk);
        net_rx_packet = 32'hABCDEF01;
        net_rx_valid = 1;
        @(posedge net_clk);
        net_rx_valid = 0;
        
        // Wait for interrupt
        wait(cpu_interrupt == 1);
        $display("Interrupt received!");
        
        // Test 3: Read packet from network (LWNET operation)
        $display("Test 3: Reading packet from network interface");
        axi_read(32'h00000000);
        $display("Read data: 0x%h", axi_rdata);
        
        #200;
        $display("Test completed successfully!");
        $finish;
    end
    
    // AXI Write task
    task axi_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge cpu_clk);
            axi_awaddr = addr;
            axi_awvalid = 1;
            axi_wdata = data;
            axi_wvalid = 1;
            
            @(posedge cpu_clk);
            while (!axi_awready || !axi_wready) @(posedge cpu_clk);
            
            axi_awvalid = 0;
            axi_wvalid = 0;
            
            @(posedge cpu_clk);
            while (!axi_bvalid) @(posedge cpu_clk);
            
            $display("AXI Write: addr=0x%h, data=0x%h, resp=%d", addr, data, axi_bresp);
        end
    endtask
    
    // AXI Read task
    task axi_read;
        input [31:0] addr;
        begin
            @(posedge cpu_clk);
            axi_araddr = addr;
            axi_arvalid = 1;
            
            @(posedge cpu_clk);
            while (!axi_arready) @(posedge cpu_clk);
            
            axi_arvalid = 0;
            
            @(posedge cpu_clk);
            while (!axi_rvalid) @(posedge cpu_clk);
            
            $display("AXI Read: addr=0x%h, data=0x%h, resp=%d", addr, axi_rdata, axi_rresp);
        end
    endtask
    
    // Monitor network transmissions
    always @(posedge net_clk) begin
        if (net_tx_valid && net_tx_ready) begin
            $display("Time %0t: Network TX: packet=0x%h", $time, net_tx_packet);
        end
    end
    
    // VCD dump for waveform viewing
    initial begin
        $dumpfile("network_interface_tb.vcd");
        $dumpvars(0, network_interface_tb);
    end

endmodule
