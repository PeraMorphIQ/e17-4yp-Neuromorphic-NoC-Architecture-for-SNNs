`timescale 1ns/100ps

`include "noc/async_fifo.v"

// Network Interface - connects CPU to NoC router
// Implements AXI4-Lite slave interface for CPU communication
module network_interface #(
    parameter ROUTER_ADDR_WIDTH = 4,  // Router address width
    parameter NEURON_ADDR_WIDTH = 12, // Neuron address width
    parameter FIFO_DEPTH = 4          // FIFO depth (2^4 = 16 entries)
)(
    // CPU Clock Domain
    input wire cpu_clk,
    input wire cpu_rst_n,
    
    // Network Clock Domain
    input wire net_clk,
    input wire net_rst_n,
    
    // AXI4-Lite Slave Interface (CPU side)
    input wire [31:0] axi_awaddr,   // Write address
    input wire axi_awvalid,
    output reg axi_awready,
    
    input wire [31:0] axi_wdata,    // Write data
    input wire [3:0] axi_wstrb,     // Write strobes
    input wire axi_wvalid,
    output reg axi_wready,
    
    output reg [1:0] axi_bresp,     // Write response
    output reg axi_bvalid,
    input wire axi_bready,
    
    input wire [31:0] axi_araddr,   // Read address
    input wire axi_arvalid,
    output reg axi_arready,
    
    output reg [31:0] axi_rdata,    // Read data
    output reg [1:0] axi_rresp,     // Read response
    output reg axi_rvalid,
    input wire axi_rready,
    
    // Network Interface (Router side)
    output wire [31:0] net_tx_packet,
    output wire net_tx_valid,
    input wire net_tx_ready,
    
    input wire [31:0] net_rx_packet,
    input wire net_rx_valid,
    output wire net_rx_ready,
    
    // Interrupt to CPU
    output reg cpu_interrupt
);

    // Packet format: [31:16] = Router Address, [15:0] = Neuron Address
    
    /********************* Write FIFO (CPU -> Network) *********************/
    wire wr_fifo_full, wr_fifo_empty;
    wire wr_fifo_wr_en, wr_fifo_rd_en;
    wire [31:0] wr_fifo_wr_data, wr_fifo_rd_data;
    
    async_fifo #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(FIFO_DEPTH)
    ) write_fifo (
        .wr_clk(cpu_clk),
        .wr_rst_n(cpu_rst_n),
        .wr_en(wr_fifo_wr_en),
        .wr_data(wr_fifo_wr_data),
        .wr_full(wr_fifo_full),
        
        .rd_clk(net_clk),
        .rd_rst_n(net_rst_n),
        .rd_en(wr_fifo_rd_en),
        .rd_data(wr_fifo_rd_data),
        .rd_empty(wr_fifo_empty)
    );
    
    /********************* Read FIFO (Network -> CPU) *********************/
    wire rd_fifo_full, rd_fifo_empty;
    wire rd_fifo_wr_en, rd_fifo_rd_en;
    wire [31:0] rd_fifo_wr_data, rd_fifo_rd_data;
    
    async_fifo #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(FIFO_DEPTH)
    ) read_fifo (
        .wr_clk(net_clk),
        .wr_rst_n(net_rst_n),
        .wr_en(rd_fifo_wr_en),
        .wr_data(rd_fifo_wr_data),
        .wr_full(rd_fifo_full),
        
        .rd_clk(cpu_clk),
        .rd_rst_n(cpu_rst_n),
        .rd_en(rd_fifo_rd_en),
        .rd_data(rd_fifo_rd_data),
        .rd_empty(rd_fifo_empty)
    );
    
    /********************* AXI4-Lite Write Logic *********************/
    localparam AXI_RESP_OKAY = 2'b00;
    localparam AXI_RESP_SLVERR = 2'b10;
    
    // AXI Write State Machine
    localparam WR_IDLE = 2'b00, WR_ADDR = 2'b01, WR_DATA = 2'b10, WR_RESP = 2'b11;
    reg [1:0] wr_state;
    reg [31:0] wr_addr_reg;
    
    always @(posedge cpu_clk or negedge cpu_rst_n) begin
        if (!cpu_rst_n) begin
            wr_state <= WR_IDLE;
            axi_awready <= 1'b0;
            axi_wready <= 1'b0;
            axi_bvalid <= 1'b0;
            axi_bresp <= AXI_RESP_OKAY;
            wr_addr_reg <= 32'b0;
        end else begin
            case (wr_state)
                WR_IDLE: begin
                    axi_awready <= 1'b1;
                    axi_wready <= 1'b0;
                    axi_bvalid <= 1'b0;
                    if (axi_awvalid && axi_awready) begin
                        wr_addr_reg <= axi_awaddr;
                        wr_state <= WR_DATA;
                        axi_awready <= 1'b0;
                        axi_wready <= 1'b1;
                    end
                end
                
                WR_DATA: begin
                    if (axi_wvalid && axi_wready) begin
                        axi_wready <= 1'b0;
                        wr_state <= WR_RESP;
                        axi_bvalid <= 1'b1;
                        // Check if FIFO is full
                        if (wr_fifo_full) begin
                            axi_bresp <= AXI_RESP_SLVERR;
                        end else begin
                            axi_bresp <= AXI_RESP_OKAY;
                        end
                    end
                end
                
                WR_RESP: begin
                    if (axi_bready && axi_bvalid) begin
                        axi_bvalid <= 1'b0;
                        wr_state <= WR_IDLE;
                    end
                end
                
                default: wr_state <= WR_IDLE;
            endcase
        end
    end
    
    // Write to FIFO when AXI write completes successfully
    assign wr_fifo_wr_en = (wr_state == WR_DATA) && axi_wvalid && axi_wready && !wr_fifo_full;
    assign wr_fifo_wr_data = axi_wdata;
    
    /********************* AXI4-Lite Read Logic *********************/
    
    // AXI Read State Machine
    localparam RD_IDLE = 2'b00, RD_ADDR = 2'b01, RD_DATA = 2'b10;
    reg [1:0] rd_state;
    
    always @(posedge cpu_clk or negedge cpu_rst_n) begin
        if (!cpu_rst_n) begin
            rd_state <= RD_IDLE;
            axi_arready <= 1'b0;
            axi_rvalid <= 1'b0;
            axi_rdata <= 32'b0;
            axi_rresp <= AXI_RESP_OKAY;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    axi_arready <= 1'b1;
                    axi_rvalid <= 1'b0;
                    if (axi_arvalid && axi_arready) begin
                        axi_arready <= 1'b0;
                        rd_state <= RD_DATA;
                    end
                end
                
                RD_DATA: begin
                    axi_rvalid <= 1'b1;
                    if (rd_fifo_empty) begin
                        axi_rdata <= 32'b0;
                        axi_rresp <= AXI_RESP_SLVERR;
                    end else begin
                        axi_rdata <= rd_fifo_rd_data;
                        axi_rresp <= AXI_RESP_OKAY;
                    end
                    
                    if (axi_rready && axi_rvalid) begin
                        axi_rvalid <= 1'b0;
                        rd_state <= RD_IDLE;
                    end
                end
                
                default: rd_state <= RD_IDLE;
            endcase
        end
    end
    
    // Read from FIFO when AXI read completes successfully
    assign rd_fifo_rd_en = (rd_state == RD_DATA) && axi_rready && axi_rvalid && !rd_fifo_empty;
    
    /********************* Network Interface Logic *********************/
    
    // Transmit to network: read from write FIFO
    assign net_tx_packet = wr_fifo_rd_data;
    assign net_tx_valid = !wr_fifo_empty;
    assign wr_fifo_rd_en = net_tx_valid && net_tx_ready;
    
    // Receive from network: write to read FIFO
    assign rd_fifo_wr_data = net_rx_packet;
    assign rd_fifo_wr_en = net_rx_valid && !rd_fifo_full;
    assign net_rx_ready = !rd_fifo_full;
    
    /********************* Interrupt Generation *********************/
    // Generate interrupt when read FIFO has data
    reg [3:0] rd_fifo_threshold;
    
    always @(posedge cpu_clk or negedge cpu_rst_n) begin
        if (!cpu_rst_n) begin
            cpu_interrupt <= 1'b0;
            rd_fifo_threshold <= 4'd1; // Interrupt when at least 1 packet available
        end else begin
            // Interrupt when FIFO is not empty (simple threshold)
            cpu_interrupt <= !rd_fifo_empty;
        end
    end

endmodule
