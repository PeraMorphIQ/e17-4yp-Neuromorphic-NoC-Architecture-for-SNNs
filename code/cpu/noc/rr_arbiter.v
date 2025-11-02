`timescale 1ns/100ps

// Round-Robin Arbiter for fair packet arbitration
// Implements a fair scheduling algorithm to prevent starvation
module rr_arbiter #(
    parameter NUM_PORTS = 4
)(
    input wire clk,
    input wire rst_n,
    
    // Request signals from each port
    input wire [NUM_PORTS-1:0] request,
    
    // Grant signals to each port (one-hot encoded)
    output reg [NUM_PORTS-1:0] grant
);

    // Priority pointer - indicates which port has highest priority
    reg [1:0] priority_ptr;
    
    // Internal grant decision
    wire [NUM_PORTS-1:0] grant_next;
    
    // Calculate grants based on round-robin priority
    always @(*) begin
        grant = 4'b0000;
        
        // Priority 0: Check from priority_ptr to end
        case (priority_ptr)
            2'd0: begin
                if (request[0]) grant = 4'b0001;
                else if (request[1]) grant = 4'b0010;
                else if (request[2]) grant = 4'b0100;
                else if (request[3]) grant = 4'b1000;
            end
            
            2'd1: begin
                if (request[1]) grant = 4'b0010;
                else if (request[2]) grant = 4'b0100;
                else if (request[3]) grant = 4'b1000;
                else if (request[0]) grant = 4'b0001;
            end
            
            2'd2: begin
                if (request[2]) grant = 4'b0100;
                else if (request[3]) grant = 4'b1000;
                else if (request[0]) grant = 4'b0001;
                else if (request[1]) grant = 4'b0010;
            end
            
            2'd3: begin
                if (request[3]) grant = 4'b1000;
                else if (request[0]) grant = 4'b0001;
                else if (request[1]) grant = 4'b0010;
                else if (request[2]) grant = 4'b0100;
            end
        endcase
    end
    
    // Update priority pointer on each grant
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            priority_ptr <= 2'd0;
        end else if (|grant) begin  // If any grant was given
            // Move priority to next port
            if (grant[0]) priority_ptr <= 2'd1;
            else if (grant[1]) priority_ptr <= 2'd2;
            else if (grant[2]) priority_ptr <= 2'd3;
            else if (grant[3]) priority_ptr <= 2'd0;
        end
    end

endmodule
