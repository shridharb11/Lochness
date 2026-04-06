module ppu_2c02 (
    // Clocks
    input  wire         ppu_clk,            // ppu clk
    input  wire         reset,
    input  wire         clk_en,             // Enable pulse

    // ------------------------------------------
    // CPU SLAVE INTERFACE (Registers $2000-$2007)
    // ------------------------------------------
    input  wire         cs_n,           // Chip Select (Active Low)
    input  wire         rw,             // 1=Read, 0=Write
    input  wire [2:0]   addr,           // Register Select (0-7), only selecting $2000 to $2007
    input  wire [7:0]   data_in,        // From CPU
    output wire [7:0]   data_out,       // To CPU
    output wire         nmi_out,        // Output to CPU (VBlank Trigger)

    // ------------------------------------------
    // VRAM MASTER INTERFACE (PPU Bus)
    // ------------------------------------------
    output wire [13:0]  vram_addr,      // Video Memory Address
    output wire [7:0]   vram_data_out,  // Write to VRAM
    input  wire [7:0]   vram_data_in,   // Read from Pattern Tables/NameTables
    output wire         vram_we,        // Write Enable for VRAM
    output wire         vram_re,        //read enable for VRAM
    // ------------------------------------------
    // VIDEO OUTPUT INTERFACE
    // ------------------------------------------
    output wire [5:0]   color_out,      // The final 6-bit NES Palette Index
    output wire         pixel_valid,    // 1 = Visible Pixel, 0 = Blanking
    output wire [8:0]   scanline,       // Current Y line (0-261) for VGA Adapter
    output wire [8:0]   cycle,          // Current X pixel (0-340) for VGA Adapter

    input  wire mirroring       // 0 = Horizontal, 1 = Vertical
);


//timing controller
reg [8:0] r_sl, r_cy;
assign scanline = r_sl;
assign cycle = r_cy; 

