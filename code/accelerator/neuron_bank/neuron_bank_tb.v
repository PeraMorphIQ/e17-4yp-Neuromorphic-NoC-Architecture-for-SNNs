`include "neuron_bank.v"
`timescale 1ns/100ps

module neuron_bank_tb;

    reg clk;
    reg rst;
    reg [31:0] addr;
    reg write_en;
    reg [31:0] write_data;
    reg read_en;
    wire [31:0] read_data;
    wire busywait;

    neuron_bank #(
        .NUM_NEURONS(4)
    ) uut (
        .clk(clk),
        .rst(rst),
        .addr(addr),
        .write_en(write_en),
        .write_data(write_data),
        .read_en(read_en),
        .read_data(read_data),
        .busywait(busywait)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("neuron_bank_tb.vcd");
        $dumpvars(0, neuron_bank_tb);

        clk = 0;
        rst = 1;
        write_en = 0;
        read_en = 0;
        addr = 0;
        write_data = 0;

        #20;
        rst = 0;

        // Test 1: Write to Neuron 0 Param A (Addr 0x00)
        #10;
        addr = 32'h00000000;
        write_data = 32'h3F800000; // 1.0 in float
        write_en = 1;
        #10;
        write_en = 0;

        // Test 2: Read back Neuron 0 Param A
        #10;
        addr = 32'h00000000;
        read_en = 1;
        #10;
        read_en = 0;
        
        // Test 3: Write to Neuron 1 Param B (Addr 0x40 + 0x04 = 0x44)
        #10;
        addr = 32'h00000044;
        write_data = 32'h40000000; // 2.0 in float
        write_en = 1;
        #10;
        write_en = 0;

        // Test 4: Read back Neuron 1 Param B
        #10;
        addr = 32'h00000044;
        read_en = 1;
        #10;
        read_en = 0;

        // Test 5: Start Update for Neuron 0 (Addr 0x18, Bit 0)
        #10;
        addr = 32'h00000018;
        write_data = 32'h00000001;
        write_en = 1;
        #10;
        write_en = 0;

        #100;
        $finish;
    end

endmodule
