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
    reg [2:0] priority_ptr;  // Changed to 3 bits to support up to 5 ports
    
    // Internal grant decision
    wire [NUM_PORTS-1:0] grant_next;
    
    // Calculate grants based on round-robin priority
    integer i, j;
    reg found;
    
    always @(*) begin
        grant = {NUM_PORTS{1'b0}};
        found = 1'b0;
        
        // Round-robin priority arbitration
        for (i = 0; i < NUM_PORTS && !found; i = i + 1) begin
            j = (priority_ptr + i) % NUM_PORTS;
            if (request[j] && !found) begin
                grant[j] = 1'b1;
                found = 1'b1;
            end
        end
    end
    
    // Update priority pointer on each grant
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            priority_ptr <= 3'd0;
        end else if (|grant) begin  // If any grant was given
            // Move priority to next port after the granted one
            for (k = 0; k < NUM_PORTS; k = k + 1) begin
                if (grant[k]) begin
                    priority_ptr <= (k + 1) % NUM_PORTS;
                end
            end
        end
    end

endmodule
