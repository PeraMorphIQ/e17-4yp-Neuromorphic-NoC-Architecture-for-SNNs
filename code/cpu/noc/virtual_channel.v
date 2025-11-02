`timescale 1ns/100ps

// Virtual Channel - FIFO buffer for storing packets in one direction
module virtual_channel #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 4  // Buffer depth
)(
    input wire clk,
    input wire rst_n,
    
    // Write interface
    input wire wr_en,
    input wire [DATA_WIDTH-1:0] wr_data,
    output wire full,
    
    // Read interface
    input wire rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire empty,
    
    // Status
    output wire [3:0] count  // Number of packets in buffer
);

    // Memory array
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    // Read and write pointers
    reg [3:0] wr_ptr;
    reg [3:0] rd_ptr;
    reg [3:0] pkt_count;
    
    // Status signals
    assign full = (pkt_count == DEPTH);
    assign empty = (pkt_count == 0);
    assign count = pkt_count;
    
    // Read data (combinational)
    assign rd_data = mem[rd_ptr[1:0]];  // Use lower 2 bits for depth=4
    
    // Write operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 4'b0;
        end else if (wr_en && !full) begin
            mem[wr_ptr[1:0]] <= wr_data;
            wr_ptr <= wr_ptr + 1;
        end
    end
    
    // Read operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 4'b0;
        end else if (rd_en && !empty) begin
            rd_ptr <= rd_ptr + 1;
        end
    end
    
    // Packet count management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pkt_count <= 4'b0;
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: pkt_count <= pkt_count + 1;  // Write only
                2'b01: pkt_count <= pkt_count - 1;  // Read only
                2'b11: pkt_count <= pkt_count;      // Both (no change)
                default: pkt_count <= pkt_count;    // Neither
            endcase
        end
    end

endmodule
