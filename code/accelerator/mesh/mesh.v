`include "../node/node.v"

module mesh #(
    parameter ROWS = 2,
    parameter COLS = 2,
    parameter DATA_WIDTH = 32,
    parameter NUM_NEURONS = 16
) (
    input clk,
    input rst
);

    // Wires for connections
    // We use arrays of wires to connect the grid.
    // Indices: [y][x]
    
    // North Ports
    wire [DATA_WIDTH-1:0] north_dout [ROWS-1:0][COLS-1:0];
    wire                  north_vout [ROWS-1:0][COLS-1:0];
    wire                  north_rin  [ROWS-1:0][COLS-1:0]; // Ready In (Input to Node's Output Port)
    
    wire [DATA_WIDTH-1:0] north_din  [ROWS-1:0][COLS-1:0];
    wire                  north_vin  [ROWS-1:0][COLS-1:0];
    wire                  north_rout [ROWS-1:0][COLS-1:0]; // Ready Out (Output from Node's Input Port)

    // East Ports
    wire [DATA_WIDTH-1:0] east_dout [ROWS-1:0][COLS-1:0];
    wire                  east_vout [ROWS-1:0][COLS-1:0];
    wire                  east_rin  [ROWS-1:0][COLS-1:0];
    
    wire [DATA_WIDTH-1:0] east_din  [ROWS-1:0][COLS-1:0];
    wire                  east_vin  [ROWS-1:0][COLS-1:0];
    wire                  east_rout [ROWS-1:0][COLS-1:0];

    // South Ports
    wire [DATA_WIDTH-1:0] south_dout [ROWS-1:0][COLS-1:0];
    wire                  south_vout [ROWS-1:0][COLS-1:0];
    wire                  south_rin  [ROWS-1:0][COLS-1:0];
    
    wire [DATA_WIDTH-1:0] south_din  [ROWS-1:0][COLS-1:0];
    wire                  south_vin  [ROWS-1:0][COLS-1:0];
    wire                  south_rout [ROWS-1:0][COLS-1:0];

    // West Ports
    wire [DATA_WIDTH-1:0] west_dout [ROWS-1:0][COLS-1:0];
    wire                  west_vout [ROWS-1:0][COLS-1:0];
    wire                  west_rin  [ROWS-1:0][COLS-1:0];
    
    wire [DATA_WIDTH-1:0] west_din  [ROWS-1:0][COLS-1:0];
    wire                  west_vin  [ROWS-1:0][COLS-1:0];
    wire                  west_rout [ROWS-1:0][COLS-1:0];

    genvar x, y;
    generate
        for (y = 0; y < ROWS; y = y + 1) begin : ROW_LOOP
            for (x = 0; x < COLS; x = x + 1) begin : COL_LOOP
                
                // Instantiate Node
                node #(
                    .ADDR_X(x),
                    .ADDR_Y(y),
                    .NUM_NEURONS(NUM_NEURONS)
                ) u_node (
                    .clk(clk),
                    .rst(rst),
                    
                    // North (1)
                    .din_1(north_din[y][x]), .vin_1(north_vin[y][x]), .rout_1(north_rout[y][x]),
                    .dout_1(north_dout[y][x]), .vout_1(north_vout[y][x]), .rin_1(north_rin[y][x]),

                    // East (2)
                    .din_2(east_din[y][x]), .vin_2(east_vin[y][x]), .rout_2(east_rout[y][x]),
                    .dout_2(east_dout[y][x]), .vout_2(east_vout[y][x]), .rin_2(east_rin[y][x]),

                    // South (3)
                    .din_3(south_din[y][x]), .vin_3(south_vin[y][x]), .rout_3(south_rout[y][x]),
                    .dout_3(south_dout[y][x]), .vout_3(south_vout[y][x]), .rin_3(south_rin[y][x]),

                    // West (4)
                    .din_4(west_din[y][x]), .vin_4(west_vin[y][x]), .rout_4(west_rout[y][x]),
                    .dout_4(west_dout[y][x]), .vout_4(west_vout[y][x]), .rin_4(west_rin[y][x])
                );

                // Connections Logic
                
                // North Connection (Connects to South of y-1)
                if (y > 0) begin
                    assign north_din[y][x] = south_dout[y-1][x];
                    assign north_vin[y][x] = south_vout[y-1][x];
                    assign south_rin[y-1][x] = north_rout[y][x];
                end else begin
                    assign north_din[y][x] = 32'b0;
                    assign north_vin[y][x] = 1'b0;
                end

                // South Connection (Connects to North of y+1)
                if (y < ROWS-1) begin
                    assign south_din[y][x] = north_dout[y+1][x];
                    assign south_vin[y][x] = north_vout[y+1][x];
                    assign north_rin[y+1][x] = south_rout[y][x];
                end else begin
                    assign south_din[y][x] = 32'b0;
                    assign south_vin[y][x] = 1'b0;
                end

                // East Connection (Connects to West of x+1)
                if (x < COLS-1) begin
                    assign east_din[y][x] = west_dout[y][x+1];
                    assign east_vin[y][x] = west_vout[y][x+1];
                    assign west_rin[y][x+1] = east_rout[y][x];
                end else begin
                    assign east_din[y][x] = 32'b0;
                    assign east_vin[y][x] = 1'b0;
                end

                // West Connection (Connects to East of x-1)
                if (x > 0) begin
                    assign west_din[y][x] = east_dout[y][x-1];
                    assign west_vin[y][x] = east_vout[y][x-1];
                    assign east_rin[y][x-1] = west_rout[y][x];
                end else begin
                    assign west_din[y][x] = 32'b0;
                    assign west_vin[y][x] = 1'b0;
                end
                
                // Handle boundary outputs (rin)
                // If at boundary, nobody is reading, so we can set rin to 1 (always ready to dump) or 0 (block).
                // Usually 0 to indicate no connection, or 1 if we want to discard packets.
                // Let's set to 0 (block) to simulate closed mesh.
                if (y == 0) assign north_rin[y][x] = 1'b0;
                if (y == ROWS-1) assign south_rin[y][x] = 1'b0;
                if (x == COLS-1) assign east_rin[y][x] = 1'b0;
                if (x == 0) assign west_rin[y][x] = 1'b0;

            end
        end
    endgenerate

endmodule
