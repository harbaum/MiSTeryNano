/* top.sv - atarist on tang nano toplevel */

`define BLACKBERRY_TRACKBALL
// `define JOYSTICK_MOUSE

module top(
  input		clk,

  input		reset,
  input		user,

  output [5:0]	leds_n,

  // spi flash interface
  output	mspi_cs,
  output	mspi_clk,
  inout		mspi_di,
  inout		mspi_hold,
  inout		mspi_wp,
  inout		mspi_do,

  // "Magic" port names that the gowin compiler connects to the on-chip SDRAM
  output	O_sdram_clk,
  output	O_sdram_cke,
  output	O_sdram_cs_n, // chip select
  output	O_sdram_cas_n, // columns address select
  output	O_sdram_ras_n, // row address select
  output	O_sdram_wen_n, // write enable
  inout [31:0]	IO_sdram_dq, // 32 bit bidirectional data bus
  output [10:0]	O_sdram_addr, // 11 bit multiplexed address bus
  output [1:0]	O_sdram_ba, // two banks
  output [3:0]	O_sdram_dqm, // 32/4

  // generic IO, used for mouse/joystick/...
  input [7:0]	io,

  // SD card slot
  output	  sd_clk,
  inout		  sd_cmd,   // MOSI
  inout	[3:0] sd_dat,   // 0: MISO
	   
  // hdmi/tdms
  output	tmds_clk_n,
  output	tmds_clk_p,
  output [2:0]	tmds_d_n,
  output [2:0]	tmds_d_p
);

wire [5:0] leds;      // control leds with positive logic
assign leds_n = ~leds;

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
wire [23:1] rom_addr;
wire [15:0] rom_dout;

wire flash_ready;

flash flash (
    .clk(clk_flash),
    .resetn(pll_lock),
    .ready(flash_ready),
    .busy(),

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

wire ras_n, cash_n, casl_n;
wire [23:1] ram_a;
wire we_n;
wire [15:0] mdout;   // out to ram
wire [15:0] mdin;    // in from ram

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

wire [14:0] audio_l;
wire [14:0] audio_r;

`ifdef JOYSTICK_MOUSE
// -------------------- simulate mouse from joystick signals ------------------------
reg [32:0] mouse_emu_cnt;
always @(posedge clk_32) begin
    if(!pll_lock)
        mouse_emu_cnt <= 32'd0;
    else
        mouse_emu_cnt <= mouse_emu_cnt + 32'd1;
end

wire mbit = mouse_emu_cnt[19];
wire [5:0] joy0 = { !io[0], !io[1], !io[3] & mbit, !io[2] & mbit, !io[5] & mbit, !io[4] & mbit };
`endif

`ifdef BLACKBERRY_TRACKBALL
reg [7:0] ioD;

reg [1:0] mouse_x;
reg [1:0] mouse_y;

always @(posedge clk_32) begin
    ioD <= { ioD[6], io[2], ioD[4], io[3], ioD[2], io[4], ioD[0], io[5] };

    if(ioD[7] != ioD[6])  mouse_x <= { !mouse_x[0],  mouse_x[1] };
    if(ioD[5] != ioD[4])  mouse_x <= {  mouse_x[0], !mouse_x[1] };

    if(ioD[3] != ioD[2])  mouse_y <= { !mouse_y[0],  mouse_y[1] };
    if(ioD[1] != ioD[0])  mouse_y <= {  mouse_y[0], !mouse_y[1] };
end

wire [5:0] joy0 = { !io[0], !io[1], mouse_x[1], mouse_x[0], mouse_y[1], mouse_y[0] };
`endif

wire [1:0]  sd_rd;   // fdc requests sector read
wire [7:0]  sd_rd_data;
wire [31:0] sd_lba;  
wire [8:0]  sd_byte_index;
wire	    sd_rd_byte_strobe;
wire	    sd_busy, sd_done;
wire [31:0] sd_img_size;
wire [1:0]  sd_img_mounted;

atarist atarist (
    .clk_32(clk_32),
    .resb(!reset && pll_lock && ram_ready && flash_ready),       // user reset button
    .porb(pll_lock),

    // video output
    .hsync_n(st_hs_n),
    .vsync_n(st_vs_n),
    .blank_n(st_bl_n),
    .de(st_de),
    .r(st_r),
    .g(st_g),
    .b(st_b),
    .monomode(),

    .keyboard_matrix_out(),
    .keyboard_matrix_in(8'hff),
	.joy0( joy0  ),
	.joy1( 5'h00 ),

    // Sound output
    .audio_mix_l( audio_l ),
    .audio_mix_r( audio_r ),

    // MIDI UART
    .midi_rx(1'b0),
    .midi_tx(),

    // floppy sd card interface
    .sd_img_mounted ( sd_img_mounted ),
    .sd_img_size    ( sd_img_size ),
	.sd_lba         ( sd_lba ),
	.sd_rd          ( sd_rd ),
	.sd_wr          (),
	.sd_ack         ( sd_busy ),
	.sd_buff_addr   ( sd_byte_index ),
	.sd_dout        ( sd_rd_data ),
	.sd_din         (),
    .sd_dout_strobe ( sd_rd_byte_strobe ),

    // interface to ROM
    .rom_n(rom_n),
    .rom_addr(rom_addr),
    .rom_data_out(rom_dout),

    // interface to sdram
    .ram_ras_n(ras_n),
    .ram_cash_n(cash_n),
    .ram_casl_n(casl_n),
    .ram_ref(refresh),
    .ram_addr(ram_a),
    .ram_we_n(we_n),
    .ram_data_in(mdout),
    .ram_data_out(mdin),

    .leds(leds[1:0])
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

         // sign expand audio to 16 bit
         .audio_l( { audio_l[14], audio_l } ),
         .audio_r( { audio_r[14], audio_r } ),

	     .tmds_clk_n(tmds_clk_n),
	     .tmds_clk_p(tmds_clk_p),
	     .tmds_d_n(tmds_d_n),
	     .tmds_d_p(tmds_d_p)
	     );
   
// -------------------------- SD card -------------------------------

assign leds[5:2] = sd_card_stat;

assign sd_dat = 4'b111z;   // drive unused data lines high and configure dat[0] for input

wire [3:0] sd_card_stat;
wire [1:0] sd_card_type;

sd_fat_reader #(
    .CLK_DIV(3'd1)                    // for 32 Mhz clock
) sd_fat_reader (
    .rstn(pll_lock),                  // rstn active-low, 1:working, 0:reset
    .clk(clk_32),                     // clock

    // SD card signals
    .sdclk(sd_clk),
    .sdcmd(sd_cmd),
    .sddat0(sd_dat[0]),

    // show card status
    .card_stat(sd_card_stat),         // show the sdcard initialize status
    .card_type(sd_card_type),         // 0=UNKNOWN    , 1=SDv1    , 2=SDv2  , 3=SDHCv2

    .file_len(sd_img_size),           // length of image file
    .file_ready(sd_img_mounted),

    // user read sector command interface (sync with clk)
    .rstart(sd_rd[0]), 
    .rsector(sd_lba),
    .rbusy(sd_busy),
    .rdone(sd_done),
    // sector data output interface (sync with clk)
    .outen(sd_rd_byte_strobe), // when outen=1, a byte of sector content is read out from outbyte
    .outaddr(sd_byte_index),   // outaddr from 0 to 511, because the sector size is 512
    .outbyte(sd_rd_data)       // a byte of sector content
);

endmodule
