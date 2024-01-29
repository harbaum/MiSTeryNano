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

  output        lcd_dclk,
  output        lcd_hs, //lcd horizontal synchronization
  output        lcd_vs, //lcd vertical synchronization        
  output        lcd_de, //lcd data enable     
  output [4:0]  lcd_r,  //lcd red
  output [5:0]  lcd_g,  //lcd green
  output [4:0]  lcd_b,  //lcd blue

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

  // audio
  output       hp_bck,
  output       hp_ws,
  output       hp_din,
  output       pa_en

  // spi_dir has a low-pass filter which makes it impossible to use
  // we thus use jtag_tck as a replacement
//  output    jtag_tck,
//  input     jtag_tdi,    // this is being used for interrupt
);

// the lcd variante does not need the 160MHz hdmi clock. Thus a pll
// generates the 32MHz directly
wire clk32;
wire pll_lock_32m;

pll_32m pll_32m (
    .clkout( clk32 ),
    .lock(pll_lock_32m),
    .clkin(clk)
);

// power on reset is returned by misterynano whenever all plls
// are up and running.
wire por;

// On the Tang Nano 20k we support two different MCU setups. Once uses the internal
// BL616 of the Tang Nano 20k and one uses an external M0S Dock. The MCU control signals
// of the MiSTeryNano have to be connected to both of them. This is simple for signals
// being sent out of the FPGA as these are simply connected to both MCU ports (even
// if no M0S may actually be connected at all). But for the input signals coming from
// the MCUs, the active one needs to be selected. This happens here.

// map output data onto both spi outputs
wire spi_io_dout;
wire spi_intn;

// intn and dout are outputs driven by the FPGA to the MCU
// din, ss and clk are inputs coming from the MCU

assign spi_dir = spi_io_dout;   // spi_dir has filter cap and pulldown any basically doesn't work
// assign jtag_tck = spi_io_dout;
// assign jtag_tdi = spi_intn;

// switch between internal SPI connected to the on-board bl616
// or to the external one possibly connected to a M0S Dock
wire spi_io_din = spi_dat;
wire spi_io_ss = spi_csn;
wire spi_io_clk = spi_sclk;

wire r0, b0;  // lowest color bits to be left unconnected

wire [15:0] audio [2];

misterynano misterynano (
  .clk   ( clk ),    // 27 Mhz in (e.g. for further PLLs)
  .reset ( reset ),
  .user  ( user ),

  // clock and power on reset from system
  .clk32 ( clk32 ),
  .pll_lock_main( pll_lock_32m ),
  .por   ( por ),  

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
  .io ( ),

  // mcu interface
  .mcu_sclk ( spi_io_clk  ),
  .mcu_csn  ( spi_io_ss   ),
  .mcu_miso ( spi_io_dout ), // from FPGA to MCU
  .mcu_mosi ( spi_io_din  ), // from MCU to FPGA
  .mcu_intn ( spi_intn    ),

  // MIDI
  .midi_in  ( 1'b1 ),
  .midi_out ( ),
		   
  // SD card slot
  .sd_clk ( sd_clk ),
  .sd_cmd ( sd_cmd ), // MOSI
  .sd_dat ( sd_dat ), // 0: MISO
	   
  // scandoubled digital video to be
  // used with lcds
  .lcd_clk  ( lcd_dclk ),
  .lcd_hs_n ( lcd_hs   ),
  .lcd_vs_n ( lcd_vs   ),
  .lcd_de   ( lcd_de   ),       // LCD is RGB 565
  .lcd_r    ( { lcd_r, r0 } ),  // leave lcb unconnected
  .lcd_g    ( lcd_g    ),
  .lcd_b    ( { lcd_b, b0 } ),  // -"- 

  // digital 16 bit audio output
  .audio ( audio )
);

/* ------------------- audio processing --------------- */

assign pa_en = 1'b1;   // enable amplifier

// generate 48k * 32 = 1536kHz audio clock. TODO: this is too
// imprecise
reg clk_audio;
reg [7:0] aclk_cnt;
always @(posedge clk32) begin
    if(aclk_cnt < 32000000 / 1536000 / 2 -1)
        aclk_cnt <= aclk_cnt + 8'd1;
    else begin
        aclk_cnt <= 8'd0;
        clk_audio <= ~clk_audio;
    end
end

// count 32 bits
reg [4:0] audio_bit_cnt;
always @(posedge clk_audio) begin
    if(por)
        audio_bit_cnt <= 5'd0;
    else 
        audio_bit_cnt <= audio_bit_cnt + 5'd1;
end

// generate i2s signals
assign hp_bck = clk_audio;
assign hp_ws = por?1'b0:audio_bit_cnt[4];
assign hp_din = por?1'b0:audio[hp_ws][audio_bit_cnt[3:0]];

endmodule

// To match emacs with gw_ide default
// Local Variables:
// tab-width: 4
// End:

