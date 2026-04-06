`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.03.2026 23:54:24
// Design Name: 
// Module Name: pallette_vram
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


module palette_vram (
    input wire ppu_clk,
    input wire reset,
    // PPU bus
    input wire [13:0] vram_addr,
    input wire [7:0] vram_data_in,
    output reg [7:0] vram_data_out,
    input wire vram_we,
    // Direct read port for color output (combinatorial)
    input wire [4:0] pal_read_addr,
    output wire [7:0] pal_color_out
);
 
    reg [7:0] pal [0:31]; // 32 bytes
    integer k;
    wire cs = (vram_addr[13:5] == 9'b111111000);
    wire mirror = vram_addr[4] && (vram_addr[1:0] == 2'b00);
    wire [4:0] phy_addr = mirror ? {1'b0, vram_addr[3:0]} : vram_addr[4:0];
    
    // Same mirror logic for the direct read port
    wire pal_mirror = pal_read_addr[4] && (pal_read_addr[1:0] == 2'b00);
    wire [4:0] pal_phy = pal_mirror ? {1'b0, pal_read_addr[3:0]} : pal_read_addr;

    // Synchronous write, synchronous CPU-bus read
    always @(posedge ppu_clk) begin
        if (reset) begin
            vram_data_out <= 8'h00;
            for (k = 0; k < 32; k = k + 1)
                pal[k] <= 8'h00;
        end else begin
            if (cs && vram_we)
                pal[phy_addr] <= vram_data_in;
            vram_data_out <= cs ? pal[phy_addr] : 8'h00;
        end
    end
 
    // Asynchronous read for pixel pipeline (color output every cycle)
    assign pal_color_out = pal[pal_phy];
 
endmodule