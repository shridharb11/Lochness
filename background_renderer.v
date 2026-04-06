module background_renderer(
input reset, ppu_clk, hblank,
input [8:0] scanline_index, scanline_x_coordinate,
input [7:0] ppu_data, x_scroll, y_scroll,
input x_scroll_nametable_select, y_scroll_nametable_select, background_pattern_table_select, left_bg_clipping,
output reg RD, ALE,
output  [3:0] bg_pixel,
output reg [13:0] ppu_addr);

// reset, ppu_clk, hblank, scanline_index, scanline_x_coordinate, x_scroll, y_scroll, x_scroll_nametable_select, y_scroll_nametable_select, background_pattern_table_select, left_bg_clipping : inputs from CPU
// ppu_data : input from internal VRAM/ palette : after passing thru an IO port
// bg_pixel, ppu_addr, RD, ALE: outputs to internal VRAM/ palette : passed thru an IO port

// temp variables and wires,regs //
wire [2:0] fine_x_scroll;   // fine scroll : for control of which pixel inside a tile
reg load_buffer;
wire [3:0] background_out;
reg [7:0] pattern_bitmap_one, pattern_bitmap_two, palette_data_one, palette_data_two; // tile characteristics data, to be fed to buffer

// instantiating background buffer
background_buffer bg_buffer( .ppu_clk(ppu_clk), .rst(reset), .load(load_buffer), .fine_x_scroll(fine_x_scroll), 
.palette_data_one(palette_data_one), .palette_data_two(palette_data_two), .pattern_bitmap_one(pattern_bitmap_one),
.pattern_bitmap_two(pattern_bitmap_two), .background_out(background_out), .hblank(hblank));


// temp variables and wires,regs //

wire render_bg, render_bg_next, output_bg;     // render_bg: controls rendering, render_bg_next: controls data prefetch during hblank, output_bg: controls output being driven

reg [3:0] name_table; wire [13:0] name_table_addr;  // name table data
reg [7:0] attribute_table; wire [13:0] attribute_table_addr;  //attribute table data
reg [7:0] attribute_table_temp;

wire bg_enable;

reg [2:0] fetch_phase_counter;  // counter for memory fetc FSM

reg [7:0]  name_table_temp; 
reg [13:0] name_table_addr_temp;   // attribute byte data
reg [2:0] attribute_low_bit, attribute_high_bit; 
wire [13:0] pattern_table_address_one, pattern_table_address_two; 

// LATCHED SCROLL REGISTERS FOR SCROLLING
reg [7:0] latched_x_scroll;
reg latched_nametable_x_select;

// tile_x_counter: keeps track of column
reg [4:0] tile_x_counter;

reg current_nametable_x; // tracks nametable

// BACKGROUND RENDERING
wire visible_line = (scanline_index >= 21) && (scanline_index <= 260);
wire visible_x = (scanline_x_coordinate >= 0) && (scanline_x_coordinate <= 255);
wire safely_visible_x = (scanline_x_coordinate >= 1) && (scanline_x_coordinate <= 251);
wire prefetch_line = (scanline_index >= 20) && (scanline_index <= 259);
wire prefetch_x = (scanline_x_coordinate >= 320) && (scanline_x_coordinate <= 335);

assign output_bg = visible_line && visible_x ;
assign render_bg = visible_line && safely_visible_x;
assign render_bg_next = prefetch_line && prefetch_x;

assign fine_x_scroll = latched_x_scroll[2:0];

// NAME TABLE ADDRESS CONSTRUCTOR
always @(*) begin
if (y_scroll_nametable_select) begin
if (current_nametable_x) name_table = 4'b1011;
else name_table = 4'b1010;
end
else begin
if (current_nametable_x) name_table = 4'b1001;
else name_table = 4'b1000;
end
end
assign name_table_addr = {name_table, y_scroll[7:3], tile_x_counter};

// ATTRIBUTE TABLE ADDRESS CONSTRUCTOR
always @(*) begin
if (y_scroll_nametable_select) begin
if (current_nametable_x) attribute_table =  8'b10111111;
else attribute_table = 8'b10101111;
end
else begin
if (current_nametable_x) attribute_table = 8'b10011111;
else attribute_table = 8'b10001111;
end
end
assign attribute_table_addr = {attribute_table, y_scroll[7:5], tile_x_counter[4:2]};


