`timescale 1ns/100ps

// Input Router - determines routing direction using XY or YX routing
module input_router #(
    parameter ROUTER_ADDR_WIDTH = 4,  // 4 bits for X, 4 bits for Y
    parameter ROUTING_ALGORITHM = 0   // 0 = XY routing, 1 = YX routing
)(
    input wire [31:0] packet,              // Input packet [31:16] = dest addr, [15:0] = neuron addr
    input wire [ROUTER_ADDR_WIDTH-1:0] current_router_addr,  // Current router address [7:4] = X, [3:0] = Y
    output reg [2:0] route_direction      // 0=North, 1=South, 2=East, 3=West, 4=Local
);

    // Extract destination coordinates from packet
    wire [ROUTER_ADDR_WIDTH-1:0] dest_addr = packet[16 +: ROUTER_ADDR_WIDTH];
    wire [3:0] dest_x = dest_addr[7:4];
    wire [3:0] dest_y = dest_addr[3:0];
    
    // Extract current coordinates
    wire [3:0] curr_x = current_router_addr[7:4];
    wire [3:0] curr_y = current_router_addr[3:0];
    
    // Calculate differences
    wire signed [4:0] diff_x = $signed({1'b0, dest_x}) - $signed({1'b0, curr_x});
    wire signed [4:0] diff_y = $signed({1'b0, dest_y}) - $signed({1'b0, curr_y});
    
    // Route directions
    localparam NORTH = 3'd0;
    localparam SOUTH = 3'd1;
    localparam EAST = 3'd2;
    localparam WEST = 3'd3;
    localparam LOCAL = 3'd4;
    
    always @(*) begin
        // Default to local if at destination
        if ((dest_x == curr_x) && (dest_y == curr_y)) begin
            route_direction = LOCAL;
        end
        else if (ROUTING_ALGORITHM == 0) begin
            // XY Routing: Route in X direction first, then Y
            if (diff_x > 0) begin
                route_direction = EAST;
            end
            else if (diff_x < 0) begin
                route_direction = WEST;
            end
            else if (diff_y > 0) begin
                route_direction = NORTH;
            end
            else if (diff_y < 0) begin
                route_direction = SOUTH;
            end
            else begin
                route_direction = LOCAL;
            end
        end
        else begin
            // YX Routing: Route in Y direction first, then X
            if (diff_y > 0) begin
                route_direction = NORTH;
            end
            else if (diff_y < 0) begin
                route_direction = SOUTH;
            end
            else if (diff_x > 0) begin
                route_direction = EAST;
            end
            else if (diff_x < 0) begin
                route_direction = WEST;
            end
            else begin
                route_direction = LOCAL;
            end
        end
    end

endmodule
