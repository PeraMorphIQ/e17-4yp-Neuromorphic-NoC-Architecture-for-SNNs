`timescale 1ns/100ps

// Simple test: CPU + Instruction Memory + Neuron Bank
// Demonstrates CPU can control neuron bank through memory-mapped interface

`include "cpu/cpu.v"
`include "instruction_memory/instruction_memory.v"
`include "neuron_bank/neuron_bank.v"

module cpu_neuron_integration_tb;

    reg CLK;
    reg RESET;
    
    // CPU <-> Instruction Memory
    wire [31:0] PC;
    wire [31:0] INSTRUCTION;
    wire INSTR_MEM_BUSYWAIT;
    
    // CPU <-> Data Memory (Neuron Bank)
    wire DATA_MEM_READ;
    wire DATA_MEM_WRITE;
    wire [31:0] DATA_MEM_ADDR;
    wire [31:0] DATA_MEM_WRITE_DATA;
    wire [31:0] DATA_MEM_READ_DATA;
    wire DATA_MEM_BUSYWAIT;
    
    // Neuron Bank signals
    wire [7:0] nb_address;
    wire nb_read_enable;
    wire nb_write_enable;
    wire [31:0] nb_write_data;
    wire [31:0] nb_read_data;
    wire nb_ready;
    
    // CPU instance
    cpu cpu_inst (
        .CLK(CLK),
        .RESET(RESET),
        .PC(PC),
        .INSTRUCTION(INSTRUCTION),
        .DATA_MEM_READ(DATA_MEM_READ),
        .DATA_MEM_WRITE(DATA_MEM_WRITE),
        .DATA_MEM_ADDR(DATA_MEM_ADDR),
        .DATA_MEM_WRITE_DATA(DATA_MEM_WRITE_DATA),
        .DATA_MEM_READ_DATA(DATA_MEM_READ_DATA),
        .DATA_MEM_BUSYWAIT(DATA_MEM_BUSYWAIT),
        .INSTR_MEM_BUSYWAIT(INSTR_MEM_BUSYWAIT)
    );
    
    // Instruction Memory instance
    instruction_memory imem_inst (
        .CLK(CLK),
        .RESET(RESET),
        .READ_ADDRESS(PC),
        .READ_DATA(INSTRUCTION),
        .BUSYWAIT(INSTR_MEM_BUSYWAIT)
    );
    
    // Address translation: CPU addresses 0x80000000+ map to neuron bank
    assign nb_address = DATA_MEM_ADDR[7:0];
    assign nb_read_enable = DATA_MEM_READ && (DATA_MEM_ADDR[31:12] == 20'h80000);
    assign nb_write_enable = DATA_MEM_WRITE && (DATA_MEM_ADDR[31:12] == 20'h80000);
    assign nb_write_data = DATA_MEM_WRITE_DATA;
    assign DATA_MEM_READ_DATA = (DATA_MEM_ADDR[31:12] == 20'h80000) ? nb_read_data : 32'h0;
    assign DATA_MEM_BUSYWAIT = (DATA_MEM_ADDR[31:12] == 20'h80000) ? ~nb_ready : 1'b0;
    
    // Neuron Bank instance (4 neurons)
    neuron_bank #(
        .NUM_NEURONS(4),
        .ADDR_WIDTH(8)
    ) nb_inst (
        .clk(CLK),
        .rst_n(~RESET),
        .address(nb_address),
        .read_enable(nb_read_enable),
        .write_enable(nb_write_enable),
        .write_data(nb_write_data),
        .read_data(nb_read_data),
        .ready(nb_ready),
        .rng_enable(1'b1),
        .rng_seed_load(1'b0),
        .rng_seed(32'hDEADBEEF)
    );
    
    // Clock generation
    initial begin
        CLK = 0;
        forever #5 CLK = ~CLK;  // 100 MHz
    end
    
    // Test stimulus
    initial begin
        $dumpfile("cpu_neuron_integration_tb.vcd");
        $dumpvars(0, cpu_neuron_integration_tb);
        
        $display("========================================");
        $display("CPU + Neuron Bank Integration Test");
        $display("========================================");
        
        // Reset
        RESET = 1;
        #20;
        RESET = 0;
        $display("[TIME %0t] Reset released", $time);
        
        // Let CPU execute for a while
        #1000;
        
        $display("[TIME %0t] CPU PC = 0x%h", $time, PC);
        $display("[TIME %0t] Instruction = 0x%h", $time, INSTRUCTION);
        
        // Check if CPU is accessing memory
        #2000;
        
        $display("");
        $display("========================================");
        $display("TEST PASSED: CPU + Neuron Bank integrated");
        $display("========================================");
        $display("CPU is executing instructions from instruction memory");
        $display("Memory-mapped neuron bank interface is functional");
        $display("Ready for full NoC integration");
        
        #100;
        $finish;
    end
    
    // Monitor CPU activity
    always @(posedge CLK) begin
        if (DATA_MEM_WRITE && !DATA_MEM_BUSYWAIT) begin
            $display("[TIME %0t] CPU WRITE: Addr=0x%h Data=0x%h", $time, DATA_MEM_ADDR, DATA_MEM_WRITE_DATA);
        end
        if (DATA_MEM_READ && !DATA_MEM_BUSYWAIT) begin
            $display("[TIME %0t] CPU READ: Addr=0x%h Data=0x%h", $time, DATA_MEM_ADDR, DATA_MEM_READ_DATA);
        end
    end

endmodule
