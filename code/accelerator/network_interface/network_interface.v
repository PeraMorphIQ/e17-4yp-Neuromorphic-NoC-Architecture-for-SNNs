`include "fifo.v"
`timescale 1ns/100ps

module network_interface (
    input clk,
    input rst,
    
    // CPU Interface
    input cpu_net_write,
    input cpu_net_read,
    input [31:0] cpu_data_in,
    output [31:0] cpu_data_out,
    output irq,
    output cpu_busywait,

    // Router Interface (Local Port)
    output [31:0] router_data_in, // Data to router (TX)
    output router_valid_in,       // Valid to router (TX)
    input router_ready_in,        // Ready from router (TX)

    input [31:0] router_data_out, // Data from router (RX)
    input router_valid_out,       // Valid from router (RX)
    output router_ready_out       // Ready to router (RX)
);

    wire tx_full, tx_empty;
    wire rx_full, rx_empty;

    // TX FIFO (CPU -> Router)
    // CPU writes when cpu_net_write is high.
    // Router reads when router_ready_in is high and fifo is not empty.
    
    wire tx_rd_en = router_ready_in && !tx_empty;
    
    fifo #(.DEPTH(16), .DATA_WIDTH(32)) tx_fifo (
        .clk(clk),
        .rst(rst),
        .wr_en(cpu_net_write),
        .din(cpu_data_in),
        .full(tx_full),
        .rd_en(tx_rd_en),
        .dout(router_data_in),
        .empty(tx_empty)
    );

    assign router_valid_in = !tx_empty;

    // RX FIFO (Router -> CPU)
    // Router writes when router_valid_out is high and fifo is not full.
    // CPU reads when cpu_net_read is high.

    wire rx_wr_en = router_valid_out && !rx_full;

    fifo #(.DEPTH(16), .DATA_WIDTH(32)) rx_fifo (
        .clk(clk),
        .rst(rst),
        .wr_en(rx_wr_en),
        .din(router_data_out),
        .full(rx_full),
        .rd_en(cpu_net_read),
        .dout(cpu_data_out),
        .empty(rx_empty)
    );

    assign router_ready_out = !rx_full;

    // Interrupt generation
    assign irq = !rx_empty;

    // Busywait logic
    // Stall if writing to full TX FIFO or reading from empty RX FIFO
    assign cpu_busywait = (cpu_net_write && tx_full) || (cpu_net_read && rx_empty);

endmodule
