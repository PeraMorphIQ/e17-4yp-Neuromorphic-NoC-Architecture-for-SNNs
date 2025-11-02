`timescale 1ns/100ps

`include "noc/router.v"
`include "noc/network_interface.v"
`include "cpu/cpu.v"
`include "neuron_bank/neuron_bank.v"

// NoC Top Module - 2D Mesh Network-on-Chip with CPUs and Neuron Banks
// Configurable mesh size with routers, network interfaces, CPUs, and neuron banks
module noc_top #(
    parameter MESH_SIZE_X = 2,    // Number of nodes in X dimension
    parameter MESH_SIZE_Y = 2,    // Number of nodes in Y dimension
    parameter ROUTER_ADDR_WIDTH = 8,
    parameter NUM_NEURONS_PER_BANK = 4
)(
    input wire cpu_clk,
    input wire net_clk,
    input wire rst_n,
    
    // External memory interface (for instruction and data memory)
    // Simplified for demonstration - in real design would have proper memory controllers
    output wire [31:0] mem_addr,
    output wire [31:0] mem_write_data,
    output wire mem_write_en,
    output wire mem_read_en,
    input wire [31:0] mem_read_data,
    input wire mem_ready,
    
    // Debug outputs
    output wire [MESH_SIZE_X*MESH_SIZE_Y-1:0] cpu_interrupts,
    output wire [31:0] debug_node_0_pc
);

    localparam TOTAL_NODES = MESH_SIZE_X * MESH_SIZE_Y;
    
    /********************* Router Interconnections *********************/
    // Each router has 5 ports: North, South, East, West, Local
    // We need wires to connect adjacent routers
    
    // North-South connections
    wire [31:0] ns_packet [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-2];
    wire ns_valid [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-2];
    wire ns_ready [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-2];
    
    wire [31:0] sn_packet [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-2];
    wire sn_valid [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-2];
    wire sn_ready [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-2];
    
    // East-West connections
    wire [31:0] ew_packet [0:MESH_SIZE_X-2][0:MESH_SIZE_Y-1];
    wire ew_valid [0:MESH_SIZE_X-2][0:MESH_SIZE_Y-1];
    wire ew_ready [0:MESH_SIZE_X-2][0:MESH_SIZE_Y-1];
    
    wire [31:0] we_packet [0:MESH_SIZE_X-2][0:MESH_SIZE_Y-1];
    wire we_valid [0:MESH_SIZE_X-2][0:MESH_SIZE_Y-1];
    wire we_ready [0:MESH_SIZE_X-2][0:MESH_SIZE_Y-1];
    
    // Local port connections (Router <-> Network Interface)
    wire [31:0] router_to_ni_packet [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire router_to_ni_valid [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire router_to_ni_ready [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    
    wire [31:0] ni_to_router_packet [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire ni_to_router_valid [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire ni_to_router_ready [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    
    // CPU <-> Network Interface (AXI4-Lite signals)
    wire [31:0] cpu_to_ni_awaddr [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire cpu_to_ni_awvalid [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire ni_to_cpu_awready [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    // ... (other AXI signals - simplified for brevity)
    
    // CPU signals
    wire [31:0] cpu_pc [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire cpu_interrupt [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    
    /********************* Generate Mesh *********************/
    genvar x, y;
    generate
        for (x = 0; x < MESH_SIZE_X; x = x + 1) begin : mesh_x
            for (y = 0; y < MESH_SIZE_Y; y = y + 1) begin : mesh_y
                
                // Calculate router address
                wire [ROUTER_ADDR_WIDTH-1:0] router_addr;
                assign router_addr = {x[3:0], y[3:0]};
                
                /********************* Router Instance *********************/
                router #(
                    .ROUTER_ADDR_WIDTH(ROUTER_ADDR_WIDTH),
                    .ROUTING_ALGORITHM(0),  // XY routing
                    .VC_DEPTH(4)
                ) router_inst (
                    .clk(net_clk),
                    .rst_n(rst_n),
                    .router_addr(router_addr),
                    
                    // North port
                    .north_in_packet((y < MESH_SIZE_Y-1) ? sn_packet[x][y] : 32'h0),
                    .north_in_valid((y < MESH_SIZE_Y-1) ? sn_valid[x][y] : 1'b0),
                    .north_in_ready((y < MESH_SIZE_Y-1) ? sn_ready[x][y] : 1'b0),
                    .north_out_packet((y < MESH_SIZE_Y-1) ? ns_packet[x][y] : ),
                    .north_out_valid((y < MESH_SIZE_Y-1) ? ns_valid[x][y] : ),
                    .north_out_ready((y < MESH_SIZE_Y-1) ? ns_ready[x][y] : 1'b1),
                    
                    // South port
                    .south_in_packet((y > 0) ? ns_packet[x][y-1] : 32'h0),
                    .south_in_valid((y > 0) ? ns_valid[x][y-1] : 1'b0),
                    .south_in_ready((y > 0) ? ns_ready[x][y-1] : 1'b0),
                    .south_out_packet((y > 0) ? sn_packet[x][y-1] : ),
                    .south_out_valid((y > 0) ? sn_valid[x][y-1] : ),
                    .south_out_ready((y > 0) ? sn_ready[x][y-1] : 1'b1),
                    
                    // East port
                    .east_in_packet((x < MESH_SIZE_X-1) ? we_packet[x][y] : 32'h0),
                    .east_in_valid((x < MESH_SIZE_X-1) ? we_valid[x][y] : 1'b0),
                    .east_in_ready((x < MESH_SIZE_X-1) ? we_ready[x][y] : 1'b0),
                    .east_out_packet((x < MESH_SIZE_X-1) ? ew_packet[x][y] : ),
                    .east_out_valid((x < MESH_SIZE_X-1) ? ew_valid[x][y] : ),
                    .east_out_ready((x < MESH_SIZE_X-1) ? ew_ready[x][y] : 1'b1),
                    
                    // West port
                    .west_in_packet((x > 0) ? ew_packet[x-1][y] : 32'h0),
                    .west_in_valid((x > 0) ? ew_valid[x-1][y] : 1'b0),
                    .west_in_ready((x > 0) ? ew_ready[x-1][y] : 1'b0),
                    .west_out_packet((x > 0) ? we_packet[x-1][y] : ),
                    .west_out_valid((x > 0) ? we_valid[x-1][y] : ),
                    .west_out_ready((x > 0) ? we_ready[x-1][y] : 1'b1),
                    
                    // Local port (to Network Interface)
                    .local_in_packet(ni_to_router_packet[x][y]),
                    .local_in_valid(ni_to_router_valid[x][y]),
                    .local_in_ready(ni_to_router_ready[x][y]),
                    .local_out_packet(router_to_ni_packet[x][y]),
                    .local_out_valid(router_to_ni_valid[x][y]),
                    .local_out_ready(router_to_ni_ready[x][y])
                );
                
                /********************* Network Interface Instance *********************/
                network_interface #(
                    .ROUTER_ADDR_WIDTH(4),
                    .NEURON_ADDR_WIDTH(12),
                    .FIFO_DEPTH(4)
                ) ni_inst (
                    .cpu_clk(cpu_clk),
                    .cpu_rst_n(rst_n),
                    .net_clk(net_clk),
                    .net_rst_n(rst_n),
                    
                    // AXI4-Lite interface to CPU (simplified - only showing key signals)
                    .axi_awaddr(32'h0),  // Connected to CPU's data memory interface
                    .axi_awvalid(1'b0),
                    .axi_awready(),
                    .axi_wdata(32'h0),
                    .axi_wstrb(4'hF),
                    .axi_wvalid(1'b0),
                    .axi_wready(),
                    .axi_bresp(),
                    .axi_bvalid(),
                    .axi_bready(1'b1),
                    .axi_araddr(32'h0),
                    .axi_arvalid(1'b0),
                    .axi_arready(),
                    .axi_rdata(),
                    .axi_rresp(),
                    .axi_rvalid(),
                    .axi_rready(1'b1),
                    
                    // Network interface
                    .net_tx_packet(ni_to_router_packet[x][y]),
                    .net_tx_valid(ni_to_router_valid[x][y]),
                    .net_tx_ready(ni_to_router_ready[x][y]),
                    .net_rx_packet(router_to_ni_packet[x][y]),
                    .net_rx_valid(router_to_ni_valid[x][y]),
                    .net_rx_ready(router_to_ni_ready[x][y]),
                    
                    // Interrupt to CPU
                    .cpu_interrupt(cpu_interrupt[x][y])
                );
                
                /********************* CPU Instance *********************/
                // Note: Simplified CPU instantiation
                // In real design, would properly connect all CPU signals
                // Including integration with network interface via custom instructions
                
                /********************* Neuron Bank Instance *********************/
                neuron_bank #(
                    .NUM_NEURONS(NUM_NEURONS_PER_BANK),
                    .ADDR_WIDTH(8)
                ) neuron_bank_inst (
                    .clk(cpu_clk),
                    .rst_n(rst_n),
                    .address(8'h0),      // Connected to CPU's address bus
                    .read_enable(1'b0),
                    .write_enable(1'b0),
                    .write_data(32'h0),
                    .read_data(),
                    .ready(),
                    .rng_enable(1'b1),
                    .rng_seed_load(1'b0),
                    .rng_seed(32'hDEADBEEF)
                );
                
            end
        end
    endgenerate
    
    /********************* Outputs *********************/
    // Collect interrupts
    genvar int_x, int_y;
    generate
        for (int_x = 0; int_x < MESH_SIZE_X; int_x = int_x + 1) begin : int_collect_x
            for (int_y = 0; int_y < MESH_SIZE_Y; int_y = int_y + 1) begin : int_collect_y
                assign cpu_interrupts[int_x * MESH_SIZE_Y + int_y] = cpu_interrupt[int_x][int_y];
            end
        end
    endgenerate
    
    // Debug: output PC of node (0,0)
    assign debug_node_0_pc = (MESH_SIZE_X > 0 && MESH_SIZE_Y > 0) ? cpu_pc[0][0] : 32'h0;
    
    // Memory interface (simplified - would need proper arbitration in real design)
    assign mem_addr = 32'h0;
    assign mem_write_data = 32'h0;
    assign mem_write_en = 1'b0;
    assign mem_read_en = 1'b0;

endmodule
