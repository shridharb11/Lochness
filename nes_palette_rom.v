module nes_palette_rom (
    input  wire        clk,             // Clock signal
    input  wire [5:0]  palette_index,   // 6-bit NES Palette Index (0-63)
    
    // 6-bit RGB Output: R[5:4], G[3:2], B[1:0]
    output reg  [5:0]  rgb_out         
);

    always @(posedge clk) begin
        case (palette_index)
            // --- Row 0: Dark Colors ---
            6'h00: rgb_out <= 6'b01_01_01; // $00: Dark Gray
            6'h01: rgb_out <= 6'b00_00_10; // $01: Dark Blue
            6'h02: rgb_out <= 6'b00_00_11; // $02: Blue
            6'h03: rgb_out <= 6'b01_00_11; // $03: Dark Purple
            6'h04: rgb_out <= 6'b10_00_10; // $04: Dark Magenta
            6'h05: rgb_out <= 6'b11_00_01; // $05: Dark Red/Pink
            6'h06: rgb_out <= 6'b10_00_00; // $06: Dark Red
            6'h07: rgb_out <= 6'b01_01_00; // $07: Brown
            6'h08: rgb_out <= 6'b01_10_00; // $08: Dark Olive
            6'h09: rgb_out <= 6'b00_10_00; // $09: Dark Green
            6'h0A: rgb_out <= 6'b00_11_00; // $0A: Green
            6'h0B: rgb_out <= 6'b00_11_01; // $0B: Dark Cyan
            6'h0C: rgb_out <= 6'b00_10_11; // $0C: Blue-Cyan
            6'h0D: rgb_out <= 6'b00_00_00; // $0D: Black
            6'h0E: rgb_out <= 6'b00_00_00; // $0E: Black
            6'h0F: rgb_out <= 6'b00_00_00; // $0F: Black

            // --- Row 1: Medium Colors ---
            6'h10: rgb_out <= 6'b10_10_10; // $10: Light Gray
            6'h11: rgb_out <= 6'b00_01_11; // $11: Medium Blue
            6'h12: rgb_out <= 6'b01_01_11; // $12: Light Blue
            6'h13: rgb_out <= 6'b10_00_11; // $13: Purple
            6'h14: rgb_out <= 6'b11_00_11; // $14: Magenta
            6'h15: rgb_out <= 6'b11_01_01; // $15: Pink/Red
            6'h16: rgb_out <= 6'b11_01_00; // $16: Orange
            6'h17: rgb_out <= 6'b11_10_00; // $17: Brown/Orange
            6'h18: rgb_out <= 6'b10_11_00; // $18: Yellow-Green
            6'h19: rgb_out <= 6'b01_11_00; // $19: Green
            6'h1A: rgb_out <= 6'b00_11_01; // $1A: Light Green
            6'h1B: rgb_out <= 6'b00_11_10; // $1B: Cyan-Green
            6'h1C: rgb_out <= 6'b00_10_11; // $1C: Cyan
            6'h1D: rgb_out <= 6'b00_00_00; // $1D: Black
            6'h1E: rgb_out <= 6'b00_00_00; // $1E: Black
            6'h1F: rgb_out <= 6'b00_00_00; // $1F: Black

            // --- Row 2: Bright Colors ---
            6'h20: rgb_out <= 6'b11_11_11; // $20: White
            6'h21: rgb_out <= 6'b01_10_11; // $21: Sky Blue
            6'h22: rgb_out <= 6'b01_01_11; // $22: Pale Blue
            6'h23: rgb_out <= 6'b10_01_11; // $23: Lavender
            6'h24: rgb_out <= 6'b11_01_10; // $24: Pink
            6'h25: rgb_out <= 6'b11_01_01; // $25: Light Red
            6'h26: rgb_out <= 6'b11_10_00; // $26: Light Orange
            6'h27: rgb_out <= 6'b11_11_00; // $27: Light Yellow
            6'h28: rgb_out <= 6'b10_11_00; // $28: Pale Yellow-Green
            6'h29: rgb_out <= 6'b01_11_01; // $29: Pale Green
            6'h2A: rgb_out <= 6'b01_11_10; // $2A: Mint Green
            6'h2B: rgb_out <= 6'b01_11_11; // $2B: Pale Cyan
            6'h2C: rgb_out <= 6'b00_11_11; // $2C: Light Cyan
            6'h2D: rgb_out <= 6'b01_01_01; // $2D: Dark Gray
            6'h2E: rgb_out <= 6'b00_00_00; // $2E: Black
            6'h2F: rgb_out <= 6'b00_00_00; // $2F: Black

            // --- Row 3: Pastel Colors ---
            6'h30: rgb_out <= 6'b11_11_11; // $30: White
            6'h31: rgb_out <= 6'b10_11_11; // $31: Pale Sky Blue
            6'h32: rgb_out <= 6'b10_10_11; // $32: Very Pale Blue
            6'h33: rgb_out <= 6'b11_10_11; // $33: Very Pale Purple
            6'h34: rgb_out <= 6'b11_10_11; // $34: Very Pale Pink
            6'h35: rgb_out <= 6'b11_10_10; // $35: Very Pale Red
            6'h36: rgb_out <= 6'b11_11_10; // $36: Very Pale Orange
            6'h37: rgb_out <= 6'b11_11_01; // $37: Very Pale Yellow
            6'h38: rgb_out <= 6'b11_11_01; // $38: Very Pale Yellow-Green
            6'h39: rgb_out <= 6'b10_11_01; // $39: Very Pale Green
            6'h3A: rgb_out <= 6'b10_11_10; // $3A: Very Pale Mint
            6'h3B: rgb_out <= 6'b10_11_11; // $3B: Very Pale Cyan
            6'h3C: rgb_out <= 6'b10_11_11; // $3C: Very Pale Cyan 2
            6'h3D: rgb_out <= 6'b10_10_10; // $3D: Light Gray
            6'h3E: rgb_out <= 6'b00_00_00; // $3E: Black
            6'h3F: rgb_out <= 6'b00_00_00; // $3F: Black

            default: rgb_out <= 6'b00_00_00; // Default to black
        endcase
    end
endmodule