`timescale 1ns/100ps

`include "noc/input_router.v"
`include "noc/virtual_channel.v"
`include "noc/rr_arbiter.v"

// Input Module - handles packet routing and buffering
// Contains input controller, router, virtual channels, and arbiter
module input_module #(
    parameter ROUTER_ADDR_WIDTH = 4,
    parameter ROUTING_ALGORITHM = 0,
    parameter VC_DEPTH = 4
)(
    input wire clk,
    input wire rst_n,
    
    // Current router address
    input wire [ROUTER_ADDR_WIDTH-1:0] router_addr,
    
    // Input from network interface or adjacent router
    input wire [31:0] in_packet,
    input wire in_valid,
    output wire in_ready,
    
    // Outputs to router crossbar (4 VCs for N, S, E, W)
    output wire [31:0] vc_north_data,
    output wire vc_north_valid,
    input wire vc_north_ready,
    
    output wire [31:0] vc_south_data,
    output wire vc_south_valid,
    input wire vc_south_ready,
    
    output wire [31:0] vc_east_data,
    output wire vc_east_valid,
    input wire vc_east_ready,
    
    output wire [31:0] vc_west_data,
    output wire vc_west_valid,
    input wire vc_west_ready,
    
    output wire [31:0] vc_local_data,
    output wire vc_local_valid,
    input wire vc_local_ready
);

    // Route direction from router
    wire [2:0] route_dir;
    
    // Routing directions
    localparam NORTH = 3'd0;
    localparam SOUTH = 3'd1;
    localparam EAST = 3'd2;
    localparam WEST = 3'd3;
    localparam LOCAL = 3'd4;
    
    /********************* Input Router *********************/
    input_router #(
        .ROUTER_ADDR_WIDTH(ROUTER_ADDR_WIDTH),
        .ROUTING_ALGORITHM(ROUTING_ALGORITHM)
    ) router_inst (
        .packet(in_packet),
        .current_router_addr(router_addr),
        .route_direction(route_dir)
    );
    
    /********************* Virtual Channels *********************/
    // North VC
    wire vc_north_full, vc_north_empty;
    wire vc_north_wr_en, vc_north_rd_en;
    
    virtual_channel #(
        .DATA_WIDTH(32),
        .DEPTH(VC_DEPTH)
    ) vc_north (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(vc_north_wr_en),
        .wr_data(in_packet),
        .full(vc_north_full),
        .rd_en(vc_north_rd_en),
        .rd_data(vc_north_data),
        .empty(vc_north_empty),
        .count()
    );
    
    // South VC
    wire vc_south_full, vc_south_empty;
    wire vc_south_wr_en, vc_south_rd_en;
    
    virtual_channel #(
        .DATA_WIDTH(32),
        .DEPTH(VC_DEPTH)
    ) vc_south (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(vc_south_wr_en),
        .wr_data(in_packet),
        .full(vc_south_full),
        .rd_en(vc_south_rd_en),
        .rd_data(vc_south_data),
        .empty(vc_south_empty),
        .count()
    );
    
    // East VC
    wire vc_east_full, vc_east_empty;
    wire vc_east_wr_en, vc_east_rd_en;
    
    virtual_channel #(
        .DATA_WIDTH(32),
        .DEPTH(VC_DEPTH)
    ) vc_east (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(vc_east_wr_en),
        .wr_data(in_packet),
        .full(vc_east_full),
        .rd_en(vc_east_rd_en),
        .rd_data(vc_east_data),
        .empty(vc_east_empty),
        .count()
    );
    
    // West VC
    wire vc_west_full, vc_west_empty;
    wire vc_west_wr_en, vc_west_rd_en;
    
    virtual_channel #(
        .DATA_WIDTH(32),
        .DEPTH(VC_DEPTH)
    ) vc_west (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(vc_west_wr_en),
        .wr_data(in_packet),
        .full(vc_west_full),
        .rd_en(vc_west_rd_en),
        .rd_data(vc_west_data),
        .empty(vc_west_empty),
        .count()
    );
    
    // Local VC
    wire vc_local_full, vc_local_empty;
    wire vc_local_wr_en, vc_local_rd_en;
    
    virtual_channel #(
        .DATA_WIDTH(32),
        .DEPTH(VC_DEPTH)
    ) vc_local (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(vc_local_wr_en),
        .wr_data(in_packet),
        .full(vc_local_full),
        .rd_en(vc_local_rd_en),
        .rd_data(vc_local_data),
        .empty(vc_local_empty),
        .count()
    );
    
    /********************* Input Controller *********************/
    // Check if target VC has space
    wire target_vc_ready = (route_dir == NORTH) ? !vc_north_full :
                           (route_dir == SOUTH) ? !vc_south_full :
                           (route_dir == EAST)  ? !vc_east_full :
                           (route_dir == WEST)  ? !vc_west_full :
                           (route_dir == LOCAL) ? !vc_local_full : 1'b0;
    
    // Accept packet if valid and target VC has space
    assign in_ready = in_valid && target_vc_ready;
    
    // Write enables for VCs based on routing decision
    assign vc_north_wr_en = in_valid && in_ready && (route_dir == NORTH);
    assign vc_south_wr_en = in_valid && in_ready && (route_dir == SOUTH);
    assign vc_east_wr_en = in_valid && in_ready && (route_dir == EAST);
    assign vc_west_wr_en = in_valid && in_ready && (route_dir == WEST);
    assign vc_local_wr_en = in_valid && in_ready && (route_dir == LOCAL);
    
    /********************* Output Arbitration *********************/
    // Each VC can request to send if it has data and downstream is ready
    wire [3:0] arb_request;
    wire [3:0] arb_grant;
    
    assign arb_request[0] = !vc_north_empty;
    assign arb_request[1] = !vc_south_empty;
    assign arb_request[2] = !vc_east_empty;
    assign arb_request[3] = !vc_west_empty;
    // Note: Local doesn't go through arbiter, directly to network interface
    
    rr_arbiter #(
        .NUM_PORTS(4)
    ) arbiter (
        .clk(clk),
        .rst_n(rst_n),
        .request(arb_request),
        .grant(arb_grant)
    );
    
    // Read enables based on grants and downstream ready
    assign vc_north_rd_en = arb_grant[0] && vc_north_ready;
    assign vc_south_rd_en = arb_grant[1] && vc_south_ready;
    assign vc_east_rd_en = arb_grant[2] && vc_east_ready;
    assign vc_west_rd_en = arb_grant[3] && vc_west_ready;
    assign vc_local_rd_en = !vc_local_empty && vc_local_ready;
    
    // Valid signals
    assign vc_north_valid = !vc_north_empty;
    assign vc_south_valid = !vc_south_empty;
    assign vc_east_valid = !vc_east_empty;
    assign vc_west_valid = !vc_west_empty;
    assign vc_local_valid = !vc_local_empty;

endmodule
