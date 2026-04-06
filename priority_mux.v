module priority_mux(
input bg_enable, sprite_enable, left_bg_clip, left_spr_clip, //R2001
input [8:0] cycle, // from timing controller
input [3:0] bg_pixel, spr_pixel,
input spr_priority, is_from_sprite_0,
output reg [4:0] palette_addr,
output sprite0_hit_pulse
);

// if the lower 2 bits (pattern bits) are 00, the pixel is transparent
wire bg_opaque  = (bg_pixel[1:0]  != 2'b00) && bg_enable;
wire spr_opaque = (spr_pixel[1:0] != 2'b00) && sprite_enable;

// if clipping bits are 0, force pixels to transparent in the first 8 pixels
wire bg_visible  = bg_opaque  && !((cycle < 8) && !left_bg_clip);
wire spr_visible = spr_opaque && !((cycle < 8) && !left_spr_clip);

assign sprite0_hit_pulse = is_from_sprite_0 && spr_visible && bg_visible && (cycle < 255);

always @(*) begin
// Both transparent: Default to Background Palette 0, Color 0
if (!bg_visible && !spr_visible) begin
palette_addr = 5'b00000;
end 

// Only Background is opaque
else if (bg_visible && !spr_visible) begin
palette_addr = {1'b0, bg_pixel}; 
end 

// Only Sprite is opaque
else if (!bg_visible && spr_visible) begin
palette_addr = {1'b1, spr_pixel}; 
end 

// BOTH are opaque: Check OAM Priority Bit
else begin
if (spr_priority == 1'b0) begin
palette_addr = {1'b1, spr_pixel};
end else begin
palette_addr = {1'b0, bg_pixel};
end
end
end

endmodule
