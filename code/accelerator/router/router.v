`timescale 1ns/100ps

module router #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_X = 0,
    parameter ADDR_Y = 0
) (
    input clk,
    input rst,

    // Ports: 0:Local, 1:North, 2:East, 3:South, 4:West
    input  [DATA_WIDTH-1:0] din_0, din_1, din_2, din_3, din_4,
    input                   vin_0, vin_1, vin_2, vin_3, vin_4,
    output                  rout_0, rout_1, rout_2, rout_3, rout_4,

    output [DATA_WIDTH-1:0] dout_0, dout_1, dout_2, dout_3, dout_4,
    output                  vout_0, vout_1, vout_2, vout_3, vout_4,
    input                   rin_0, rin_1, rin_2, rin_3, rin_4
);

    // Internal wires
    wire [DATA_WIDTH-1:0] din [4:0];
    wire vin [4:0];
    wire rout [4:0];
    
    wire [DATA_WIDTH-1:0] dout [4:0];
    wire vout [4:0];
    wire rin [4:0];

    assign din[0] = din_0; assign din[1] = din_1; assign din[2] = din_2; assign din[3] = din_3; assign din[4] = din_4;
    assign vin[0] = vin_0; assign vin[1] = vin_1; assign vin[2] = vin_2; assign vin[3] = vin_3; assign vin[4] = vin_4;
    
    assign rout_0 = rout[0]; assign rout_1 = rout[1]; assign rout_2 = rout[2]; assign rout_3 = rout[3]; assign rout_4 = rout[4];

    assign dout_0 = dout[0]; assign dout_1 = dout[1]; assign dout_2 = dout[2]; assign dout_3 = dout[3]; assign dout_4 = dout[4];
    assign vout_0 = vout[0]; assign vout_1 = vout[1]; assign vout_2 = vout[2]; assign vout_3 = vout[3]; assign vout_4 = vout[4];
    
    assign rin[0] = rin_0; assign rin[1] = rin_1; assign rin[2] = rin_2; assign rin[3] = rin_3; assign rin[4] = rin_4;

    // Routing Logic and Arbitration
    // For each input, determine desired output.
    // For each output, arbitrate among inputs requesting it.

    reg [2:0] dest_port [4:0]; // Desired output port for each input
    wire [4:0] req [4:0];      // req[input][output] - Request matrix

    genvar i;
    generate
        for (i = 0; i < 5; i = i + 1) begin : routing_logic
            wire [7:0] dest_x = din[i][31:24];
            wire [7:0] dest_y = din[i][23:16];
            
            always @(*) begin
                if (dest_x < ADDR_X) dest_port[i] = 3'd4; // West
                else if (dest_x > ADDR_X) dest_port[i] = 3'd2; // East
                else begin
                    if (dest_y < ADDR_Y) dest_port[i] = 3'd1; // North (Assuming Y increases downwards)
                    else if (dest_y > ADDR_Y) dest_port[i] = 3'd3; // South
                    else dest_port[i] = 3'd0; // Local
                end
            end
            
            assign req[i][0] = vin[i] && (dest_port[i] == 3'd0);
            assign req[i][1] = vin[i] && (dest_port[i] == 3'd1);
            assign req[i][2] = vin[i] && (dest_port[i] == 3'd2);
            assign req[i][3] = vin[i] && (dest_port[i] == 3'd3);
            assign req[i][4] = vin[i] && (dest_port[i] == 3'd4);
        end
    endgenerate

    // Output Arbitration (Round Robin)
    // For each output port, select one input port.
    
    reg [2:0] grant_idx [4:0]; // Which input is granted for each output
    
    // Simple fixed priority for now to save time, or simple RR state.
    // Let's do a simple priority: Local > North > East > South > West (or similar)
    // Actually, RR is better to avoid starvation.
    
    reg [2:0] rr_ptr [4:0]; // Round robin pointer for each output

    integer j, k;
    reg [4:0] grant [4:0]; // grant[output][input]

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (j=0; j<5; j=j+1) rr_ptr[j] <= 0;
        end else begin
            for (j=0; j<5; j=j+1) begin // For each output
                if (vout[j] && rin[j]) begin // If transaction happened
                    rr_ptr[j] <= rr_ptr[j] + 1;
                    if (rr_ptr[j] == 4) rr_ptr[j] <= 0;
                end
            end
        end
    end

    // Combinational Arbitration Logic
    always @(*) begin
        for (j=0; j<5; j=j+1) begin // For each output port j
            grant[j] = 5'b0;
            // Check inputs starting from rr_ptr[j]
            // This is a simplified RR, checking in loop
            if (req[rr_ptr[j]][j]) grant[j][rr_ptr[j]] = 1'b1;
            else if (req[(rr_ptr[j]+1)%5][j]) grant[j][(rr_ptr[j]+1)%5] = 1'b1;
            else if (req[(rr_ptr[j]+2)%5][j]) grant[j][(rr_ptr[j]+2)%5] = 1'b1;
            else if (req[(rr_ptr[j]+3)%5][j]) grant[j][(rr_ptr[j]+3)%5] = 1'b1;
            else if (req[(rr_ptr[j]+4)%5][j]) grant[j][(rr_ptr[j]+4)%5] = 1'b1;
        end
    end

    // Crossbar / Muxing
    genvar o;
    generate
        for (o = 0; o < 5; o = o + 1) begin : output_logic
            // Data out
            assign dout[o] = grant[o][0] ? din[0] :
                             grant[o][1] ? din[1] :
                             grant[o][2] ? din[2] :
                             grant[o][3] ? din[3] :
                             grant[o][4] ? din[4] : 32'd0;
            
            // Valid out
            assign vout[o] = |grant[o];
        end
    endgenerate

    // Ready out (to inputs)
    // Input i is ready if it is granted by its desired output AND that output is ready to accept.
    generate
        for (i = 0; i < 5; i = i + 1) begin : input_ready_logic
            assign rout[i] = (grant[0][i] && rin[0]) ||
                             (grant[1][i] && rin[1]) ||
                             (grant[2][i] && rin[2]) ||
                             (grant[3][i] && rin[3]) ||
                             (grant[4][i] && rin[4]);
        end
    endgenerate

endmodule
