`include "mesh.v"
`timescale 1ns/100ps

module mesh_tb;

    parameter ROWS = 2;
    parameter COLS = 2;
    parameter NUM_NEURONS = 32;
    parameter DATA_WIDTH = 32;

    reg clk;
    reg rst;

    // Instantiate the Mesh
    mesh #(
        .ROWS(ROWS),
        .COLS(COLS),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_NEURONS(NUM_NEURONS)
    ) u_mesh (
        .clk(clk),
        .rst(rst)
    );

    // Clock Generation
    always #5 clk = ~clk; // 100MHz clock

    initial begin
        // $dumpfile("mesh_tb.vcd");
        // $dumpvars(0, mesh_tb);

        clk = 0;
        rst = 1;
        
        #20;
        rst = 0;
        
        // Run for some cycles
        #1000;
        
        $finish;
    end

    // Monitor some signals from Node (0,0)
    // Note: Accessing internal signals depends on hierarchy
    // u_mesh.ROW_LOOP[0].COL_LOOP[0].u_node.pc
    
    initial begin
        $monitor("Time: %t | Node(0,0) PC: %h Instr: %h Busy: I=%b D=%b Haz: %b | Node(1,1) PC: %h Instr: %h", 
                 $time, 
                 u_mesh.ROW_LOOP[0].COL_LOOP[0].u_node.pc,
                 u_mesh.ROW_LOOP[0].COL_LOOP[0].u_node.instruction,
                 u_mesh.ROW_LOOP[0].COL_LOOP[0].u_node.instr_mem_busywait,
                 u_mesh.ROW_LOOP[0].COL_LOOP[0].u_node.data_mem_busywait,
                 u_mesh.ROW_LOOP[0].COL_LOOP[0].u_node.CPU.ID_LU_HAZ_SIG,
                 u_mesh.ROW_LOOP[1].COL_LOOP[1].u_node.pc,
                 u_mesh.ROW_LOOP[1].COL_LOOP[1].u_node.instruction);
    end

endmodule