// ATTRIBUTE BYTE BIT SELECTOR 
always @(*) begin
if (name_table_addr_temp[1]) begin
if (name_table_addr_temp[6]) begin
attribute_low_bit = 6;
attribute_high_bit = 7;
end
else begin
attribute_low_bit = 2;
attribute_high_bit = 3;
end
end
else begin 
if (name_table_addr_temp[6]) begin
attribute_low_bit = 4;
attribute_high_bit = 5;
end
else begin
attribute_low_bit = 0;
attribute_high_bit = 1;
end
end
end

// PATTERN TABLE ADDRESS CONSTRUCTOR
assign pattern_table_address_one = {1'b0, background_pattern_table_select, name_table_temp ,
1'b0, y_scroll[2:0]};
assign pattern_table_address_two = {1'b0, background_pattern_table_select, name_table_temp,
1'b1, y_scroll[2:0]}; 




    

// MEMORY FETCH FSM
always @(posedge ppu_clk) begin
if (reset) begin
ALE <= 0;
RD <= 0 ;
pattern_bitmap_one <= 0;
pattern_bitmap_two <= 0;
palette_data_one <= 0;
palette_data_two <= 0;
fetch_phase_counter <= 0;
load_buffer <= 0;

latched_x_scroll <= 0;
latched_nametable_x_select <= 0;
tile_x_counter <= 0;
current_nametable_x <= 0;

name_table_addr_temp <= 0;

ppu_addr <= 0;
end

else begin

if (scanline_x_coordinate == 0 && fetch_phase_counter == 0) begin
// capture scroll at start of scanline so CPU writes mid-line dont affect rendering
latched_x_scroll <= x_scroll;
latched_nametable_x_select <= x_scroll_nametable_select;
// initialise tile counter to coarse x scroll so first fetch starts at correct tile
tile_x_counter <= x_scroll[7:3];
current_nametable_x <= x_scroll_nametable_select;
end

if (render_bg || render_bg_next) begin

case(fetch_phase_counter)
0: begin     // name table fetch cycle 1 
load_buffer<=0;
ppu_addr <= name_table_addr;
name_table_addr_temp <= name_table_addr;
ALE <= 1;
RD <=1 ;
fetch_phase_counter <= 1;
end

1: begin    // name table fetch cycle 2 - latching the value
ALE <= 0;
RD <= 0;
name_table_temp <= ppu_data;
fetch_phase_counter <= 2;
end

2: begin     // attribute table fetch cycle 1
ppu_addr <= attribute_table_addr;
ALE <= 1;
RD <=1 ;
fetch_phase_counter <= 3;
end

3: begin   // attribute table fetch cycle 2
ALE <= 0;
RD <= 0;
attribute_table_temp <= ppu_data;
palette_data_one <= {8{ppu_data[attribute_low_bit]}};
palette_data_two <= {8{ppu_data[attribute_high_bit]}};
fetch_phase_counter <= 4;
end

4: begin           // pattern table low byte fetch cycle 1
ppu_addr <= pattern_table_address_one;
ALE <= 1;
RD <=1 ;
fetch_phase_counter <= 5;
end


5: begin      // pattern table low byte fetch cycle 2
ALE <= 0;
RD <=0 ;
pattern_bitmap_one <= ppu_data;
fetch_phase_counter <= 6;
end

6:begin            // pattern table high byte fetch cycle 1
ppu_addr <= pattern_table_address_two;
ALE <= 1;
RD <=1 ;
fetch_phase_counter <= 7;
end

7: begin   // pattern table high byte fetch cycle 2
ALE <= 0;
RD <=0 ;
pattern_bitmap_two <= ppu_data;
fetch_phase_counter <= 0;
load_buffer <= 1;

// advance tile counter , once it hits 31 reset to 0 and flip to the next nametable
if (tile_x_counter == 31) begin
tile_x_counter <= 0;
current_nametable_x <= ~current_nametable_x;
end
else begin
tile_x_counter <= tile_x_counter + 1;
end
end

default: begin
fetch_phase_counter <=0;
end
endcase
end

else begin
ALE <= 0;
RD  <= 0;
load_buffer <= 0;
fetch_phase_counter <= 0;  
end

end


end  

assign bg_enable = output_bg && !(left_bg_clipping && (scanline_x_coordinate <8));  
// enable output if scanline is pointed inside screen and left side screen clipping condition is false


assign bg_pixel = bg_enable ? background_out : 4'b0000;
// bg_pixel : output to VGA


endmodule