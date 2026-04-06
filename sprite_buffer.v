`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.01.2026 01:15:42
// Design Name: 
// Module Name: sprite_buffer
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

module sprite_buffer(
    input  ppu_clk,
    input  en_ppu,
    input  rst,
    input  high_bit_load,
    input  low_bit_load,
    input  hblank,
    input  x_clk_load,
    input  [7:0] sprite_buffer_data,
    output reg [1:0] out_buffer
);

    reg [7:0] shift_out_high, shift_out_low;
    reg [8:0] x_clk;      
    reg [3:0] shift_state;

    always @(posedge ppu_clk) begin
        if (rst) begin
            // x_clk=320 ensures counter never reaches 0 until properly loaded
            x_clk          <= 9'd320;
            shift_state    <= 4'd0;
            out_buffer     <= 2'd0;
            shift_out_high <= 8'd0;
            shift_out_low  <= 8'd0;
        end
        else if (en_ppu) begin
            if (hblank) begin
                shift_state <= 4'd0;
                out_buffer  <= 2'd0;
                if (high_bit_load) shift_out_high <= sprite_buffer_data;
                if (low_bit_load)  shift_out_low  <= sprite_buffer_data;
                if (x_clk_load)    x_clk          <= {1'b0, sprite_buffer_data};
            end
            else begin
                if (x_clk > 9'd0) begin
                    x_clk      <= x_clk - 9'd1;     
                    out_buffer <= 2'd0;
                end
                else begin
                    if (shift_state < 4'd8) begin
                        out_buffer     <= {shift_out_high[7], shift_out_low[7]};
                        shift_state    <= shift_state + 4'd1;   
                        shift_out_high <= {shift_out_high[6:0], 1'b0};
                        shift_out_low  <= {shift_out_low[6:0],  1'b0};
                    end
                    else
                        out_buffer <= 2'd0;
                end
            end
        end
    end

endmodule
