module vga_adapter (
    input wire clk_sys,
    input wire clk_en_ppu,
    input wire reset,

    input wire[5:0] nes_color,
    input wire pixel_valid,

    output wire[3:0] vga_r,
    output wire[3:0] vga_g,
    output wire[3:0] vga_b,
    output wire      hsync,
    output wire      vsync
);
    // Recover X and Y coordinates purely from the pixel_valid signal
    reg [7:0]  in_x;
    reg [7:0]  in_y;
    reg [11:0] blank_cnt;
    reg        prev_valid;

    always @(posedge clk_sys) begin
        if (reset) begin
            in_x <= 0;
            in_y <= 0;
            blank_cnt <= 0;
            prev_valid <= 0;
        end else if (clk_en_ppu) begin
            prev_valid <= pixel_valid;
            
            if (pixel_valid) begin
                blank_cnt <= 0;
                if (in_x < 255) 
                    in_x <= in_x + 1;
            end else begin
                blank_cnt <= blank_cnt + 1;
                
                // Falling Edge: End of a visible scanline
                if (prev_valid && !pixel_valid) begin
                    in_x <= 0;
                    if (in_y < 239) 
                        in_y <= in_y + 1;
                end
                
                // Long Blanking: If invalid for >150 PPU clocks, we hit VBLANK
                // Reset Y coordinate for the next frame
                if (blank_cnt > 150) begin
                    in_y <= 0;
                end
            end
        end
    end

    // Concatenating Y and X creates a clean 16-bit address space
    reg  [5:0] framebuffer [0:65535];
    wire [15:0] write_addr = {in_y, in_x};
    reg  [5:0] fb_read_data;

    always @(posedge clk_sys) begin
        // Write Port (PPU Domain)
        if (pixel_valid && clk_en_ppu) begin
            framebuffer[write_addr] <= nes_color;
        end
    end

    // Custom timing to achieve ~31.5kHz H-Sync and ~60Hz V-Sync
    localparam H_SYNC   = 64;
    localparam H_BP     = 90;
    localparam H_ACTIVE = 512; // 256 NES pixels * 2
    localparam H_FP     = 16;
    localparam H_TOTAL  = 682; // 21.477M / 682 = 31.49 kHz

    localparam V_SYNC   = 2;
    localparam V_BP     = 33;
    localparam V_ACTIVE = 480; // 240 NES pixels * 2
    localparam V_FP     = 10;
    localparam V_TOTAL  = 525; // 31.49k / 525 = 59.98 Hz

    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    always @(posedge clk_sys) begin
        if (reset) begin
            h_cnt <= 0;
            v_cnt <= 0;
        end else begin
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt <= 0;
                if (v_cnt == V_TOTAL - 1)
                    v_cnt <= 0;
                else
                    v_cnt <= v_cnt + 1;
            end else begin
                h_cnt <= h_cnt + 1;
            end
        end
    end

    // VGA Sync Signals (Active Low standard)
    wire raw_hsync = ~(h_cnt < H_SYNC);
    wire raw_vsync = ~(v_cnt < V_SYNC);
    
    // Display Bounds Checking
    wire h_active = (h_cnt >= (H_SYNC + H_BP)) && (h_cnt < (H_SYNC + H_BP + H_ACTIVE));
    wire v_active = (v_cnt >= (V_SYNC + V_BP)) && (v_cnt < (V_SYNC + V_BP + V_ACTIVE));
    wire display_active = h_active && v_active;

    // Read Address Calculation (Scale 512x480 down to 256x240)
    wire [7:0] read_x = (h_cnt - (H_SYNC + H_BP)) >> 1;
    wire [7:0] read_y = (v_cnt - (V_SYNC + V_BP)) >> 1;
    wire [15:0] read_addr = {read_y, read_x};

    always @(posedge clk_sys) begin
        // Read Port (VGA Domain)
        fb_read_data <= framebuffer[read_addr];
    end

    wire [5:0] rgb_6bit;
    
    nes_palette_rom palette_inst (
        .clk(clk_sys),
        .palette_index(fb_read_data),
        .rgb_out(rgb_6bit)
    );
    // Because reading from BRAM takes 1 clock, and the ROM takes 1 clock, 
    // the video data is delayed by 2 clock cycles. We must delay the sync 
    // and active signals by 2 cycles to keep the image perfectly aligned.

    reg [2:0] active_pipe;
    reg [2:0] hsync_pipe;
    reg [2:0] vsync_pipe;

    always @(posedge clk_sys) begin
        active_pipe <= {active_pipe[1:0], display_active};
        hsync_pipe  <= {hsync_pipe[1:0],  raw_hsync};
        vsync_pipe  <= {vsync_pipe[1:0],  raw_vsync};
    end

    assign hsync = hsync_pipe[2];
    assign vsync = vsync_pipe[2];

    // Map 6-bit internal color to physical 12-bit VGA pins (duplicate bits to scale brightness)
    assign vga_r = active_pipe[2] ? {rgb_6bit[5:4], rgb_6bit[5:4]} : 4'h0;
    assign vga_g = active_pipe[2] ? {rgb_6bit[3:2], rgb_6bit[3:2]} : 4'h0;
    assign vga_b = active_pipe[2] ? {rgb_6bit[1:0], rgb_6bit[1:0]} : 4'h0;

endmodule