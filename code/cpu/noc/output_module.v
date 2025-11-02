`timescale 1ns/100ps

`include "noc/virtual_channel.v"
`include "noc/rr_arbiter.v"

// Output Module - manages outgoing packets with virtual channels
module output_module #(
    parameter VC_DEPTH = 4,
    parameter NUM_INPUT_PORTS = 5  // N, S, E, W, Local
)(
    input wire clk,
    input wire rst_n,
    
    // Inputs from router crossbar (one per input port)
    input wire [31:0] in_north_data,
    input wire in_north_valid,
    output wire in_north_ready,
    
    input wire [31:0] in_south_data,
    input wire in_south_valid,
    output wire in_south_ready,
    
    input wire [31:0] in_east_data,
    input wire in_east_valid,
    output wire in_east_ready,
    
    input wire [31:0] in_west_data,
    input wire in_west_valid,
    output wire in_west_ready,
    
    input wire [31:0] in_local_data,
    input wire in_local_valid,
    output wire in_local_ready,
    
    // Output to adjacent router or network interface
    output reg [31:0] out_packet,
    output reg out_valid,
    input wire out_ready
);

    /********************* Virtual Channels *********************/
    // North VC
    wire vc_north_full, vc_north_empty;
    wire vc_north_wr_en, vc_north_rd_en;
    wire [31:0] vc_north_data;
    
    virtual_channel #(
        .DATA_WIDTH(32),
        .DEPTH(VC_DEPTH)
    ) vc_north (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(vc_north_wr_en),
        .wr_data(in_north_data),
        .full(vc_north_full),
        .rd_en(vc_north_rd_en),
        .rd_data(vc_north_data),
        .empty(vc_north_empty),
        .count()
    );
    
    // South VC
    wire vc_south_full, vc_south_empty;
    wire vc_south_wr_en, vc_south_rd_en;
    wire [31:0] vc_south_data;
    
    virtual_channel #(
        .DATA_WIDTH(32),
        .DEPTH(VC_DEPTH)
    ) vc_south (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(vc_south_wr_en),
        .wr_data(in_south_data),
        .full(vc_south_full),
        .rd_en(vc_south_rd_en),
        .rd_data(vc_south_data),
        .empty(vc_south_empty),
        .count()
    );
    
    // East VC
    wire vc_east_full, vc_east_empty;
    wire vc_east_wr_en, vc_east_rd_en;
    wire [31:0] vc_east_data;
    
    virtual_channel #(
        .DATA_WIDTH(32),
        .DEPTH(VC_DEPTH)
    ) vc_east (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(vc_east_wr_en),
        .wr_data(in_east_data),
        .full(vc_east_full),
        .rd_en(vc_east_rd_en),
        .rd_data(vc_east_data),
        .empty(vc_east_empty),
        .count()
    );
    
    // West VC
    wire vc_west_full, vc_west_empty;
    wire vc_west_wr_en, vc_west_rd_en;
    wire [31:0] vc_west_data;
    
    virtual_channel #(
        .DATA_WIDTH(32),
        .DEPTH(VC_DEPTH)
    ) vc_west (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(vc_west_wr_en),
        .wr_data(in_west_data),
        .full(vc_west_full),
        .rd_en(vc_west_rd_en),
        .rd_data(vc_west_data),
        .empty(vc_west_empty),
        .count()
    );
    
    // Local VC
    wire vc_local_full, vc_local_empty;
    wire vc_local_wr_en, vc_local_rd_en;
    wire [31:0] vc_local_data;
    
    virtual_channel #(
        .DATA_WIDTH(32),
        .DEPTH(VC_DEPTH)
    ) vc_local (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(vc_local_wr_en),
        .wr_data(in_local_data),
        .full(vc_local_full),
        .rd_en(vc_local_rd_en),
        .rd_data(vc_local_data),
        .empty(vc_local_empty),
        .count()
    );
    
    /********************* Input Flow Control *********************/
    // Ready signals indicate VC has space
    assign in_north_ready = !vc_north_full;
    assign in_south_ready = !vc_south_full;
    assign in_east_ready = !vc_east_full;
    assign in_west_ready = !vc_west_full;
    assign in_local_ready = !vc_local_full;
    
    // Write to VCs when valid and ready
    assign vc_north_wr_en = in_north_valid && in_north_ready;
    assign vc_south_wr_en = in_south_valid && in_south_ready;
    assign vc_east_wr_en = in_east_valid && in_east_ready;
    assign vc_west_wr_en = in_west_valid && in_west_ready;
    assign vc_local_wr_en = in_local_valid && in_local_ready;
    
    /********************* Output Arbitration *********************/
    // Arbiter requests
    wire [4:0] arb_request;
    wire [4:0] arb_grant;
    
    assign arb_request[0] = !vc_north_empty && out_ready;
    assign arb_request[1] = !vc_south_empty && out_ready;
    assign arb_request[2] = !vc_east_empty && out_ready;
    assign arb_request[3] = !vc_west_empty && out_ready;
    assign arb_request[4] = !vc_local_empty && out_ready;
    
    // 5-port round-robin arbiter
    rr_arbiter #(
        .NUM_PORTS(5)
    ) arbiter (
        .clk(clk),
        .rst_n(rst_n),
        .request(arb_request[3:0]),  // Use 4-port arbiter, handle local separately
        .grant(arb_grant[3:0])
    );
    
    // Local gets grant if no other port is requesting
    assign arb_grant[4] = arb_request[4] && !(|arb_request[3:0]);
    
    // Read enables
    assign vc_north_rd_en = arb_grant[0];
    assign vc_south_rd_en = arb_grant[1];
    assign vc_east_rd_en = arb_grant[2];
    assign vc_west_rd_en = arb_grant[3];
    assign vc_local_rd_en = arb_grant[4];
    
    /********************* Output Multiplexing *********************/
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_packet <= 32'b0;
            out_valid <= 1'b0;
        end else begin
            // Multiplex data based on grant
            if (arb_grant[0]) begin
                out_packet <= vc_north_data;
                out_valid <= 1'b1;
            end
            else if (arb_grant[1]) begin
                out_packet <= vc_south_data;
                out_valid <= 1'b1;
            end
            else if (arb_grant[2]) begin
                out_packet <= vc_east_data;
                out_valid <= 1'b1;
            end
            else if (arb_grant[3]) begin
                out_packet <= vc_west_data;
                out_valid <= 1'b1;
            end
            else if (arb_grant[4]) begin
                out_packet <= vc_local_data;
                out_valid <= 1'b1;
            end
            else begin
                out_valid <= 1'b0;
            end
        end
    end

endmodule
