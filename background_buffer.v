module background_buffer(
input ppu_clk, rst, load, hblank,
input [2:0] fine_x_scroll,
input [7:0] palette_data_one, palette_data_two, pattern_bitmap_one, pattern_bitmap_two,
output [3:0] background_out );

reg [15:0] pattern_lo_sr, pattern_hi_sr, palette_lo_sr, palette_hi_sr;

always @(posedge ppu_clk) begin
if (rst) begin   // begin if reset 
pattern_lo_sr <= 16'b0;
pattern_hi_sr <=16'b0;
palette_lo_sr <= 16'b0;
palette_hi_sr <= 16'b0 ;
end  // if reset end

else begin   // if not reset begin

pattern_lo_sr <= pattern_lo_sr << 1;
pattern_hi_sr <= pattern_hi_sr << 1;
palette_lo_sr <= palette_lo_sr << 1;
palette_hi_sr <= palette_hi_sr << 1;

if (load) begin
pattern_hi_sr[15:8] <= pattern_bitmap_two;
pattern_lo_sr[15:8] <= pattern_bitmap_one;
palette_hi_sr[15:8] <= palette_data_two;
palette_lo_sr[15:8] <= palette_data_one;
end

end // if not reset end

end // always block end

assign background_out = hblank ? 4'b0000 :
{pattern_hi_sr[15 - fine_x_scroll],
 pattern_lo_sr[15 - fine_x_scroll],
 palette_hi_sr[15 - fine_x_scroll],
 palette_lo_sr[15 - fine_x_scroll]};

endmodule
