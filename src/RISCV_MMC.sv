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
    input clk,
    input rst,
    //input Interrupt,      // for optional future use.
    input [31:0] instr,
    input [31:0] mem_read_data,       // v2: Renamed to support lb/lbu/lh/lhu
    output mem_read,
    output mem_write,  // Delete reg for release. v2: Changed to column-wise write enable to support sb/sw. Each column is a byte.
    output [31:0] PC,
    output [31:0] alu_result,
    output [31:0] mem_write_data  // Delete reg for release. v2: Renamed to support sb/sw
    );


	// Create all the wires/logic signals you need here
	// Instruction Fields (sliced from the 32-bit instr)
    logic [4:0] rs1, rs2, rd;
    assign rs1 = instr[19:15];
    assign rs2 = instr[24:20];
    assign rd  = instr[11:7];

    // Control Signals from Decoder
    logic [1:0] pcs;
    logic mem_to_reg, alu_src_b, reg_write;
    logic [2:0] imm_src;
    logic [3:0] alu_control;
    // NEW: alu_src_a selects what feeds the ALU's first input (tutorial ALUSrcA signal).
    // 2'b00 = rd1 (default), 2'b01 = zero (LUI), 2'b10 = PC (auipc)
    logic [1:0] alu_src_a;

    // Data path signals
    logic [31:0] rd1, rd2, ext_imm, src_b, write_data;
    logic [31:0] pc_next, pc_current;
    logic [2:0]  alu_flags;
    // pc_src is 2 bits: 00=PC+4, 01=PC+imm (branch/jal), 11=rs1+imm (jalr)
    logic [1:0]  pc_src;

    // pc_plus4 carries the JAL/JALR return address (PC+4) for writeback into rd
    logic [31:0] pc_plus4;

    // NEW: src_a is the ALUSrcA MUX output - what actually enters the ALU's A port.
    // Keeping it separate from rd1 means the register file output is never corrupted.
    logic [31:0] src_a;

    // Intermediate wire for JALR target - named so Vivado can slice it (cannot slice
    // an expression directly, e.g. (rd1+ext_imm)[31:1] is not legal in Vivado).
    logic [31:0] jalr_target;


	// Instantiate your extender module here
	    Extend ext_inst (
        .instr_imm(instr[31:7]),
        .imm_src(imm_src),
        .ext_imm(ext_imm)
    );
    

	// Instantiate your instruction decoder here
	Decoder dec_inst (
        .instr(instr),
        .PCS(pcs),
        .mem_to_reg(mem_to_reg),
        .mem_write(mem_write),     // Connects directly to the output port
        .alu_control(alu_control),
        // NEW: alu_src_a connected from Decoder to the ALUSrcA MUX below
        .alu_src_a(alu_src_a),
        .alu_src_b(alu_src_b),
        .imm_src(imm_src),
        .reg_write(reg_write)
    );


	// Instantiate your ALU here
	    ALU alu_inst (
        // NEW: src_a (MUX output) replaces the old direct rd1 connection.
        // This allows LUI (src_a=0) and auipc (src_a=PC) to feed the ALU correctly.
        .src_a(src_a),
        .src_b(src_b),   // The MUX output
        .control(alu_control),
        .result(alu_result), // Connects directly to the output port
        .flags(alu_flags)
    );


	// Instantiate the Register File
	RegFile rf_inst (
        .clk(clk),
        .we(reg_write),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .WD(write_data), // The MUX output
        .RD1(rd1),
        .RD2(rd2)
    );


	// Instantiate the PC Logic
    PC_Logic pc_logic_inst (
        .PCS(pcs),              // From Decoder
        .funct3(instr[14:12]),  // From Instruction
        .alu_flags(alu_flags),  // From ALU
        .PC_src(pc_src)         // Output decision
    );	


	// Instantiate the Program Counter
	ProgramCounter pc_inst (
        .clk(clk),
        .rst(rst),
        .pc_in(pc_next),
        .pc(pc_current)
    );
    
    
    // --- Glue Logic (Multiplexers) ---

    // ALU Source A MUX
    // 2'b01 (LUI)  : src_a = 0      → ALU computes 0 + ext_imm = ext_imm
    // 2'b10 (auipc): src_a = PC     → ALU computes PC + ext_imm
    // default      : src_a = rd1    → normal register-register / register-immediate ops
    assign src_a = (alu_src_a == 2'b01) ? 32'b0      :
                   (alu_src_a == 2'b10) ? pc_current  :
                                          rd1;

    // ALU Source B Mux
    assign src_b = (alu_src_b) ? ext_imm : rd2;

    // pc_plus4 is the sequential next address - used as the return address for
    // both JAL (pcs==2'b10) and JALR (pcs==2'b11).
    assign pc_plus4 = pc_current + 4;

    // Result/Write-back Mux (3-way)
    // Priority: memory load > JAL/JALR link > ALU result
    assign write_data = (mem_to_reg)                       ? mem_read_data :
                        (pcs == 2'b10 || pcs == 2'b11)     ? pc_plus4      :
                                                             alu_result;

    // Intermediate JALR target - must be a named signal before Vivado allows bit-slicing
    assign jalr_target = rd1 + ext_imm;

    // PC Next Mux (3-way)
    // 2'b01: branch taken or JAL  → PC + ext_imm
    // 2'b11: JALR                 → (rd1 + ext_imm) with bit 0 cleared (RISC-V spec)
    // default: normal fetch       → PC + 4
    assign pc_next = (pc_src == 2'b01) ? (pc_current + ext_imm)    : // branch / jal
                     (pc_src == 2'b11) ? {jalr_target[31:1], 1'b0} : // jalr (bit 0 cleared)
                                         (pc_current + 4);            // normal fetch

    // Final Output Connections
    assign PC = pc_current;
    assign mem_write_data = rd2;
    assign mem_read = mem_to_reg;
    

endmodule