module rom_async #(parameter ADDR_WIDTH=15, DATA_WIDTH=8) (
    input  wire [ADDR_WIDTH-1:0] addr,
    output wire [DATA_WIDTH-1:0] data_out
);
    reg [DATA_WIDTH-1:0] mem [(1<<ADDR_WIDTH)-1:0];

    // Load .hex file for initialization
    initial begin
        $readmemh("mario.hex", mem); 
    end

    assign data_out = mem[addr];
endmodule
