`timescale 1ns / 1ps
/*
----------------------------------------------------------------------------------
-- Company: NUS
-- Engineer: (c) Rajesh Panicker
--
-- Create Date: 09/22/2020 06:49:10 PM
-- Module Name: CondLogic
-- Project Name: CG3207 Project
-- Target Devices: Nexys 4 / Basys 3
-- Tool Versions: Vivado 2019.2
-- Description: RISC-V Processor Conditional Logic Module
--
-- Dependencies: NIL
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments: Interface and implementation can be modified.
--
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- License terms :
-- You are free to use this code as long as you
--     (i) DO NOT post it on any public repository;
--     (ii) use it only for educational purposes;
--     (iii) accept the responsibility to ensure that your implementation does not violate anyone's intellectual property.
--     (iv) accept that the program is provided "as is" without warranty of any kind or assurance regarding its suitability for any particular purpose;
--     (v) send an email to rajesh<dot>panicker<at>ieee.org briefly mentioning its use (except when used for the course CG3207 at the National University of Singapore);
--     (vi) retain this notice in this file as well as any files derived from this.
----------------------------------------------------------------------------------
*/

module PC_Logic(
    input [1:0] PCS,        // 00 = normal, 01 = branch, 10 = JAL, 11 = JALR
    input [2:0] funct3,     // branch condition field
    input [2:0] alu_flags,  // {eq, lt, ltu}
    output reg [1:0] PC_src // 00 = PC+4, 01 = PC+imm, 11 = ALU result (JALR)
);

    /*
        Important Note:
        In RISC-V, the flags are produced and consumed in the same branch instruction.
        This module only decides which PC source to use next.
    */

    always @(*) begin
        case (PCS)
            2'b00: PC_src = 2'b00; // normal instruction => PC + 4

            2'b01: begin // conditional branch
                case (funct3)
                    3'b000: PC_src = ( alu_flags[2]) ? 2'b01 : 2'b00; // BEQ
                    3'b001: PC_src = (~alu_flags[2]) ? 2'b01 : 2'b00; // BNE
                    3'b100: PC_src = ( alu_flags[1]) ? 2'b01 : 2'b00; // BLT
                    3'b101: PC_src = (~alu_flags[1]) ? 2'b01 : 2'b00; // BGE
                    3'b110: PC_src = ( alu_flags[0]) ? 2'b01 : 2'b00; // BLTU
                    3'b111: PC_src = (~alu_flags[0]) ? 2'b01 : 2'b00; // BGEU
                    default: PC_src = 2'b00;
                endcase
            end

            2'b10: PC_src = 2'b01; // JAL => PC + immediate
            2'b11: PC_src = 2'b11; // JALR => ALU result

            default: PC_src = 2'b00;
        endcase
    end

endmodule



