`timescale 1ns/100ps

`include "fpu/Addition-Subtraction.v"
`include "fpu/Multiplication.v"

// Direct LIF calculation test
module lif_direct_test;

    reg clk;
    reg [31:0] a, b, v, I;
    reg [31:0] temp1, temp2;
    
    wire [31:0] mul_result1, mul_result2, add_result;
    wire mul_exc1, mul_exc2, mul_ovf1, mul_unf1, mul_ovf2, mul_unf2;
    wire add_exc;
    
    // FPU for a * v
    Multiplication mul1 (
        .a_operand(a),
        .b_operand(v),
        .Exception(mul_exc1),
        .Overflow(mul_ovf1),
        .Underflow(mul_unf1),
        .result(mul_result1)
    );
    
    // FPU for b * I  
    Multiplication mul2 (
        .a_operand(b),
        .b_operand(I),
        .Exception(mul_exc2),
        .Overflow(mul_ovf2),
        .Underflow(mul_unf2),
        .result(mul_result2)
    );
    
    // FPU for temp1 + temp2
    Addition_Subtraction adder (
        .a_operand(temp1),
        .b_operand(temp2),
        .AddBar_Sub(1'b0),
        .Exception(add_exc),
        .result(add_result)
    );
    
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
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        $display("======================================");
        $display("Direct LIF Calculation Test");
        $display("======================================");
        $display("LIF equation: v' = av + bI");
        $display("");
        
        // LIF parameters
        a = 32'h3F733333;  // 0.95
        b = 32'h3DCCCCCD;  // 0.1
        v = 32'hC2820000;  // -65.0
        I = 32'h40A00000;  // 5.0
        
        $display("Parameters:");
        $display("  a = %f", ieee754_to_real(a));
        $display("  b = %f", ieee754_to_real(b));
        $display("  v = %f", ieee754_to_real(v));
        $display("  I = %f", ieee754_to_real(I));
        $display("");
        
        #10;  // Wait for combinational logic
        
        $display("Step 1: Calculate a * v");
        temp1 = mul_result1;
        $display("  a * v = %f * %f = %f", 
                 ieee754_to_real(a), ieee754_to_real(v), ieee754_to_real(temp1));
        
        #10;
        
        $display("\nStep 2: Calculate b * I");
        temp2 = mul_result2;
        $display("  b * I = %f * %f = %f", 
                 ieee754_to_real(b), ieee754_to_real(I), ieee754_to_real(temp2));
        
        #10;
        
        $display("\nStep 3: Calculate v' = temp1 + temp2");
        $display("  v' = %f + %f = %f", 
                 ieee754_to_real(temp1), ieee754_to_real(temp2), ieee754_to_real(add_result));
        
        $display("\nExpected: v' = 0.95*(-65) + 0.1*5 = -61.75 + 0.5 = -61.25");
        
        #10;
        $display("\n======================================");
        $display("Test Complete");
        $display("======================================");
        $finish;
    end

endmodule
