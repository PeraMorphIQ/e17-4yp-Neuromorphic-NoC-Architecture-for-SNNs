`include "cpu/cpu.v"
`timescale 1ns/100ps

module cpu_tb;
    parameter CLOCK_PERIOD = 10;

    // Inputs
    reg CLK, RESET;
    reg [31:0] PROD_DATA_MEM_READ_DATA, INSTRUCTION;
    wire INSTR_MEM_BUSYWAIT, DATA_MEM_BUSYWAIT;

    // Produced Outputs
    wire [2:0] PROD_DATA_MEM_WRITE;
    wire [3:0] PROD_DATA_MEM_READ;
    wire [31:0] PC, PROD_DATA_MEM_ADDR, PROD_DATA_MEM_WRITE_DATA;

    // Expected Outputs
    reg [2:0] EXP_DATA_MEM_WRITE;
    reg [3:0] EXP_DATA_MEM_READ;
    reg [31:0] EXP_DATA_MEM_ADDR, EXP_DATA_MEM_WRITE_DATA;
    reg [31:0] EXP_REG_VALUES [31:0];

    // Counters for passing and total testcases
    integer pass_count;
    integer testcase_count;
    integer fails;
    integer i, j, k;
    

    // Instantiate the CPU
    cpu dut (
        CLK, RESET, PC, INSTRUCTION, PROD_DATA_MEM_READ, PROD_DATA_MEM_WRITE,
        PROD_DATA_MEM_ADDR, PROD_DATA_MEM_WRITE_DATA, PROD_DATA_MEM_READ_DATA,
        DATA_MEM_BUSYWAIT, INSTR_MEM_BUSYWAIT
    );

    // Tie busywait signals to LOW
    assign INSTR_MEM_BUSYWAIT = 0;
    assign DATA_MEM_BUSYWAIT = 0;
    
    // Dump wavedata to VCD file (for GTKWave)
    // initial 
    // begin
    //     $dumpfile("cpu_tb.vcd");
    //     $dumpvars(0, dut);
    //     for (k = 0; k < 32; k = k + 1)
    //         $dumpvars(1, dut.ID_REG_FILE.REGISTERS[k]);
    // end

