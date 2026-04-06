module nes_clk_divider(
    input  wire clk_sys,    // 21.47 MHz
    input  wire reset,
    output wire en_ppu,    
    output wire en_cpu
    );

    reg [3:0]   counter;

    always @(posedge clk_sys) begin
        if (reset) counter <= 0;
        else begin
            if (counter == 11) counter <= 0;
            else counter <= counter + 1;
        end
    end

    // PPU runs at 1/4 speed
    assign en_ppu = (counter[1:0] == 2'b00); 

    // CPU runs at 1/12 speed
    assign en_cpu = (counter == 4'd0);    
endmodule