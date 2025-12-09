`timescale 1ns/100ps

module instruction_memory (CLK, RESET, READ_ADDRESS, READ_DATA, BUSYWAIT);
    input CLK, RESET;
    input [31:0] READ_ADDRESS;
    output reg BUSYWAIT;
    output reg [31:0] READ_DATA;

    reg [7:0] memory_array [1023:0];    // 1024 x 8-bits memory array
    integer i;

    // Synthesis-friendly initialization
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            // Initialize with hardcoded program for synthesis
            // This approach is synthesizable (creates flip-flops)
            {memory_array[10'd3],  memory_array[10'd2],  memory_array[10'd1],  memory_array[10'd0]}  <= 32'h00040019; // loadi 4 #25
            {memory_array[10'd7],  memory_array[10'd6],  memory_array[10'd5],  memory_array[10'd4]}  <= 32'h00050023; // loadi 5 #35
            {memory_array[10'd11], memory_array[10'd10], memory_array[10'd9],  memory_array[10'd8]}  <= 32'h02060405; // add 6 4 5
            {memory_array[10'd15], memory_array[10'd14], memory_array[10'd13], memory_array[10'd12]} <= 32'h0001005A; // loadi 1 90
            {memory_array[10'd19], memory_array[10'd18], memory_array[10'd17], memory_array[10'd16]} <= 32'hFF0FFC6F; // sub 1 1 4
            
            // Initialize remaining memory to NOPs or zeros
            for (i = 20; i < 1024; i = i + 1) begin
                memory_array[i] <= 8'h00;
            end
            
            BUSYWAIT <= 0;
        end
    end

    // For simulation: optionally load from file
    // This is only for simulation and will be ignored by synthesis tools
    `ifdef SIMULATION
    initial begin
        $readmemh("instruction_mem.hex", memory_array);
        BUSYWAIT = 0;
    end
    `endif

    always @ (*)
    begin
        READ_DATA[7:0]      <= memory_array[{READ_ADDRESS[31:2],2'b00}];
        READ_DATA[15:8]     <= memory_array[{READ_ADDRESS[31:2],2'b01}];
        READ_DATA[23:16]    <= memory_array[{READ_ADDRESS[31:2],2'b10}];
        READ_DATA[31:24]    <= memory_array[{READ_ADDRESS[31:2],2'b11}];
    end

endmodule