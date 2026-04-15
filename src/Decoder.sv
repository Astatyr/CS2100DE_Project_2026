`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: National University of Singapore
// Engineer: Neil Banerjee
// 
// Create Date: 22.02.2025 20:37:13
// Design Name: RISCV-MMC
// Module Name: Decoder 
// Project Name: CS2100DE Labs
// Target Devices: Nexys 4/Nexys 4 DDR
// Tool Versions: Vivado 2023.2
// Description: Instruction decoder and Control Unit for the RISC-V CPU we are building
// 
// Dependencies: Nil
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps
module Decoder(
    input  [31:0] instr,
    output reg [1:0] PCS,
    output reg       mem_to_reg,
    output reg       mem_write,
    output reg [3:0] alu_control,
    output reg       alu_src_b,
    output reg [1:0] alu_src_a,
    output reg [2:0] imm_src,
    output reg       reg_write,
    output reg       link_reg
);

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = instr[6:0];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];

    always @(instr) begin
        // Default control signal values (NOP-like state)
        PCS         = 2'b00;
        mem_to_reg  = 1'b0;
        mem_write   = 1'b0;
        alu_src_b   = 1'b0;
        alu_src_a   = 2'b00;   // default: src_a = rs1
        reg_write   = 1'b0;
        imm_src     = 3'b000;
        alu_control = 4'b0000;
        link_reg    = 1'b0;

        case (opcode)

            // ------------------------------------------------------------------
            // R-type: register-register arithmetic/logic
            // ------------------------------------------------------------------
            7'b0110011: begin
                reg_write = 1'b1;
                alu_src_b = 1'b0;  // src_b = rs2

                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000001)
                            alu_control = 4'b1001; // MUL
                        else
                            alu_control = (funct7[5]) ? 4'b1000 : 4'b0000; // SUB : ADD
                    end
                    3'b001: alu_control = 4'b0001; // SLL
                    3'b010: alu_control = 4'b0010; // SLT
                    3'b011: alu_control = 4'b0011; // SLTU
                    3'b100: alu_control = 4'b0100; // XOR
                    3'b101: alu_control = (funct7[5]) ? 4'b1101 : 4'b0101; // SRA : SRL
                    3'b110: alu_control = 4'b0110; // OR
                    3'b111: alu_control = 4'b0111; // AND
                    default: alu_control = 4'b0000;
                endcase
            end

            // ------------------------------------------------------------------
            // I-type: register-immediate arithmetic/logic
            // ------------------------------------------------------------------
            7'b0010011: begin
                reg_write   = 1'b1;
                alu_src_b   = 1'b1;
                imm_src     = 3'b000;

                case (funct3)
                    3'b000: alu_control = 4'b0000; // ADDI
                    3'b001: alu_control = 4'b0001; // SLLI
                    3'b010: alu_control = 4'b0010; // SLTI
                    3'b011: alu_control = 4'b0011; // SLTIU
                    3'b100: alu_control = 4'b0100; // XORI
                    3'b101: alu_control = (funct7[5]) ? 4'b1101 : 4'b0101; // SRAI : SRLI
                    3'b110: alu_control = 4'b0110; // ORI
                    3'b111: alu_control = 4'b0111; // ANDI
                    default: alu_control = 4'b0000;
                endcase
            end

            // ------------------------------------------------------------------
            // I-type Load: LW
            // ------------------------------------------------------------------
            7'b0000011: begin
                reg_write   = 1'b1;
                alu_src_b   = 1'b1;
                mem_to_reg  = 1'b1;
                imm_src     = 3'b000;
                alu_control = 4'b0000; // ADD (base + offset)
            end

            // ------------------------------------------------------------------
            // I-type Jump: JALR
            //   Jump target = rs1 + imm
            //   rd = PC + 4
            // ------------------------------------------------------------------
            7'b1100111: begin
                PCS         = 2'b11;
                reg_write   = 1'b1;
                alu_src_b   = 1'b1;
                imm_src     = 3'b000;
                alu_control = 4'b0000; // ADD (rs1 + imm)
                link_reg    = 1'b1;    // rd gets return address = PC + 4
            end

            // ------------------------------------------------------------------
            // S-type: SW
            // ------------------------------------------------------------------
            7'b0100011: begin
                mem_write   = 1'b1;
                alu_src_b   = 1'b1;
                imm_src     = 3'b001;
                alu_control = 4'b0000; // ADD (base + offset)
            end

            // ------------------------------------------------------------------
            // B-type: conditional branches
            // ------------------------------------------------------------------
            7'b1100011: begin
                PCS         = 2'b01;
                alu_src_b   = 1'b0;
                imm_src     = 3'b010;
                alu_control = 4'b1000; // SUB for comparison flags
            end

            // ------------------------------------------------------------------
            // J-type: JAL
            //   PC = PC + J-imm
            //   rd = PC + 4
            // ------------------------------------------------------------------
            7'b1101111: begin
                PCS       = 2'b10;
                reg_write = 1'b1;
                imm_src   = 3'b100;
                link_reg  = 1'b1; // rd gets return address = PC + 4
            end

            // ------------------------------------------------------------------
            // U-type: LUI
            //   rd = 0 + U-imm
            // ------------------------------------------------------------------
            7'b0110111: begin
                reg_write   = 1'b1;
                alu_src_a   = 2'b01;   // src_a = 0
                alu_src_b   = 1'b1;    // src_b = U-immediate
                imm_src     = 3'b011;
                alu_control = 4'b0000; // ADD (0 + imm)
            end

            // ------------------------------------------------------------------
            // U-type: AUIPC
            //   rd = PC + U-imm
            // ------------------------------------------------------------------
            7'b0010111: begin
                reg_write   = 1'b1;
                alu_src_a   = 2'b10;   // src_a = current PC
                alu_src_b   = 1'b1;    // src_b = U-immediate
                imm_src     = 3'b011;
                alu_control = 4'b0000; // ADD (PC + imm)
            end

            default: ;
        endcase
    end

endmodule
