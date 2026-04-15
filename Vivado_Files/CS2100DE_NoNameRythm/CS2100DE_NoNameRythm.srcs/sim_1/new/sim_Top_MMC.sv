`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: National University of Singapore
// Engineer: Neil Banerjee
// 
// Create Date: 02.04.2025 20:41:55
// Design Name: RISCV-MMC
// Module Name: sim_Top_MMC
// Project Name: CS2100DE Labs
// Target Devices: Nexys 4/Nexys 4 DDR
// Tool Versions: Vivado 2023.2
// Description: Simulation testbench for rhythm game Top_MMC
// 
// Dependencies: Nil
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module sim_Top_MMC(
    
    );
    
    logic clk;
    logic btnCpuReset;
    logic btnC;
    logic btnU;
    logic btnL;
    logic btnR;
    logic btnD;
    logic [15:0] sw;
    
    logic [15:0] led;
    logic [6:0] seg;
    logic [7:0] an;
    
    Top_MMC dut (
        .clk(clk),
        .btnCpuReset(btnCpuReset),
        .btnC(btnC),
        .btnU(btnU),
        .btnL(btnL),
        .btnR(btnR),
        .btnD(btnD),
        .sw(sw),
        .led(led),
        .seg(seg),
        .an(an)
    );
    
    initial begin
        clk         = 0;
        btnCpuReset = 0;
        btnC        = 0;
        btnU        = 0;
        btnL        = 0;
        btnR        = 0;
        btnD        = 0;
        sw          = 16'hA5A5; // initial seed shown on start screen

        // hold reset for 2 ns then release
        #2;
        btnCpuReset = 1;

        // let CPU run through main init and enter start screen loop
        #500;

        // change seed mid start screen - 7-seg display should update
        sw = 16'h1234;
        #200;

        // press btnC to lock seed and start game
        btnC = 1;
        #10;
        btnC = 0;

        // let generate_notes (128 RNG iterations) and run_game init complete
        #2000;

        // press btnU - top note hit attempt
        btnU = 1;
        #10;
        btnU = 0;
        #200;

        // press btnD - bottom note hit attempt
        btnD = 1;
        #10;
        btnD = 0;
        #200;

        // press btnL - left note hit attempt
        btnL = 1;
        #10;
        btnL = 0;
        #200;

        // press btnR - right note hit attempt
        btnR = 1;
        #10;
        btnR = 0;
        #200;

        // mid-game reset - should return to start screen
        btnC = 1;
        #10;
        btnC = 0;
        #500;

        // new seed and second game
        sw = 16'hBEEF;
        #200;
        btnC = 1;
        #10;
        btnC = 0;
        #2000;
    end
    
    always begin
        clk = ~clk;
        #5;
    end
    
endmodule