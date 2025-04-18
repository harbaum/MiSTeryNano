/*
    top.sv - atarist on tang primer 25k toplevel

    This top level implements the default variant for 25k with M0S Dock
*/ 

module top(
  input			clk,   // 50 MHz in

  input			reset, // S2
  input			user, // S1

  output [1:0]	leds_n,

  // spi flash interface
  output		mspi_cs,
  output		mspi_clk,
  inout			mspi_di,
  inout			mspi_hold,
  inout			mspi_wp,
  inout			mspi_do,

  // MiSTer SDRAM module
  output		O_sdram_clk,
  output		O_sdram_cs_n,  // chip select
  output		O_sdram_cas_n, // column address select
  output		O_sdram_ras_n, // row address select
  output		O_sdram_wen_n, // write enable
  inout [15:0]	IO_sdram_dq,   // 16 bit bidirectional data bus
  output [12:0]	O_sdram_addr,  // 13 bit multiplexed address bus
  output [1:0]	O_sdram_ba,    // two banks
  output [1:0]	O_sdram_dqm,   // 16/2

  // interface to external BL616/M0S
  inout [7:0]	m0s,

  // SD card slot
  output		sd_clk,
  inout			sd_cmd, // MOSI
  inout [3:0]	sd_dat, // 0: MISO
	   
  // hdmi/tdms
  output		tmds_clk_n,
  output		tmds_clk_p,
  output [2:0]	tmds_d_n,
  output [2:0]	tmds_d_p
);

wire clk32;
wire pll_lock_hdmi;
wire por; 
wire spi_io_dout;
wire spi_intn;  
   
// intn and dout are outputs driven by the FPGA to the MCU
// din, ss and clk are inputs coming from the MCU
assign m0s[7:0] = { 3'bzzz, spi_intn, 3'bzzz, spi_io_dout };

// switch between internal SPI connected to the on-board bl616
// or to the external one possibly connected to a M0S Dock
wire spi_io_din = m0s[1];
wire spi_io_ss = m0s[2];
wire spi_io_clk = m0s[3];

wire [15:0] audio [2];
wire        vreset;
wire [1:0]  vmode;
wire        vwide;

wire [5:0]  r;
wire [5:0]  g;
wire [5:0]  b;

wire [5:0] leds_int_n;   
assign leds_n = ~leds_int_n[1:0];  

// MiSTer SDRAM is only 16 bits wide
wire [31:0] sdram_dq;  
assign IO_sdram_dq = sdram_dq[15:0];
   
wire [3:0] sdram_dqm;  
assign O_sdram_dqm = sdram_dqm[1:0];

misterynano misterynano (
  .clk   ( clk ),           // 27MHz clock uses e.g. for the flash pll

  .reset ( reset ),
  .user  ( user ),

  // clock and power on reset from system
  .clk32 ( clk32 ),         // 32 Mhz system clock input
  .pll_lock_main( pll_lock_hdmi),
  .por   ( por ),           // output. True while not all PLLs locked

  .leds_n ( leds_int_n ),
  .ws2812 ( ),

  // spi flash interface
  .mspi_cs   ( mspi_cs   ),
  .mspi_clk  ( mspi_clk  ),
  .mspi_di   ( mspi_di   ),
  .mspi_hold ( mspi_hold ),
  .mspi_wp   ( mspi_wp   ),
  .mspi_do   ( mspi_do   ),

  // SDRAM
  .sdram_clk   ( O_sdram_clk    ),
  .sdram_cke   ( ),
  .sdram_cs_n  ( O_sdram_cs_n   ), // chip select
  .sdram_cas_n ( O_sdram_cas_n  ), // column address select
  .sdram_ras_n ( O_sdram_ras_n  ), // row address select
  .sdram_wen_n ( O_sdram_wen_n  ), // write enable
  .sdram_dq    ( sdram_dq       ), // 16 bit bidirectional data bus
  .sdram_addr  ( O_sdram_addr   ), // 13 bit multiplexed address bus
  .sdram_ba    ( O_sdram_ba     ), // two banks
  .sdram_dqm   ( sdram_dqm      ), // 16/4

  // generic IO, used for mouse/joystick/...
  .io          ( 8'b11111111    ), // unused

  // mcu interface
  .mcu_sclk ( spi_io_clk  ),
  .mcu_csn  ( spi_io_ss   ),
  .mcu_miso ( spi_io_dout ), // from FPGA to MCU
  .mcu_mosi ( spi_io_din  ), // from MCU to FPGA
  .mcu_intn ( spi_intn    ),

  // parallel port
  .parallel_strobe_oe ( ),
  .parallel_strobe_in ( 1'b1 ), 
  .parallel_strobe_out ( ), 
  .parallel_data_oe ( ),
  .parallel_data_in ( 8'h00 ),
  .parallel_data_out ( ),
  .parallel_busy ( 1'b1 ), 
		   
  // MIDI
  .midi_in  ( 1'b1  ),
  .midi_out ( ),
		   
  // SD card slot
  .sd_clk ( sd_clk ),
  .sd_cmd ( sd_cmd ), // MOSI
  .sd_dat ( sd_dat ), // 0: MISO

  .vreset ( vreset ),
  .vmode  ( vmode  ),
  .vwide  ( vwide  ),
	   
  // scandoubled digital video to be
  // used with lcds
  .lcd_clk  ( ),
  .lcd_hs_n ( ),
  .lcd_vs_n ( ),
  .lcd_de   ( ),
  .lcd_r    ( r ),
  .lcd_g    ( g ),
  .lcd_b    ( b ),

  // digital 16 bit audio output
  .audio ( audio )
);

video2hdmi video2hdmi (
    .clk      ( clk      ),       // clock in
    .clk_32   ( clk32    ),       // 32 Mhz clock out
    .pll_lock ( pll_lock_hdmi ),  // output clock is stable

    .vreset ( vreset ),
    .vmode ( vmode ),
    .vwide ( vwide ),

    .r( r ),
    .g( g ),
    .b( b ),
    .audio ( audio ),
    
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

