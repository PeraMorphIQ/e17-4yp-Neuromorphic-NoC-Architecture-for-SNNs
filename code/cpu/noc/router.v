`timescale 1ns/100ps

`include "noc/input_module.v"
`include "noc/output_module.v"

// Router - 5x5 crossbar connecting 5 input and 5 output modules
// Ports: North, South, East, West, Local
module router #(
    parameter ROUTER_ADDR_WIDTH = 4,
    parameter ROUTING_ALGORITHM = 0,
    parameter VC_DEPTH = 4
)(
    input wire clk,
    input wire rst_n,
    
    // Router address in the mesh
    input wire [ROUTER_ADDR_WIDTH-1:0] router_addr,
    
    // North Port
    input wire [31:0] north_in_packet,
    input wire north_in_valid,
    output wire north_in_ready,
    output wire [31:0] north_out_packet,
    output wire north_out_valid,
    input wire north_out_ready,
    
    // South Port
    input wire [31:0] south_in_packet,
    input wire south_in_valid,
    output wire south_in_ready,
    output wire [31:0] south_out_packet,
    output wire south_out_valid,
    input wire south_out_ready,
    
    // East Port
    input wire [31:0] east_in_packet,
    input wire east_in_valid,
    output wire east_in_ready,
    output wire [31:0] east_out_packet,
    output wire east_out_valid,
    input wire east_out_ready,
    
    // West Port
    input wire [31:0] west_in_packet,
    input wire west_in_valid,
    output wire west_in_ready,
    output wire [31:0] west_out_packet,
    output wire west_out_valid,
    input wire west_out_ready,
    
    // Local Port (to/from Network Interface)
    input wire [31:0] local_in_packet,
    input wire local_in_valid,
    output wire local_in_ready,
    output wire [31:0] local_out_packet,
    output wire local_out_valid,
    input wire local_out_ready
);

    /********************* Input Modules *********************/
    // North Input Module
    wire [31:0] north_im_to_north_om, north_im_to_south_om, north_im_to_east_om, north_im_to_west_om, north_im_to_local_om;
    wire north_im_to_north_om_valid, north_im_to_south_om_valid, north_im_to_east_om_valid, north_im_to_west_om_valid, north_im_to_local_om_valid;
    wire north_im_to_north_om_ready, north_im_to_south_om_ready, north_im_to_east_om_ready, north_im_to_west_om_ready, north_im_to_local_om_ready;
    
    input_module #(
        .ROUTER_ADDR_WIDTH(ROUTER_ADDR_WIDTH),
        .ROUTING_ALGORITHM(ROUTING_ALGORITHM),
        .VC_DEPTH(VC_DEPTH)
    ) north_input (
        .clk(clk),
        .rst_n(rst_n),
        .router_addr(router_addr),
        .in_packet(north_in_packet),
        .in_valid(north_in_valid),
        .in_ready(north_in_ready),
        .vc_north_data(north_im_to_north_om),
        .vc_north_valid(north_im_to_north_om_valid),
        .vc_north_ready(north_im_to_north_om_ready),
        .vc_south_data(north_im_to_south_om),
        .vc_south_valid(north_im_to_south_om_valid),
        .vc_south_ready(north_im_to_south_om_ready),
        .vc_east_data(north_im_to_east_om),
        .vc_east_valid(north_im_to_east_om_valid),
        .vc_east_ready(north_im_to_east_om_ready),
        .vc_west_data(north_im_to_west_om),
        .vc_west_valid(north_im_to_west_om_valid),
        .vc_west_ready(north_im_to_west_om_ready),
        .vc_local_data(north_im_to_local_om),
        .vc_local_valid(north_im_to_local_om_valid),
        .vc_local_ready(north_im_to_local_om_ready)
    );
    
    // South Input Module
    wire [31:0] south_im_to_north_om, south_im_to_south_om, south_im_to_east_om, south_im_to_west_om, south_im_to_local_om;
    wire south_im_to_north_om_valid, south_im_to_south_om_valid, south_im_to_east_om_valid, south_im_to_west_om_valid, south_im_to_local_om_valid;
    wire south_im_to_north_om_ready, south_im_to_south_om_ready, south_im_to_east_om_ready, south_im_to_west_om_ready, south_im_to_local_om_ready;
    
    input_module #(
        .ROUTER_ADDR_WIDTH(ROUTER_ADDR_WIDTH),
        .ROUTING_ALGORITHM(ROUTING_ALGORITHM),
        .VC_DEPTH(VC_DEPTH)
    ) south_input (
        .clk(clk),
        .rst_n(rst_n),
        .router_addr(router_addr),
        .in_packet(south_in_packet),
        .in_valid(south_in_valid),
        .in_ready(south_in_ready),
        .vc_north_data(south_im_to_north_om),
        .vc_north_valid(south_im_to_north_om_valid),
        .vc_north_ready(south_im_to_north_om_ready),
        .vc_south_data(south_im_to_south_om),
        .vc_south_valid(south_im_to_south_om_valid),
        .vc_south_ready(south_im_to_south_om_ready),
        .vc_east_data(south_im_to_east_om),
        .vc_east_valid(south_im_to_east_om_valid),
        .vc_east_ready(south_im_to_east_om_ready),
        .vc_west_data(south_im_to_west_om),
        .vc_west_valid(south_im_to_west_om_valid),
        .vc_west_ready(south_im_to_west_om_ready),
        .vc_local_data(south_im_to_local_om),
        .vc_local_valid(south_im_to_local_om_valid),
        .vc_local_ready(south_im_to_local_om_ready)
    );
    
    // East Input Module
    wire [31:0] east_im_to_north_om, east_im_to_south_om, east_im_to_east_om, east_im_to_west_om, east_im_to_local_om;
    wire east_im_to_north_om_valid, east_im_to_south_om_valid, east_im_to_east_om_valid, east_im_to_west_om_valid, east_im_to_local_om_valid;
    wire east_im_to_north_om_ready, east_im_to_south_om_ready, east_im_to_east_om_ready, east_im_to_west_om_ready, east_im_to_local_om_ready;
    
    input_module #(
        .ROUTER_ADDR_WIDTH(ROUTER_ADDR_WIDTH),
        .ROUTING_ALGORITHM(ROUTING_ALGORITHM),
        .VC_DEPTH(VC_DEPTH)
    ) east_input (
        .clk(clk),
        .rst_n(rst_n),
        .router_addr(router_addr),
        .in_packet(east_in_packet),
        .in_valid(east_in_valid),
        .in_ready(east_in_ready),
        .vc_north_data(east_im_to_north_om),
        .vc_north_valid(east_im_to_north_om_valid),
        .vc_north_ready(east_im_to_north_om_ready),
        .vc_south_data(east_im_to_south_om),
        .vc_south_valid(east_im_to_south_om_valid),
        .vc_south_ready(east_im_to_south_om_ready),
        .vc_east_data(east_im_to_east_om),
        .vc_east_valid(east_im_to_east_om_valid),
        .vc_east_ready(east_im_to_east_om_ready),
        .vc_west_data(east_im_to_west_om),
        .vc_west_valid(east_im_to_west_om_valid),
        .vc_west_ready(east_im_to_west_om_ready),
        .vc_local_data(east_im_to_local_om),
        .vc_local_valid(east_im_to_local_om_valid),
        .vc_local_ready(east_im_to_local_om_ready)
    );
    
    // West Input Module
    wire [31:0] west_im_to_north_om, west_im_to_south_om, west_im_to_east_om, west_im_to_west_om, west_im_to_local_om;
    wire west_im_to_north_om_valid, west_im_to_south_om_valid, west_im_to_east_om_valid, west_im_to_west_om_valid, west_im_to_local_om_valid;
    wire west_im_to_north_om_ready, west_im_to_south_om_ready, west_im_to_east_om_ready, west_im_to_west_om_ready, west_im_to_local_om_ready;
    
    input_module #(
        .ROUTER_ADDR_WIDTH(ROUTER_ADDR_WIDTH),
        .ROUTING_ALGORITHM(ROUTING_ALGORITHM),
        .VC_DEPTH(VC_DEPTH)
    ) west_input (
        .clk(clk),
        .rst_n(rst_n),
        .router_addr(router_addr),
        .in_packet(west_in_packet),
        .in_valid(west_in_valid),
        .in_ready(west_in_ready),
        .vc_north_data(west_im_to_north_om),
        .vc_north_valid(west_im_to_north_om_valid),
        .vc_north_ready(west_im_to_north_om_ready),
        .vc_south_data(west_im_to_south_om),
        .vc_south_valid(west_im_to_south_om_valid),
        .vc_south_ready(west_im_to_south_om_ready),
        .vc_east_data(west_im_to_east_om),
        .vc_east_valid(west_im_to_east_om_valid),
        .vc_east_ready(west_im_to_east_om_ready),
        .vc_west_data(west_im_to_west_om),
        .vc_west_valid(west_im_to_west_om_valid),
        .vc_west_ready(west_im_to_west_om_ready),
        .vc_local_data(west_im_to_local_om),
        .vc_local_valid(west_im_to_local_om_valid),
        .vc_local_ready(west_im_to_local_om_ready)
    );
    
    // Local Input Module
    wire [31:0] local_im_to_north_om, local_im_to_south_om, local_im_to_east_om, local_im_to_west_om, local_im_to_local_om;
    wire local_im_to_north_om_valid, local_im_to_south_om_valid, local_im_to_east_om_valid, local_im_to_west_om_valid, local_im_to_local_om_valid;
    wire local_im_to_north_om_ready, local_im_to_south_om_ready, local_im_to_east_om_ready, local_im_to_west_om_ready, local_im_to_local_om_ready;
    
    input_module #(
        .ROUTER_ADDR_WIDTH(ROUTER_ADDR_WIDTH),
        .ROUTING_ALGORITHM(ROUTING_ALGORITHM),
        .VC_DEPTH(VC_DEPTH)
    ) local_input (
        .clk(clk),
        .rst_n(rst_n),
        .router_addr(router_addr),
        .in_packet(local_in_packet),
        .in_valid(local_in_valid),
        .in_ready(local_in_ready),
        .vc_north_data(local_im_to_north_om),
        .vc_north_valid(local_im_to_north_om_valid),
        .vc_north_ready(local_im_to_north_om_ready),
        .vc_south_data(local_im_to_south_om),
        .vc_south_valid(local_im_to_south_om_valid),
        .vc_south_ready(local_im_to_south_om_ready),
        .vc_east_data(local_im_to_east_om),
        .vc_east_valid(local_im_to_east_om_valid),
        .vc_east_ready(local_im_to_east_om_ready),
        .vc_west_data(local_im_to_west_om),
        .vc_west_valid(local_im_to_west_om_valid),
        .vc_west_ready(local_im_to_west_om_ready),
        .vc_local_data(local_im_to_local_om),
        .vc_local_valid(local_im_to_local_om_valid),
        .vc_local_ready(local_im_to_local_om_ready)
    );
    
    /********************* Output Modules *********************/
    // North Output Module
    output_module #(
        .VC_DEPTH(VC_DEPTH)
    ) north_output (
        .clk(clk),
        .rst_n(rst_n),
        .in_north_data(north_im_to_north_om),
        .in_north_valid(north_im_to_north_om_valid),
        .in_north_ready(north_im_to_north_om_ready),
        .in_south_data(south_im_to_north_om),
        .in_south_valid(south_im_to_north_om_valid),
        .in_south_ready(south_im_to_north_om_ready),
        .in_east_data(east_im_to_north_om),
        .in_east_valid(east_im_to_north_om_valid),
        .in_east_ready(east_im_to_north_om_ready),
        .in_west_data(west_im_to_north_om),
        .in_west_valid(west_im_to_north_om_valid),
        .in_west_ready(west_im_to_north_om_ready),
        .in_local_data(local_im_to_north_om),
        .in_local_valid(local_im_to_north_om_valid),
        .in_local_ready(local_im_to_north_om_ready),
        .out_packet(north_out_packet),
        .out_valid(north_out_valid),
        .out_ready(north_out_ready)
    );
    
    // South Output Module
    output_module #(
        .VC_DEPTH(VC_DEPTH)
    ) south_output (
        .clk(clk),
        .rst_n(rst_n),
        .in_north_data(north_im_to_south_om),
        .in_north_valid(north_im_to_south_om_valid),
        .in_north_ready(north_im_to_south_om_ready),
        .in_south_data(south_im_to_south_om),
        .in_south_valid(south_im_to_south_om_valid),
        .in_south_ready(south_im_to_south_om_ready),
        .in_east_data(east_im_to_south_om),
        .in_east_valid(east_im_to_south_om_valid),
        .in_east_ready(east_im_to_south_om_ready),
        .in_west_data(west_im_to_south_om),
        .in_west_valid(west_im_to_south_om_valid),
        .in_west_ready(west_im_to_south_om_ready),
        .in_local_data(local_im_to_south_om),
        .in_local_valid(local_im_to_south_om_valid),
        .in_local_ready(local_im_to_south_om_ready),
        .out_packet(south_out_packet),
        .out_valid(south_out_valid),
        .out_ready(south_out_ready)
    );
    
    // East Output Module
    output_module #(
        .VC_DEPTH(VC_DEPTH)
    ) east_output (
        .clk(clk),
        .rst_n(rst_n),
        .in_north_data(north_im_to_east_om),
        .in_north_valid(north_im_to_east_om_valid),
        .in_north_ready(north_im_to_east_om_ready),
        .in_south_data(south_im_to_east_om),
        .in_south_valid(south_im_to_east_om_valid),
        .in_south_ready(south_im_to_east_om_ready),
        .in_east_data(east_im_to_east_om),
        .in_east_valid(east_im_to_east_om_valid),
        .in_east_ready(east_im_to_east_om_ready),
        .in_west_data(west_im_to_east_om),
        .in_west_valid(west_im_to_east_om_valid),
        .in_west_ready(west_im_to_east_om_ready),
        .in_local_data(local_im_to_east_om),
        .in_local_valid(local_im_to_east_om_valid),
        .in_local_ready(local_im_to_east_om_ready),
        .out_packet(east_out_packet),
        .out_valid(east_out_valid),
        .out_ready(east_out_ready)
    );
    
    // West Output Module
    output_module #(
        .VC_DEPTH(VC_DEPTH)
    ) west_output (
        .clk(clk),
        .rst_n(rst_n),
        .in_north_data(north_im_to_west_om),
        .in_north_valid(north_im_to_west_om_valid),
        .in_north_ready(north_im_to_west_om_ready),
        .in_south_data(south_im_to_west_om),
        .in_south_valid(south_im_to_west_om_valid),
        .in_south_ready(south_im_to_west_om_ready),
        .in_east_data(east_im_to_west_om),
        .in_east_valid(east_im_to_west_om_valid),
        .in_east_ready(east_im_to_west_om_ready),
        .in_west_data(west_im_to_west_om),
        .in_west_valid(west_im_to_west_om_valid),
        .in_west_ready(west_im_to_west_om_ready),
        .in_local_data(local_im_to_west_om),
        .in_local_valid(local_im_to_west_om_valid),
        .in_local_ready(local_im_to_west_om_ready),
        .out_packet(west_out_packet),
        .out_valid(west_out_valid),
        .out_ready(west_out_ready)
    );
    
    // Local Output Module
    output_module #(
        .VC_DEPTH(VC_DEPTH)
    ) local_output (
        .clk(clk),
        .rst_n(rst_n),
        .in_north_data(north_im_to_local_om),
        .in_north_valid(north_im_to_local_om_valid),
        .in_north_ready(north_im_to_local_om_ready),
        .in_south_data(south_im_to_local_om),
        .in_south_valid(south_im_to_local_om_valid),
        .in_south_ready(south_im_to_local_om_ready),
        .in_east_data(east_im_to_local_om),
        .in_east_valid(east_im_to_local_om_valid),
        .in_east_ready(east_im_to_local_om_ready),
        .in_west_data(west_im_to_local_om),
        .in_west_valid(west_im_to_local_om_valid),
        .in_west_ready(west_im_to_local_om_ready),
        .in_local_data(local_im_to_local_om),
        .in_local_valid(local_im_to_local_om_valid),
        .in_local_ready(local_im_to_local_om_ready),
        .out_packet(local_out_packet),
        .out_valid(local_out_valid),
        .out_ready(local_out_ready)
    );

endmodule