// `ifdef FSDB
//     // Dump wavedata to FSDB file (for power analysis with Synopsys tools)
//     initial
//     begin
//         $fsdbDumpfile("cpu_tb.fsdb");
//         $fsdbDumpvars(0, dut);
//         $fsdbDumpMDA();  // Dump multi-dimensional arrays
//     end
// `endif

    // Clock pulse
    initial CLK = 1'b1;
    always #(CLOCK_PERIOD / 2) CLK = ~CLK;

    initial
    begin
        // Initialize test cases
        pass_count = 0;
        testcase_count = 0;
        PROD_DATA_MEM_READ_DATA = 32'b0;  // Initialize memory read data

        reset_values();
        #(CLOCK_PERIOD)             // Wait one cycle after reset

        // ============ Test 1: LUI - Load Upper Immediate ============
        // LUI x1, 1  -> x1 = 0x1000 (1 << 12)
        INSTRUCTION = 32'b00000000000000000001000010110111;
        sync_expected_regs();
        EXP_REG_VALUES[1] = 32'd4096;
        EXP_DATA_MEM_WRITE = 3'b000;
        EXP_DATA_MEM_READ = 4'b0000;
        #(CLOCK_PERIOD*5)
        INSTRUCTION = 32'h00000013;  // NOP
        #(CLOCK_PERIOD)
        run_testcase("LUI x1, 1");

        // ============ Test 2: ADDI ============
        // ADDI x3, x0, 7  -> x3 = 0 + 7 = 7
        INSTRUCTION = 32'b00000000011100000000000110010011;
        sync_expected_regs();
        EXP_REG_VALUES[3] = 32'd7;
        #(CLOCK_PERIOD*5)
        INSTRUCTION = 32'h00000013;  // NOP
        #(CLOCK_PERIOD)
        run_testcase("ADDI x3, x0, 7");

        // ============ Test 3: ADDI with existing register ============
        // ADDI x3, x3, 3  -> x3 = 7 + 3 = 10
        INSTRUCTION = 32'b00000000001100011000000110010011;
        sync_expected_regs();
        EXP_REG_VALUES[3] = 32'd10;
        #(CLOCK_PERIOD*5)
        INSTRUCTION = 32'h00000013;  // NOP
        #(CLOCK_PERIOD)
        run_testcase("ADDI x3, x3, 3");

        // ============ Test 4: ADDI negative immediate ============
        // ADDI x4, x0, -5  -> x4 = 0 - 5 = -5 (0xFFFFFFFB)
        INSTRUCTION = 32'b11111111101100000000001000010011;
        sync_expected_regs();
        EXP_REG_VALUES[4] = 32'hFFFFFFFB;
        #(CLOCK_PERIOD*5)
        INSTRUCTION = 32'h00000013;  // NOP
        #(CLOCK_PERIOD)
        run_testcase("ADDI x4, x0, -5");

        // ============ Test 5: SLTI - Set Less Than Immediate ============
        // SLTI x5, x3, 15  -> x5 = (10 < 15) = 1
        INSTRUCTION = 32'b00000000111100011010001010010011;
        sync_expected_regs();
        EXP_REG_VALUES[5] = 32'd1;
        #(CLOCK_PERIOD*5)
        INSTRUCTION = 32'h00000013;  // NOP
        #(CLOCK_PERIOD)
        run_testcase("SLTI x5, x3, 15");

        // ============ Test 6: SLTI false case ============
        // SLTI x6, x3, 5  -> x6 = (10 < 5) = 0
        INSTRUCTION = 32'b00000000010100011010001100010011;
        sync_expected_regs();
        EXP_REG_VALUES[6] = 32'd0;
        #(CLOCK_PERIOD*5)
        INSTRUCTION = 32'h00000013;  // NOP
        #(CLOCK_PERIOD)
        run_testcase("SLTI x6, x3, 5");

        // ============ Test 7: SLTIU - Set Less Than Immediate Unsigned ============
        // SLTIU x7, x4, 10  -> x7 = (0xFFFFFFFB < 10 unsigned) = 0
        INSTRUCTION = 32'b00000000101000100011001110010011;
        sync_expected_regs();
        EXP_REG_VALUES[7] = 32'd0;
        #(CLOCK_PERIOD*5)
        INSTRUCTION = 32'h00000013;  // NOP
        #(CLOCK_PERIOD)
        run_testcase("SLTIU x7, x4, 10");

        // ============ Test 8: ANDI ============
        // ANDI x8, x3, 12  -> x8 = 10 & 12 = 8
        sync_expected_regs();
        EXP_REG_VALUES[8] = 32'd8;
        exec_and_check(32'b00000000110000011111010000010011, "ANDI x8, x3, 12");

        // ============ Test 9: ORI ============
        // ORI x9, x3, 5  -> x9 = 10 | 5 = 15
        sync_expected_regs();
        EXP_REG_VALUES[9] = 32'd15;
        exec_and_check(32'b00000000010100011110010010010011, "ORI x9, x3, 5");

        // ============ Test 10: XORI ============
        // XORI x10, x3, 7  -> x10 = 10 ^ 7 = 13
        sync_expected_regs();
        EXP_REG_VALUES[10] = 32'd13;
        exec_and_check(32'b00000000011100011100010100010011, "XORI x10, x3, 7");

        // ============ Test 11: SLLI - Shift Left Logical Immediate ============
        // SLLI x11, x3, 2  -> x11 = 10 << 2 = 40
        sync_expected_regs();
        EXP_REG_VALUES[11] = 32'd40;
        exec_and_check(32'b00000000001000011001010110010011, "SLLI x11, x3, 2");

        // ============ Test 12: SRLI - Shift Right Logical Immediate ============
        // SRLI x12, x11, 1  -> x12 = 40 >> 1 = 20
        sync_expected_regs();
        EXP_REG_VALUES[12] = 32'd20;
        exec_and_check(32'b00000000000101011101011000010011, "SRLI x12, x11, 1");

        // ============ Test 13: SRAI - Shift Right Arithmetic Immediate ============
        // SRAI x13, x4, 1  -> x13 = -5 >> 1 = -3 (0xFFFFFFFD)
        sync_expected_regs();
        EXP_REG_VALUES[13] = 32'hFFFFFFFD;
        exec_and_check(32'b01000000000100100101011010010011, "SRAI x13, x4, 1");

        // ============ Test 14: ADD ============
        // ADD x14, x3, x9  -> x14 = 10 + 15 = 25
        sync_expected_regs();
        EXP_REG_VALUES[14] = 32'd25;
        exec_and_check(32'b00000000100100011000011100110011, "ADD x14, x3, x9");

        // ============ Test 15: SUB ============
        // SUB x15, x9, x3  -> x15 = 15 - 10 = 5
        sync_expected_regs();
        EXP_REG_VALUES[15] = 32'd5;
        exec_and_check(32'b01000000001101001000011110110011, "SUB x15, x9, x3");

        // ============ Test 16: SLL - Shift Left Logical ============
        // SLL x16, x3, x5  -> x16 = 10 << 1 = 20 (shift by x5 which is 1)
        sync_expected_regs();
        EXP_REG_VALUES[16] = 32'd20;
        exec_and_check(32'b00000000010100011001100000110011, "SLL x16, x3, x5");

        // ============ Test 17: SLT - Set Less Than ============
        // SLT x17, x3, x9  -> x17 = (10 < 15) = 1
        sync_expected_regs();
        EXP_REG_VALUES[17] = 32'd1;
        exec_and_check(32'b00000000100100011010100010110011, "SLT x17, x3, x9");

        // ============ Test 18: SLTU - Set Less Than Unsigned ============
        // SLTU x18, x4, x3  -> x18 = (0xFFFFFFFB < 10 unsigned) = 0
        sync_expected_regs();
        EXP_REG_VALUES[18] = 32'd0;
        exec_and_check(32'b00000000001100100011100100110011, "SLTU x18, x4, x3");

        // ============ Test 19: XOR ============
        // XOR x19, x3, x9  -> x19 = 10 ^ 15 = 5
        sync_expected_regs();
        EXP_REG_VALUES[19] = 32'd5;
        exec_and_check(32'b00000000100100011100100110110011, "XOR x19, x3, x9");

        // ============ Test 20: SRL - Shift Right Logical ============
        // SRL x20, x11, x5  -> x20 = 40 >> 1 = 20
        sync_expected_regs();
        EXP_REG_VALUES[20] = 32'd20;
        exec_and_check(32'b00000000010101011101101000110011, "SRL x20, x11, x5");

        // ============ Test 21: SRA - Shift Right Arithmetic ============
        // SRA x21, x4, x5  -> x21 = -5 >> 1 = -3
        sync_expected_regs();
        EXP_REG_VALUES[21] = 32'hFFFFFFFD;
        exec_and_check(32'b01000000010100100101101010110011, "SRA x21, x4, x5");

        // ============ Test 22: OR ============
        // OR x22, x3, x15  -> x22 = 10 | 5 = 15
        sync_expected_regs();
        EXP_REG_VALUES[22] = 32'd15;
        exec_and_check(32'b00000000111100011110101100110011, "OR x22, x3, x15");

        // ============ Test 23: AND ============
        // AND x23, x9, x3  -> x23 = 15 & 10 = 10
        sync_expected_regs();
        EXP_REG_VALUES[23] = 32'd10;
        exec_and_check(32'b00000000001101001111101110110011, "AND x23, x9, x3");

        // ============ Test 24: AUIPC ============
        // AUIPC x24, 2  -> x24 = PC + (2 << 12) = PC + 8192
        sync_expected_regs();
        EXP_REG_VALUES[24] = PC + 32'd8192;
        exec_and_check(32'b00000000000000000010110000010111, "AUIPC x24, 2");

        // ============ Test 25: Large LUI ============
        // LUI x25, 0xABCDE  -> x25 = 0xABCDE000
        sync_expected_regs();
        EXP_REG_VALUES[25] = 32'hABCDE000;
        exec_and_check(32'b10101011110011011110110010110111, "LUI x25, 0xABCDE");

        // ============ Test 26: ADDI with zero ============
        // ADDI x26, x0, 0  -> x26 = 0
        sync_expected_regs();
        EXP_REG_VALUES[26] = 32'd0;
        exec_and_check(32'b00000000000000000000110100010011, "ADDI x26, x0, 0");

        // ============ Test 27: Chain arithmetic ============
        // ADDI x27, x14, 100  -> x27 = 25 + 100 = 125
        sync_expected_regs();
        EXP_REG_VALUES[27] = 32'd125;
        exec_and_check(32'b00000110010001110000110110010011, "ADDI x27, x14, 100");

        // ============ Test 28: ANDI all zeros ============
        // ANDI x28, x9, 0  -> x28 = 15 & 0 = 0
        sync_expected_regs();
        EXP_REG_VALUES[28] = 32'd0;
        exec_and_check(32'b00000000000001001111111000010011, "ANDI x28, x9, 0");

        // ============ Test 29: ORI all ones ============
        // ORI x29, x3, -1  -> x29 = 10 | 0xFFF = 0xFFF
        sync_expected_regs();
        EXP_REG_VALUES[29] = 32'hFFFFFFFF;
        exec_and_check(32'b11111111111100011110111010010011, "ORI x29, x3, -1");

        // ============ Test 30: XORI with all ones ============
        // XORI x30, x3, -1  -> x30 = ~10 = 0xFFFFFFF5
        sync_expected_regs();
        EXP_REG_VALUES[30] = 32'hFFFFFFF5;
        exec_and_check(32'b11111111111100011100111100010011, "XORI x30, x3, -1");


        // Display test results
        $display("\n========================================");
        $display("%t - Testbench completed.", $time);
        if (pass_count == testcase_count)
            $display("%t - \033[1;32m✓ ALL TESTS PASSED: %0d out of %0d testcase(s)\033[0m", $time, pass_count, testcase_count);
        else
            $display("%t - \033[1;31m✗ SOME TESTS FAILED: %0d out of %0d testcase(s) passing\033[0m", $time, pass_count, testcase_count);
        $display("========================================\n");
        
        // End simulation
        $finish;
    end


    // Helper task to run a single testcase
    task run_testcase (input reg[127:0] instruction_name);
    begin
        testcase_count = testcase_count + 1;
        fails = 0;

        // Display instruction being tested
        $display("\033[1m[ %0s ]\033[0m", instruction_name);

        // Compare register values
        for (i = 0; i < 32; i = i + 1) 
        begin
            if (dut.ID_REG_FILE.REGISTERS[i] !== EXP_REG_VALUES[i])
            begin
                $display("\t\033[1;31m[FAILED]\033[0m REGISTERS[%0d] = %0x, EXP_REG_VALUES[%0d] = %0x", i, dut.ID_REG_FILE.REGISTERS[i], i, EXP_REG_VALUES[i]);
                fails = fails + 1;
            end
        end

        // If MSB doesn't match, fail
        // If MSB matches, check LSBs only if MSB=1
        if ((PROD_DATA_MEM_WRITE[2] !== EXP_DATA_MEM_WRITE[2]) ||
            ((PROD_DATA_MEM_WRITE[2] === 1'b1) && (PROD_DATA_MEM_WRITE[1:0] !== EXP_DATA_MEM_WRITE[1:0])))
        begin
            $display("\t\033[1;31m[FAILED]\033[0m PROD_DATA_MEM_WRITE = %b, EXP_DATA_MEM_WRITE = %b", PROD_DATA_MEM_WRITE, EXP_DATA_MEM_WRITE);
            fails = fails + 1;
        end
        
        // If MSB doesn't match, fail
        // If MSB matches, check LSBs only if MSB=1
        if ((PROD_DATA_MEM_READ[3] !== EXP_DATA_MEM_READ[3]) ||
            ((PROD_DATA_MEM_READ[3] === 1'b1) && (PROD_DATA_MEM_READ[2:0] !== EXP_DATA_MEM_READ[2:0])))
        begin
            $display("\t\033[1;31m[FAILED]\033[0m PROD_DATA_MEM_READ = %b, EXP_DATA_MEM_READ = %b", PROD_DATA_MEM_READ, EXP_DATA_MEM_READ);
            fails = fails + 1;
        end

        // Only compare in case of data memory read/write
        if ((EXP_DATA_MEM_READ[3] || EXP_DATA_MEM_WRITE[2]) && (PROD_DATA_MEM_ADDR !== EXP_DATA_MEM_ADDR))
        begin
            $display("\t\033[1;31m[FAILED]\033[0m PROD_DATA_MEM_ADDR = %0x, EXP_DATA_MEM_ADDR = %0x", PROD_DATA_MEM_ADDR, EXP_DATA_MEM_ADDR);
            fails = fails + 1;
        end

    // Only compare in case of data memory write
        if ((EXP_DATA_MEM_WRITE) && (PROD_DATA_MEM_WRITE_DATA !== EXP_DATA_MEM_WRITE_DATA))
        begin
            $display("\t\033[1;31m[FAILED]\033[0m PROD_DATA_MEM_WRITE_DATA = %0x, EXP_DATA_MEM_WRITE_DATA = %0x", PROD_DATA_MEM_WRITE_DATA, EXP_DATA_MEM_WRITE_DATA);
            fails = fails + 1;
        end
        
        // Check if testcase passed
        if (fails === 0) 
        begin
            pass_count = pass_count + 1;
        end
    end
    endtask

    task reset_values;
    begin
        for (j = 0; j < 32; j = j + 1)
        begin
            EXP_REG_VALUES[j] <= 0;       // Write zero to all registers
        end

        RESET = 1;
        #(CLOCK_PERIOD)
        RESET = 0;
    end
    endtask

    // Task to sync expected register values with current DUT state
    task sync_expected_regs;
    begin
        for (j = 0; j < 32; j = j + 1)
        begin
            EXP_REG_VALUES[j] = dut.ID_REG_FILE.REGISTERS[j];  // Copy current register state
        end
        EXP_DATA_MEM_WRITE = 3'b000;
        EXP_DATA_MEM_READ = 4'b0000;
        EXP_DATA_MEM_ADDR = 32'dx;
        EXP_DATA_MEM_WRITE_DATA = 32'dx;
    end
    endtask

    // Task to execute instruction and check results
    task exec_and_check(input reg[31:0] instr, input reg[127:0] test_name);
    begin
        INSTRUCTION = instr;
        #(CLOCK_PERIOD*5)   // Wait for instruction to complete
        INSTRUCTION = 32'h00000013;  // Insert NOP
        #(CLOCK_PERIOD)     // Wait for NOP to enter pipeline
        run_testcase(test_name);
    end
    endtask


endmodule
