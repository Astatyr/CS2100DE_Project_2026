`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: National University of Singapore
// Engineer: Neil Banerjee
// 
// Create Date: 05.03.2025 23:43:42
// Design Name: RISCV-MMC
// Module Name: Extend
// Project Name: CS2100DE Labs
// Target Devices: Nexys 4/Nexys 4 DDR
// Tool Versions: Vivado 2023.2
// Description: Module for extending immediates
// 
// Dependencies: Nil
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Extend(
    input [31:7] instr_imm,    // The upper bits of the instruction
    input [2:0] imm_src,       // 3-bit selector from the Decoder
    output reg [31:0] ext_imm  // The final 32-bit sign-extended immediate
    );
    
    // This block triggers whenever the input bits or the selection signal changes
    always @(imm_src, instr_imm) begin
        case (imm_src)
            // I-type: 12-bit immediate [31:20]
            // Format: { {20{Sign}}, instr[31:20] }
            3'b000: begin 
                ext_imm = {{20{instr_imm[31]}}, instr_imm[31:20]};
            end

            // S-type: 12-bit immediate split across [31:25] and [11:7]
            // Format: { {20{Sign}}, instr[31:25], instr[11:7] }
            3'b001: begin 
                ext_imm = {{20{instr_imm[31]}}, instr_imm[31:25], instr_imm[11:7]};
            end

            // B-type: 12-bit signed offset, but bit 0 is always 0 (multiples of 2)
            // Format: { {19{Sign}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0 }
            3'b010: begin 
                ext_imm = {{19{instr_imm[31]}}, instr_imm[31], instr_imm[7], instr_imm[30:25], instr_imm[11:8], 1'b0};
            end

            // U-type: 20-bit immediate [31:12] placed in the upper part of the word
            // Format: { instr[31:12], 12'b0 }
            3'b011: begin 
                ext_imm = {instr_imm[31:12], 12'b0};
            end

            // J-type: 20-bit signed offset, but bit 0 is always 0
            // Format: { {11{Sign}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0 }
            3'b100: begin 
                ext_imm = {{11{instr_imm[31]}}, instr_imm[31], instr_imm[19:12], instr_imm[20], instr_imm[30:21], 1'b0};
            end

            default: begin
                ext_imm = 32'b0;
            end
        endcase
    end
endmodule

