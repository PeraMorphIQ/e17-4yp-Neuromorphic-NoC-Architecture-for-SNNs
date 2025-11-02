`timescale 1ns/100ps

`include "fpu/Addition-Subtraction.v"
`include "fpu/Multiplication.v"

// Neuron Core - Configurable hardware for Izhikevich and LIF neuron models
// Performs membrane potential updates and after-spike reset with IEEE 754 FPU
module neuron_core (
    input wire clk,
    input wire rst_n,
    
    // Configuration signals
    input wire config_enable,
    input wire [31:0] config_data,
    input wire [2:0] config_addr,  // 0=type, 1=v_th, 2=a, 3=b, 4=c, 5=d
    
    // Control signals
    input wire start,              // Start neuron update
    input wire spike_resolved,     // Spike has been resolved by CPU
    output reg spike_detected,     // Neuron has spiked
    output reg busy,               // Neuron is computing
    
    // Input/Output
    input wire [31:0] input_current,  // Input current I
    output reg [31:0] v_out,          // Membrane potential output
    output reg [31:0] u_out           // Recovery variable (Izhikevich only)
);

    // Neuron type: 0 = LIF, 1 = Izhikevich
    reg neuron_type;
    
    // Neuron parameters (stored as IEEE 754 single-precision float)
    reg [31:0] v_th;    // Threshold voltage
    reg [31:0] a, b, c, d;  // Izhikevich parameters / LIF parameters
    
    // Internal state
    reg [31:0] v, u;    // Membrane potential and recovery variable
    reg [31:0] I;       // Input current register
    
    // FSM states
    localparam IDLE = 3'd0;
    localparam UPDATE_V = 3'd1;
    localparam UPDATE_U = 3'd2;
    localparam CHECK_SPIKE = 3'd3;
    localparam WAIT_RESOLVE = 3'd4;
    localparam RESET = 3'd5;
    
    reg [2:0] state;
    reg [2:0] cycle_count;
    
    // Floating-point computation wires
    wire [31:0] fp_add_result, fp_sub_result, fp_mul_result;
    wire [31:0] fp_op1, fp_op2;
    reg [1:0] fp_operation;  // 0=add, 1=sub, 2=mul
    
    // Temporary registers for multi-cycle computation
    reg [31:0] temp1, temp2, temp3;
    
    /********************* Configuration Logic *********************/
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            neuron_type <= 1'b0;  // Default to LIF
            v_th <= 32'h41200000;  // 10.0 in IEEE 754
            a <= 32'h3D23D70A;     // 0.04 for Izhikevich
            b <= 32'h40A00000;     // 5.0 for Izhikevich
            c <= 32'hC2820000;     // -65.0 for Izhikevich
            d <= 32'h40000000;     // 2.0 for Izhikevich
        end else if (config_enable) begin
            case (config_addr)
                3'd0: neuron_type <= config_data[0];
                3'd1: v_th <= config_data;
                3'd2: a <= config_data;
                3'd3: b <= config_data;
                3'd4: c <= config_data;
                3'd5: d <= config_data;
            endcase
        end
    end
    
    /********************* State Machine *********************/
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            v <= 32'hC2820000;  // -65.0 (resting potential)
            u <= 32'h00000000;  // 0.0
            I <= 32'h00000000;
            spike_detected <= 1'b0;
            busy <= 1'b0;
            cycle_count <= 3'd0;
            v_out <= 32'hC2820000;
            u_out <= 32'h00000000;
        end else begin
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    spike_detected <= 1'b0;
                    if (start) begin
                        I <= input_current;
                        busy <= 1'b1;
                        cycle_count <= 3'd0;
                        state <= UPDATE_V;
                    end
                end
                
                UPDATE_V: begin
                    // Compute membrane potential update
                    if (neuron_type == 1'b0) begin
                        // LIF: v' = av + bI
                        case (cycle_count)
                            3'd0: begin
                                // Wait for FP multiplier to compute a * v
                                cycle_count <= cycle_count + 1;
                            end
                            3'd1: begin
                                // Capture temp1 = a * v, setup for b * I
                                temp1 <= fp_mul_result;
                                cycle_count <= cycle_count + 1;
                            end
                            3'd2: begin
                                // Wait for FP multiplier to compute b * I
                                cycle_count <= cycle_count + 1;
                            end
                            3'd3: begin
                                // Capture temp2 = b * I, setup for addition
                                temp2 <= fp_mul_result;
                                cycle_count <= cycle_count + 1;
                            end
                            3'd4: begin
                                // Wait for FP adder to compute temp1 + temp2
                                cycle_count <= cycle_count + 1;
                            end
                            3'd5: begin
                                // Capture v = temp1 + temp2
                                v <= fp_add_result;
                                state <= CHECK_SPIKE;
                                cycle_count <= 3'd0;
                            end
                        endcase
                    end else begin
                        // Izhikevich: v' = 0.04v^2 + 5v + 140 - u + I
                        // Simplified for now - just use LIF behavior
                        v <= v; // Placeholder
                        state <= UPDATE_U;
                        cycle_count <= 3'd0;
                    end
                end
                
                UPDATE_U: begin
                    // Only for Izhikevich: u' = a(bv - u)
                    // Simplified for now
                    u <= u; // Placeholder
                    state <= CHECK_SPIKE;
                    cycle_count <= 3'd0;
                end
                
                CHECK_SPIKE: begin
                    // Check if v >= v_th
                    if ($signed(v) >= $signed(v_th)) begin
                        spike_detected <= 1'b1;
                        v_out <= v;
                        u_out <= u;
                        state <= WAIT_RESOLVE;
                    end else begin
                        v_out <= v;
                        u_out <= u;
                        state <= IDLE;
                    end
                end
                
                WAIT_RESOLVE: begin
                    if (spike_resolved) begin
                        state <= RESET;
                        cycle_count <= 3'd0;
                    end
                end
                
                RESET: begin
                    // After-spike reset
                    if (neuron_type == 1'b0) begin
                        // LIF: v = v - v_th
                        v <= fp_sub_result;
                        state <= IDLE;
                    end else begin
                        // Izhikevich: v = c, u = u + d
                        case (cycle_count)
                            3'd0: begin
                                v <= c;
                                cycle_count <= cycle_count + 1;
                            end
                            3'd1: begin
                                u <= fp_add_result;  // u + d
                                state <= IDLE;
                            end
                        endcase
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    /********************* IEEE 754 Floating-Point Units *********************/
    
    // Operand selection based on state and cycle
    assign fp_op1 = (state == UPDATE_V && cycle_count == 3'd0) ? (neuron_type ? v : a) :
                    (state == UPDATE_V && cycle_count == 3'd1) ? (neuron_type ? v : a) :
                    (state == UPDATE_V && cycle_count == 3'd2) ? (neuron_type ? a : b) :
                    (state == UPDATE_V && cycle_count == 3'd3) ? (neuron_type ? a : b) :
                    (state == UPDATE_V && cycle_count == 3'd4) ? (neuron_type ? temp1 : temp1) :
                    (state == UPDATE_V && cycle_count == 3'd5) ? (neuron_type ? temp1 : temp1) :
                    (state == UPDATE_V && cycle_count == 3'd3) ? b :
                    (state == UPDATE_V && cycle_count == 3'd4) ? temp1 :
                    (state == UPDATE_V && cycle_count == 3'd5) ? temp1 :
                    (state == UPDATE_V && cycle_count == 3'd6) ? temp1 :
                    (state == UPDATE_U && cycle_count == 3'd0) ? b :
                    (state == UPDATE_U && cycle_count == 3'd1) ? temp1 :
                    (state == UPDATE_U && cycle_count == 3'd2) ? a :
                    (state == RESET && neuron_type == 1'b0) ? v :
                    (state == RESET && cycle_count == 3'd1) ? u : 32'h00000000;
    
    assign fp_op2 = (state == UPDATE_V && cycle_count == 3'd0) ? (neuron_type ? v : v) :
                    (state == UPDATE_V && cycle_count == 3'd1) ? (neuron_type ? v : v) :
                    (state == UPDATE_V && cycle_count == 3'd2) ? (neuron_type ? temp1 : I) :
                    (state == UPDATE_V && cycle_count == 3'd3) ? (neuron_type ? temp1 : I) :
                    (state == UPDATE_V && cycle_count == 3'd4) ? (neuron_type ? v : temp2) :
                    (state == UPDATE_V && cycle_count == 3'd5) ? (neuron_type ? v : temp2) :
                    (state == UPDATE_V && cycle_count == 3'd3) ? temp3 :
                    (state == UPDATE_V && cycle_count == 3'd4) ? 32'h430C0000 :  // 140.0
                    (state == UPDATE_V && cycle_count == 3'd5) ? u :
                    (state == UPDATE_V && cycle_count == 3'd6) ? I :
                    (state == UPDATE_U && cycle_count == 3'd0) ? v :
                    (state == UPDATE_U && cycle_count == 3'd1) ? u :
                    (state == UPDATE_U && cycle_count == 3'd2) ? temp1 :
                    (state == RESET && neuron_type == 1'b0) ? v_th :
                    (state == RESET && cycle_count == 3'd1) ? d : 32'h00000000;
    
    // Wires for FPU outputs and exceptions
    wire add_exception, sub_exception, mul_exception, mul_overflow, mul_underflow;
    wire [31:0] fpu_add_out, fpu_sub_out, fpu_mul_out;
    
    // IEEE 754 Addition Unit
    // AddBar_Sub = 0 for addition
    Addition_Subtraction fp_adder (
        .a_operand(fp_op1),
        .b_operand(fp_op2),
        .AddBar_Sub(1'b0),  // 0 = Add
        .Exception(add_exception),
        .result(fpu_add_out)
    );
    
    // IEEE 754 Subtraction Unit  
    // AddBar_Sub = 1 for subtraction
    Addition_Subtraction fp_subtractor (
        .a_operand(fp_op1),
        .b_operand(fp_op2),
        .AddBar_Sub(1'b1),  // 1 = Subtract
        .Exception(sub_exception),
        .result(fpu_sub_out)
    );
    
    // IEEE 754 Multiplication Unit
    Multiplication fp_multiplier (
        .a_operand(fp_op1),
        .b_operand(fp_op2),
        .Exception(mul_exception),
        .Overflow(mul_overflow),
        .Underflow(mul_underflow),
        .result(fpu_mul_out)
    );
    
    // Select appropriate FPU result based on operation needed
    assign fp_add_result = fpu_add_out;
    assign fp_sub_result = fpu_sub_out;
    assign fp_mul_result = fpu_mul_out;

endmodule
