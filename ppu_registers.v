module ppu_registers(
input ppu_clk, reset,

input cs_n, rw,   // chip_select : active low; 1=read, 0 = write
input [2:0] addr, //2000-2007 reg select
input [7:0] data_in,
output reg [7:0] data_out,

input vblank, //from timing controller
input sprite0_hit_pulse, //from priority mux
input sprite_overflow, // from sprite renderer
output reg nmi_out,  //NMI TRIGGER TO CPU

// VRAM COMMS
input [7:0] vram_data_in,
output reg [7:0] vram_data_out,
output wire [13:0] vram_addr,
output reg vram_we,vram_re,

//OAM COMMS
output reg [7:0] oam_data_out,
output wire [7:0] oam_addr,
output reg oam_we,

// PALETTE COMMS
input wire [7:0] palette_data_in,
output reg [4:0] palette_addr,
output reg [7:0] palette_data_out,
output reg palette_we,
    
// R2000 PPUCTRL o/p
output reg nmi_enable,      // bit 7: enable NMI on vblank
output reg sprite_height,   // bit 5: 0 = 8x8 sprites, 1 = 8x16 sprites
output reg bg_pt_select,    // bit 4: background pattern table select (0 = $0000, 1 = $1000)
output reg sprite_pt_select,// bit 3: sprite pattern table select (0 = $0000, 1 = $1000)
output reg vram_increment,  // bit 2: VRAM address increment (0 = add 1, 1 = add 32)
output reg nt_select_x,     // bit 0: base nametable X select
output reg nt_select_y,     // bit 1: base nametable Y select

 // R2001 PPUMASK o/p
output reg bg_enable,       // bit 3: enable background rendering
output reg sprite_enable,   // bit 4: enable sprite rendering
output reg left_bg_clip,    // bit 1: 0 = hide leftmost 8 pixels of background
output reg left_spr_clip,   // bit 2: 0 = hide leftmost 8 pixels of sprites
output reg greyscale,       // bit 0: 0 = normal color, 1 = greyscale
output reg [2:0] color_emphasis,  // bits 7-5: color emphasis bits for VGA adapter

 // SCROLL OUTPUTS (from R2005)
output reg [7:0] x_scroll,        // first write to $2005: horizontal scroll offset
output reg [7:0] y_scroll         // second write to $2005: vertical scroll offset
);


// INTERNAL REGISTERS    
reg [13:0] vram_addr_reg;   // internal VRAM address built from $2006
reg [7:0] vram_read_buf;   // read buffer for $2007 reads
reg addr_latch;       // 0 = first write, 1 = second write
reg vblank_flag;      // internal vblank flag
reg vblank_prev;      // previous vblank for edge detection
reg [7:0] oamaddr_reg;     // internal OAM address register
reg vram_re_delayed, pal_region_delayed;
reg sprite_zero_hit;

wire cpu_write = !cs_n && !rw;  // CPU is performing a write
wire cpu_read  = !cs_n && rw;  // CPU is performing a read

