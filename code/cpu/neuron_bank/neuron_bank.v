`timescale 1ns/100ps

`include "neuron_bank/neuron_core.v"
`include "neuron_bank/rng.v"

// Neuron Bank - Contains multiple neuron cores with CPU-addressable registers
// Each bank is mapped to a CPU core for initialization and spike resolution
module neuron_bank #(
    parameter NUM_NEURONS = 4,     // Number of neurons in this bank
    parameter ADDR_WIDTH = 8        // Address width for registers
)(
    input wire clk,
    input wire rst_n,
    
    // CPU Interface
    input wire [ADDR_WIDTH-1:0] address,
    input wire read_enable,
    input wire write_enable,
    input wire [31:0] write_data,
    output reg [31:0] read_data,
    output reg ready,
    
    // RNG Control
    input wire rng_enable,
    input wire rng_seed_load,
    input wire [31:0] rng_seed
);

    // Address map:
    // 0x00-0x07: Neuron 0 config (type, v_th, a, b, c, d, control, status)
    // 0x08-0x0F: Neuron 1 config
    // 0x10-0x17: Neuron 2 config
    // 0x18-0x1F: Neuron 3 config
    // ...
    // 0x80-0x83: Neuron 0 input
    // 0x84-0x87: Neuron 1 input
    // ...
    // 0xC0: RNG seed
    // 0xC1: RNG output
    // 0xC2: Spike status register (bit per neuron)
    
    localparam CONFIG_BASE = 8'h00;
    localparam INPUT_BASE = 8'h80;
    localparam RNG_SEED_ADDR = 8'hC0;
    localparam RNG_OUT_ADDR = 8'hC1;
    localparam SPIKE_STATUS_ADDR = 8'hC2;
    
    // Neuron configuration and control
    reg [NUM_NEURONS-1:0] neuron_config_enable;
    reg [31:0] neuron_config_data [0:NUM_NEURONS-1];
    reg [2:0] neuron_config_addr [0:NUM_NEURONS-1];
    
    reg [NUM_NEURONS-1:0] neuron_start;
    reg [NUM_NEURONS-1:0] neuron_spike_resolved;
    wire [NUM_NEURONS-1:0] neuron_spike_detected;
    wire [NUM_NEURONS-1:0] neuron_busy;
    
    // Input buffers for each neuron
    reg [31:0] neuron_input [0:NUM_NEURONS-1];
    
    // Neuron outputs
    wire [31:0] neuron_v_out [0:NUM_NEURONS-1];
    wire [31:0] neuron_u_out [0:NUM_NEURONS-1];
    
    // Stored configuration for read-back (shadow registers)
    reg [NUM_NEURONS-1:0] neuron_type_reg;
    reg [31:0] neuron_v_th [0:NUM_NEURONS-1];
    reg [31:0] neuron_a [0:NUM_NEURONS-1];
    reg [31:0] neuron_b [0:NUM_NEURONS-1];
    reg [31:0] neuron_c [0:NUM_NEURONS-1];
    reg [31:0] neuron_d [0:NUM_NEURONS-1];
    
    // RNG
    wire [31:0] rng_output;
    
    rng rng_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(rng_enable),
        .seed(rng_seed),
        .seed_load(rng_seed_load),
        .random_out(rng_output)
    );
    
    /********************* Neuron Core Instances *********************/
    genvar i;
    generate
        for (i = 0; i < NUM_NEURONS; i = i + 1) begin : neuron_cores
            neuron_core neuron_inst (
                .clk(clk),
                .rst_n(rst_n),
                .config_enable(neuron_config_enable[i]),
                .config_data(neuron_config_data[i]),
                .config_addr(neuron_config_addr[i]),
                .start(neuron_start[i]),
                .spike_resolved(neuron_spike_resolved[i]),
                .spike_detected(neuron_spike_detected[i]),
                .busy(neuron_busy[i]),
                .input_current(neuron_input[i]),
                .v_out(neuron_v_out[i]),
                .u_out(neuron_u_out[i])
            );
        end
    endgenerate
    
    /********************* CPU Read/Write Logic *********************/
    integer j;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready <= 1'b1;
            read_data <= 32'h0;
            for (j = 0; j < NUM_NEURONS; j = j + 1) begin
                neuron_config_enable[j] <= 1'b0;
                neuron_config_data[j] <= 32'h0;
                neuron_config_addr[j] <= 3'h0;
                neuron_start[j] <= 1'b0;
                neuron_spike_resolved[j] <= 1'b0;
                neuron_input[j] <= 32'h0;
                // Initialize shadow configuration registers
                neuron_type_reg[j] <= 1'b0;
                neuron_v_th[j] <= 32'h41200000;  // 10.0
                neuron_a[j] <= 32'h3D23D70A;     // 0.04
                neuron_b[j] <= 32'h40A00000;     // 5.0
                neuron_c[j] <= 32'hC2820000;     // -65.0
                neuron_d[j] <= 32'h40000000;     // 2.0
            end
        end else begin
            // Default: clear one-shot signals
            neuron_config_enable <= {NUM_NEURONS{1'b0}};
            neuron_start <= {NUM_NEURONS{1'b0}};
            neuron_spike_resolved <= {NUM_NEURONS{1'b0}};
            
            // Write operation
            if (write_enable) begin
                if (address < INPUT_BASE) begin
                    // Configuration registers
                    integer neuron_id;
                    integer reg_offset;
                    neuron_id = address[7:3];  // Which neuron (divide by 8)
                    reg_offset = address[2:0]; // Which register within neuron config
                    
                    if (neuron_id < NUM_NEURONS) begin
                        case (reg_offset)
                            3'd0: begin // Neuron type
                                neuron_config_enable[neuron_id] <= 1'b1;
                                neuron_config_data[neuron_id] <= write_data;
                                neuron_config_addr[neuron_id] <= 3'd0;
                                neuron_type_reg[neuron_id] <= write_data[0];
                            end
                            3'd1: begin // v_th
                                neuron_config_enable[neuron_id] <= 1'b1;
                                neuron_config_data[neuron_id] <= write_data;
                                neuron_config_addr[neuron_id] <= 3'd1;
                                neuron_v_th[neuron_id] <= write_data;
                            end
                            3'd2: begin // parameter a
                                neuron_config_enable[neuron_id] <= 1'b1;
                                neuron_config_data[neuron_id] <= write_data;
                                neuron_config_addr[neuron_id] <= 3'd2;
                                neuron_a[neuron_id] <= write_data;
                            end
                            3'd3: begin // parameter b
                                neuron_config_enable[neuron_id] <= 1'b1;
                                neuron_config_data[neuron_id] <= write_data;
                                neuron_config_addr[neuron_id] <= 3'd3;
                                neuron_b[neuron_id] <= write_data;
                            end
                            3'd4: begin // parameter c
                                neuron_config_enable[neuron_id] <= 1'b1;
                                neuron_config_data[neuron_id] <= write_data;
                                neuron_config_addr[neuron_id] <= 3'd4;
                                neuron_c[neuron_id] <= write_data;
                            end
                            3'd5: begin // parameter d
                                neuron_config_enable[neuron_id] <= 1'b1;
                                neuron_config_data[neuron_id] <= write_data;
                                neuron_config_addr[neuron_id] <= 3'd5;
                                neuron_d[neuron_id] <= write_data;
                            end
                            3'd6: begin // Control: start neuron update
                                if (write_data[0])
                                    neuron_start[neuron_id] <= 1'b1;
                            end
                            3'd7: begin // Control: spike resolved
                                if (write_data[0])
                                    neuron_spike_resolved[neuron_id] <= 1'b1;
                            end
                        endcase
                    end
                end else if (address >= INPUT_BASE && address < RNG_SEED_ADDR) begin
                    // Input buffer writes
                    integer inp_neuron_id;
                    inp_neuron_id = address - INPUT_BASE;
                    if (inp_neuron_id < NUM_NEURONS) begin
                        neuron_input[inp_neuron_id] <= write_data;
                    end
                end
            end
            
            // Read operation
            if (read_enable) begin
                if (address < INPUT_BASE) begin
                    // Read neuron configuration/status
                    integer rd_neuron_id;
                    integer rd_reg_offset;
                    rd_neuron_id = address[7:3];
                    rd_reg_offset = address[2:0];
                    
                    if (rd_neuron_id < NUM_NEURONS) begin
                        case (rd_reg_offset)
                            3'd0: read_data <= {31'h0, neuron_type_reg[rd_neuron_id]};
                            3'd1: read_data <= neuron_v_th[rd_neuron_id];
                            3'd2: read_data <= neuron_a[rd_neuron_id];
                            3'd3: read_data <= neuron_b[rd_neuron_id];
                            3'd4: read_data <= neuron_c[rd_neuron_id];
                            3'd5: read_data <= neuron_d[rd_neuron_id];
                            3'd6: read_data <= {31'h0, neuron_busy[rd_neuron_id]};
                            3'd7: read_data <= {31'h0, neuron_spike_detected[rd_neuron_id]};
                        endcase
                    end else begin
                        read_data <= 32'h0;
                    end
                end else if (address >= INPUT_BASE && address < RNG_SEED_ADDR) begin
                    // Read input buffer
                    integer rd_inp_id;
                    rd_inp_id = address - INPUT_BASE;
                    if (rd_inp_id < NUM_NEURONS) begin
                        read_data <= neuron_input[rd_inp_id];
                    end else begin
                        read_data <= 32'h0;
                    end
                end else if (address == RNG_OUT_ADDR) begin
                    // Read RNG output
                    read_data <= rng_output;
                end else if (address == SPIKE_STATUS_ADDR) begin
                    // Read spike status register
                    read_data <= {{(32-NUM_NEURONS){1'b0}}, neuron_spike_detected};
                end else begin
                    read_data <= 32'h0;
                end
            end
        end
    end

endmodule
