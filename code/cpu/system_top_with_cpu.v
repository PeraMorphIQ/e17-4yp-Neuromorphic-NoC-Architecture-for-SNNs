// =============================================================================
// System Top with RISC-V CPUs - Complete Neuromorphic NoC Architecture
// =============================================================================
// Description: Final integrated design as described in the research paper.
//              Each node contains:
//              - RV32IMF RISC-V CPU with custom SNN instructions (LWNET, SWNET)
//              - Network Interface (AXI4-Lite + CDC)
//              - Router (5-port, XY routing)
//              - Neuron Bank (configurable neuron cores)
//              - Instruction Memory (program storage)
//
// Architecture: 2x2 Mesh NoC (scalable to larger meshes)
// =============================================================================

module system_top_with_cpu #(
    parameter MESH_SIZE_X = 2,
    parameter MESH_SIZE_Y = 2,
    parameter NUM_NEURONS_PER_BANK = 4,
    parameter PACKET_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8,
    parameter NUM_VC = 4,
    parameter VC_DEPTH = 4
)(
    // System clocks and reset
    input wire                          cpu_clk,        // CPU clock domain (50 MHz)
    input wire                          net_clk,        // Network clock domain (100 MHz)
    input wire                          rst_n,          // Active-low reset
    
    // External memory interface for loading programs (optional)
    input wire [MESH_SIZE_X*MESH_SIZE_Y-1:0] prog_load_enable,
    input wire [31:0]                   prog_load_addr,
    input wire [31:0]                   prog_load_data,
    input wire [MESH_SIZE_X*MESH_SIZE_Y-1:0] prog_load_write,
    
    // External input injection (for training/inference)
    input wire [7:0]                    ext_node_select,    // {Y[3:0], X[3:0]}
    input wire [7:0]                    ext_neuron_id,
    input wire [31:0]                   ext_input_current,
    input wire                          ext_input_valid,
    
    // Debug outputs
    output wire [MESH_SIZE_X*MESH_SIZE_Y-1:0] cpu_interrupt,
    output wire [MESH_SIZE_X*MESH_SIZE_Y*NUM_NEURONS_PER_BANK-1:0] spike_out,
    output wire [MESH_SIZE_X*MESH_SIZE_Y-1:0] cpu_halted,
    
    // Router monitoring (for debugging)
    output wire [MESH_SIZE_X*MESH_SIZE_Y*5-1:0] router_input_valid,
    output wire [MESH_SIZE_X*MESH_SIZE_Y*5-1:0] router_input_ready,
    output wire [MESH_SIZE_X*MESH_SIZE_Y*5-1:0] router_output_valid,
    output wire [MESH_SIZE_X*MESH_SIZE_Y*5-1:0] router_output_ready
);

    // =========================================================================
    // Internal Wire Declarations for NoC Mesh Interconnect
    // =========================================================================
    
    // North-South connections (vertical)
    wire [PACKET_WIDTH-1:0] ns_packet [0:MESH_SIZE_X-1][0:MESH_SIZE_Y];
    wire                    ns_valid  [0:MESH_SIZE_X-1][0:MESH_SIZE_Y];
    wire                    ns_ready  [0:MESH_SIZE_X-1][0:MESH_SIZE_Y];
    
    // East-West connections (horizontal)
    wire [PACKET_WIDTH-1:0] ew_packet [0:MESH_SIZE_X][0:MESH_SIZE_Y-1];
    wire                    ew_valid  [0:MESH_SIZE_X][0:MESH_SIZE_Y-1];
    wire                    ew_ready  [0:MESH_SIZE_X][0:MESH_SIZE_Y-1];
    
    // Local connections (CPU/NI <-> Router)
    wire [PACKET_WIDTH-1:0] local_to_router_packet   [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire                    local_to_router_valid     [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire                    local_to_router_ready     [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire [PACKET_WIDTH-1:0] router_to_local_packet   [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire                    router_to_local_valid     [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire                    router_to_local_ready     [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    
    // =========================================================================
    // CPU-to-Neuron Bank Interface Wires
    // =========================================================================
    
    wire [ADDR_WIDTH-1:0]   cpu_nb_address   [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire                    cpu_nb_read      [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire                    cpu_nb_write     [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire [DATA_WIDTH-1:0]   cpu_nb_write_data[0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire [DATA_WIDTH-1:0]   nb_cpu_read_data [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire                    nb_cpu_ready     [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    wire                    nb_cpu_interrupt [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-1];
    
    // =========================================================================
    // Generate 2D Mesh of Nodes
    // =========================================================================
    
    genvar x, y;
    generate
        for (y = 0; y < MESH_SIZE_Y; y = y + 1) begin : gen_y
            for (x = 0; x < MESH_SIZE_X; x = x + 1) begin : gen_x
                
                // =============================================================
                // Router Instantiation
                // =============================================================
                
                // Intermediate wires for router ports
                wire [PACKET_WIDTH-1:0] north_in_pkt, north_out_pkt;
                wire north_in_valid, north_in_ready;
                wire north_out_valid, north_out_ready;
                
                wire [PACKET_WIDTH-1:0] south_in_pkt, south_out_pkt;
                wire south_in_valid, south_in_ready;
                wire south_out_valid, south_out_ready;
                
                wire [PACKET_WIDTH-1:0] east_in_pkt, east_out_pkt;
                wire east_in_valid, east_in_ready;
                wire east_out_valid, east_out_ready;
                
                wire [PACKET_WIDTH-1:0] west_in_pkt, west_out_pkt;
                wire west_in_valid, west_in_ready;
                wire west_out_valid, west_out_ready;
                
                // Connect router to mesh (with boundary checks)
                // North connections
                if (y < MESH_SIZE_Y - 1) begin
                    assign north_in_pkt = ns_packet[x][y+1];
                    assign north_in_valid = ns_valid[x][y+1];
                    assign ns_ready[x][y+1] = north_in_ready;
                    assign ns_packet[x][y] = north_out_pkt;
                    assign ns_valid[x][y] = north_out_valid;
                    assign north_out_ready = ns_ready[x][y];
                end else begin
                    assign north_in_pkt = 32'h0;
                    assign north_in_valid = 1'b0;
                    assign ns_packet[x][y] = north_out_pkt;
                    assign ns_valid[x][y] = north_out_valid;
                    assign north_out_ready = 1'b1;
                end
                
                // South connections
                if (y > 0) begin
                    assign south_in_pkt = ns_packet[x][y-1];
                    assign south_in_valid = ns_valid[x][y-1];
                    assign ns_ready[x][y-1] = south_in_ready;
                    assign ns_packet[x][y+1] = south_out_pkt;
                    assign ns_valid[x][y+1] = south_out_valid;
                    assign south_out_ready = ns_ready[x][y+1];
                end else begin
                    assign south_in_pkt = 32'h0;
                    assign south_in_valid = 1'b0;
                    assign ns_packet[x][y] = south_out_pkt;
                    assign ns_valid[x][y] = south_out_valid;
                    assign south_out_ready = 1'b1;
                end
                
                // East connections
                if (x < MESH_SIZE_X - 1) begin
                    assign east_in_pkt = ew_packet[x+1][y];
                    assign east_in_valid = ew_valid[x+1][y];
                    assign ew_ready[x+1][y] = east_in_ready;
                    assign ew_packet[x][y] = east_out_pkt;
                    assign ew_valid[x][y] = east_out_valid;
                    assign east_out_ready = ew_ready[x][y];
                end else begin
                    assign east_in_pkt = 32'h0;
                    assign east_in_valid = 1'b0;
                    assign ew_packet[x+1][y] = east_out_pkt;
                    assign ew_valid[x+1][y] = east_out_valid;
                    assign east_out_ready = 1'b1;
                end
                
                // West connections
                if (x > 0) begin
                    assign west_in_pkt = ew_packet[x-1][y];
                    assign west_in_valid = ew_valid[x-1][y];
                    assign ew_ready[x-1][y] = west_in_ready;
                    assign ew_packet[x][y] = west_out_pkt;
                    assign ew_valid[x][y] = west_out_valid;
                    assign west_out_ready = ew_ready[x][y];
                end else begin
                    assign west_in_pkt = 32'h0;
                    assign west_in_valid = 1'b0;
                    assign ew_packet[x][y] = west_out_pkt;
                    assign ew_valid[x][y] = west_out_valid;
                    assign west_out_ready = 1'b1;
                end
                
                router #(
                    .PACKET_WIDTH(PACKET_WIDTH),
                    .X_COORD(x),
                    .Y_COORD(y),
                    .NUM_VC(NUM_VC),
                    .VC_DEPTH(VC_DEPTH)
                ) router_inst (
                    .clk(net_clk),
                    .rst_n(rst_n),
                    
                    // North port
                    .north_in_packet(north_in_pkt),
                    .north_in_valid(north_in_valid),
                    .north_in_ready(north_in_ready),
                    .north_out_packet(north_out_pkt),
                    .north_out_valid(north_out_valid),
                    .north_out_ready(north_out_ready),
                    
                    // South port
                    .south_in_packet(south_in_pkt),
                    .south_in_valid(south_in_valid),
                    .south_in_ready(south_in_ready),
                    .south_out_packet(south_out_pkt),
                    .south_out_valid(south_out_valid),
                    .south_out_ready(south_out_ready),
                    
                    // East port
                    .east_in_packet(east_in_pkt),
                    .east_in_valid(east_in_valid),
                    .east_in_ready(east_in_ready),
                    .east_out_packet(east_out_pkt),
                    .east_out_valid(east_out_valid),
                    .east_out_ready(east_out_ready),
                    
                    // West port
                    .west_in_packet(west_in_pkt),
                    .west_in_valid(west_in_valid),
                    .west_in_ready(west_in_ready),
                    .west_out_packet(west_out_pkt),
                    .west_out_valid(west_out_valid),
                    .west_out_ready(west_out_ready),
                    
                    // Local port (to/from Network Interface)
                    .local_in_packet(local_to_router_packet[x][y]),
                    .local_in_valid(local_to_router_valid[x][y]),
                    .local_in_ready(local_to_router_ready[x][y]),
                    .local_out_packet(router_to_local_packet[x][y]),
                    .local_out_valid(router_to_local_valid[x][y]),
                    .local_out_ready(router_to_local_ready[x][y])
                );
                
                // =============================================================
                // Network Interface Instantiation
                // =============================================================
                
                // AXI4-Lite signals from CPU
                wire        axi_awvalid, axi_awready;
                wire [31:0] axi_awaddr;
                wire        axi_wvalid, axi_wready;
                wire [31:0] axi_wdata;
                wire        axi_bvalid, axi_bready;
                wire [1:0]  axi_bresp;
                wire        axi_arvalid, axi_arready;
                wire [31:0] axi_araddr;
                wire        axi_rvalid, axi_rready;
                wire [31:0] axi_rdata;
                wire [1:0]  axi_rresp;
                
                network_interface #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ADDR_WIDTH(16),
                    .X_COORD(x),
                    .Y_COORD(y)
                ) ni_inst (
                    .cpu_clk(cpu_clk),
                    .net_clk(net_clk),
                    .rst_n(rst_n),
                    
                    // AXI4-Lite interface (CPU side)
                    .s_axi_awaddr(axi_awaddr),
                    .s_axi_awvalid(axi_awvalid),
                    .s_axi_awready(axi_awready),
                    .s_axi_wdata(axi_wdata),
                    .s_axi_wvalid(axi_wvalid),
                    .s_axi_wready(axi_wready),
                    .s_axi_bresp(axi_bresp),
                    .s_axi_bvalid(axi_bvalid),
                    .s_axi_bready(axi_bready),
                    .s_axi_araddr(axi_araddr),
                    .s_axi_arvalid(axi_arvalid),
                    .s_axi_arready(axi_arready),
                    .s_axi_rdata(axi_rdata),
                    .s_axi_rresp(axi_rresp),
                    .s_axi_rvalid(axi_rvalid),
                    .s_axi_rready(axi_rready),
                    
                    // NoC interface (Router side)
                    .noc_in_packet(router_to_local_packet[x][y]),
                    .noc_in_valid(router_to_local_valid[x][y]),
                    .noc_in_ready(router_to_local_ready[x][y]),
                    .noc_out_packet(local_to_router_packet[x][y]),
                    .noc_out_valid(local_to_router_valid[x][y]),
                    .noc_out_ready(local_to_router_ready[x][y]),
                    
                    // Interrupt to CPU
                    .interrupt(nb_cpu_interrupt[x][y])
                );
                
                // =============================================================
                // RISC-V CPU Instantiation
                // =============================================================
                
                wire [31:0] cpu_inst_addr;
                wire [31:0] cpu_instruction;
                wire        cpu_mem_read, cpu_mem_write;
                wire [31:0] cpu_mem_addr, cpu_mem_write_data, cpu_mem_read_data;
                wire        cpu_mem_ready;
                wire        cpu_net_read, cpu_net_write;
                wire [31:0] cpu_net_write_data, cpu_net_read_data;
                wire        cpu_net_ready;
                
                cpu #(
                    .NODE_X(x),
                    .NODE_Y(y)
                ) cpu_inst (
                    .CLK(cpu_clk),
                    .RESET(~rst_n),
                    
                    // Instruction memory interface
                    .INSTRUCTION_ADDRESS(cpu_inst_addr),
                    .INSTRUCTION(cpu_instruction),
                    
                    // Data memory interface (for neuron bank access)
                    .MEM_READ(cpu_mem_read),
                    .MEM_WRITE(cpu_mem_write),
                    .MEM_ADDRESS(cpu_mem_addr),
                    .MEM_WRITE_DATA(cpu_mem_write_data),
                    .MEM_READ_DATA(cpu_mem_read_data),
                    .MEM_READY(cpu_mem_ready),
                    
                    // Network interface (custom instructions: LWNET, SWNET)
                    .NET_READ(cpu_net_read),
                    .NET_WRITE(cpu_net_write),
                    .NET_WRITE_DATA(cpu_net_write_data),
                    .NET_READ_DATA(cpu_net_read_data),
                    .NET_READY(cpu_net_ready),
                    
                    // Interrupt from network interface
                    .NET_INTERRUPT(nb_cpu_interrupt[x][y]),
                    
                    // Debug
                    .HALTED(cpu_halted[y*MESH_SIZE_X + x])
                );
                
                // Connect CPU memory interface to neuron bank
                assign cpu_nb_address[x][y] = cpu_mem_addr[ADDR_WIDTH-1:0];
                assign cpu_nb_read[x][y] = cpu_mem_read;
                assign cpu_nb_write[x][y] = cpu_mem_write;
                assign cpu_nb_write_data[x][y] = cpu_mem_write_data;
                assign cpu_mem_read_data = nb_cpu_read_data[x][y];
                assign cpu_mem_ready = nb_cpu_ready[x][y];
                
                // Connect CPU network interface to AXI4-Lite
                // (Simplified - in real design, use proper AXI adapter)
                assign axi_awaddr = {16'h0, cpu_net_write_data[31:16]};
                assign axi_awvalid = cpu_net_write;
                assign axi_wdata = cpu_net_write_data;
                assign axi_wvalid = cpu_net_write;
                assign axi_bready = 1'b1;
                assign axi_araddr = 32'h0;
                assign axi_arvalid = cpu_net_read;
                assign axi_rready = 1'b1;
                assign cpu_net_read_data = axi_rdata;
                assign cpu_net_ready = (cpu_net_read && axi_rvalid) || (cpu_net_write && axi_bvalid);
                
                // =============================================================
                // Instruction Memory Instantiation
                // =============================================================
                
                instruction_memory #(
                    .MEM_SIZE(1024),  // 1K instructions
                    .INIT_FILE("")    // Can specify initialization file per node
                ) imem_inst (
                    .CLK(cpu_clk),
                    .RESET(~rst_n),
                    
                    // Read port (CPU fetch)
                    .READ_ADDRESS(cpu_inst_addr[11:2]),  // Word-aligned
                    .READ_DATA(cpu_instruction),
                    
                    // Write port (for loading programs)
                    .WRITE_ENABLE(prog_load_enable[y*MESH_SIZE_X + x] && prog_load_write[y*MESH_SIZE_X + x]),
                    .WRITE_ADDRESS(prog_load_addr[11:2]),
                    .WRITE_DATA(prog_load_data)
                );
                
                // =============================================================
                // Neuron Bank Instantiation
                // =============================================================
                
                wire [NUM_NEURONS_PER_BANK-1:0] neuron_spikes;
                
                neuron_bank #(
                    .NUM_NEURONS(NUM_NEURONS_PER_BANK),
                    .DATA_WIDTH(DATA_WIDTH),
                    .ADDR_WIDTH(ADDR_WIDTH)
                ) nb_inst (
                    .clk(cpu_clk),
                    .rst_n(rst_n),
                    
                    // CPU interface
                    .address(cpu_nb_address[x][y]),
                    .read_enable(cpu_nb_read[x][y]),
                    .write_enable(cpu_nb_write[x][y]),
                    .write_data(cpu_nb_write_data[x][y]),
                    .read_data(nb_cpu_read_data[x][y]),
                    .ready(nb_cpu_ready[x][y]),
                    
                    // External input injection (for testing/training)
                    .ext_input_valid((ext_node_select == {y[3:0], x[3:0]}) && ext_input_valid),
                    .ext_neuron_id(ext_neuron_id[3:0]),
                    .ext_input_current(ext_input_current),
                    
                    // Spike outputs
                    .spike_out(neuron_spikes),
                    .interrupt(nb_cpu_interrupt[x][y])
                );
                
                // Connect neuron spikes to output
                assign spike_out[(y*MESH_SIZE_X + x + 1)*NUM_NEURONS_PER_BANK - 1 -: NUM_NEURONS_PER_BANK] = neuron_spikes;
                
                // =============================================================
                // Debug Signal Assignments
                // =============================================================
                
                assign cpu_interrupt[y*MESH_SIZE_X + x] = nb_cpu_interrupt[x][y];
                
                // Router monitoring (5 ports per router)
                assign router_input_valid[(y*MESH_SIZE_X + x)*5 +: 5] = {
                    local_to_router_valid[x][y],
                    west_in_valid,
                    east_in_valid,
                    south_in_valid,
                    north_in_valid
                };
                
                assign router_input_ready[(y*MESH_SIZE_X + x)*5 +: 5] = {
                    local_to_router_ready[x][y],
                    west_in_ready,
                    east_in_ready,
                    south_in_ready,
                    north_in_ready
                };
                
                assign router_output_valid[(y*MESH_SIZE_X + x)*5 +: 5] = {
                    router_to_local_valid[x][y],
                    west_out_valid,
                    east_out_valid,
                    south_out_valid,
                    north_out_valid
                };
                
                assign router_output_ready[(y*MESH_SIZE_X + x)*5 +: 5] = {
                    router_to_local_ready[x][y],
                    west_out_ready,
                    east_out_ready,
                    south_out_ready,
                    north_out_ready
                };
                
            end
        end
    endgenerate

endmodule
