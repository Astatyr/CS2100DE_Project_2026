`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: National University of Singapore
// Engineer: Neil Banerjee
// 
// Create Date: 06.03.2025 23:18:08
// Design Name: RISCV-MMC
// Module Name: Decoder_Extend_sim
// Project Name: CS2100DE Labs
// Target Devices: Nexys4/Nexys 4 DDR
// Tool Versions: Vivado 2023.2
// Description: Simulating the decoder and immediate extender
// 
// Dependencies: Nil
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Decoder_Extend_sim();
    
    // Inputs to the Unit Under Test (UUT)
    logic [31:0] instr;
    
    // Outputs from the Decoder (Updated widths to match module)
    logic [2:0]  imm_src;     // Changed from logic to [2:0]
    logic [1:0]  PCS;         // Changed from logic to [1:0]
    logic        mem_to_reg;
    logic        mem_write;
    logic [3:0]  alu_control; // Changed from logic to [3:0]
    logic        alu_src_b;
    logic        reg_write;
    
    // Output from the Extender
    logic [31:0] ext_imm;
    
    // Instantiate the Decoder
    Decoder decoder_uut (
        .instr(instr),
        .PCS(PCS),
        .imm_src(imm_src),
        .mem_to_reg(mem_to_reg),
        .mem_write(mem_write),
        .alu_control(alu_control),
        .alu_src_b(alu_src_b),
        .reg_write(reg_write)
    );
    
    // Instantiate the Extend module
    Extend extender_uut (
        .instr_imm(instr[31:7]),
        .imm_src(imm_src),
        .ext_imm(ext_imm)
    );
    
    initial begin
        // --- Test Case 1: ADDI (I-type) ---
        // addi x20, x20, -8
        // Expected: reg_write=1, alu_src_b=1, imm_src=000, ext_imm=FFFFFFF8
        instr = 32'hFF8A0A13; 
        #10;
        
        // --- Test Case 2: SW (S-type) ---
        // sw x5, 4(x6) -> Machine code: 00532223
        // Expected: mem_write=1, alu_src_b=1, imm_src=001, reg_write=0
        instr = 32'h00532223;
        #10;

        // --- Test Case 3: BEQ (B-type) ---
        // beq x5, x6, 8 -> Machine code: 00628463
        // Expected: PCS=01, imm_src=010, reg_write=0
        instr = 32'h00628463;
        #10;

        $finish; // End simulation
    end
    
endmodule
