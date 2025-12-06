`timescale 1ns/100ps

module neuron(CLK, RESET, SPIKED, I, a, b, c, d);
    // Izhikevich neuron model using fixed-point arithmetic
    // All values are represented as signed 32-bit fixed point with 16 fractional bits
    // Format: Q16.16 (16 integer bits, 16 fractional bits)
    
    localparam signed [31:0] FIXED_0_04 = 32'h00000A3D;  // 0.04 in Q16.16
    localparam signed [31:0] FIXED_5    = 32'h00050000;  // 5.0 in Q16.16
    localparam signed [31:0] FIXED_140  = 32'h008C0000;  // 140.0 in Q16.16
    localparam signed [31:0] FIXED_30   = 32'h001E0000;  // 30.0 in Q16.16

    input CLK, RESET;
    input signed [31:0] I, a, b, c, d;  // Fixed-point Q16.16 format
    output reg SPIKED;

    reg signed [31:0] V;   // Membrane potential
    reg signed [31:0] U;   // Recovery variable

    // Intermediate calculation wires
    wire signed [63:0] v_squared_full;
    wire signed [31:0] v_squared;
    wire signed [63:0] term1_full, term2_full, term3_full, term4_full;
    wire signed [31:0] term1, term2, term3;
    wire signed [31:0] v_prime;
    
    wire signed [63:0] u_term1_full, u_term2_full;
    wire signed [31:0] u_term1, u_term2;
    wire signed [31:0] u_prime;

    /******************************** V' Calculation ********************************/
    // V' = 0.04*V^2 + 5*V + 140 - U + I
    
    // V^2 (multiply and scale back)
    assign v_squared_full = V * V;
    assign v_squared = v_squared_full[47:16];  // Extract Q16.16 result
    
    // 0.04 * V^2
    assign term1_full = FIXED_0_04 * v_squared;
    assign term1 = term1_full[47:16];
    
    // 5 * V
    assign term2_full = FIXED_5 * V;
    assign term2 = term2_full[47:16];
    
    // Combine: 0.04*V^2 + 5*V + 140 - U + I
    assign term3 = term1 + term2 + FIXED_140 - U + I;
    assign v_prime = term3;

    /******************************** U' Calculation ********************************/
    // U' = a * (b*V - U)
    
    // b * V
    assign u_term1_full = b * V;
    assign u_term1 = u_term1_full[47:16];
    
    // a * (b*V - U)
    assign u_term2_full = a * (u_term1 - U);
    assign u_prime = u_term2_full[47:16];

    /******************************** Spike Detection ********************************/
    // Spike when V >= 30
    wire spike_condition;
    assign spike_condition = (V >= FIXED_30);

    /******************************** State Update ********************************/
    always @ (posedge CLK) begin
        if (RESET) begin
            V <= c;  // Initialize to resting potential
            U <= b;  // Initialize recovery variable
            SPIKED <= 1'b0;
        end
        else begin
            if (spike_condition) begin
                // Spike detected - reset
                V <= c;
                U <= U + d;
                SPIKED <= 1'b1;
            end
            else begin
                // Normal update
                V <= V + v_prime;  // Simple Euler integration
                U <= U + u_prime;
                SPIKED <= 1'b0;
            end
        end
    end
    
endmodule
