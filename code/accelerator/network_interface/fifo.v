`timescale 1ns/100ps

module fifo #(parameter DEPTH=16, DATA_WIDTH=32) (
    input clk,
    input rst,
    input wr_en,
    input [DATA_WIDTH-1:0] din,
    output full,
    input rd_en,
    output reg [DATA_WIDTH-1:0] dout,
    output empty
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [$clog2(DEPTH):0] wr_ptr;
    reg [$clog2(DEPTH):0] rd_ptr;

    assign empty = (wr_ptr == rd_ptr);
    assign full = (wr_ptr[$clog2(DEPTH)] != rd_ptr[$clog2(DEPTH)]) && 
                  (wr_ptr[$clog2(DEPTH)-1:0] == rd_ptr[$clog2(DEPTH)-1:0]);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            dout <= 0;
        end else begin
            if (wr_en && !full) begin
                mem[wr_ptr[$clog2(DEPTH)-1:0]] <= din;
                wr_ptr <= wr_ptr + 1;
            end
            if (rd_en && !empty) begin
                dout <= mem[rd_ptr[$clog2(DEPTH)-1:0]];
                rd_ptr <= rd_ptr + 1;
            end
        end
    end

endmodule
