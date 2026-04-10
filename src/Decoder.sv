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
    input [31:0] instr,           
    output reg [1:0] PCS,         
    output reg mem_to_reg,        
    output reg mem_write,         
    output reg [3:0] alu_control, 
    // NEW: alu_src_a selects the ALU's first operand (src_a).
    // This is required by the tutorial Q2.b/Q2.c architecture (ALUSrcA signal).
    // 2'b00 = rd1 (register file output, default for all R/I/S/B instructions)
    // 2'b01 = 32'b0 (zero, for LUI: result = 0 + ext_imm = ext_imm)
    // 2'b10 = PC    (for auipc: result = PC + ext_imm)
    output reg [1:0] alu_src_a,
    output reg alu_src_b,         
    output reg [2:0] imm_src,     
    output reg reg_write          
    );
    
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = instr[6:0];   
    assign funct3 = instr[14:12]; 
    assign funct7 = instr[31:25]; 
    
    always @(instr) begin
        PCS        = 2'b00;
        mem_to_reg = 0;
        mem_write  = 0;
        alu_src_b  = 0;
        alu_src_a  = 2'b00;
        reg_write  = 0;
        imm_src    = 3'b000;
        alu_control= 4'b0000;

        case (opcode)
            7'b0110011: begin // R-type
                reg_write = 1'b1;
                alu_src_b = 1'b0;
                case (funct3)
                    3'b000: alu_control = (funct7[5]) ? 4'b1000 : 4'b0000; // sub : add
                    3'b001: alu_control = 4'b0001; // sll
                    3'b010: alu_control = 4'b0010; // slt
                    3'b011: alu_control = 4'b0011; // sltu
                    3'b100: alu_control = 4'b0100; // xor
                    3'b101: alu_control = (funct7[5]) ? 4'b1101 : 4'b0101; // sra : srl
                    3'b110: alu_control = 4'b0110; // or
                    3'b111: alu_control = 4'b0111; // and
                    default: alu_control = 4'b0000;
                endcase
            end

            7'b0010011: begin // I-type
                reg_write = 1'b1;
                alu_src_b = 1'b1;
                imm_src   = 3'b000;
                case (funct3)
                    3'b000: alu_control = 4'b0000; // addi
                    3'b001: alu_control = 4'b0001; // slli
                    3'b010: alu_control = 4'b0010; // slti
                    3'b011: alu_control = 4'b0011; // sltiu
                    3'b100: alu_control = 4'b0100; // xori
                    3'b101: alu_control = (funct7[5]) ? 4'b1101 : 4'b0101; // srai : srli
                    3'b110: alu_control = 4'b0110; // ori
                    3'b111: alu_control = 4'b0111; // andi
                    default: alu_control = 4'b0000;
                endcase
            end

            7'b0000011: begin // I-type Load (lw)
                reg_write  = 1'b1;
                alu_src_b  = 1'b1;
                mem_to_reg = 1'b1;
                imm_src    = 3'b000;
                alu_control= 4'b0000; 
            end

            7'b0100011: begin // S-type (sw)
                mem_write  = 1'b1;
                alu_src_b  = 1'b1;
                imm_src    = 3'b001;
                alu_control= 4'b0000;
            end

            7'b1100011: begin // B-type (beq, bne, bge etc.)
                PCS        = 2'b01; 
                alu_src_b  = 1'b0;
                imm_src    = 3'b010;
                alu_control= 4'b0000;
            end

            7'b1101111: begin // J-type (jal)
                PCS       = 2'b10;
                reg_write = 1'b1;
                imm_src   = 3'b100;
            end

            7'b1100111: begin // I-type (jalr)
                PCS        = 2'b11;
                reg_write  = 1'b1;
                alu_src_b  = 1'b1;
                imm_src    = 3'b000; // I-type immediate
                alu_control= 4'b0000; // ADD: rs1 + imm = raw jump target
            end

            7'b0110111: begin // U-type (lui)
                reg_write  = 1'b1;
                alu_src_a  = 2'b01;
                alu_src_b  = 1'b1;
                imm_src    = 3'b011; // U-type: Extend produces {imm[31:12], 12'b0}
                alu_control= 4'b0000;
            end

            // result = PC + {imm[31:12], 12'b0}, written to rd.
            7'b0010111: begin // U-type (auipc)
                reg_write  = 1'b1;
                alu_src_a  = 2'b10;
                alu_src_b  = 1'b1;
                imm_src    = 3'b011; // U-type: Extend produces {imm[31:12], 12'b0}
                alu_control= 4'b0000; // ADD: PC + ext_imm
            end

            default: ;
        endcase
    end
endmodule