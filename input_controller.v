module input_controller (
    input wire clk,
    input wire reset,
    input wire clk_en,
    input wire cs,  // Chip Select for $4016
    input wire rw,  // Read/Write signal: 1 for Read, 0 for Write
    input wire [7:0] data_in,
    output reg [7:0] data_out,
    input wire [7:0] fpga_buttons
);
    
reg latch_signal;
    reg [7:0] shift_reg;

    // Output logic: The NES CPU only reads the bottom bit (bit 0) for the button state.
    // The top bits are technically open bus, but 0 is safe.
    always @(*) begin
        data_out = {7'b0000000, shift_reg[0]};
    end

    always @(posedge clk) begin
        if (reset) begin
            latch_signal <= 1'b0;
            shift_reg    <= 8'h00;
        end else if (clk_en) begin
            
            // CPU Write to $4016
            if (cs && !rw) begin
                latch_signal <= data_in[0];
            end
            
            // Latch mode behavior
            if (latch_signal) begin
                // While the latch signal is high, continuously load the physical buttons.
                // Note: The NES standard order is A, B, Select, Start, Up, Down, Left, Right.
                shift_reg <= fpga_buttons; 
            end 
            // CPU Read from $4016
            else if (cs && rw) begin
                // Every time the CPU reads, we shift the register right by 1
                // We fill the MSB with 1 (standard behavior for an empty/unplugged controller bit)
                shift_reg <= {1'b1, shift_reg[7:1]};
            end
            
        end
    end
endmodule
