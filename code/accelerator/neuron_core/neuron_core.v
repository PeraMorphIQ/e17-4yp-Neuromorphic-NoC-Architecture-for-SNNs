`include "fpu/Multiplication.v"
`include "fpu/Addition_Subtraction.v"
`include "fpu/Comparison.v"

`timescale 1ns/100ps

module neuron_core (
    input clk,
    input rst,
    
    // Configuration (IEEE-754 floating-point format)
    input [31:0] param_a,
    input [31:0] param_b,
    input [31:0] param_c,
    input [31:0] param_d,
    input [31:0] param_vth,
    input [31:0] current_input, // I
    input mode, // 0: LIF, 1: Izhikevich (kept for compatibility, always Izhikevich)
    
    // Control
    input start_update,
    input start_reset,
    output reg busy,
    output reg spike_detected,
    
    // State monitoring
    output [31:0] v_out,
    output [31:0] u_out
);

    // IEEE-754 floating-point constants
    localparam POINT_ZERO_FOUR = 32'h3d23d70a;  // 0.04
    localparam FIVE = 32'h40a00000;              // 5.0
    localparam ONE_FORTY = 32'h430c0000;         // 140.0

    // Internal State (IEEE-754 format)
    reg [31:0] V;   // Membrane potential
    reg [31:0] U;   // Recovery variable

    // Connection wires
    wire [31:0] POINT_ZERO_FOUR_V, POINT_ZERO_FOUR_V_SQUARED, FIVE_V, B_V, 
                B_V_MINUS_U, ADD1_OUT, ADD2_OUT, ADD3_OUT, V_NEW, U_NEW, U_PLUS_D;

    wire [1:0] COMPARE_RESULT;
    wire Mul1_Exception, Mul1_Overflow, Mul1_Underflow,
         Mul2_Exception, Mul2_Overflow, Mul2_Underflow,
         Mul3_Exception, Mul3_Overflow, Mul3_Underflow,
         Mul4_Exception, Mul4_Overflow, Mul4_Underflow,
         Mul5_Exception, Mul5_Overflow, Mul5_Underflow,
         Add1_Exception, Add2_Exception, Add3_Exception,
         Add4_Exception, Add5_Exception, Add6_Exception;


    /******************************** V' Calculation ********************************/
    // V' = 0.04*V^2 + 5*V + 140 - U + I
    Multiplication mul1 (POINT_ZERO_FOUR, V, Mul1_Exception, Mul1_Overflow, Mul1_Underflow, POINT_ZERO_FOUR_V);
    Multiplication mul2 (POINT_ZERO_FOUR_V, V, Mul2_Exception, Mul2_Overflow, Mul2_Underflow, POINT_ZERO_FOUR_V_SQUARED);

    Multiplication mul3 (FIVE, V, Mul3_Exception, Mul3_Overflow, Mul3_Underflow, FIVE_V);

    Addition_Subtraction add1 (POINT_ZERO_FOUR_V_SQUARED, FIVE_V, 1'b0, Add1_Exception, ADD1_OUT);
    Addition_Subtraction add2 (ADD1_OUT, ONE_FORTY, 1'b0, Add2_Exception, ADD2_OUT);
    Addition_Subtraction add3 (ADD2_OUT, U, 1'b1, Add3_Exception, ADD3_OUT);
    Addition_Subtraction add4 (ADD3_OUT, current_input, 1'b0, Add4_Exception, V_NEW);

    /******************************** U' Calculation ********************************/
    // U' = a * (b*V - U)
    Multiplication mul4 (param_b, V, Mul4_Exception, Mul4_Overflow, Mul4_Underflow, B_V);
    Addition_Subtraction add5 (B_V, U, 1'b1, Add5_Exception, B_V_MINUS_U);

    Multiplication mul5 (param_a, B_V_MINUS_U, Mul5_Exception, Mul5_Overflow, Mul5_Underflow, U_NEW);

    /******************************** U RESET Calculation ********************************/
    Addition_Subtraction add6 (U, param_d, 1'b0, Add6_Exception, U_PLUS_D);

    /******************************** SPIKED Calculation ********************************/
    // Compare V with threshold (param_vth)
    Comparison CuI (V, param_vth, COMPARE_RESULT);
    wire SPIKED;
    assign #1 SPIKED = (COMPARE_RESULT == 2'b00) | (COMPARE_RESULT == 2'b01);

    // Output current state
    assign v_out = V;
    assign u_out = U;

    // State machine for control
    reg update_pending;
    reg reset_pending;

    // State update logic
    always @ (posedge clk)
    begin
        if (rst)
        begin
            V <= #1 param_c;
            U <= #1 param_b;  // Initialize U to b parameter (typical initialization)
            busy <= #1 1'b0;
            spike_detected <= #1 1'b0;
            update_pending <= #1 1'b0;
            reset_pending <= #1 1'b0;
        end
        else if (start_reset)
        begin
            busy <= #1 1'b1;
            reset_pending <= #1 1'b1;
            update_pending <= #1 1'b0;
        end
        else if (start_update)
        begin
            busy <= #1 1'b1;
            update_pending <= #1 1'b1;
            reset_pending <= #1 1'b0;
            spike_detected <= #1 1'b0;
        end
        else if (reset_pending)
        begin
            V <= #1 param_c;
            U <= #1 param_b;
            busy <= #1 1'b0;
            reset_pending <= #1 1'b0;
        end
        else if (update_pending)
        begin
            if (SPIKED)
            begin
                V <= #1 param_c;         // Reset V to c when spiked
                U <= #1 U_PLUS_D;        // Add d to U when spiked
                spike_detected <= #1 1'b1;
            end
            else
            begin
                V <= #1 V_NEW;
                U <= #1 U_NEW;
                spike_detected <= #1 1'b0;
            end
            busy <= #1 1'b0;
            update_pending <= #1 1'b0;
        end
    end
    
endmodule
