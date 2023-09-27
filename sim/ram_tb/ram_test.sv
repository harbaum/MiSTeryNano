/* ram_test.sv - atarist ram test on tang nano toplevel */

module top(
  input clk,

  input reset,
  input user,

  output [5:0] leds_n,

  // (m)spi flash interface
  output mspi_cs,
  output mspi_clk,
  inout  mspi_di,
  inout  mspi_hold,
  inout  mspi_wp,
  inout  mspi_do,

  // "Magic" port names that the gowin compiler connects to the on-chip SDRAM
  output O_sdram_clk,
  output O_sdram_cke,
  output O_sdram_cs_n,            // chip select
  output O_sdram_cas_n,           // columns address select
  output O_sdram_ras_n,           // row address select
  output O_sdram_wen_n,           // write enable
  inout [31:0] IO_sdram_dq,       // 32 bit bidirectional data bus
  output [10:0] O_sdram_addr,     // 11 bit multiplexed address bus
  output [1:0] O_sdram_ba,        // two banks
  output [3:0] O_sdram_dqm,       // 32/4

  input [7:0]   io,

  // SD card slot
  output          sd_clk,
  inout           sd_cmd,   // MOSI
  inout [3:0] sd_dat,   // 0: MISO          

  // hdmi/tdms
  output       tmds_clk_n,
  output       tmds_clk_p,
  output [2:0] tmds_d_n,
  output [2:0] tmds_d_p
);

wire sys_resetn;

wire clk_32;
wire pll_lock_hdmi;

wire pll_lock = pll_lock_hdmi && pll_lock_flash;

/* -------------------- flash -------------------- */
   
wire clk_flash;      // 100.265 MHz SPI flash clock
wire pll_lock_flash;   
flash_pll flash_pll (
        .clkout( clk_flash ),
        .clkoutp( mspi_clk ),   // shifted by -22.5/335.5 deg
        .lock(pll_lock_flash),
        .clkin(clk)
    );

wire rom_n;
wire [23:0] rom_addr;
wire [15:0] rom_dout;

assign leds_n = ~rom_addr[6:1];

wire flash_ready;

flash flash (
    .clk(clk_flash),
    .resetn(pll_lock),
    .ready(flash_ready),

    // cpu expects ROM to start at fc0000 and it in fact is at 100000
    .address( { 5'b00100, rom_addr[17:1] } ),
    .cs( !rom_n ),
    .dout(rom_dout),

    .mspi_cs(mspi_cs),
    .mspi_di(mspi_di),
    .mspi_hold(mspi_hold),
    .mspi_wp(mspi_wp),
    .mspi_do(mspi_do)
);

/* -------------------- RAM -------------------- */

wire ras0_n, ras1_n;
wire cas0h_n, cas0l_n, cas1h_n, cas1l_n;
wire [23:1] ram_a;
wire we_n;
wire [15:0] mdout;   // out to ram
wire [15:0] mdin;    // in from ram

wire ras_n = ras0_n & ras1_n;
wire cash_n = cas0h_n & cas1h_n;
wire casl_n = cas0l_n & cas1l_n;

wire ram_ready;
wire refresh;
   
sdram sdram (
        .clk(clk_32),
        .reset_n(pll_lock),
        .ready(ram_ready),          // ram is done initialzing

        // interface to sdram chip
        .sd_clk(O_sdram_clk),      // clock
        .sd_cke(O_sdram_cke),      // clock enable
        .sd_data(IO_sdram_dq),     // 32 bit bidirectional data bus
        .sd_addr(O_sdram_addr),    // 11 bit multiplexed address bus
        .sd_dqm(O_sdram_dqm),      // two byte masks
        .sd_ba(O_sdram_ba),        // two banks
        .sd_cs(O_sdram_cs_n),      // a single chip select
        .sd_we(O_sdram_wen_n),     // write enable
        .sd_ras(O_sdram_ras_n),    // row address select
        .sd_cas(O_sdram_cas_n),    // columns address select

        .refresh(refresh),
        .din(mdout),                // data input from chipset/cpu
        .dout(mdin),
        .addr(ram_a[22:1]),         // 22 bit word address
        .ds( { cash_n, casl_n } ),  // upper/lower data strobe
        .cs( !ras_n ),              // cpu/chipset requests read/write
        .we( !we_n )                // cpu/chipset requests write
);

// ST video signals to be sent through the scan doubler
wire st_hs_n, st_vs_n, st_bl_n, st_de;
wire [3:0] st_r;
wire [3:0] st_g;
wire [3:0] st_b;

ste_tb ste_tb (
    .clk32(clk_32),
    .resb(!reset && pll_lock && ram_ready && flash_ready),       // user reset button
    .porb(pll_lock),

    .HSYNC_N(st_hs_n),
    .VSYNC_N(st_vs_n),
    .BLANK_N(st_bl_n),
    .DE(st_de),
    .R(st_r),
    .G(st_g),
    .B(st_b),

    // interface to ROM
    .ROM2_N(rom_n),
    .A(rom_addr),
    .ROM_DOUT(rom_dout),

    // interface to sdram
    .RAS0_N(ras0_n),
    .RAS1_N(ras1_n),
    .CAS0H_N(cas0h_n),
    .CAS0L_N(cas0l_n),
    .CAS1H_N(cas1h_n),
    .CAS1L_N(cas1l_n),
    .REF(refresh),
    .ram_a(ram_a),
    .we_n(we_n),
    .mdout(mdout),
    .mdin(mdin),

    .tos192k(1'b1),
    .turbo(1'b0)
  );

video video (
	     .clk(clk),
	     .clk_32(clk_32),
	     .pll_lock(pll_lock_hdmi),
	 
	     .hs_in_n(st_hs_n),
	     .vs_in_n(st_vs_n),
	     .de_in(st_de),
	     .r_in(st_r),
	     .g_in(st_g),
	     .b_in(st_b),
	     
	     .tmds_clk_n(tmds_clk_n),
	     .tmds_clk_p(tmds_clk_p),
	     .tmds_d_n(tmds_d_n),
	     .tmds_d_p(tmds_d_p)
	     );
   
   
endmodule
