/*
    top.sv - atarist on tang nano 20k toplevel

    This top level implements the default variant for 20k with M0S
    Dock, DB9-Joystick and MIDI
*/ 

module top(
  input			clk,

  input			reset, // S2
  input			user, // S1

  output [5:0]	leds_n,
  output		ws2812,

  // spi flash interface
  output		mspi_cs,
  output		mspi_clk,
  inout			mspi_di,
  inout			mspi_hold,
  inout			mspi_wp,
  inout			mspi_do,

  // "Magic" port names that the gowin compiler connects to the on-chip SDRAM
  output		O_sdram_clk,
  output		O_sdram_cke,
  output		O_sdram_cs_n, // chip select
  output		O_sdram_cas_n,
    
 // columns address select
  output		O_sdram_ras_n, // row address select
  output		O_sdram_wen_n, // write enable
  inout [31:0]	IO_sdram_dq, // 32 bit bidirectional data bus
  output [10:0]	O_sdram_addr, // 11 bit multiplexed address bus
  output [1:0]	O_sdram_ba, // two banks
  output [3:0]	O_sdram_dqm, // 32/4

  // generic IO, used for mouse/joystick/...
  inout [7:0]	io,

  // interface to external BL616/M0S
  inout [5:0]	m0s,

  // MIDI
  input			midi_in,
  output		midi_out,
		   
  // SD card slot
  output		sd_clk,
  inout			sd_cmd, // MOSI
  inout [3:0]	sd_dat, // 0: MISO
	   
  // SPI connection to ob-board BL616. By default an external
  // connection is used with a M0S Dock
  input			spi_sclk, // in... 
  input			spi_csn, // in (io?)
  output		spi_dir, // out
  input			spi_dat, // in (io?)

//  output    jtag_tck,

  // hdmi/tdms
  output		tmds_clk_n,
  output		tmds_clk_p,
  output [2:0]	tmds_d_n,
  output [2:0]	tmds_d_p
);

// assign jtag_tck = spi_dir;

misterynano misterynano (
  .clk   ( clk ),

  .reset ( reset ),
  .user  ( user ),

  .leds_n ( leds_n ),
  .ws2812 ( ws2812 ),

  // spi flash interface
  .mspi_cs   ( mspi_cs   ),
  .mspi_clk  ( mspi_clk  ),
  .mspi_di   ( mspi_di   ),
  .mspi_hold ( mspi_hold ),
  .mspi_wp   ( mspi_wp   ),
  .mspi_do   ( mspi_do   ),

  // SDRAM
  .sdram_clk   ( O_sdram_clk    ),
  .sdram_cke   ( O_sdram_cke    ),
  .sdram_cs_n  ( O_sdram_cs_n   ), // chip select
  .sdram_cas_n ( O_sdram_cas_n  ), // columns address select
  .sdram_ras_n ( O_sdram_ras_n  ), // row address select
  .sdram_wen_n ( O_sdram_wen_n  ), // write enable
  .sdram_dq    ( IO_sdram_dq    ), // 32 bit bidirectional data bus
  .sdram_addr  ( O_sdram_addr   ), // 11 bit multiplexed address bus
  .sdram_ba    ( O_sdram_ba     ), // two banks
  .sdram_dqm   ( O_sdram_dqm    ), // 32/4

  // generic IO, used for mouse/joystick/...
  .io ( io ),

  // interface to external BL616/M0S
  .m0s ( m0s ),

  // MIDI
  .midi_in  ( midi_in  ),
  .midi_out ( midi_out ),
		   
  // SD card slot
  .sd_clk ( sd_clk ),
  .sd_cmd ( sd_cmd ), // MOSI
  .sd_dat ( sd_dat ), // 0: MISO
	   
  // SPI connection to ob-board BL616. By default an external
  // connection is used with a M0S Dock
  .spi_sclk ( spi_sclk ), // in... 
  .spi_csn  ( spi_csn  ), // in (io?)
  .spi_dir  ( spi_dir  ), // out
  .spi_dat  ( spi_dat  ), // in (io?)

  // scandoubled digital video to be
  // used with lcds
  .lcd_clk  ( ),
  .lcd_hs_n ( ),
  .lcd_vs_n ( ),
  .lcd_de   ( ),
  .lcd_r    ( ),
  .lcd_g    ( ),
  .lcd_b    ( ),

  // digital 16 bit audio output
  .audio ( ),

  // tdms to be used with hdmi or dvi
  .tmds_clk_n ( tmds_clk_n ),
  .tmds_clk_p ( tmds_clk_p ),
  .tmds_d_n   ( tmds_d_n   ),
  .tmds_d_p   ( tmds_d_p   )
);

endmodule

// To match emacs with gw_ide default
// Local Variables:
// tab-width: 4
// End:

