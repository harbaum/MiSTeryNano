/* top.sv - atarist on tang nano toplevel */

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
  inout [9:0]	io,
  // config inputs
  input [3:0]	cfg,

  // SD card slot
  output	   sd_clk,
  inout		   sd_cmd,   // MOSI
  inout	[3:0]  sd_dat,   // 0: MISO
	   
  // SPI connection to BL616
  // currently used for two PS2 like keyboard/mouse connections
  input        spi_sclk, // in... 
  input        spi_csn,  // in (io?)
  input        spi_dir,  // out
  input        spi_dat,  // in (io?)

  // hdmi/tdms
  output	   tmds_clk_n,
  output	   tmds_clk_p,
  output [2:0] tmds_d_n,
  output [2:0] tmds_d_p
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

    // cpu expects ROM to start at $fc0000 and it is in fact is at $100000 in
    // ST mode and at $140000 in STE mode
    .address( { 4'b0010, !cfg[3], rom_addr[17:1] } ),
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

        // allow RAM access to the entire 8MB provided by the
        // Tang Nano 20k. It's up to the ST chipset to make use
        // if this
        .refresh(refresh),
        .din(mdout),                // data input from chipset/cpu
        .dout(mdin),
        .addr(ram_a[22:1]),         // 22 bit word address
        .ds( { cash_n, casl_n } ),  // upper/lower data strobe
        .cs( !ras_n && !ram_a[23] ),// cpu/chipset requests read/write
        .we( !we_n )                // cpu/chipset requests write
);

// ST video signals to be sent through the scan doubler
wire st_hs_n, st_vs_n, st_bl_n, st_de;
wire [3:0] st_r;
wire [3:0] st_g;
wire [3:0] st_b;

wire [14:0] audio_l;
wire [14:0] audio_r;

// MOUSE_DIRECT implements the mouse as it was until incl. release 1.0.1
// Since then mouse and keyboard are implemented via an external microcontroller
// which acts as a USB host for MiSTeryNano
`ifdef MOUSE_DIRECT
// -------------------- simulate mouse from joystick signals ------------------------
reg [32:0] mouse_emu_cnt;
always @(posedge clk_32) begin
    if(!pll_lock)
        mouse_emu_cnt <= 32'd0;
    else
        mouse_emu_cnt <= mouse_emu_cnt + 32'd1;
end

wire mbit = mouse_emu_cnt[19];
wire [5:0] mjoy_joy0 = { !io[0], !io[1], !io[3] & mbit, !io[2] & mbit, !io[5] & mbit, !io[4] & mbit };

// -------------------- parse blackberry trackball signals ------------------------
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

wire [5:0] mbtb_joy0 = { !io[0], !io[1], mouse_x[1], mouse_x[0], mouse_y[1], mouse_y[0] };

// cfg[1] selects between "joystick mouse" and "blackberry trackball"
// wire [5:0] joy0 = cfg[1]?mjoy_joy0:mbtb_joy0;  // TODO: or mouse_atari into this

// joystick fire button is shared with right mouse button
// wire [4:0] joy1 = { !io[0], !io[7], !io[6], !io[9], !io[8] };
`else
`ifdef PS2
// in PS2/USB mode the joystick uses the inputs that were formerly
// used for the mouse. This may also be replaces by USB joysticks
wire [4:0] joy1 = { !io[0], !io[2], !io[1], !io[4], !io[3] };

wire [7:0] keyboard_matrix[14:0];
wire [5:0] mouse_atari;
wire [5:0] joy0 = mouse_atari;

wire [14:0] keyboard_matrix_out;
wire [7:0] keyboard_matrix_in =
	      (!keyboard_matrix_out[0]?keyboard_matrix[0]:8'hff)&
	      (!keyboard_matrix_out[1]?keyboard_matrix[1]:8'hff)&
	      (!keyboard_matrix_out[2]?keyboard_matrix[2]:8'hff)&
	      (!keyboard_matrix_out[3]?keyboard_matrix[3]:8'hff)&
	      (!keyboard_matrix_out[4]?keyboard_matrix[4]:8'hff)&
	      (!keyboard_matrix_out[5]?keyboard_matrix[5]:8'hff)&
	      (!keyboard_matrix_out[6]?keyboard_matrix[6]:8'hff)&
	      (!keyboard_matrix_out[7]?keyboard_matrix[7]:8'hff)&
	      (!keyboard_matrix_out[8]?keyboard_matrix[8]:8'hff)&
	      (!keyboard_matrix_out[9]?keyboard_matrix[9]:8'hff)&
	      (!keyboard_matrix_out[10]?keyboard_matrix[10]:8'hff)&
	      (!keyboard_matrix_out[11]?keyboard_matrix[11]:8'hff)&
	      (!keyboard_matrix_out[12]?keyboard_matrix[12]:8'hff)&
	      (!keyboard_matrix_out[13]?keyboard_matrix[13]:8'hff)&
	      (!keyboard_matrix_out[14]?keyboard_matrix[14]:8'hff);

// --------------- PS/2 decoder for mouse and keyboard -------------------

// include spi_xxx pins as they come from the internal BL616 controller
wire ps2_kbd_clk    = cfg[1]?io[6]:spi_sclk;
wire ps2_kbd_data   = cfg[1]?io[7]:spi_csn;
wire ps2_mouse_clk  = cfg[1]?io[8]:spi_dir;
wire ps2_mouse_data = cfg[1]?io[9]:spi_dat;

// ps2 state machine is supposed to run at 2 Mhz
reg [3:0] ps2_clk_cnt;
wire ps2_ena = ps2_clk_cnt == 4'd0;
always @(posedge clk_32)
    ps2_clk_cnt <= ps2_clk_cnt + 4'd1;

// filter potentially noisy ps2 clocks
reg kbd_clk, mouse_clk;
always @(posedge clk_32) begin
    reg [7:0] kbd_clk_shift;
    reg [7:0] mouse_clk_shift;

    if(ps2_ena) begin
        kbd_clk_shift <= { kbd_clk_shift[6:0], ps2_kbd_clk };
        if(kbd_clk_shift == 8'h00) kbd_clk <= 1'b0;
        if(kbd_clk_shift == 8'hff) kbd_clk <= 1'b1;

        mouse_clk_shift <= { mouse_clk_shift[6:0], ps2_mouse_clk };
        if(mouse_clk_shift == 8'h00) mouse_clk <= 1'b0;
        if(mouse_clk_shift == 8'hff) mouse_clk <= 1'b1;
    end
end

ps2 ps2 (
    .clk(clk_32),
    .ena_2m(ps2_ena),
    .reset(reset_btn || !pll_lock),
	    
    .kbd_clk(kbd_clk),
    .kbd_data(ps2_kbd_data),
    .matrix(keyboard_matrix),
	    
    .mouse_clk(mouse_clk),
    .mouse_data(ps2_mouse_data),
    .mouse_atari(mouse_atari),

    .joy_port_toggle() // F11  
);
`endif
`endif

// ----------------- SPI input parser ----------------------

wire spi_io_dout;
assign io[9:6] = { 3'bzzz, spi_io_dout };

wire spi_io_din = io[7];
wire spi_io_ss = io[8];
wire spi_io_clk = io[9];

wire       mcu_hid_strobe;
wire       mcu_osd_strobe;
wire       mcu_start;
wire [7:0] mcu_data_out;  
   
mcu_spi mcu (
        .clk(clk_32),
        .reset(!pll_lock),

        .spi_io_ss(spi_io_ss),
        .spi_io_clk(spi_io_clk),
        .spi_io_din(spi_io_din),
        .spi_io_dout(spi_io_dout),

        .mcu_hid_strobe(mcu_hid_strobe),
        .mcu_osd_strobe(mcu_osd_strobe),
        .mcu_start(mcu_start),
        .mcu_dout(mcu_data_out)
        );

// in HID mode the joystick uses the inputs that were formerly
// used for the mouse. This may also be replaced by USB joysticks
wire [4:0] joy1 = { !io[0], !io[2], !io[1], !io[4], !io[3] };

// The keyboard matrix is maintained inside HID
wire [7:0] keyboard[14:0];

wire [14:0] keyboard_matrix_out;
wire [7:0] keyboard_matrix_in =
	      (!keyboard_matrix_out[0]?keyboard[0]:8'hff)&
	      (!keyboard_matrix_out[1]?keyboard[1]:8'hff)&
	      (!keyboard_matrix_out[2]?keyboard[2]:8'hff)&
	      (!keyboard_matrix_out[3]?keyboard[3]:8'hff)&
	      (!keyboard_matrix_out[4]?keyboard[4]:8'hff)&
	      (!keyboard_matrix_out[5]?keyboard[5]:8'hff)&
	      (!keyboard_matrix_out[6]?keyboard[6]:8'hff)&
	      (!keyboard_matrix_out[7]?keyboard[7]:8'hff)&
	      (!keyboard_matrix_out[8]?keyboard[8]:8'hff)&
	      (!keyboard_matrix_out[9]?keyboard[9]:8'hff)&
	      (!keyboard_matrix_out[10]?keyboard[10]:8'hff)&
	      (!keyboard_matrix_out[11]?keyboard[11]:8'hff)&
	      (!keyboard_matrix_out[12]?keyboard[12]:8'hff)&
	      (!keyboard_matrix_out[13]?keyboard[13]:8'hff)&
	      (!keyboard_matrix_out[14]?keyboard[14]:8'hff);

wire [5:0] joy0;

// decode SPI/MCU data received for human input devices (HID) and
// convert into ST compatible mouse and keyboard signals
hid hid (
        .clk(clk_32),
        .reset(!pll_lock),

         // interface to receive user data from MCU (mouse, kbd, ...)
        .data_in_strobe(mcu_hid_strobe),
        .data_in_start(mcu_start),
        .data_in(mcu_data_out),

        .mouse(joy0),
        .keyboard(keyboard)
         );   


// signals to wire the floppy controller to the sd card
wire [1:0]  sd_rd;   // fdc requests sector read
wire [7:0]  sd_rd_data;
wire [31:0] sd_lba;  
wire [8:0]  sd_byte_index;
wire	    sd_rd_byte_strobe;
wire	    sd_busy, sd_done;
wire [31:0] sd_img_size;
wire [1:0]  sd_img_mounted;

wire reset_btn;

atarist atarist (
    .clk_32(clk_32),
    .resb(!reset_btn && pll_lock && ram_ready && flash_ready && sd_ready),       // user reset button
    .porb(pll_lock),

    // video output
    .hsync_n(st_hs_n),
    .vsync_n(st_vs_n),
    .blank_n(st_bl_n),
    .de(st_de),
    .r(st_r),
    .g(st_g),
    .b(st_b),
    .mono_detect(cfg[0]),    // mono=0, color=1

    .keyboard_matrix_out(keyboard_matrix_out),
    .keyboard_matrix_in(keyboard_matrix_in),
	.joy0( joy0 ),
	.joy1( joy1 ),

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

    .ste(!cfg[3]),                 // enable STE mode if cfg[3] is tied to GND
    .enable_extra_ram(!cfg[2]),    // enable extra ram if cfg[2] is tied to gnd

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

wire [7:0] osd_dir_row;
wire [3:0] osd_dir_col;
wire [7:0] osd_dir_chr;
wire [5:0] osd_dir_len;
wire [7:0] osd_file;
wire osd_file_selected;

video video (
	     .clk(clk),
	     .clk_32(clk_32),
	     .pll_lock(pll_lock_hdmi),

         // interface to show directory on OSD
         .osd_btn_in({user,reset}),
         .osd_btn_out(reset_btn),
         .osd_dir_row(osd_dir_row),
         .osd_dir_col(osd_dir_col),
         .osd_dir_chr(osd_dir_chr),
         .osd_dir_len(osd_dir_len),
         .osd_file_selected(osd_file_selected),
         .osd_file(osd_file),

         .mcu_start(mcu_start),
         .mcu_osd_strobe(mcu_osd_strobe),
         .mcu_data(mcu_data_out),
	 
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

// card_stat == 8 means card is initialized. Wait up to 2 seconds for this before
// booting the ST
reg [31:0] sd_wait;
reg sd_ready;
always @(posedge clk_32) begin
    if(!pll_lock) begin
        sd_wait <= 32'd0;
        sd_ready <= 1'b0;
    end else begin
        if(!sd_ready) begin
            // ready once card stat reaches 8
            if(sd_card_stat == 4'd8)
                sd_ready <= 1'b1;

            // or after 2 seconds
            if(sd_wait < 32'd64000000)
                sd_wait <= sd_wait + 32'd1;
            else
                sd_ready <= 1'b1;
        end
    end
end

wire [3:0] sd_card_stat;
wire [1:0] sd_card_type;

sd_fat_reader #(
    .CLK_DIV(3'd1)                    // for 32 Mhz clock
) sd_fat_reader (
    .rstn(pll_lock),                  // rstn active-low, 1:working, 0:reset
    .clk(clk_32),                     // clock

    .dir_entries_used(osd_dir_len),
    .dir_row(osd_dir_row),
    .dir_col(osd_dir_col),
    .dir_chr(osd_dir_chr),
    .file_index(osd_file),
    .file_selected(osd_file_selected),

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