wire cy_end = (r_cy == 9'd340);
wire frame_end = (r_sl == 9'd261) && cy_end;

wire in_vis = (r_sl >= 9'd20) && (r_sl <= 9'd259); // visible scanlines
wire in_vbl = (r_sl < 9'd20); // vblank
wire in_hbl = (r_cy > 9'd256) && (r_cy <= 9'd320); // hblank (sprite fetch)
wire pix_ok = in_vis && (r_cy >= 9'd1) && (r_cy <= 9'd256); // valid pixel output
wire vblank = in_vbl;

assign pixel_valid = pix_ok;
 
always @(posedge ppu_clk) begin
    if (reset) begin
        r_sl <= 9'd0; r_cy <= 9'd0;
    end else if (clk_en) begin
        if (cy_end) begin
            r_cy <= 9'd0;
            r_sl <= frame_end ? 9'd0 : r_sl + 9'd1;
        end else
            r_cy <= r_cy + 9'd1;
    end
end

wire nmi_out_w;
wire [13:0] reg_vram_addr;
wire [7:0] reg_vram_data_out;
wire reg_vram_we;
wire reg_vram_re;
wire [7:0] reg_oam_addr;
wire [7:0] reg_oam_data_out;
wire reg_oam_we;
wire [4:0] reg_palette_addr;
wire [7:0] reg_palette_data_out;
wire reg_palette_we;
wire nmi_enable;
wire sprite_height;
wire bg_pt_select;
wire sprite_pt_select;
wire vram_increment;
wire nt_select_x;
wire nt_select_y;
wire bg_enable;
wire sprite_enable;
wire left_bg_clip;
wire left_spr_clip;
wire greyscale;
wire [2:0] color_emphasis;
wire [7:0] x_scroll_w;
wire [7:0] y_scroll_w;
wire [7:0] data_out_w;

// status signals going into registers
wire sprite_zero_hit_w;
wire sprite_overflow_w;

ppu_registers regs (
    .ppu_clk (ppu_clk),
    .reset (reset),
    .cs_n (cs_n),
    .rw (rw),
    .addr (addr),
    .data_in (data_in),
    .data_out (data_out_w),
    .vblank (vblank),
    .sprite0_hit_pulse (sprite_zero_hit_w),
    .sprite_overflow (sprite_overflow_w),
    .nmi_out (nmi_out_w),
    .vram_data_in (vram_data_in_mux),
    .vram_data_out (reg_vram_data_out),
    .vram_addr (reg_vram_addr),
    .vram_we (reg_vram_we),
    .vram_re (reg_vram_re),
    .oam_data_out (reg_oam_data_out),
    .oam_addr (reg_oam_addr),
    .oam_we (reg_oam_we),
    .palette_data_in (pal_color_cpu),
    .palette_addr (reg_palette_addr),
    .palette_data_out(reg_palette_data_out),
    .palette_we (reg_palette_we),
    .nmi_enable (nmi_enable),
    .sprite_height (sprite_height),
    .bg_pt_select (bg_pt_select),
    .sprite_pt_select(sprite_pt_select),
    .vram_increment (vram_increment),
    .nt_select_x (nt_select_x),
    .nt_select_y (nt_select_y),
    .bg_enable (bg_enable),
    .sprite_enable (sprite_enable),
    .left_bg_clip (left_bg_clip),
    .left_spr_clip (left_spr_clip),
    .greyscale (greyscale),
    .color_emphasis (color_emphasis),
    .x_scroll (x_scroll_w),
    .y_scroll (y_scroll_w)
);

assign nmi_out  = nmi_out_w;
assign data_out = data_out_w;

// OAM
reg [7:0] oam_mem [0:255];
reg [7:0] r_oam_q;

wire [7:0] spr_oam_addr;
// during visible lines sprite renderer owns OAM, otherwise CPU register access owns it
wire [7:0] oam_rd_addr = in_vis ? spr_oam_addr : reg_oam_addr;

always @(posedge ppu_clk) begin
    // CPU writes to OAM via $2004
    if (reg_oam_we)
        oam_mem[reg_oam_addr] <= reg_oam_data_out;
    // read port
    r_oam_q <= oam_mem[oam_rd_addr];
end

wire [7:0] oam_q = r_oam_q;

wire render_vram_we  = 1'b0; // renderers only read
wire [13:0] render_vram_addr;
wire [7:0] int_vram_data_out;

// CPU owns VRAM bus during vblank, renderers own it during rendering
wire vram_we_final = in_vbl ? reg_vram_we   : 1'b0;
wire [13:0] vram_addr_final = in_vbl ? reg_vram_addr : render_vram_addr;
wire [7:0] vram_din_final = reg_vram_data_out;

internal_vram ivram (
    .ppu_clk (ppu_clk),
    .reset (reset),
    .vram_addr (vram_addr_final),
    .vram_data_in (vram_din_final),
    .vram_data_out(int_vram_data_out),
    .vram_we (vram_we_final),
    .mirroring (mirroring)
);

// PALETTE VRAM
wire [7:0] pal_color_out;  // async read for pixel pipeline
wire [7:0] pal_color_cpu;  // for CPU $2007 reads

// palette write port: CPU during vblank
wire [4:0]  pal_addr_final = in_vbl ? reg_palette_addr : mux_palette_addr;
wire [7:0]  pal_din_final = reg_palette_data_out;
wire pal_we_final = in_vbl ? reg_palette_we   : 1'b0;

palette_vram pvram (
    .ppu_clk (ppu_clk),
    .reset (reset),
    .vram_addr ({9'b111111000, pal_addr_final}),
    .vram_data_in (pal_din_final),
    .vram_data_out (pal_color_cpu),
    .vram_we (pal_we_final),
    .pal_read_addr (mux_palette_addr),
    .pal_color_out (pal_color_out)
);

// CHR ROM
wire [13:0] chr_addr;
wire [7:0]  chr_data_out;

rom_async #( .ADDR_WIDTH(13) ) chr_rom (
    .addr (chr_addr[12:0]),
    .data_out (chr_data_out)
);

// BACKGROUND RENDERER
wire [13:0] bg_ppu_addr;
wire bg_ale, bg_rd;
wire [3:0]  bg_pixel;

// ppu_data fed to bg renderer comes from CHR ROM or internal VRAM
// depending on address range
wire [7:0] ppu_data_bg = (bg_ppu_addr[13:12] == 2'b00) ? chr_data_out : int_vram_data_out;

background_renderer bg_rend (
    .reset (reset),
    .ppu_clk (ppu_clk),
    .hblank (in_hbl),
    .scanline_index (r_sl),
    .scanline_x_coordinate (r_cy),
    .ppu_data (ppu_data_bg),
    .x_scroll (x_scroll_w),
    .y_scroll (y_scroll_w),
    .x_scroll_nametable_select (nt_select_x),
    .y_scroll_nametable_select (nt_select_y),
    .background_pattern_table_select(bg_pt_select),
    .left_bg_clipping (left_bg_clip),
    .RD (bg_rd),
    .ALE (bg_ale),
    .bg_pixel (bg_pixel),
    .ppu_addr (bg_ppu_addr)
);

// SPRITE RENDERER
wire [13:0] spr_ppu_addr;
wire spr_ale, spr_rd;
wire [4:0]  sprite_pixel_out;
wire primary_pixel;

// ppu_data fed to sprite renderer comes from CHR ROM
wire [7:0] ppu_data_spr = chr_data_out;

sprite_renderer spr_rend (
    .ppu_clk (ppu_clk),
    .rst (reset),
    .en_ppu (clk_en),
    .hblank (in_hbl),
    .sprite_height (sprite_height),
    .sprite_pt_select(sprite_pt_select),
    .scanline (r_sl),
    .scanline_clk (r_cy),
    .sprite_ram_data (oam_q),
    .ppu_data (ppu_data_spr),
    .left_side_clipping(left_spr_clip),
    .sprite_ram_addr (spr_oam_addr),
    .ppu_addr (spr_ppu_addr),
    .ale (spr_ale),
    .rd (spr_rd),
    .sprite_overflow (sprite_overflow_w),
    .sprite_pixel_out(sprite_pixel_out),
    .primary_pixel (primary_pixel)
);

assign chr_addr = in_hbl ? spr_ppu_addr : bg_ppu_addr;
assign render_vram_addr = bg_ppu_addr; // only bg renderer accesses internal VRAM explicitly

// expose VRAM addr to top level for external connections if needed
assign vram_addr = vram_addr_final;
assign vram_data_out = vram_din_final;
assign vram_we = vram_we_final;

// mux for vram_data_in going back to ppu_registers for $2007 reads
wire [7:0] vram_data_in_mux = (reg_vram_addr[13:12] == 2'b00) ? chr_data_out : int_vram_data_out;


wire [3:0] spr_pixel_4bit = {sprite_pixel_out[1:0], sprite_pixel_out[4:3]};
wire spr_priority_bit = sprite_pixel_out[2];

wire [4:0] mux_palette_addr;
wire sprite_zero_hit_raw;

priority_mux pmux (
    .bg_enable (bg_enable),
    .sprite_enable (sprite_enable),
    .left_bg_clip (left_bg_clip),
    .left_spr_clip (left_spr_clip),
    .cycle (r_cy),
    .bg_pixel (bg_pixel),
    .spr_pixel (spr_pixel_4bit),
    .spr_priority (spr_priority_bit),
    .is_from_sprite_0(primary_pixel),
    .palette_addr (mux_palette_addr),
    .sprite0_hit_pulse (sprite_zero_hit_raw)
);

// latch sprite zero hit — stays set until $2002 read clears it in ppu_registers (or vblank)
reg sprite_zero_hit_latch;
always @(posedge ppu_clk) begin
    if (reset || in_vbl)
        sprite_zero_hit_latch <= 1'b0;
    else if (sprite_zero_hit_raw)
        sprite_zero_hit_latch <= 1'b1;
end
assign sprite_zero_hit_w = sprite_zero_hit_latch;

assign color_out = pal_color_out[5:0];

endmodule
