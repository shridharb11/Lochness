module nes_top (
    // Clock & Reset
    input  wire         mCLOCK,         // FPGA master Clock
    input  wire         nRESET,         // Physical Reset Button (Active Low)

    // Physical Inputs
    input  wire [7:0]   BUTTONS,            // Controller 1

    // VGA Output
    output wire [3:0]   VGA_R,
    output wire [3:0]   VGA_G,
    output wire [3:0]   VGA_B,
    output wire         VGA_HS,
    output wire         VGA_VS
);

    // CLOCKING DOMAINS
    // ============================
    // You need a PLL to generate:
    // 1. clk_sys (21.47727 MHz) - NTSC Standard
    // Then we use enable gating to generate
    // 2. clk_ppu    (5.37 MHz)     - Sys / 4
    // 3. clk_cpu    (1.79 MHz)     - Sys / 12
    wire clk_sys, pll_locked;
    
    clk_wiz_0 pll_inst(
       .clk_in1 (mCLOCK),
       .resetn  (nRESET),
       .clk_out1(clk_sys),
       .locked (pll_locked)
    );

    // System Reset (Active High) - Hold until PLL is stable
    wire reset = !nRESET || !pll_locked;

    // Clock divider
    wire en_ppu;
    wire en_cpu;

    nes_clk_divider clk_div_inst (
        .clk_sys(clk_sys),
        .reset(reset),
        .en_ppu(en_ppu),
        .en_cpu(en_cpu)
    );

    // BUS LOGIC
    // ============================
    
    // CPU Signals
    wire [15:0] cpu_addr_raw;
    wire [7:0]  cpu_data_out_raw;
    wire        cpu_rw_raw;     // 1 = Read, 0 = Write
    wire        cpu_nmi;        // CPU interrupt signal       
    wire        cpu_rdy;        // Ready signal. 1=Run, 0=Pause (For DMA)

    // DMA Signals
    wire [15:0] dma_addr;
    wire [7:0]  dma_data_out;
    wire        dma_rw;
    wire        dma_active;     
    wire        dma_halt_req;

    // Main System Bus
    wire [15:0] sys_addr;
    wire [7:0]  sys_data_out;
    wire        sys_rw;
    reg  [7:0]  sys_data_in; 

    // DMA MUX Logic
    assign sys_addr     = (dma_active) ? dma_addr     : cpu_addr_raw;
    assign sys_data_out = (dma_active) ? dma_data_out : cpu_data_out_raw;
    assign sys_rw       = (dma_active) ? dma_rw       : cpu_rw_raw;
    assign cpu_rdy      = !dma_halt_req;

    // ADDRESS LOGIC
    // ============================

    // Chip select
    wire ram_cs = (sys_addr < 16'h2000);    // $0000 - $1FFF, 8KB for Work RAM, but only first 2KB ($0000 - $07FF) are actually used, and the rest are mirrored logically
    wire ppu_cs = (sys_addr >= 16'h2000 && sys_addr < 16'h4000); // $1FFF - $3FFF ($2000 - $2007, mirrored like a billion times)
    wire input_cs = (sys_addr == 16'h4016 || sys_addr == 16'h4017);  // $4016 and $4017
    wire rom_cs = (sys_addr >= 16'h8000);   // Game ROM

    // Chip data outputs
    wire [7:0] ram_data_out, ppu_data_out, rom_data_out, input_data_out; 

    // Open Bus Latch
    // On the real NES, the data bus is just a wire. If you read from an address
    // where no chip is connected (e.g., $5000), the wire "floats" and holds
    // the voltage of the last valid number that was on it.
    // This register simulates that capacitance.
    reg [7:0] open_bus;

    always @(posedge clk_sys) begin
        // Case 1: CPU Write (sys_rw == 0)
        // If the CPU is writing, the bus is definitely driven by the CPU.
        // We capture this value so it becomes the "Ghost" for the next cycle.
        if (sys_rw == 0) 
            open_bus <= sys_data_out; 
        
        // Case 2: CPU Read (Valid Chip Selected)
        // If the CPU reads from a real chip (RAM, ROM, PPU), that chip drives the bus.
        // We capture this output so it becomes the "Ghost" if the next read is empty.
        else if (ram_cs) open_bus <= ram_data_out;
        else if (rom_cs) open_bus <= rom_data_out;
        else if (ppu_cs) open_bus <= ppu_data_out;
        
        // Case 3: CPU Read (Empty Space)
        // If reading unmapped space, NO ONE drives the bus.
        // We do NOT update 'open_bus'. It keeps its old value.
    end

    // Read Multiplexer 
    // This logic decides what data the CPU actually "sees" on its input pins.
    always @(*) begin
        if (ram_cs)         
            sys_data_in = ram_data_out;   // Address $0000-$1FFF: Connect RAM
        else if (ppu_cs)    
            sys_data_in = ppu_data_out;   // Address $2000-$3FFF: Connect PPU
        else if (rom_cs)    
            sys_data_in = rom_data_out;   // Address $8000-$FFFF: Connect Cartridge
        else if (input_cs)  
            sys_data_in = input_data_out; // Address $4016-$4017: Connect Controller
        else                
            sys_data_in = open_bus;       // Unmapped Address: Return the ghost value from the latch
    end

    // Module instantiation

    cpu_2a03 cpu_inst (
        .cpu_clk(clk_sys), 
        .reset(reset), 
        .clk_en(en_cpu),
        .data_in(sys_data_in),
        .nmi_in(cpu_nmi),
        .irq_in(1'b1),  // Used by APU, and Mapper, so we can safely disable it
        .rdy(cpu_rdy),
        .addr(cpu_addr_raw),
        .data_out(cpu_data_out_raw),
        .rw(cpu_rw_raw)
    );

    dma_controller dma_inst (
        .clk(clk_sys),
        .reset(reset),
        .clk_en(en_cpu),
        .cpu_addr_in(cpu_addr_raw), 
        .cpu_data_in(cpu_data_out_raw), 
        .cpu_rw(cpu_rw_raw),
        .cpu_halt(dma_halt_req),
        .dma_active(dma_active), 
        .dma_addr_out(dma_addr), 
        .dma_data_out(dma_data_out), 
        .dma_rw_out(dma_rw),
        .bus_data_in(sys_data_in)
    );

    // Main RAM
    ram_sync #( .ADDR_WIDTH(11) ) cpu_ram (
        .clk(clk_sys),
        .addr(sys_addr[10:0]),
        .data_in(sys_data_out),
        .data_out(ram_data_out),
        .we(!sys_rw && ram_cs)  // Write when RW = 0 and CS = 1
    );

    rom_async #( .ADDR_WIDTH(15) ) prg_rom (
        .addr(sys_addr[14:0]), 
        .data_out(rom_data_out)
    );

    input_controller input_inst (
        .clk(clk_sys), .reset(reset), .clk_en(en_cpu),
        .cs(input_cs), .rw(sys_rw),
        .data_in(sys_data_out), .data_out(input_data_out),
        .fpga_buttons(BUTTONS)
    );

    // PPU & Video Subsystem
    wire [13:0] vram_addr;
    wire [7:0]  vram_data_in, vram_data_out;
    wire        vram_we, vram_re;
    wire [5:0]  nes_color;
    wire        pixel_valid;
    wire [8:0] scanline, cycle;
    wire mirroring;

    ppu_2c02 ppu_inst (
        .ppu_clk(clk_sys), .reset(reset), .clk_en(en_ppu), // <--- NEW PORT
        .cs_n(!ppu_cs), .rw(sys_rw), .addr(sys_addr[2:0]),
        .data_in(sys_data_out), .data_out(ppu_data_out),
        .nmi_out(cpu_nmi),
        .vram_addr(vram_addr), .vram_data_in(vram_data_in), 
        .vram_data_out(vram_data_out), .vram_we(vram_we), .vram_re(vram_re),
        .color_out(nes_color), .pixel_valid(pixel_valid), .scanline(scanline), .cycle(cycle), .mirroring(mirroring)
    );

    // VRAM Mux Logic
    wire chr_cs = (vram_addr < 14'h2000); 
    wire nt_cs  = (vram_addr >= 14'h2000 && vram_addr < 14'h3F00);
    wire [7:0] chr_out, nt_out;

    rom_async #( .ADDR_WIDTH(13) ) chr_rom ( .addr(vram_addr[12:0]), .data_out(chr_out) );
    
    ram_sync #( .ADDR_WIDTH(11) ) vram_chip (
        .clk(clk_sys), .addr(vram_addr[10:0]), 
        .data_in(vram_data_out), .we(vram_we && nt_cs), .data_out(nt_out)
    );

    assign vram_data_in = (chr_cs) ? chr_out : nt_out;

    // VGA Adapter
    vga_adapter vga_inst (
        .clk_sys(clk_sys), .clk_en_ppu(en_ppu), .reset(reset),
        .nes_color(nes_color), .pixel_valid(pixel_valid),
        .vga_r(VGA_R), .vga_g(VGA_G), .vga_b(VGA_B),
        .hsync(VGA_HS), .vsync(VGA_VS)
    );


endmodule
