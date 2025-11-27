// `include "../cpu_core/fpu/Addition-Subtraction.v"
// `include "../cpu_core/fpu/Multiplication.v"
// `include "../cpu_core/fpu/Comparison.v"

`timescale 1ns/100ps

module neuron_core (
    input clk,
    input rst,
    
    // Configuration
    input [31:0] param_a,
    input [31:0] param_b,
    input [31:0] param_c,
    input [31:0] param_d,
    input [31:0] param_vth,
    input [31:0] current_input, // I
    input mode, // 0: LIF, 1: Izhikevich
    
    // Control
    input start_update,
    input start_reset,
    output reg busy,
    output reg spike_detected,
    
    // State monitoring
    output reg [31:0] v_out,
    output reg [31:0] u_out
);

    // Internal State
    reg [31:0] v, u;
    
    // FPU Signals
    reg [31:0] fadd_op1, fadd_op2;
    wire [31:0] fadd_res;
    wire fadd_exc;
    
    reg [31:0] fmul_op1, fmul_op2;
    wire [31:0] fmul_res;
    wire fmul_exc;
    
    reg [31:0] fcomp_op1, fcomp_op2;
    wire fcomp_res; // 1 if op1 < op2 (A_lt_B)
    
    // Instantiations
    // Note: Using the modules from cpu_core/fpu. 
    // Addition_Subtraction(a, b, AddBar_Sub, Exception, result)
    reg fadd_sub_op; 
    Addition_Subtraction FADD (fadd_op1, fadd_op2, fadd_sub_op, fadd_exc, fadd_res);
    
    // Multiplication(a, b, Exception, Overflow, Underflow, result)
    wire fmul_ovf, fmul_unf;
    Multiplication FMUL (fmul_op1, fmul_op2, fmul_exc, fmul_ovf, fmul_unf, fmul_res);
    
    // Comparison(a, b, result)
    // 00 -> equal, 01 -> a > b, 10 -> a < b
    wire [1:0] fcomp_res_bits;
    Comparison FCOMP (fcomp_op1, fcomp_op2, fcomp_res_bits);
    
    assign fcomp_res = (fcomp_res_bits == 2'b10); // a < b

    // Constants (IEEE 754 Single Precision)
    localparam FLOAT_0_04 = 32'h3D23D70A; // 0.04
    localparam FLOAT_5_0  = 32'h40A00000; // 5.0
    localparam FLOAT_140  = 32'h430C0000; // 140.0
    localparam FLOAT_1_0  = 32'h3F800000; // 1.0
    
    // State Machine
    localparam IDLE = 0;
    localparam UPDATE_1 = 1; // v^2
    localparam UPDATE_2 = 2; // 0.04 * v^2
    localparam UPDATE_3 = 3; // 5*v
    localparam UPDATE_4 = 4; // (0.04v^2 + 5v)
    localparam UPDATE_5 = 5; // ... + 140
    localparam UPDATE_6 = 6; // ... - u
    localparam UPDATE_7 = 7; // ... + I (New v)
    localparam UPDATE_U_1 = 8; // b*v
    localparam UPDATE_U_2 = 9; // bv - u
    localparam UPDATE_U_3 = 10; // a(bv-u)
    localparam UPDATE_U_4 = 11; // u + ... (New u)
    localparam CHECK_SPIKE = 12;
    localparam RESET_1 = 13;
    localparam RESET_2 = 14;
    
    reg [3:0] state;
    
    // Temporary registers for calculation
    reg [31:0] temp1, temp2, temp3;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            v <= 0;
            u <= 0;
            busy <= 0;
            spike_detected <= 0;
            v_out <= 0;
            u_out <= 0;
        end else begin
            case (state)
                IDLE: begin
                    busy <= 0;
                    if (start_update) begin
                        busy <= 1;
                        spike_detected <= 0;
                        if (mode == 1) state <= UPDATE_1; // Izhikevich
                        else state <= UPDATE_7; // LIF (Simplified for now, jumping to end logic or implementing separate path)
                        // For simplicity, let's implement Izhikevich flow first as it's more complex.
                        // LIF: v' = av + bI. 
                        // Let's stick to Izhikevich for the demo as per paper details.
                    end else if (start_reset) begin
                        busy <= 1;
                        state <= RESET_1;
                    end
                end
                
                // Izhikevich Update: v' = 0.04v^2 + 5v + 140 - u + I
                // u' = a(bv - u)
                
                // Step 1: Calculate v^2
                UPDATE_1: begin
                    fmul_op1 <= v;
                    fmul_op2 <= v;
                    state <= UPDATE_2;
                end
                
                // Step 2: Calculate 0.04 * v^2 AND 5*v (Parallel if we had 2 muls, but we have 1)
                // We have 1 MUL and 1 ADD/SUB.
                // Let's serialize.
                UPDATE_2: begin
                    temp1 <= fmul_res; // v^2
                    fmul_op1 <= FLOAT_0_04;
                    fmul_op2 <= fmul_res; // 0.04 * v^2
                    state <= UPDATE_3;
                end
                
                UPDATE_3: begin
                    temp1 <= fmul_res; // 0.04v^2
                    fmul_op1 <= FLOAT_5_0;
                    fmul_op2 <= v; // 5v
                    state <= UPDATE_4;
                end
                
                UPDATE_4: begin
                    temp2 <= fmul_res; // 5v
                    // Add 0.04v^2 + 5v
                    fadd_op1 <= temp1;
                    fadd_op2 <= fmul_res;
                    fadd_sub_op <= 0; // Add
                    state <= UPDATE_5;
                end
                
                UPDATE_5: begin
                    temp1 <= fadd_res; // 0.04v^2 + 5v
                    // Add 140
                    fadd_op1 <= fadd_res;
                    fadd_op2 <= FLOAT_140;
                    fadd_sub_op <= 0;
                    state <= UPDATE_6;
                end
                
                UPDATE_6: begin
                    temp1 <= fadd_res; // ... + 140
                    // Subtract u
                    fadd_op1 <= fadd_res;
                    fadd_op2 <= u;
                    fadd_sub_op <= 1; // Sub
                    state <= UPDATE_7;
                end
                
                UPDATE_7: begin
                    temp1 <= fadd_res; // ... - u
                    // Add I
                    fadd_op1 <= fadd_res;
                    fadd_op2 <= current_input;
                    fadd_sub_op <= 0;
                    
                    // Also start u update: b*v
                    fmul_op1 <= param_b;
                    fmul_op2 <= v;
                    
                    state <= UPDATE_U_1;
                end
                
                UPDATE_U_1: begin
                    v <= fadd_res; // New v calculated!
                    v_out <= fadd_res;
                    
                    temp2 <= fmul_res; // b*v
                    // bv - u
                    fadd_op1 <= fmul_res;
                    fadd_op2 <= u;
                    fadd_sub_op <= 1; // Sub
                    state <= UPDATE_U_2;
                end
                
                UPDATE_U_2: begin
                    temp2 <= fadd_res; // bv - u
                    // a * (bv - u)
                    fmul_op1 <= param_a;
                    fmul_op2 <= fadd_res;
                    state <= UPDATE_U_3;
                end
                
                UPDATE_U_3: begin
                    temp2 <= fmul_res; // a(bv-u)
                    // u + ... (Euler integration: u = u + du)
                    // Assuming the equation u' = ... is du/dt. 
                    // Discrete: u[n+1] = u[n] + u'[n].
                    fadd_op1 <= u;
                    fadd_op2 <= fmul_res;
                    fadd_sub_op <= 0;
                    state <= UPDATE_U_4;
                end
                
                UPDATE_U_4: begin
                    u <= fadd_res; // New u
                    u_out <= fadd_res;
                    state <= CHECK_SPIKE;
                end
                
                CHECK_SPIKE: begin
                    // Check if v >= vth
                    fcomp_op1 <= v;
                    fcomp_op2 <= param_vth;
                    // Result is 1 if op1 < op2. So if result is 0, then op1 >= op2.
                    // Wait, Comparison module: A_lt_B.
                    // If v < vth, no spike.
                    // If !(v < vth), spike.
                    state <= IDLE; // Or wait state?
                    // We need to check result in next cycle? No, combinational?
                    // Let's assume we need a cycle to latch result if registered, but FCOMP is usually combinational in these simple ALUs.
                    // Let's check in next cycle logic or assign here.
                    // Actually, let's do it in next cycle to be safe.
                end
                
            endcase
            
            if (state == CHECK_SPIKE) begin
                 // Check comparison result
                 if (!fcomp_res) begin // v >= vth
                    spike_detected <= 1;
                 end
                 busy <= 0;
                 state <= IDLE;
            end
            
            // Reset Logic
            if (state == RESET_1) begin
                // v <- c
                v <= param_c;
                v_out <= param_c;
                
                // u <- u + d
                fadd_op1 <= u;
                fadd_op2 <= param_d;
                fadd_sub_op <= 0;
                state <= RESET_2;
            end
            
            if (state == RESET_2) begin
                u <= fadd_res;
                u_out <= fadd_res;
                busy <= 0;
                state <= IDLE;
            end
            
        end
    end

endmodule