// palette region is $3F00-$3FFF in PPU address space
wire pal_region = (vram_addr_reg[13:8] == 6'b111111);   // CLAUDE

// CPU ACCESS HANDLER
always @(posedge ppu_clk) begin
if (reset) begin
nmi_enable       <= 1'b0;
sprite_height    <= 1'b0;
bg_pt_select     <= 1'b0;
sprite_pt_select <= 1'b0;
vram_increment   <= 1'b0;
nt_select_x      <= 1'b0;
nt_select_y      <= 1'b0;
bg_enable        <= 1'b0;
sprite_enable    <= 1'b0;
left_bg_clip     <= 1'b0;
left_spr_clip    <= 1'b0;
greyscale        <= 1'b0;
color_emphasis   <= 3'b000;
x_scroll         <= 8'd0;
y_scroll         <= 8'd0;
addr_latch       <= 1'b0;
vram_addr_reg    <= 14'd0;
oamaddr_reg      <= 8'd0;
oam_we           <= 1'b0;
oam_data_out     <= 8'd0;
vram_we          <= 1'b0;
vram_re          <= 1'b0;
vram_data_out    <= 8'd0;
palette_we       <= 1'b0;
palette_addr     <= 5'd0;
palette_data_out <= 8'd0;
vram_read_buf    <= 8'd0;
end

else begin
data_out <= 8'd0;
oam_we <= 1'b0;
vram_we <= 1'b0;
vram_re <= 1'b0;
palette_we <= 1'b0;

// vram data read latency handler
vram_re_delayed <= vram_re;
pal_region_delayed <= pal_region;
if (vram_re_delayed && !pal_region_delayed) vram_read_buf <= vram_data_in;


// CPU WRITE HANDLER
if (cpu_write) begin
case(addr) 

// R2000 PPUCTRL
3'd0: begin
nmi_enable       <= data_in[7];
sprite_height    <= data_in[5];
bg_pt_select     <= data_in[4];
sprite_pt_select <= data_in[3];
vram_increment   <= data_in[2];
nt_select_y      <= data_in[1];
nt_select_x      <= data_in[0];
end

 // R2001 PPUMASK
3'd1: begin
color_emphasis <= data_in[7:5];
sprite_enable  <= data_in[4];
bg_enable      <= data_in[3];
left_spr_clip  <= data_in[2];
left_bg_clip   <= data_in[1];
greyscale      <= data_in[0];
end

// R2003 OAMADDR
3'd3: begin
oamaddr_reg <= data_in;
end

// $2004 OAMDATA
// write one byte to OAM at current oamaddr, then increment oamaddr
3'd4: begin
oam_data_out <= data_in;
oam_we       <= 1'b1;
oamaddr_reg  <= oamaddr_reg + 8'd1;
end

// $2005 PPUSCROLL
// first write = X scroll, second write = Y scroll
3'd5: begin
if (!addr_latch) begin
x_scroll   <= data_in;
addr_latch <= 1'b1;
end else begin
y_scroll   <= data_in;
addr_latch <= 1'b0;
end
end

// $2006 PPUADDR
// first write = high byte (bits 13:8), second write = low byte (bits 7:0)
3'd6: begin
if (!addr_latch) begin
vram_addr_reg[13:8] <= data_in[5:0];   // this is bcoz vram addr is 14 bit , upper 6 bits come in the first cycle and next 8 in the next cycle
addr_latch <= 1'b1;
end else begin
vram_addr_reg[7:0] <= data_in;
addr_latch <= 1'b0;
end
end

// $2007 PPUDATA write
3'd7: begin
if (pal_region) begin
// writing to palette RAM
palette_addr <= vram_addr_reg[4:0];
palette_data_out <= data_in;
palette_we <= 1'b1;
end else begin
// writing to VRAM
vram_data_out <= data_in;
vram_we <= 1'b1;
end
// auto increment VRAM address after every $2007 write
vram_addr_reg <= vram_addr_reg + (vram_increment ? 14'd32 : 14'd1);
end
endcase
end

// CPU READ HANDLER
if (cpu_read) begin
case (addr) 

// $2002 PPUSTATUS
// reading clears vblank flag and resets address latch
3'd2: begin
data_out   <= {vblank_flag, sprite_zero_hit, sprite_overflow, 5'b00000}; // vblank_flag cleared in NMI always block above
addr_latch <= 1'b0;
end

// $2004 OAMDATA read
3'd4: begin
data_out <= 8'b0; // OAM read not implemented 
end

// $2007 PPUDATA read
// returns buffered value, triggers new read, increments address
3'd7: begin
if (pal_region) begin  // palette reads return immediately without buffering
data_out <= palette_data_in;
end else begin  // non-palette reads return the previously buffered value
data_out <= vram_read_buf;
vram_re <= 1'b1;
end
vram_addr_reg <= vram_addr_reg + (vram_increment ? 14'd32 : 14'd1);
end

                
default: data_out <= 8'd0;
endcase
end
end
end

always @(posedge ppu_clk) begin
if (reset) begin
vblank_flag <= 1'b0;
sprite_zero_hit <= 1'b0;
nmi_out <= 1'b0;
end else begin
vblank_prev <= vblank;
if (vblank && !vblank_prev) vblank_flag <= 1'b1;       
if (sprite0_hit_pulse) begin
sprite_zero_hit <= 1'b1; // CATCH THE PULSE
end
// The NES clears BOTH flags at the end of the VBlank period (dot 1 of pre-render)
if (!vblank && vblank_prev) begin 
vblank_flag <= 1'b0;
sprite_zero_hit <= 1'b0; // RESET FOR NEXT FRAME
end
// Manual Clear for $2002 Read (ONLY clears VBlank, NOT Sprite 0)
if (cpu_read && addr == 3'd2) begin
vblank_flag <= 1'b0;
end
// generate NMI pulse on rising edge of vblank if enabled
nmi_out <= nmi_enable && vblank && !vblank_prev;
end
end


assign oam_addr = oamaddr_reg;
assign vram_addr = vram_addr_reg;
endmodule