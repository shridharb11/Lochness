## Clock Signal (Nexys 4 DDR has a 100MHz onboard oscillator)
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { mCLOCK }]; 
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { mCLOCK }];

## Reset Button (CPU Reset - BTNC)
set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { nRESET }];

## NES Controller 1 Mapping
## A Button -> Center Push Button (BTNC)
# Note: nRESET is often mapped to a dedicated reset, if you use BTNC for 'A', 
# ensure your reset is mapped elsewhere like the CPU_RESET pin (C12).
set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { BUTTONS[0] }]; 

## B, Select, Start -> Slide Switches (SW0, SW1, SW2)
set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports { BUTTONS[1] }]; 
set_property -dict { PACKAGE_PIN L16   IOSTANDARD LVCMOS33 } [get_ports { BUTTONS[2] }]; 
set_property -dict { PACKAGE_PIN M13   IOSTANDARD LVCMOS33 } [get_ports { BUTTONS[3] }]; 

## Directional Pad -> Push Buttons (Up, Down, Left, Right)
set_property -dict { PACKAGE_PIN M18   IOSTANDARD LVCMOS33 } [get_ports { BUTTONS[4] }]; # BTNU
set_property -dict { PACKAGE_PIN P18   IOSTANDARD LVCMOS33 } [get_ports { BUTTONS[5] }]; # BTND
set_property -dict { PACKAGE_PIN P17   IOSTANDARD LVCMOS33 } [get_ports { BUTTONS[6] }]; # BTNL
set_property -dict { PACKAGE_PIN M17   IOSTANDARD LVCMOS33 } [get_ports { BUTTONS[7] }]; # BTNR

## VGA Outputs
## Red Channel
set_property -dict { PACKAGE_PIN A3    IOSTANDARD LVCMOS33 } [get_ports { VGA_R[0] }]; 
set_property -dict { PACKAGE_PIN B4    IOSTANDARD LVCMOS33 } [get_ports { VGA_R[1] }]; 
set_property -dict { PACKAGE_PIN C5    IOSTANDARD LVCMOS33 } [get_ports { VGA_R[2] }]; 
set_property -dict { PACKAGE_PIN A4    IOSTANDARD LVCMOS33 } [get_ports { VGA_R[3] }]; 

## Green Channel
set_property -dict { PACKAGE_PIN C6    IOSTANDARD LVCMOS33 } [get_ports { VGA_G[0] }]; 
set_property -dict { PACKAGE_PIN A5    IOSTANDARD LVCMOS33 } [get_ports { VGA_G[1] }]; 
set_property -dict { PACKAGE_PIN B6    IOSTANDARD LVCMOS33 } [get_ports { VGA_G[2] }]; 
set_property -dict { PACKAGE_PIN A6    IOSTANDARD LVCMOS33 } [get_ports { VGA_G[3] }]; 

## Blue Channel
set_property -dict { PACKAGE_PIN B7    IOSTANDARD LVCMOS33 } [get_ports { VGA_B[0] }]; 
set_property -dict { PACKAGE_PIN C7    IOSTANDARD LVCMOS33 } [get_ports { VGA_B[1] }]; 
set_property -dict { PACKAGE_PIN D7    IOSTANDARD LVCMOS33 } [get_ports { VGA_B[2] }]; 
set_property -dict { PACKAGE_PIN D8    IOSTANDARD LVCMOS33 } [get_ports { VGA_B[3] }]; 

## Sync Signals
set_property -dict { PACKAGE_PIN B11   IOSTANDARD LVCMOS33 } [get_ports { VGA_HS }]; 
set_property -dict { PACKAGE_PIN B12   IOSTANDARD LVCMOS33 } [get_ports { VGA_VS }]; 

## Timing Constraint for Generated Clock
create_generated_clock -name clk_sys [get_pins pll_inst/clk_out1]