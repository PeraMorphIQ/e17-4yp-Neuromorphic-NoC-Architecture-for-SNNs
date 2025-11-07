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

`timescale 1ns/100ps

// Include all required modules (using _no_includes versions to avoid duplication)
`include "support_modules/mux_2to1_32bit.v"
`include "support_modules/mux_2to1_3bit.v"
`include "support_modules/mux_4to1_32bit.v"
`include "support_modules/plus_4_adder.v"
`include "fpu/Priority Encoder.v"
`include "fpu/Addition-Subtraction_no_includes.v"
`include "fpu/Multiplication_no_includes.v"
`include "fpu/Division_no_includes.v"
`include "fpu/Iteration.v"
`include "fpu/Comparison.v"
`include "fpu/Converter.v"
`include "fpu/fpu_no_includes.v"
`include "f_alu/f_alu.v"
`include "alu/alu.v"
`include "reg_file/reg_file.v"
`include "f_reg_file/f_reg_file.v"
`include "immediate_generation_unit/immediate_generation_unit.v"
`include "immediate_select_unit/immediate_select_unit.v"
`include "control_unit/control_unit_no_includes.v"
`include "branch_control_unit/branch_control_unit.v"
`include "forwarding_units/ex_forward_unit.v"
`include "forwarding_units/mem_forward_unit.v"
`include "hazard_detection_unit/hazard_detection_unit.v"
`include "pipeline_flush_unit/pipeline_flush_unit.v"
`include "pipeline_registers/pr_if_id.v"
`include "pipeline_registers/pr_id_ex.v"
`include "pipeline_registers/pr_ex_mem.v"
`include "pipeline_registers/pr_mem_wb.v"
`include "cpu/cpu_no_includes.v"
`include "noc/async_fifo.v"
`include "noc/input_router.v"
`include "noc/rr_arbiter.v"
`include "noc/virtual_channel.v"
`include "noc/input_module_no_includes.v"
`include "noc/output_module_no_includes.v"
`include "noc/router_no_includes.v"
`include "noc/network_interface_no_includes.v"
`include "neuron_bank/rng.v"
`include "neuron_bank/neuron_core.v"
`include "neuron_bank/neuron_bank_no_includes.v"

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
                
                // Calculate router address: {Y[1:0], X[1:0]}
                wire [3:0] router_address;
                assign router_address = {y[1:0], x[1:0]};
                
                router #(
                    .ROUTER_ADDR_WIDTH(4),
                    .ROUTING_ALGORITHM(0),  // XY routing
                    .VC_DEPTH(VC_DEPTH)
                ) router_inst (
                    .clk(net_clk),
                    .rst_n(rst_n),
                    .router_addr(router_address),
                    
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
                    .ROUTER_ADDR_WIDTH(4),
                    .NEURON_ADDR_WIDTH(12),
                    .FIFO_DEPTH(4)
                ) ni_inst (
                    .cpu_clk(cpu_clk),
                    .cpu_rst_n(rst_n),
                    .net_clk(net_clk),
                    .net_rst_n(rst_n),
                    
                    // AXI4-Lite interface (CPU side)
                    .axi_awaddr(axi_awaddr),
                    .axi_awvalid(axi_awvalid),
                    .axi_awready(axi_awready),
                    .axi_wdata(axi_wdata),
                    .axi_wstrb(4'hF),
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
                    
                    // Network Interface (Router side)
                    .net_tx_packet(local_to_router_packet[x][y]),
                    .net_tx_valid(local_to_router_valid[x][y]),
                    .net_tx_ready(local_to_router_ready[x][y]),
                    .net_rx_packet(router_to_local_packet[x][y]),
                    .net_rx_valid(router_to_local_valid[x][y]),
                    .net_rx_ready(router_to_local_ready[x][y]),
                    
                    // Interrupt to CPU
                    .cpu_interrupt(nb_cpu_interrupt[x][y])
                );
                
                // =============================================================
                // RISC-V CPU Instantiation
                // =============================================================
                
                wire [31:0] cpu_pc;
                wire [31:0] cpu_instruction;
                wire [3:0]  cpu_mem_read;
                wire [2:0]  cpu_mem_write;
                wire [31:0] cpu_mem_addr, cpu_mem_write_data, cpu_mem_read_data;
                wire        cpu_mem_busywait;
                wire        cpu_instr_busywait;
                
                cpu cpu_inst (
                    .CLK(cpu_clk),
                    .RESET(~rst_n),
                    
                    // Instruction memory interface
                    .PC(cpu_pc),
                    .INSTRUCTION(cpu_instruction),
                    .INSTR_MEM_BUSYWAIT(cpu_instr_busywait),
                    
                    // Data memory interface (for neuron bank access)
                    .DATA_MEM_READ(cpu_mem_read),
                    .DATA_MEM_WRITE(cpu_mem_write),
                    .DATA_MEM_ADDR(cpu_mem_addr),
                    .DATA_MEM_WRITE_DATA(cpu_mem_write_data),
                    .DATA_MEM_READ_DATA(cpu_mem_read_data),
                    .DATA_MEM_BUSYWAIT(cpu_mem_busywait)
                );
                
                // Memory access logic - route to neuron bank or network interface
                // Address space:
                //   0x80000000-0x8000FFFF: Neuron Bank (memory-mapped)
                //   0x90000000-0x9000FFFF: Network Interface (for LWNET/SWNET)
                
                wire accessing_neuron_bank;
                wire accessing_network;
                assign accessing_neuron_bank = (cpu_mem_addr[31:16] == 16'h8000);
                assign accessing_network = (cpu_mem_addr[31:16] == 16'h9000);
                
                // Connect CPU to Neuron Bank
                assign cpu_nb_address[x][y] = cpu_mem_addr[ADDR_WIDTH-1:0];
                assign cpu_nb_read[x][y] = (|cpu_mem_read) && accessing_neuron_bank;
                assign cpu_nb_write[x][y] = (|cpu_mem_write) && accessing_neuron_bank;
                assign cpu_nb_write_data[x][y] = cpu_mem_write_data;
                
                // Connect CPU to Network Interface via AXI4-Lite
                assign axi_awaddr = cpu_mem_addr;
                assign axi_awvalid = (|cpu_mem_write) && accessing_network;
                assign axi_wdata = cpu_mem_write_data;
                assign axi_wvalid = (|cpu_mem_write) && accessing_network;
                assign axi_bready = 1'b1;
                assign axi_araddr = cpu_mem_addr;
                assign axi_arvalid = (|cpu_mem_read) && accessing_network;
                assign axi_rready = 1'b1;
                
                // Multiplex read data back to CPU
                assign cpu_mem_read_data = accessing_neuron_bank ? nb_cpu_read_data[x][y] :
                                          accessing_network ? axi_rdata :
                                          32'h0;
                
                // Generate busywait signal
                assign cpu_mem_busywait = accessing_neuron_bank ? ~nb_cpu_ready[x][y] :
                                         accessing_network ? ~(axi_rvalid || axi_bvalid) :
                                         1'b0;
                
                // =============================================================
                // Instruction Memory Instantiation
                // =============================================================
                
                // Instruction memory with external loading capability
                reg [7:0] imem_array [1023:0];
                
                // Program loading logic
                always @(posedge cpu_clk) begin
                    if (~rst_n) begin
                        // Reset - can initialize with NOP instructions
                        // NOP = 0x00000013 (addi x0, x0, 0)
                    end else if (prog_load_enable[y*MESH_SIZE_X + x] && prog_load_write[y*MESH_SIZE_X + x]) begin
                        // Load instruction from external interface
                        imem_array[{prog_load_addr[9:2], 2'b00}] <= prog_load_data[7:0];
                        imem_array[{prog_load_addr[9:2], 2'b01}] <= prog_load_data[15:8];
                        imem_array[{prog_load_addr[9:2], 2'b10}] <= prog_load_data[23:16];
                        imem_array[{prog_load_addr[9:2], 2'b11}] <= prog_load_data[31:24];
                    end
                end
                
                // Instruction fetch
                assign cpu_instruction = {
                    imem_array[{cpu_pc[9:2], 2'b11}],
                    imem_array[{cpu_pc[9:2], 2'b10}],
                    imem_array[{cpu_pc[9:2], 2'b01}],
                    imem_array[{cpu_pc[9:2], 2'b00}]
                };
                
                assign cpu_instr_busywait = 1'b0;  // No wait states for instruction fetch
                
                // =============================================================
                // External Input Injection Logic
                // =============================================================
                // Allow testbench to inject current to neurons via external interface
                // This routes external writes to the neuron bank
                // ext_neuron_id can be:
                //   - Neuron ID (0-3) for input injection: address = 0x80 + neuron_id*4
                //   - Full address (>= 0x80) for direct register access
                
                wire ext_target_match;
                wire [7:0] ext_nb_address;
                wire ext_nb_write;
                reg ext_write_latched;
                
                assign ext_target_match = (ext_node_select == {y[1:0], x[1:0]}) && ext_input_valid;
                
                // If ext_neuron_id < 4, treat as neuron ID and compute input address
                // Otherwise, treat as full address
                assign ext_nb_address = (ext_neuron_id < 8'd4) ? 
                                       (8'h80 + (ext_neuron_id[1:0] * 4)) :  // Input register
                                       ext_neuron_id[7:0];                    // Direct address
                
                assign ext_nb_write = ext_target_match && !ext_write_latched;
                
                // Latch external write for one cycle to prevent multiple writes
                always @(posedge cpu_clk or negedge rst_n) begin
                    if (!rst_n) begin
                        ext_write_latched <= 1'b0;
                    end else begin
                        if (ext_target_match) begin
                            ext_write_latched <= 1'b1;
                        end else if (!ext_input_valid) begin
                            ext_write_latched <= 1'b0;
                        end
                    end
                end
                
                // Multiplex CPU and external writes to neuron bank
                wire [7:0] nb_address_mux;
                wire nb_write_enable_mux;
                wire [31:0] nb_write_data_mux;
                
                assign nb_address_mux = ext_nb_write ? ext_nb_address : cpu_nb_address[x][y];
                assign nb_write_enable_mux = ext_nb_write ? 1'b1 : cpu_nb_write[x][y];
                assign nb_write_data_mux = ext_nb_write ? ext_input_current : cpu_nb_write_data[x][y];
                
                // =============================================================
                // Neuron Bank Instantiation
                // =============================================================
                
                wire [NUM_NEURONS_PER_BANK-1:0] neuron_spikes;
                
                neuron_bank #(
                    .NUM_NEURONS(NUM_NEURONS_PER_BANK),
                    .ADDR_WIDTH(ADDR_WIDTH)
                ) nb_inst (
                    .clk(cpu_clk),
                    .rst_n(rst_n),
                    
                    // CPU interface (multiplexed with external injection)
                    .address(nb_address_mux),
                    .read_enable(cpu_nb_read[x][y]),
                    .write_enable(nb_write_enable_mux),
                    .write_data(nb_write_data_mux),
                    .read_data(nb_cpu_read_data[x][y]),
                    .ready(nb_cpu_ready[x][y]),
                    
                    // RNG Control (optional - can be tied off or controlled)
                    .rng_enable(1'b0),
                    .rng_seed_load(1'b0),
                    .rng_seed(32'h0)
                );
                
                // Spike monitoring - read spike status from neuron bank
                // Note: In real implementation, spikes would be monitored by reading
                // the spike status register (0xC2) from neuron bank. For now, we
                // track spike interrupts as an indication of spike activity.
                reg [NUM_NEURONS_PER_BANK-1:0] spike_status;
                
                always @(posedge cpu_clk or negedge rst_n) begin
                    if (~rst_n) begin
                        spike_status <= {NUM_NEURONS_PER_BANK{1'b0}};
                    end else begin
                        // Spike interrupt indicates spike activity
                        if (nb_cpu_interrupt[x][y]) begin
                            // In real system, CPU would read spike status register
                            // For monitoring, we pulse the spike output
                            spike_status <= {NUM_NEURONS_PER_BANK{1'b1}};
                        end else begin
                            spike_status <= {NUM_NEURONS_PER_BANK{1'b0}};
                        end
                    end
                end
                
                assign neuron_spikes = spike_status;
                
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
