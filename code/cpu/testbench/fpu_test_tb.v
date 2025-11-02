`timescale 1ns/100ps

`include "fpu/Addition-Subtraction.v"
`include "fpu/Multiplication.v"

// Simple FPU test
module fpu_test_tb;

    reg [31:0] a, b;
    wire [31:0] add_result, sub_result, mul_result;
    wire add_exc, sub_exc, mul_exc, mul_ovf, mul_unf;
    
    // Instantiate FPUs
    Addition_Subtraction adder (
        .a_operand(a),
        .b_operand(b),
        .AddBar_Sub(1'b0),
        .Exception(add_exc),
        .result(add_result)
    );
    
    Addition_Subtraction subtractor (
        .a_operand(a),
        .b_operand(b),
        .AddBar_Sub(1'b1),
        .Exception(sub_exc),
        .result(sub_result)
    );
    
    Multiplication multiplier (
        .a_operand(a),
        .b_operand(b),
        .Exception(mul_exc),
        .Overflow(mul_ovf),
        .Underflow(mul_unf),
        .result(mul_result)
    );
    
    // Helper function
    function real ieee754_to_real;
        input [31:0] ieee754;
        reg sign;
        reg [7:0] exponent;
        reg [22:0] mantissa;
        real value;
        integer exp_value;
        begin
            sign = ieee754[31];
            exponent = ieee754[30:23];
            mantissa = ieee754[22:0];
            
            if (exponent == 0) begin
                value = 0.0;
            end else begin
                exp_value = exponent - 127;
                value = (1.0 + mantissa / 8388608.0) * (2.0 ** exp_value);
                if (sign) value = -value;
            end
            
            ieee754_to_real = value;
        end
    endfunction
    
    initial begin
        $display("======================================");
        $display("FPU Standalone Test");
        $display("======================================");
        
        // Test 1: 0.95 * -65.0 = -61.75
        a = 32'h3F733333;  // 0.95
        b = 32'hC2820000;  // -65.0
        #10;
        $display("\nTest 1: Multiplication");
        $display("  0.95 * -65.0");
        $display("  Result: %f (expected -61.75)", ieee754_to_real(mul_result));
        
        // Test 2: 0.1 * 5.0 = 0.5
        a = 32'h3DCCCCCD;  // 0.1
        b = 32'h40A00000;  // 5.0
        #10;
        $display("\nTest 2: Multiplication");
        $display("  0.1 * 5.0");
        $display("  Result: %f (expected 0.5)", ieee754_to_real(mul_result));
        
        // Test 3: -61.75 + 0.5 = -61.25
        a = 32'hC2770000;  // -61.75
        b = 32'h3F000000;  // 0.5
        #10;
        $display("\nTest 3: Addition");
        $display("  -61.75 + 0.5");
        $display("  Result: %f (expected -61.25)", ieee754_to_real(add_result));
        
        #10;
        $display("\n======================================");
        $display("FPU Test Complete");
        $display("======================================");
        $finish;
    end

endmodule
