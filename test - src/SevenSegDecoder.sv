`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.04.2025 19:02:15
// Design Name: 
// Module Name: SevenSegDecoder
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Revision 0.02 - Added base_mode input for rhythm game segment patterns
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module SevenSegDecoder(
    input clk,
    input [31:0] data,
    // 0 = standard hex display (0-F), used during score/game-over display.
    // 1 = game segment patterns (see table below), used during active gameplay.
    //
    // Game nibble encoding (seg[6:0] = {CG,CF,CE,CD,CC,CB,CA}, active-low):
    //   0x0 = blank         (all segments off)     7'b1111111
    //   0x1 = middle  '-'   (seg g, line marker)   7'b0111111
    //   0x2 = top     '-'   (seg a, press btnU)     7'b1111110
    //   0x3 = bottom  '-'   (seg d, press btnD)     7'b1110111
    //   0x4 = left    '|'   (segs e+f, press btnL)  7'b1001111
    //   0x5 = right   '|'   (segs b+c, press btnR)  7'b1111001
    //   0x6-0xF = hex digits 0-9 (same as base_mode=0), used on AN7 for score
    input base_mode,
    output logic [6:0] seg,
    output reg [7:0] an
    );
    
    logic [12:0] counter;
    logic [2:0] an_to_display;
    logic [3:0] byte_to_display;

    assign seg = base_mode ? (
        // Game mode: nibbles 0-5 are custom shapes; 6-F fall through to hex
        (byte_to_display == 4'h0) ? 7'b1111111  // blank
      : (byte_to_display == 4'h1) ? 7'b0111111  // middle '-'  (seg g)
      : (byte_to_display == 4'h2) ? 7'b1111110  // top    '-'  (seg a)
      : (byte_to_display == 4'h3) ? 7'b1110111  // bottom '-'  (seg d)
      : (byte_to_display == 4'h4) ? 7'b1001111  // left   '|'  (segs e+f)
      : (byte_to_display == 4'h5) ? 7'b1111001  // right  '|'  (segs b+c)
      : (byte_to_display == 4'h6) ? 7'b1000000  // '0'
      : (byte_to_display == 4'h7) ? 7'b1111001  // '1'
      : (byte_to_display == 4'h8) ? 7'b0100100  // '2'
      : (byte_to_display == 4'h9) ? 7'b0110000  // '3'
      : (byte_to_display == 4'hA) ? 7'b0011001  // '4'
      : (byte_to_display == 4'hB) ? 7'b0010010  // '5'
      : (byte_to_display == 4'hC) ? 7'b0000010  // '6'
      : (byte_to_display == 4'hD) ? 7'b1111000  // '7'
      : (byte_to_display == 4'hE) ? 7'b0000000  // '8'
      :                             7'b0010000   // '9'
    ) : (
        // Hex mode: standard 0-F decode (original behaviour, unchanged)
        (byte_to_display == 4'b0000) ? 7'b1000000  // 0
      : (byte_to_display == 4'b0001) ? 7'b1111001  // 1
      : (byte_to_display == 4'b0010) ? 7'b0100100  // 2
      : (byte_to_display == 4'b0011) ? 7'b0110000  // 3
      : (byte_to_display == 4'b0100) ? 7'b0011001  // 4
      : (byte_to_display == 4'b0101) ? 7'b0010010  // 5
      : (byte_to_display == 4'b0110) ? 7'b0000010  // 6
      : (byte_to_display == 4'b0111) ? 7'b1111000  // 7
      : (byte_to_display == 4'b1000) ? 7'b0000000  // 8
      : (byte_to_display == 4'b1001) ? 7'b0010000  // 9
      : (byte_to_display == 4'b1010) ? 7'b0001000  // A
      : (byte_to_display == 4'b1011) ? 7'b0000011  // b
      : (byte_to_display == 4'b1100) ? 7'b1000110  // C
      : (byte_to_display == 4'b1101) ? 7'b0100001  // d
      : (byte_to_display == 4'b1110) ? 7'b0000110  // E
      : (byte_to_display == 4'b1111) ? 7'b0001110  // F
      :                                7'b1111111
    );
    
    initial begin
        counter <= 0;
        an_to_display <= 0;
    end
    
    always @(posedge clk) begin
        counter <= counter + 1;
        if (counter == 0) begin
            an_to_display <= an_to_display + 1;
        end
        
        // Nibble-to-display mapping:
        //   AN7 (leftmost)  = data[31:28]   score digit / miss zone indicator
        //   AN6 (2nd left)  = data[27:24]   LINE position in game
        //   AN5..AN0        = data[23:0]     note lane in game
        case (an_to_display)
          3'b000: begin byte_to_display <= data[31:28]; an <= ~8'h80; end // AN7
          3'b001: begin byte_to_display <= data[27:24]; an <= ~8'h40; end // AN6 (line)
          3'b010: begin byte_to_display <= data[23:20]; an <= ~8'h20; end // AN5
          3'b011: begin byte_to_display <= data[19:16]; an <= ~8'h10; end // AN4
          3'b100: begin byte_to_display <= data[15:12]; an <= ~8'h08; end // AN3
          3'b101: begin byte_to_display <= data[11:8];  an <= ~8'h04; end // AN2
          3'b110: begin byte_to_display <= data[7:4];   an <= ~8'h02; end // AN1
          3'b111: begin byte_to_display <= data[3:0];   an <= ~8'h01; end // AN0 (rightmost)
          default: begin byte_to_display <= 4'b0; an <= ~8'h00; end
        endcase
    end
endmodule