`timescale 1ns/100ps

module data_memory (
    input clk,
    input [31:0] addr,
    input [31:0] write_data,
    input [2:0] write_ctrl, // {write_en, size[1:0]} ? No, cpu.v says DATA_MEM_WRITE is 3 bits.
                            // control_unit.v: DATA_MEM_WRITE[2] is enable. [1:0] is size.
    input [3:0] read_ctrl,  // {read_en, size[2:0]} ? No, cpu.v says DATA_MEM_READ is 4 bits.
                            // control_unit.v: DATA_MEM_READ[3] is enable. [2:0] is funct3.
    output reg [31:0] read_data,
    output busywait
);

    // 1KB Data Memory
    reg [7:0] mem [0:1023];

    // Busywait simulation (simple, always ready for now)
    assign busywait = 1'b0;

    wire write_en = write_ctrl[2];
    wire [1:0] write_size = write_ctrl[1:0]; // 00: Byte, 01: Half, 10: Word

    wire read_en = read_ctrl[3];
    wire [2:0] read_funct3 = read_ctrl[2:0];

    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1) mem[i] = 0;
    end

    // Write Logic
    always @(posedge clk) begin
        if (write_en) begin
            case (write_size)
                2'b00: mem[addr[9:0]] <= write_data[7:0]; // SB
                2'b01: begin // SH
                    mem[addr[9:0]] <= write_data[7:0];
                    mem[addr[9:0]+1] <= write_data[15:8];
                end
                2'b10: begin // SW
                    mem[addr[9:0]] <= write_data[7:0];
                    mem[addr[9:0]+1] <= write_data[15:8];
                    mem[addr[9:0]+2] <= write_data[23:16];
                    mem[addr[9:0]+3] <= write_data[31:24];
                end
            endcase
        end
    end

    // Read Logic (Combinational or synchronous? CPU expects data in WB stage?
    // CPU pipeline: MEM stage sets address. WB stage expects data?
    // Let's look at cpu.v.
    // DATA_MEM_READ_DATA is input to CPU.
    // It goes to WB_DATA_MEM_READ_DATA in MEM/WB register.
    // So it must be available in MEM stage.
    // So combinational read is expected if address is stable in MEM stage.
    
    always @(*) begin
        if (read_en) begin
            case (read_funct3)
                3'b000: read_data = {{24{mem[addr[9:0]][7]}}, mem[addr[9:0]]}; // LB
                3'b001: read_data = {{16{mem[addr[9:0]+1][7]}}, mem[addr[9:0]+1], mem[addr[9:0]]}; // LH
                3'b010: read_data = {mem[addr[9:0]+3], mem[addr[9:0]+2], mem[addr[9:0]+1], mem[addr[9:0]]}; // LW
                3'b100: read_data = {24'b0, mem[addr[9:0]]}; // LBU
                3'b101: read_data = {16'b0, mem[addr[9:0]+1], mem[addr[9:0]]}; // LHU
                default: read_data = 32'b0;
            endcase
        end else begin
            read_data = 32'b0;
        end
    end

endmodule
