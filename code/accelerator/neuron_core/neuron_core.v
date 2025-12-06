`timescale 1ns/100ps

module neuron_core (
    input clk,
    input rst,
    
    // Configuration (Q16.16 fixed-point format)
    input signed [31:0] param_a,
    input signed [31:0] param_b,
    input signed [31:0] param_c,
    input signed [31:0] param_d,
    input signed [31:0] param_vth,
    input signed [31:0] current_input, // I
    input mode, // 0: LIF, 1: Izhikevich
    
    // Control
    input start_update,
    input start_reset,
    output reg busy,
    output reg spike_detected,
    
    // State monitoring
    output reg signed [31:0] v_out,
    output reg signed [31:0] u_out
);

    // Internal State (Q16.16 fixed-point)
    reg signed [31:0] v, u;
    
    // Constants (Q16.16 fixed-point format: value * 65536)
    localparam signed [31:0] FIXED_0_04 = 32'h00000A3D;  // 0.04
    localparam signed [31:0] FIXED_5_0  = 32'h00050000;  // 5.0
    localparam signed [31:0] FIXED_140  = 32'h008C0000;  // 140.0
    localparam signed [31:0] FIXED_1_0  = 32'h00010000;  // 1.0
    
    // State Machine
    localparam IDLE = 0;
    localparam UPDATE_1 = 1;   // v^2
    localparam UPDATE_2 = 2;   // 0.04 * v^2
    localparam UPDATE_3 = 3;   // 5*v
    localparam UPDATE_4 = 4;   // (0.04v^2 + 5v)
    localparam UPDATE_5 = 5;   // ... + 140
    localparam UPDATE_6 = 6;   // ... - u
    localparam UPDATE_7 = 7;   // ... + I (New v)
    localparam UPDATE_U_1 = 8; // b*v
    localparam UPDATE_U_2 = 9; // bv - u
    localparam UPDATE_U_3 = 10; // a(bv-u)
    localparam UPDATE_U_4 = 11; // u + ... (New u)
    localparam CHECK_SPIKE = 12;
    localparam RESET_1 = 13;
    localparam RESET_2 = 14;
    
    reg [3:0] state;
    
    // Temporary registers for calculation
    reg signed [31:0] temp1, temp2, temp3;
    reg signed [63:0] mul_result;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            v <= 0;
            u <= 0;
            busy <= 0;
            spike_detected <= 0;
            v_out <= 0;
            u_out <= 0;
            temp1 <= 0;
            temp2 <= 0;
            temp3 <= 0;
        end else begin
            case (state)
                IDLE: begin
                    busy <= 0;
                    if (start_update) begin
                        busy <= 1;
                        spike_detected <= 0;
                        if (mode == 1) state <= UPDATE_1; // Izhikevich
                        else state <= UPDATE_7; // LIF (simplified)
                    end else if (start_reset) begin
                        busy <= 1;
                        state <= RESET_1;
                    end
                end
                
                // Izhikevich Update: v' = 0.04v^2 + 5v + 140 - u + I
                // u' = a(bv - u)
                
                // Step 1: Calculate v^2
                UPDATE_1: begin
                    mul_result <= v * v;
                    state <= UPDATE_2;
                end
                
                // Step 2: Calculate 0.04 * v^2
                UPDATE_2: begin
                    temp1 <= mul_result[47:16]; // v^2 (Q16.16 from Q32.32)
                    mul_result <= FIXED_0_04 * mul_result[47:16];
                    state <= UPDATE_3;
                end
                
                // Step 3: Calculate 5*v
                UPDATE_3: begin
                    temp1 <= mul_result[47:16]; // 0.04v^2
                    mul_result <= FIXED_5_0 * v;
                    state <= UPDATE_4;
                end
                
                // Step 4: Add 0.04v^2 + 5v
                UPDATE_4: begin
                    temp2 <= mul_result[47:16]; // 5v
                    temp3 <= temp1 + mul_result[47:16]; // 0.04v^2 + 5v
                    state <= UPDATE_5;
                end
                
                // Step 5: Add 140
                UPDATE_5: begin
                    temp1 <= temp3 + FIXED_140; // ... + 140
                    state <= UPDATE_6;
                end
                
                // Step 6: Subtract u
                UPDATE_6: begin
                    temp1 <= temp1 - u; // ... - u
                    state <= UPDATE_7;
                end
                
                // Step 7: Add I and start u calculation
                UPDATE_7: begin
                    temp1 <= temp1 + current_input; // ... + I (this is v')
                    mul_result <= param_b * v; // Start: b*v
                    state <= UPDATE_U_1;
                end
                
                // Step 8: Update v and calculate bv - u
                UPDATE_U_1: begin
                    v <= temp1; // New v calculated!
                    v_out <= temp1;
                    
                    temp2 <= mul_result[47:16]; // b*v
                    temp2 <= mul_result[47:16] - u; // bv - u
                    state <= UPDATE_U_2;
                end
                
                // Step 9: Calculate a * (bv - u)
                UPDATE_U_2: begin
                    mul_result <= param_a * temp2;
                    state <= UPDATE_U_3;
                end
                
                // Step 10: Calculate u + a(bv-u)
                UPDATE_U_3: begin
                    temp2 <= mul_result[47:16]; // a(bv-u)
                    temp2 <= u + mul_result[47:16]; // u + a(bv-u)
                    state <= UPDATE_U_4;
                end
                
                // Step 11: Update u
                UPDATE_U_4: begin
                    u <= temp2; // New u
                    u_out <= temp2;
                    state <= CHECK_SPIKE;
                end
                
                // Step 12: Check for spike
                CHECK_SPIKE: begin
                    if (v >= param_vth) begin
                        spike_detected <= 1;
                    end
                    busy <= 0;
                    state <= IDLE;
                end
                
                // Reset states
                RESET_1: begin
                    v <= param_c;
                    v_out <= param_c;
                    temp1 <= u + param_d; // u + d
                    state <= RESET_2;
                end
                
                RESET_2: begin
                    u <= temp1;
                    u_out <= temp1;
                    busy <= 0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
