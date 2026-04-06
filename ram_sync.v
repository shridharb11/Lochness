module ram_sync #(parameter ADDR_WIDTH=11, DATA_WIDTH=8) (
    input  wire clk,
    input  wire [ADDR_WIDTH-1:0] addr,
    input  wire [DATA_WIDTH-1:0] data_in,
    input  wire we,
    output reg  [DATA_WIDTH-1:0] data_out
);
    reg [DATA_WIDTH-1:0] mem [(1<<ADDR_WIDTH)-1:0];
    
    always @(posedge clk) begin
        if (we) mem[addr] <= data_in;
        data_out <= mem[addr];
    end
endmodule