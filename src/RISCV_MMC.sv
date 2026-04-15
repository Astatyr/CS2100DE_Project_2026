`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: National University of Singapore
// Engineer: Neil Banerjee
// 
// Create Date: 22.02.2025 21:29:09
// Design Name: RISCV-MMC
// Module Name: RISCV_MMC
// Project Name: CS2100DE Labs
// Target Devices: Nexys 4/Nexys 4 DDR
// Tool Versions: Vivado 2023.2
// Description: The main RISC-V CPU 
// 
// Dependencies: Nil
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module RISCV_MMC(
    input         clk,
    input         rst,

    // Instruction memory interface
    input  [31:0] instr,

    // Data memory interface
    input  [31:0] mem_read_data,
    output        mem_read,
    output        mem_write,
    output [31:0] PC,
    output [31:0] alu_result,
    output [31:0] mem_write_data
);

    assign mem_read = mem_to_reg;

    // -------------------------------------------------------------------------
    // Instruction field extraction
    // -------------------------------------------------------------------------
    logic [4:0] rs1, rs2, rd;
    assign rs1 = instr[19:15];
    assign rs2 = instr[24:20];
    assign rd  = instr[11:7];

    // -------------------------------------------------------------------------
    // Control signals
    // -------------------------------------------------------------------------
    logic [1:0] pcs;
    logic       mem_to_reg;
    logic       alu_src_b;
    logic [1:0] alu_src_a;    // 00=rs1, 01=zero (LUI), 10=PC (AUIPC)
    logic       reg_write;
    logic [2:0] imm_src;
    logic [3:0] alu_control;
    logic       link_reg;     // 1 = write PC+4 to rd (JAL / JALR)

    // -------------------------------------------------------------------------
    // Datapath signals
    // -------------------------------------------------------------------------
    logic [31:0] rd1, rd2;
    logic [31:0] ext_imm;
    logic [31:0] src_a, src_b;
    logic [31:0] write_data;
    logic [31:0] pc_next;
    logic [31:0] pc_current;
    logic [2:0]  alu_flags;
    logic [1:0]  pc_src;      // 00=PC+4, 01=PC+imm, 11=ALU result (JALR)

    // =========================================================================
    // Sub-module instantiations
    // =========================================================================

    Extend ext_inst (
        .instr_imm (instr[31:7]),
        .imm_src   (imm_src),
        .ext_imm   (ext_imm)
    );

    Decoder dec_inst (
        .instr       (instr),
        .PCS         (pcs),
        .mem_to_reg  (mem_to_reg),
        .mem_write   (mem_write),
        .alu_control (alu_control),
        .alu_src_b   (alu_src_b),
        .alu_src_a   (alu_src_a),
        .imm_src     (imm_src),
        .reg_write   (reg_write),
        .link_reg    (link_reg)
    );

    ALU alu_inst (
        .src_a   (src_a),
        .src_b   (src_b),
        .control (alu_control),
        .result  (alu_result),
        .flags   (alu_flags)
    );

    RegFile rf_inst (
        .clk (clk),
        .we  (reg_write),
        .rs1 (rs1),
        .rs2 (rs2),
        .rd  (rd),
        .WD  (write_data),
        .RD1 (rd1),
        .RD2 (rd2)
    );

    PC_Logic pc_logic_inst (
        .PCS       (pcs),
        .funct3    (instr[14:12]),
        .alu_flags (alu_flags),
        .PC_src    (pc_src)
    );

    ProgramCounter pc_inst (
        .clk   (clk),
        .rst   (rst),
        .pc_in (pc_next),
        .pc    (pc_current)
    );

    // =========================================================================
    // Glue logic - multiplexers
    // =========================================================================

    // --- ALU src_a mux -------------------------------------------------------
    //   2'b00 : rd1        - normal instructions
    //   2'b01 : 32'b0      - LUI
    //   2'b10 : pc_current - AUIPC
    assign src_a = (alu_src_a == 2'b01) ? 32'b0
                 : (alu_src_a == 2'b10) ? pc_current
                 :                        rd1;

    // --- ALU src_b mux -------------------------------------------------------
    //   1 : sign-extended immediate
    //   0 : rd2
    assign src_b = (alu_src_b) ? ext_imm : rd2;

    // --- Write-back mux ------------------------------------------------------
    //   mem_to_reg = 1 : load data from memory
    //   link_reg   = 1 : write PC + 4 (JAL / JALR)
    //   otherwise  : write ALU result
    assign write_data = (mem_to_reg) ? mem_read_data
                     : (link_reg)   ? (pc_current + 4)
                     :                alu_result;

    // --- Next-PC mux ---------------------------------------------------------
    //   00 : sequential => PC + 4
    //   01 : branch / JAL => PC + immediate
    //   11 : JALR => ALU result (rs1 + imm), with bit 0 cleared per RISC-V spec
    assign pc_next = (pc_src == 2'b00) ? (pc_current + 4)
                   : (pc_src == 2'b01) ? (pc_current + ext_imm)
                   : (pc_src == 2'b11) ? (alu_result & 32'hFFFFFFFE)
                   :                     (pc_current + 4);

    // =========================================================================
    // Output connections
    // =========================================================================
    assign PC             = pc_current;
    assign mem_write_data = rd2;
    assign mem_read       = mem_to_reg;

endmodule
