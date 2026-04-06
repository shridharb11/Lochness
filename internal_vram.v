`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.03.2026 22:33:56
// Design Name: 
// Module Name: internal_vram
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module internal_vram(
    input wire ppu_clk,
    input wire reset,
    // PPU bus
    input wire [13:0] vram_addr,
    input wire [7:0] vram_data_in,
    output reg  [7:0] vram_data_out,
    input wire vram_we,
    // Mirroring: 0 = Horizontal, 1 = Vertical
    input wire mirroring
    );
 
    reg [7:0] mem [0:2047]; // 2 KB
    integer k;

    wire cs = (vram_addr[13:12] == 2'b10) || (vram_addr[13:10] == 4'b1100);

    wire [10:0] phy_addr = mirroring ? {vram_addr[10], vram_addr[9:0]}: {vram_addr[11], vram_addr[9:0]}; 
 
    // Synchronous write, synchronous read
    always @(negedge ppu_clk) begin
        if (reset) begin
            vram_data_out <= 8'h00;
            for (k = 0; k < 2048; k = k + 1)
                mem[k] <= 8'h00;
        end else begin
            if (cs && vram_we)
                mem[phy_addr] <= vram_data_in;
            vram_data_out <= cs ? mem[phy_addr] : 8'h00;
        end
    end
 
endmodule

