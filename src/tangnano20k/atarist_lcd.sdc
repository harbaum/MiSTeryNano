//Copyright (C)2014-2024 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.9 
//Created Time: 2024-01-28 16:34:10
create_clock -name clk_sdram -period 31 -waveform {0 15} [get_ports {O_sdram_clk}] -add
create_clock -name clk_32 -period 31 -waveform {0 15} [get_ports {lcd_dclk}] -add
create_clock -name clk_spi -period 10 -waveform {0 5} [get_ports {mspi_clk}] -add
create_clock -name clk_osc -period 37 -waveform {0 18} [get_ports {clk}] -add
