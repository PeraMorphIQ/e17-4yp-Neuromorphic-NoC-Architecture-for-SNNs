`timescale 1ns/100ps

`include "noc/router.v"
`include "noc/network_interface.v"
`include "neuron_bank/neuron_bank.v"
`include "instruction_memory/instruction_memory.v"

// System Top Module - Complete Neuromorphic NoC System
// Integrates 2D mesh NoC with simplified CPU interfaces, neuron banks, and memories
// Each node has a network interface and neuron bank
// Simplified CPU interface for demonstration
module system_top #(
    parameter MESH_SIZE_X = 2,              // Number of nodes in X dimension
    parameter MESH_SIZE_Y = 2,              // Number of nodes in Y dimension
    parameter ROUTER_ADDR_WIDTH = 8,        // Router address width
    parameter NUM_NEURONS_PER_BANK = 4,     // Neurons per bank
    parameter INSTR_MEM_SIZE = 256,         // Instruction memory size (words)
    parameter DATA_MEM_SIZE = 256           // Data memory size (words)
)(
    input wire cpu_clk,         // CPU/neuron bank clock domain
    input wire net_clk,         // Network clock domain
    input wire rst_n,           // Active-low reset
    
    // External control/debug interface
    input wire [7:0] ext_node_select,       // Select node for external access
    input wire [7:0] ext_addr,              // External address
    input wire ext_write_en,                // External write enable
    input wire ext_read_en,                 // External read enable
    input wire [31:0] ext_write_data,       // External write data
    output reg [31:0] ext_read_data,        // External read data
    output reg ext_ready,                   // External access ready
    
    // Debug outputs
    output wire [MESH_SIZE_X*MESH_SIZE_Y-1:0] node_interrupts,
    output wire [MESH_SIZE_X*MESH_SIZE_Y-1:0] node_spike_detected,
    output wire [31:0] debug_router_00_north_out_packet,
    output wire debug_router_00_north_out_valid
);

    localparam TOTAL_NODES = MESH_SIZE_X * MESH_SIZE_Y;
    
    /********************* Router Interconnections *********************/
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
    
    // Network Interface <-> Neuron Bank
    wire [31:0] ni_to_nb_awaddr [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire ni_to_nb_awvalid [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire nb_to_ni_awready [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire [31:0] ni_to_nb_wdata [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire ni_to_nb_wvalid [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire nb_to_ni_wready [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire ni_to_nb_arvalid [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire nb_to_ni_arready [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire [31:0] nb_to_ni_rdata [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire nb_to_ni_rvalid [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    
    // Interrupt and spike signals
    wire node_interrupt [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire [NUM_NEURONS_PER_BANK-1:0] node_spikes [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    
    // Neuron bank control signals
    wire [7:0] nb_address [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire nb_read_enable [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire nb_write_enable [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire [31:0] nb_write_data [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire [31:0] nb_read_data [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire nb_ready [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    
    /********************* Generate Mesh *********************/
    genvar x, y;
    generate
        for (x = 0; x < MESH_SIZE_X; x = x + 1) begin : mesh_x
            for (y = 0; y < MESH_SIZE_Y; y = y + 1) begin : mesh_y
                
                // Calculate router address: upper 4 bits = x, lower 4 bits = y
                wire [ROUTER_ADDR_WIDTH-1:0] router_addr;
                assign router_addr = {x[3:0], y[3:0]};
                
                // Intermediate wires for router connections
                wire [31:0] north_in_pkt, north_out_pkt, south_in_pkt, south_out_pkt;
                wire [31:0] east_in_pkt, east_out_pkt, west_in_pkt, west_out_pkt;
                wire north_in_val, north_out_val, north_in_rdy, north_out_rdy;
                wire south_in_val, south_out_val, south_in_rdy, south_out_rdy;
                wire east_in_val, east_out_val, east_in_rdy, east_out_rdy;
                wire west_in_val, west_out_val, west_in_rdy, west_out_rdy;
                
                // Connect intermediate wires based on position in mesh
                // North connections
                assign north_in_pkt = (y < MESH_SIZE_Y-1) ? sn_packet[x][y] : 32'h0;
                assign north_in_val = (y < MESH_SIZE_Y-1) ? sn_valid[x][y] : 1'b0;
                assign north_in_rdy = (y < MESH_SIZE_Y-1) ? sn_ready[x][y] : 1'b0;
                assign north_out_rdy = (y < MESH_SIZE_Y-1) ? ns_ready[x][y] : 1'b1;
                if (y < MESH_SIZE_Y-1) begin
                    assign ns_packet[x][y] = north_out_pkt;
                    assign ns_valid[x][y] = north_out_val;
                    assign sn_ready[x][y] = north_in_rdy;
                end
                
                // South connections
                assign south_in_pkt = (y > 0) ? ns_packet[x][y-1] : 32'h0;
                assign south_in_val = (y > 0) ? ns_valid[x][y-1] : 1'b0;
                assign south_in_rdy = (y > 0) ? ns_ready[x][y-1] : 1'b0;
                assign south_out_rdy = (y > 0) ? sn_ready[x][y-1] : 1'b1;
                if (y > 0) begin
                    assign sn_packet[x][y-1] = south_out_pkt;
                    assign sn_valid[x][y-1] = south_out_val;
                    assign ns_ready[x][y-1] = south_in_rdy;
                end
                
                // East connections
                assign east_in_pkt = (x < MESH_SIZE_X-1) ? we_packet[x][y] : 32'h0;
                assign east_in_val = (x < MESH_SIZE_X-1) ? we_valid[x][y] : 1'b0;
                assign east_in_rdy = (x < MESH_SIZE_X-1) ? we_ready[x][y] : 1'b0;
                assign east_out_rdy = (x < MESH_SIZE_X-1) ? ew_ready[x][y] : 1'b1;
                if (x < MESH_SIZE_X-1) begin
                    assign ew_packet[x][y] = east_out_pkt;
                    assign ew_valid[x][y] = east_out_val;
                    assign we_ready[x][y] = east_in_rdy;
                end
                
                // West connections
                assign west_in_pkt = (x > 0) ? ew_packet[x-1][y] : 32'h0;
                assign west_in_val = (x > 0) ? ew_valid[x-1][y] : 1'b0;
                assign west_in_rdy = (x > 0) ? ew_ready[x-1][y] : 1'b0;
                assign west_out_rdy = (x > 0) ? we_ready[x-1][y] : 1'b1;
                if (x > 0) begin
                    assign we_packet[x-1][y] = west_out_pkt;
                    assign we_valid[x-1][y] = west_out_val;
                    assign ew_ready[x-1][y] = west_in_rdy;
                end
                
                /********************* Router Instance *********************/
                router #(
                    .ROUTER_ADDR_WIDTH(ROUTER_ADDR_WIDTH),
                    .ROUTING_ALGORITHM(0),  // 0 = XY routing
                    .VC_DEPTH(4)
                ) router_inst (
                    .clk(net_clk),
                    .rst_n(rst_n),
                    .router_addr(router_addr),
                    
                    // North port
                    .north_in_packet(north_in_pkt),
                    .north_in_valid(north_in_val),
                    .north_in_ready(north_in_rdy),
                    .north_out_packet(north_out_pkt),
                    .north_out_valid(north_out_val),
                    .north_out_ready(north_out_rdy),
                    
                    // South port
                    .south_in_packet(south_in_pkt),
                    .south_in_valid(south_in_val),
                    .south_in_ready(south_in_rdy),
                    .south_out_packet(south_out_pkt),
                    .south_out_valid(south_out_val),
                    .south_out_ready(south_out_rdy),
                    
                    // East port
                    .east_in_packet(east_in_pkt),
                    .east_in_valid(east_in_val),
                    .east_in_ready(east_in_rdy),
                    .east_out_packet(east_out_pkt),
                    .east_out_valid(east_out_val),
                    .east_out_ready(east_out_rdy),
                    
                    // West port
                    .west_in_packet(west_in_pkt),
                    .west_in_valid(west_in_val),
                    .west_in_ready(west_in_rdy),
                    .west_out_packet(west_out_pkt),
                    .west_out_valid(west_out_val),
                    .west_out_ready(west_out_rdy),
                    
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
                    
                    // AXI4-Lite interface (simplified - connected to neuron bank)
                    .axi_awaddr(ni_to_nb_awaddr[x][y]),
                    .axi_awvalid(ni_to_nb_awvalid[x][y]),
                    .axi_awready(nb_to_ni_awready[x][y]),
                    .axi_wdata(ni_to_nb_wdata[x][y]),
                    .axi_wstrb(4'hF),
                    .axi_wvalid(ni_to_nb_wvalid[x][y]),
                    .axi_wready(nb_to_ni_wready[x][y]),
                    .axi_bresp(),
                    .axi_bvalid(),
                    .axi_bready(1'b1),
                    .axi_araddr(ni_to_nb_awaddr[x][y]),  // Reuse awaddr for read
                    .axi_arvalid(ni_to_nb_arvalid[x][y]),
                    .axi_arready(nb_to_ni_arready[x][y]),
                    .axi_rdata(nb_to_ni_rdata[x][y]),
                    .axi_rresp(),
                    .axi_rvalid(nb_to_ni_rvalid[x][y]),
                    .axi_rready(1'b1),
                    
                    // Network interface
                    .net_tx_packet(ni_to_router_packet[x][y]),
                    .net_tx_valid(ni_to_router_valid[x][y]),
                    .net_tx_ready(ni_to_router_ready[x][y]),
                    .net_rx_packet(router_to_ni_packet[x][y]),
                    .net_rx_valid(router_to_ni_valid[x][y]),
                    .net_rx_ready(router_to_ni_ready[x][y]),
                    
                    // Interrupt to CPU (spike detected)
                    .cpu_interrupt(node_interrupt[x][y])
                );
                
                /********************* Neuron Bank Instance *********************/
                // Simple interface adapter: convert AXI-lite to simple read/write
                reg axi_write_active;
                reg axi_read_active;
                
                always @(posedge cpu_clk or negedge rst_n) begin
                    if (!rst_n) begin
                        axi_write_active <= 1'b0;
                        axi_read_active <= 1'b0;
                    end else begin
                        // Write transaction
                        if (ni_to_nb_awvalid[x][y] && ni_to_nb_wvalid[x][y] && !axi_write_active) begin
                            axi_write_active <= 1'b1;
                        end else if (nb_ready[x][y]) begin
                            axi_write_active <= 1'b0;
                        end
                        
                        // Read transaction
                        if (ni_to_nb_arvalid[x][y] && !axi_read_active) begin
                            axi_read_active <= 1'b1;
                        end else if (nb_ready[x][y]) begin
                            axi_read_active <= 1'b0;
                        end
                    end
                end
                
                // Convert AXI to simple interface
                assign nb_address[x][y] = (ext_node_select == {x[3:0], y[3:0]}) ? ext_addr : 
                                          ni_to_nb_awaddr[x][y][7:0];
                                          
                assign nb_write_enable[x][y] = (ext_node_select == {x[3:0], y[3:0]}) ? ext_write_en :
                                               (ni_to_nb_awvalid[x][y] && ni_to_nb_wvalid[x][y]);
                                               
                assign nb_read_enable[x][y] = (ext_node_select == {x[3:0], y[3:0]}) ? ext_read_en :
                                              ni_to_nb_arvalid[x][y];
                                              
                assign nb_write_data[x][y] = (ext_node_select == {x[3:0], y[3:0]}) ? ext_write_data :
                                             ni_to_nb_wdata[x][y];
                
                // AXI ready signals
                assign nb_to_ni_awready[x][y] = nb_ready[x][y];
                assign nb_to_ni_wready[x][y] = nb_ready[x][y];
                assign nb_to_ni_arready[x][y] = nb_ready[x][y];
                assign nb_to_ni_rdata[x][y] = nb_read_data[x][y];
                assign nb_to_ni_rvalid[x][y] = nb_ready[x][y] && axi_read_active;
                
                neuron_bank #(
                    .NUM_NEURONS(NUM_NEURONS_PER_BANK),
                    .ADDR_WIDTH(8)
                ) neuron_bank_inst (
                    .clk(cpu_clk),
                    .rst_n(rst_n),
                    .address(nb_address[x][y]),
                    .read_enable(nb_read_enable[x][y]),
                    .write_enable(nb_write_enable[x][y]),
                    .write_data(nb_write_data[x][y]),
                    .read_data(nb_read_data[x][y]),
                    .ready(nb_ready[x][y]),
                    .rng_enable(1'b1),
                    .rng_seed_load(1'b0),
                    .rng_seed(32'hDEAD_0000 | {x[7:0], y[7:0], 8'h00} | y[7:0])  // Unique seed per node
                );
                
                // Collect spike outputs (read from neuron bank spike status register)
                // For simplicity, we'll monitor the interrupt signal
                assign node_spikes[x][y] = {NUM_NEURONS_PER_BANK{node_interrupt[x][y]}};
                
            end
        end
    endgenerate
    
    /********************* External Interface Logic *********************/
    integer ext_x, ext_y;
    always @(*) begin
        ext_read_data = 32'h0;
        ext_ready = 1'b0;
        
        // Find the selected node
        for (ext_x = 0; ext_x < MESH_SIZE_X; ext_x = ext_x + 1) begin
            for (ext_y = 0; ext_y < MESH_SIZE_Y; ext_y = ext_y + 1) begin
                if (ext_node_select == {ext_x[3:0], ext_y[3:0]}) begin
                    ext_read_data = nb_read_data[ext_x][ext_y];
                    ext_ready = nb_ready[ext_x][ext_y];
                end
            end
        end
    end
    
    /********************* Output Assignments *********************/
    // Collect interrupts and spikes
    genvar out_x, out_y;
    generate
        for (out_x = 0; out_x < MESH_SIZE_X; out_x = out_x + 1) begin : output_x
            for (out_y = 0; out_y < MESH_SIZE_Y; out_y = out_y + 1) begin : output_y
                assign node_interrupts[out_x * MESH_SIZE_Y + out_y] = node_interrupt[out_x][out_y];
                assign node_spike_detected[out_x * MESH_SIZE_Y + out_y] = |node_spikes[out_x][out_y];
            end
        end
    endgenerate
    
    // Debug outputs for router (0,0)
    assign debug_router_00_north_out_packet = (MESH_SIZE_X > 0 && MESH_SIZE_Y > 1) ? ns_packet[0][0] : 32'h0;
    assign debug_router_00_north_out_valid = (MESH_SIZE_X > 0 && MESH_SIZE_Y > 1) ? ns_valid[0][0] : 1'b0;

endmodule
