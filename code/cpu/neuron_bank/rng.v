`timescale 1ns/100ps

// Linear Feedback Shift Register (LFSR) based Random Number Generator
// Generates pseudo-random 32-bit numbers for neuron simulation
module rng (
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire [31:0] seed,       // Seed for initialization
    input wire seed_load,         // Load new seed
    output wire [31:0] random_out // Random number output
);

    // 32-bit LFSR with taps at positions 32, 22, 2, and 1
    // This polynomial: x^32 + x^22 + x^2 + x^1 + 1
    reg [31:0] lfsr;
    wire feedback;
    
    // Feedback computation using XOR of tap positions
    assign feedback = lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0];
    
    // Output is the current LFSR state
    assign random_out = lfsr;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize with a non-zero default seed
            lfsr <= 32'hACE1ACE1;
        end else if (seed_load) begin
            // Load new seed
            lfsr <= (seed == 32'h0) ? 32'hACE1ACE1 : seed;
        end else if (enable) begin
            // Shift and feedback
            lfsr <= {lfsr[30:0], feedback};
        end
    end

endmodule
