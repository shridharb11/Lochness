`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.02.2026 18:50:52
// Design Name: 
// Module Name: sprite_renderer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module sprite_renderer(
    input ppu_clk,
    input rst,
    input en_ppu,
    input hblank,           
    input sprite_height, // 0 = 8×8 sprite,  1 = 8×16 sprite
    input sprite_pt_select, 
    input [8:0] scanline,
    input [8:0] scanline_clk,
    input [7:0] sprite_ram_data,
    input [7:0] ppu_data,
    input  left_side_clipping,
    output reg [7:0] sprite_ram_addr,
    output reg [13:0] ppu_addr, // CHR ROM address
    output reg ale, 
    output reg rd,
    output reg sprite_overflow,
    output reg [4:0] sprite_pixel_out,
    output reg primary_pixel
);

    wire visible_scanline = (scanline >= 9'd20)  && (scanline <= 9'd259);
    wire visible_pixel = (scanline_clk > 9'd0) && (scanline_clk <= 9'd128);
    wire h_blank = (scanline_clk > 9'd256) && (scanline_clk <= 9'd320);
    wire sprite_range_search = visible_scanline && visible_pixel;
    wire memory_fetch = visible_scanline && h_blank;

    reg [7:0] temp_sprite_mem [0:23];
    reg [4:0] range_temp_adrr; // write-side pointer, owned by range FSM
    reg [4:0] fetch_temp_adrr; // read-side pointer,  owned by fetch FSM
    reg [7:0] temp_sprite_wdata;
    reg temp_sprite_we;

    wire [4:0] temp_sprite_adrr = memory_fetch ? fetch_temp_adrr : range_temp_adrr; //during memory fetch fetch temp addr takes over
    wire [7:0] temp_sprite_mem_out = temp_sprite_mem[temp_sprite_adrr]; // async read

    always @(posedge ppu_clk) begin
        if (temp_sprite_we)
            temp_sprite_mem[temp_sprite_adrr] <= temp_sprite_wdata;
    end

    reg [7:0] high_bit_load, low_bit_load, x_clk_load;
    reg [7:0] sprite_buffer_data;
    wire [1:0] out_buf [7:0];

    sprite_buffer buffer0(ppu_clk,en_ppu,rst,high_bit_load[0],low_bit_load[0],hblank,x_clk_load[0],sprite_buffer_data,out_buf[0]);
    sprite_buffer buffer1(ppu_clk,en_ppu,rst,high_bit_load[1],low_bit_load[1],hblank,x_clk_load[1],sprite_buffer_data,out_buf[1]);
    sprite_buffer buffer2(ppu_clk,en_ppu,rst,high_bit_load[2],low_bit_load[2],hblank,x_clk_load[2],sprite_buffer_data,out_buf[2]);
    sprite_buffer buffer3(ppu_clk,en_ppu,rst,high_bit_load[3],low_bit_load[3],hblank,x_clk_load[3],sprite_buffer_data,out_buf[3]);
    sprite_buffer buffer4(ppu_clk,en_ppu,rst,high_bit_load[4],low_bit_load[4],hblank,x_clk_load[4],sprite_buffer_data,out_buf[4]);
    sprite_buffer buffer5(ppu_clk,en_ppu,rst,high_bit_load[5],low_bit_load[5],hblank,x_clk_load[5],sprite_buffer_data,out_buf[5]);
    sprite_buffer buffer6(ppu_clk,en_ppu,rst,high_bit_load[6],low_bit_load[6],hblank,x_clk_load[6],sprite_buffer_data,out_buf[6]);
    sprite_buffer buffer7(ppu_clk,en_ppu,rst,high_bit_load[7],low_bit_load[7],hblank,x_clk_load[7],sprite_buffer_data,out_buf[7]);

    reg  horizontal_flip_flag;
    wire [7:0] sprite_buffers_data = horizontal_flip_flag ? {ppu_data[0], ppu_data[1], ppu_data[2], ppu_data[3], ppu_data[4], ppu_data[5], ppu_data[6], ppu_data[7]} : ppu_data;
    reg [8:0] range_comparator;   
    reg [3:0] range_state;
    reg sprite_0;
    reg [3:0]  sprite_num_inrange;

    always @(posedge ppu_clk) begin : sprite_rendering

        if (en_ppu && scanline_clk == 9'd0) begin
            range_temp_adrr <= 5'd0;
            sprite_num_inrange <= 4'd0;
            sprite_overflow <= 1'b0;
            sprite_0 <= 1'b0;
            sprite_ram_addr <= 8'd0;   
            range_state <= 4'd9; // Go to clear state   
        end

        if (en_ppu && sprite_range_search) begin
            case (range_state)
                4'd0: begin
                    range_comparator <= scanline - 9'd20 - {1'b0, sprite_ram_data};
                    range_state <= 4'd1;
                end
                4'd1: begin
                    if ((!sprite_height && range_comparator <= 9'd7)  || ( sprite_height && range_comparator <= 9'd15)) begin
                        if (sprite_ram_addr == 8'd0) sprite_0 <= 1'b1;
                        if (sprite_num_inrange < 4'd8) begin
                            sprite_ram_addr <= sprite_ram_addr + 8'd2; //jump to attribute byte
                            sprite_num_inrange <= sprite_num_inrange + 4'd1;
                            range_state <= 4'd2;
                        end else begin
                            sprite_overflow <= 1'b1;
                            range_state <= 4'd8;
                        end
                    end else begin : not_in_rang
                        if (sprite_ram_addr >= 8'd252) begin
                            sprite_ram_addr <= 8'd0;
                            range_state <= 4'd8;
                        end else begin
                            sprite_ram_addr <= sprite_ram_addr + 8'd4;
                            range_state <= 4'd0;
                        end
                    end
                end
                4'd2: begin
                    if (sprite_ram_data[7]) // vertical flip
                        temp_sprite_wdata <= {sprite_ram_data[6:5], sprite_ram_data[1:0], ~range_comparator[3:0]};
                    else
                        temp_sprite_wdata <= {sprite_ram_data[6:5], sprite_ram_data[1:0],  range_comparator[3:0]};
                    temp_sprite_we <= 1'b1;   // write to temp_sprite_mem[range_temp_adrr]
                    range_state <= 4'd3;
                end
                4'd3: begin
                    sprite_ram_addr <= sprite_ram_addr - 8'd1;  // OAM byte 1 = tile index
                    range_temp_adrr <= range_temp_adrr + 5'd1;  // advance to tile-idx slot
                    temp_sprite_we <= 1'b0;
                    range_state <= 4'd4;
                end
                4'd4: begin
                    temp_sprite_wdata <= sprite_ram_data;
                    temp_sprite_we <= 1'b1;
                    range_state <= 4'd5;
                end
                4'd5: begin
                    sprite_ram_addr <= sprite_ram_addr + 8'd2;  // OAM byte 3 = X coord
                    range_temp_adrr <= range_temp_adrr + 5'd1;  
                    temp_sprite_we <= 1'b0;
                    range_state <= 4'd6;
                end
                4'd6: begin
                    temp_sprite_wdata <= sprite_ram_data;
                    temp_sprite_we <= 1'b1;
                    range_state <= 4'd7;
                end
                4'd7: begin
                    temp_sprite_we <= 1'b0;
                    if (sprite_ram_addr >= 8'd252) begin // Last OAM sprite processed
                        range_state <= 4'd8;
                    end else begin
                        range_temp_adrr <= range_temp_adrr + 5'd1; 
                        sprite_ram_addr <= sprite_ram_addr + 8'd1;  // OAM byte 0 of next sprite
                        range_state <= 4'd0;  
                    end
                end
                4'd8: begin //stall for mem fetch
                    temp_sprite_we <= 1'b0;
                    sprite_ram_addr <= 8'd0;
                    range_temp_adrr <= 5'd0;
                    range_state <= 4'd8;
                end
                4'd9: begin // Clear secondary OAM (24 bytes)
                    temp_sprite_wdata <= 8'hFF;
                    temp_sprite_we <= 1'b1;
                    if (range_temp_adrr == 5'd23) begin
                        range_state <= 4'd10;
                    end else begin
                        range_temp_adrr <= range_temp_adrr + 5'd1;
                    end
                end
                4'd10: begin // Finish clearing
                    temp_sprite_we <= 1'b0;
                    range_temp_adrr <= 5'd0;
                    range_state <= 4'd0;
                end

            endcase
        end
    end

    reg [3:0] fetch_state;
    reg [3:0] sprite_fetch_num;
    reg [7:0] attr_reg; 
    reg prim_obj_render;
    reg [2:0] sprite_attr [0:7];

    always @(posedge ppu_clk) begin : memory_fetching
        if (rst) begin
            sprite_fetch_num <= 4'd1;
            fetch_state <= 4'd0;
            fetch_temp_adrr <= 5'd1;   // first decrement in state 0 lands on 0
            x_clk_load <= 8'd0;
            high_bit_load <= 8'd0;
            low_bit_load <= 8'd0;
            sprite_buffer_data <= 8'd0;
            ppu_addr <= 14'd0;
            ale <= 1'b0;
            rd <= 1'b0;
            horizontal_flip_flag <= 1'b0;
            attr_reg <= 8'd0;   
            prim_obj_render <= 1'b0;
        end
        if (scanline_clk == 9'd0) begin
            sprite_fetch_num <= 4'd1;
            fetch_state <= 4'd0;
            fetch_temp_adrr <= 5'd1;
            prim_obj_render <= sprite_0;
        end
        if (memory_fetch) begin
            case (fetch_state)
                4'd0: begin
                    ale <= 1'b0; rd <= 1'b0;
                    if (sprite_fetch_num > sprite_num_inrange) begin
                        fetch_state <= 4'd8;   // all sprites loaded
                    end else begin
                        fetch_temp_adrr <= fetch_temp_adrr - 5'd1; // point at attr 
                        fetch_state <= 4'd1;
                    end
                end
                4'd1: begin
                    sprite_attr[sprite_fetch_num - 1] <= {temp_sprite_mem_out[6:4]}; //store attr for priority later
                    attr_reg <= temp_sprite_mem_out; // latch attribute
                    horizontal_flip_flag <= temp_sprite_mem_out[7]; //bit7 = h_flip
                    fetch_temp_adrr <= fetch_temp_adrr + 5'd1; 
                    fetch_state <= 4'd2;
                end
                4'd2: begin
                    if(!sprite_height)  begin
                        ppu_addr <= {1'b0,sprite_pt_select,temp_sprite_mem_out, 1'b0,attr_reg[2:0]};
                        ale <= 1'b1; 
                        rd <= 1'b0;
                    end
                    else begin
                        ppu_addr <= {1'b0,temp_sprite_mem_out[0],temp_sprite_mem_out[7:1],attr_reg[3],1'b0,attr_reg[2:0]};
                        ale <= 1'b1; 
                        rd <= 1'b0;
                    end
                    case (sprite_fetch_num)
                        4'd1: low_bit_load <= 8'b00000001;
                        4'd2: low_bit_load <= 8'b00000010;
                        4'd3: low_bit_load <= 8'b00000100;
                        4'd4: low_bit_load <= 8'b00001000;
                        4'd5: low_bit_load <= 8'b00010000;
                        4'd6: low_bit_load <= 8'b00100000;
                        4'd7: low_bit_load <= 8'b01000000;
                        4'd8: low_bit_load <= 8'b10000000;
                        default: low_bit_load <= 8'd0;
                    endcase
                    fetch_state <= 4'd3;
                end
                4'd3: begin
                    ale <= 1'b0;
                    rd  <= 1'b1;
                    fetch_state <= 4'd4;
                end
                4'd4: begin
                    rd <= 1'b0;
                    sprite_buffer_data <= sprite_buffers_data;
                    low_bit_load <= 8'd0;
                    ppu_addr <= ppu_addr + 14'd8; // high plane = low + 8
                    ale <= 1'b1;
                    case (sprite_fetch_num)
                        4'd1: high_bit_load <= 8'b00000001;
                        4'd2: high_bit_load <= 8'b00000010;
                        4'd3: high_bit_load <= 8'b00000100;
                        4'd4: high_bit_load <= 8'b00001000;
                        4'd5: high_bit_load <= 8'b00010000;
                        4'd6: high_bit_load <= 8'b00100000;
                        4'd7: high_bit_load <= 8'b01000000;
                        4'd8: high_bit_load <= 8'b10000000;
                        default: high_bit_load <= 8'd0;
                    endcase
                    fetch_state <= 4'd5;
                end
                4'd5: begin
                    ale <= 1'b0;
                    rd <= 1'b1;
                    fetch_temp_adrr <= fetch_temp_adrr + 5'd1; 
                    fetch_state <= 4'd6;
                end
                4'd6: begin
                    rd <= 1'b0;
                    sprite_buffer_data <= sprite_buffers_data;
                    high_bit_load <= 8'd0;
                    fetch_state <= 4'd7;
                end
                4'd7: begin
                    sprite_buffer_data <= temp_sprite_mem_out; // x-coordinate
                    case (sprite_fetch_num)
                        4'd1: x_clk_load <= 8'b00000001;
                        4'd2: x_clk_load <= 8'b00000010;
                        4'd3: x_clk_load <= 8'b00000100;
                        4'd4: x_clk_load <= 8'b00001000;
                        4'd5: x_clk_load <= 8'b00010000;
                        4'd6: x_clk_load <= 8'b00100000;
                        4'd7: x_clk_load <= 8'b01000000;
                        4'd8: x_clk_load <= 8'b10000000;
                        default: x_clk_load <= 8'd0;
                    endcase
                    fetch_temp_adrr <= fetch_temp_adrr + 5'd2;   
                    sprite_fetch_num <= sprite_fetch_num + 4'd1;   
                    fetch_state <= 4'd8;
                end
                4'd8: begin
                    x_clk_load  <= 8'd0;
                    fetch_state <= 4'd0;
                end
            endcase
        end
    end 

    //priority mux for output
    integer i;
    always @(*) begin
    sprite_pixel_out = 5'd0;
    primary_pixel = 1'b0;
    if (left_side_clipping && scanline_clk <= 9'd8) sprite_pixel_out = 5'd0;
    else begin
        for (i = 7; i >= 0; i = i - 1) begin
            if (out_buf[i] != 2'b00)
                sprite_pixel_out = {out_buf[i], sprite_attr[i]};
        end
        if (out_buf[0] != 2'b00 && prim_obj_render) primary_pixel = 1'b1;
    end
end
endmodule
