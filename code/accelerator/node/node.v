`include "../cpu_core/cpu/cpu.v"
`include "../cpu_core/instruction_memory/instruction_memory.v"
`include "../cpu_core/data_memory/data_memory.v"
`include "../network_interface/network_interface.v"
`include "../router/router.v"
`include "../neuron_bank/neuron_bank.v"

`timescale 1ns/100ps

module node #(
    parameter ADDR_X = 0,
    parameter ADDR_Y = 0,
    parameter NUM_NEURONS = 4
) (
    input clk,
    input rst,
    
    // Router Ports (N, E, S, W)
    // North (1)
    input  [31:0] din_1,
    input         vin_1,
    output        rout_1,
    output [31:0] dout_1,
    output        vout_1,
    input         rin_1,

    // East (2)
    input  [31:0] din_2,
    input         vin_2,
    output        rout_2,
    output [31:0] dout_2,
    output        vout_2,
    input         rin_2,

    // South (3)
    input  [31:0] din_3,
    input         vin_3,
    output        rout_3,
    output [31:0] dout_3,
    output        vout_3,
    input         rin_3,

    // West (4)
    input  [31:0] din_4,
    input         vin_4,
    output        rout_4,
    output [31:0] dout_4,
    output        vout_4,
    input         rin_4
);

    // Internal signals
    wire [31:0] pc, instruction;
    wire [3:0] data_mem_read;
    wire [2:0] data_mem_write;
    wire [31:0] data_mem_addr;
    wire [31:0] data_mem_write_data;
    wire [31:0] data_mem_read_data;
    wire data_mem_busywait;
    wire instr_mem_busywait;

    wire net_write, net_read;
    wire [31:0] net_write_data, net_read_data;
    wire ni_irq, ni_busywait;

    wire [31:0] ni_router_data_in, ni_router_data_out;
    wire ni_router_valid_in, ni_router_valid_out;
    wire ni_router_ready_in, ni_router_ready_out;

    // CPU
    cpu CPU (
        .CLK(clk),
        .RESET(rst),
        .PC(pc),
        .INSTRUCTION(instruction),
        .DATA_MEM_READ(data_mem_read),
        .DATA_MEM_WRITE(data_mem_write),
        .DATA_MEM_ADDR(data_mem_addr),
        .DATA_MEM_WRITE_DATA(data_mem_write_data),
        .DATA_MEM_READ_DATA(data_mem_read_data),
        .DATA_MEM_BUSYWAIT(data_mem_busywait || ni_busywait), // Stall if memory or network is busy
        .INSTR_MEM_BUSYWAIT(instr_mem_busywait),
        .NET_WRITE(net_write),
        .NET_READ(net_read),
        .NET_READ_DATA(net_read_data),
        .NET_WRITE_DATA(net_write_data)
    );

    // Instruction Memory
    instruction_memory IMEM (
        .CLK(clk),
        .RESET(rst),
        .READ_ADDRESS(pc),
        .READ_DATA(instruction),
        .BUSYWAIT(instr_mem_busywait)
    );

    // Address Decoding
    // Data Memory: 0x00000000 - 0x00000FFF (4KB reserved, though 1KB implemented)
    // Neuron Bank: 0x00001000 - ...
    wire dmem_sel = (data_mem_addr < 32'h00001000);
    wire nbank_sel = (data_mem_addr >= 32'h00001000);

    // Data Memory Signals
    wire [2:0] dmem_write_ctrl = dmem_sel ? data_mem_write : 3'b0;
    wire [3:0] dmem_read_ctrl = dmem_sel ? data_mem_read : 4'b0;
    wire [31:0] dmem_read_data_out;
    wire dmem_busywait_out;

    // Neuron Bank Signals
    wire nbank_write_en = nbank_sel && data_mem_write[2];
    wire nbank_read_en = nbank_sel && data_mem_read[3];
    wire [31:0] nbank_read_data_out;
    wire nbank_busywait_out;

    // Muxed Outputs to CPU
    assign data_mem_read_data = dmem_sel ? dmem_read_data_out : nbank_read_data_out;
    assign data_mem_busywait = (dmem_sel ? dmem_busywait_out : nbank_busywait_out) || ni_busywait;

    // Data Memory
    data_memory DMEM (
        .clk(clk),
        .addr(data_mem_addr),
        .write_data(data_mem_write_data),
        .write_ctrl(dmem_write_ctrl),
        .read_ctrl(dmem_read_ctrl),
        .read_data(dmem_read_data_out),
        .busywait(dmem_busywait_out)
    );

    // Neuron Bank
    neuron_bank #(
        .NUM_NEURONS(NUM_NEURONS)
    ) NEURON_BANK (
        .clk(clk),
        .rst(rst),
        .addr(data_mem_addr),
        .write_en(nbank_write_en),
        .write_data(data_mem_write_data),
        .read_en(nbank_read_en),
        .read_data(nbank_read_data_out),
        .busywait(nbank_busywait_out)
    );

    // Network Interface
    network_interface NI (
        .clk(clk),
        .rst(rst),
        .cpu_net_write(net_write),
        .cpu_net_read(net_read),
        .cpu_data_in(net_write_data),
        .cpu_data_out(net_read_data),
        .irq(ni_irq),
        .cpu_busywait(ni_busywait),
        
        .router_data_in(ni_router_data_in),
        .router_valid_in(ni_router_valid_in),
        .router_ready_in(ni_router_ready_in),
        
        .router_data_out(ni_router_data_out),
        .router_valid_out(ni_router_valid_out),
        .router_ready_out(ni_router_ready_out)
    );

    // Router
    router #(
        .ADDR_X(ADDR_X),
        .ADDR_Y(ADDR_Y)
    ) ROUTER (
        .clk(clk),
        .rst(rst),
        
        // Local (0)
        .din_0(ni_router_data_in),
        .vin_0(ni_router_valid_in),
        .rout_0(ni_router_ready_in),
        .dout_0(ni_router_data_out),
        .vout_0(ni_router_valid_out),
        .rin_0(ni_router_ready_out),

        // North (1)
        .din_1(din_1), .vin_1(vin_1), .rout_1(rout_1),
        .dout_1(dout_1), .vout_1(vout_1), .rin_1(rin_1),

        // East (2)
        .din_2(din_2), .vin_2(vin_2), .rout_2(rout_2),
        .dout_2(dout_2), .vout_2(vout_2), .rin_2(rin_2),

        // South (3)
        .din_3(din_3), .vin_3(vin_3), .rout_3(rout_3),
        .dout_3(dout_3), .vout_3(vout_3), .rin_3(rin_3),

        // West (4)
        .din_4(din_4), .vin_4(vin_4), .rout_4(rout_4),
        .dout_4(dout_4), .vout_4(vout_4), .rin_4(rin_4)
    );

endmodule
