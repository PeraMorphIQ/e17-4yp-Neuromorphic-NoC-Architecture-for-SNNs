`include "../neuron_core/neuron_core.v"

`timescale 1ns/100ps

module neuron_bank #(
    parameter NUM_NEURONS = 4
) (
    input clk,
    input rst,
    
    // CPU Interface (Memory Mapped)
    input [31:0] addr,
    input write_en,
    input [31:0] write_data,
    input read_en,
    output reg [31:0] read_data,
    output busywait
);

    // Address Map (per neuron)
    // Base + 0x00: Param A
    // Base + 0x04: Param B
    // Base + 0x08: Param C
    // Base + 0x0C: Param D
    // Base + 0x10: Vth
    // Base + 0x14: Input Current (I)
    // Base + 0x18: Control (Bit 0: Update, Bit 1: Reset, Bit 2: Mode)
    // Base + 0x1C: Status (Bit 0: Spike Detected, Bit 1: Busy)
    // Base + 0x20: V (Read Only)
    // Base + 0x24: U (Read Only)
    
    // Neuron Selection: Address[7:6] (assuming 4 neurons, 64 bytes per neuron space)
    // Register Selection: Address[5:0]
    
    wire [1:0] neuron_sel = addr[7:6];
    wire [5:0] reg_sel = addr[5:0];
    
    // Registers
    reg [31:0] params_a [NUM_NEURONS-1:0];
    reg [31:0] params_b [NUM_NEURONS-1:0];
    reg [31:0] params_c [NUM_NEURONS-1:0];
    reg [31:0] params_d [NUM_NEURONS-1:0];
    reg [31:0] params_vth [NUM_NEURONS-1:0];
    reg [31:0] inputs_i [NUM_NEURONS-1:0];
    reg [NUM_NEURONS-1:0] modes;
    
    reg [NUM_NEURONS-1:0] start_updates;
    reg [NUM_NEURONS-1:0] start_resets;
    
    wire [NUM_NEURONS-1:0] busy_flags;
    wire [NUM_NEURONS-1:0] spike_flags;
    wire [31:0] v_outs [NUM_NEURONS-1:0];
    wire [31:0] u_outs [NUM_NEURONS-1:0];
    
    assign busywait = 0; // Always ready for now

    genvar i;
    generate
        for (i = 0; i < NUM_NEURONS; i = i + 1) begin : NEURON_ARRAY
            neuron_core core (
                .clk(clk),
                .rst(rst),
                .param_a(params_a[i]),
                .param_b(params_b[i]),
                .param_c(params_c[i]),
                .param_d(params_d[i]),
                .param_vth(params_vth[i]),
                .current_input(inputs_i[i]),
                .mode(modes[i]),
                .start_update(start_updates[i]),
                .start_reset(start_resets[i]),
                .busy(busy_flags[i]),
                .spike_detected(spike_flags[i]),
                .v_out(v_outs[i]),
                .u_out(u_outs[i])
            );
        end
    endgenerate

    initial begin
    $display("===========================================");
    $display("Mesh Configuration:");
    $display("  NUM_NEURONS per node: %0d", NUM_NEURONS);
    $display("===========================================");
    end 

    // Write Logic
    integer j;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (j=0; j<NUM_NEURONS; j=j+1) begin
                params_a[j] <= 0;
                params_b[j] <= 0;
                params_c[j] <= 0;
                params_d[j] <= 0;
                params_vth[j] <= 0;
                inputs_i[j] <= 0;
            end
            modes <= 0;
            start_updates <= 0;
            start_resets <= 0;
        end else begin
            // Auto-clear start signals (pulse)
            start_updates <= 0;
            start_resets <= 0;
            
            if (write_en) begin
                case (reg_sel)
                    6'h00: params_a[neuron_sel] <= write_data;
                    6'h04: params_b[neuron_sel] <= write_data;
                    6'h08: params_c[neuron_sel] <= write_data;
                    6'h0C: params_d[neuron_sel] <= write_data;
                    6'h10: params_vth[neuron_sel] <= write_data;
                    6'h14: inputs_i[neuron_sel] <= write_data;
                    6'h18: begin
                        if (write_data[0]) start_updates[neuron_sel] <= 1;
                        if (write_data[1]) start_resets[neuron_sel] <= 1;
                        modes[neuron_sel] <= write_data[2];
                    end
                endcase
            end
        end
    end

    // Read Logic
    always @(*) begin
        read_data = 32'b0;
        if (read_en) begin
            case (reg_sel)
                6'h00: read_data = params_a[neuron_sel];
                6'h04: read_data = params_b[neuron_sel];
                6'h08: read_data = params_c[neuron_sel];
                6'h0C: read_data = params_d[neuron_sel];
                6'h10: read_data = params_vth[neuron_sel];
                6'h14: read_data = inputs_i[neuron_sel];
                6'h18: read_data = {29'b0, modes[neuron_sel], 1'b0, 1'b0};
                6'h1C: read_data = {30'b0, busy_flags[neuron_sel], spike_flags[neuron_sel]};
                6'h20: read_data = v_outs[neuron_sel];
                6'h24: read_data = u_outs[neuron_sel];
                default: read_data = 32'b0;
            endcase
        end
    end

endmodule
