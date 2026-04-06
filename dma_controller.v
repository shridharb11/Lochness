module dma_controller (
    input wire clk,
    input wire reset,
    input wire clk_en,           // Enable signal for CPU clock domain
    input wire [15:0] cpu_addr_in,
    input wire [7:0]  cpu_data_in,
    input wire        cpu_rw,     // 1 = Read, 0 = Write
    output wire        cpu_halt,   // Signal to halt CPU during DMA
    output wire        dma_active, // Indicates DMA is in progress
    output wire [15:0] dma_addr_out,
    output wire [7:0]  dma_data_out,
    output wire        dma_rw_out, // 1 = Read from CPU, 0 =
    input wire [7:0]  bus_data_in  // Data from CPU for DMA reads
);
// State Machine
    localparam STATE_IDLE  = 2'b00;
    localparam STATE_ALIGN = 2'b01;
    localparam STATE_READ  = 2'b10;
    localparam STATE_WRITE = 2'b11;

    reg [1:0] state, next_state;
    reg [7:0] page_reg;       // The high byte of the address to read from
    reg [7:0] offset;         // The low byte of the address (0 to 255)
    reg [7:0] data_latch;     // Holds data read from RAM before writing to PPU

    wire trigger_dma = (cpu_addr_in == 16'h4014) && (cpu_rw == 1'b0);

    always @(posedge clk) begin
        if (reset) begin
            state      <= STATE_IDLE;
            page_reg   <= 8'h00;
            offset     <= 8'h00;
            data_latch <= 8'h00;
        end else if (clk_en) begin
            case (state)
                STATE_IDLE: begin
                    if (trigger_dma) begin
                        page_reg <= cpu_data_in;
                        offset   <= 8'h00;
                        state    <= STATE_ALIGN; // DMA takes 1 or 2 dummy cycles to align
                    end
                end

                STATE_ALIGN: begin
                    // In a highly accurate emulator, this checks odd/even CPU cycles. 
                    // For simplicity, we just waste one cycle and start reading.
                    state <= STATE_READ; 
                end

                STATE_READ: begin
                    // Data from bus_data_in will be ready on the next clock edge
                    data_latch <= bus_data_in; 
                    state      <= STATE_WRITE;
                end

                STATE_WRITE: begin
                    if (offset == 8'hFF) begin
                        state <= STATE_IDLE; // Finished 256 bytes
                    end else begin
                        offset <= offset + 1'b1;
                        state  <= STATE_READ;
                    end
                end
            endcase
        end
    end

    // Combinational Output Logic
    assign dma_active   = (state != STATE_IDLE);
    assign cpu_halt     = dma_active; // Halt CPU immediately when DMA triggers

    // During READ: Address = {Page, Offset}, RW = 1 (Read)
    // During WRITE: Address = $2004 (OAMDATA), RW = 0 (Write)
    assign dma_addr_out = (state == STATE_READ) ? {page_reg, offset} : 16'h2004;
    assign dma_rw_out   = (state == STATE_READ) ? 1'b1 : 1'b0;
    
    // The data we are writing to the PPU is the data we latched during the READ state
    assign dma_data_out = data_latch;

endmodule
