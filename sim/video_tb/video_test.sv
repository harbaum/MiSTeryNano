/* top.sv - atarist on tang nano toplevel */

// load image into board:
// openFPGALoader --external-flash -o 2097152 mono32k.bin
  
// the to 0 for pal
`define VIDEO_NTSC  1'b1

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

  input       sd_clk,
  input       sd_cmd,
  input [3:0] sd_dat,

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

  input [7:0] io,
  input [3:0] cfg,

  // hdmi/tdms
  output       tmds_clk_n,
  output       tmds_clk_p,
  output [2:0] tmds_d_n,
  output [2:0] tmds_d_p
);

`define PLL pll_160m 
`define PIXEL_CLOCK 32000000

wire [2:0] tmds;
wire tmds_clock;

wire clk_pixel;
wire clk_pixel_x5;
wire clk32 = clk_pixel;   // at 800x576@50Hz the pixel clock is 32MHz

wire flash_pll_lock, main_pll_lock;
wire pll_lock = flash_pll_lock && main_pll_lock;

wire flash_clk;
flash_pll flash_pll (
        .clkout( flash_clk ),       // 104 MHz
        .clkoutp( /*mspi_clk*/ ),   // -22.5/+337.5 deg
        .lock(flash_pll_lock),
        .clkin(clk)
    );

// run spi chip and spi state machine in the same clock
assign mspi_clk = flash_clk;

`PLL pll_inst (
        .clkout(clk_pixel_x5), //output clkout
        .lock(main_pll_lock),
        .clkin(clk)
    );

Gowin_CLKDIV clk_div_5 (
        .clkout(clk_pixel),    // output clkout
        .hclkin(clk_pixel_x5), // input hclkin
        .resetn(pll_lock)      // input resetn
    );

// generate 48khz audio clock
reg clk_audio;
reg [8:0] aclk_cnt;
always @(posedge clk_pixel) begin
    // divisor = pixel clock / 48000 / 2 - 1
    if(aclk_cnt < `PIXEL_CLOCK / 48000 / 2 -1)
        aclk_cnt <= aclk_cnt + 9'd1;
    else begin
        aclk_cnt <= 9'd0;
        clk_audio <= ~clk_audio;
    end
end

/* -------------------- HDMI video and audio -------------------- */

// differential output
ELVDS_OBUF tmds_bufds [3:0] (
        .I({tmds_clock, tmds}),
        .O({tmds_clk_p, tmds_d_p}),
        .OB({tmds_clk_n, tmds_d_n})
);

logic vsync_n, hsync_n;
logic vreset;
logic [1:0] vmode;

wire [5:0] r;  // from scan doubler with dim'd lines
wire [5:0] g;
wire [5:0] b;

hdmi #(
    .AUDIO_RATE(48000), .AUDIO_BIT_WIDTH(16),
    .VENDOR_NAME( { "MiSTle", 16'd0} ),
    .PRODUCT_DESCRIPTION( {"Atari ST", 64'd0} )
) hdmi(
  .clk_pixel_x5(clk_pixel_x5),
  .clk_pixel(clk_pixel),
  .clk_audio(clk_audio),
  .audio_sample_word( {  16'h00, 16'h00 } ),
  .tmds(tmds),
  .tmds_clock(tmds_clock),

  // video input
  .stmode(vmode),    // st video mode detected
  .reset(vreset),    // signal to synchronize HDMI

  // Atari STE outputs 4 bits per color. Scandoubler outputs 6 bits (to be
  // able to implement dark scanlines) and HDMI expects 8 bits per color
  .rgb( { r, 2'b00, g, 2'b00, b, 2'b00 } )
);

ste_tb ste_tb (
    .clk32(clk_pixel),
    .resb(!reset && pll_lock),       // user reset button
    .porb(pll_lock),
    .BR_N(1'b1),
    .FC0(1'b0),
    .FC1(1'b1),
    .FC2(1'b1),
    .VMA_N(1'b1),
    .MFPINT_N(1'b1),

    .HSYNC_N(hsync_n),
    .VSYNC_N(vsync_n),
    .BLANK_N(),

    .mono_detect(1'b0),   // 0 for monochrome
    .ntsc(user),          // request ntsc/pal signal
    .vmode(vmode),
    .vreset(vreset),

    .R(r),
    .G(g),
    .B(b),

    .sd_clk(O_sdram_clk),
    .sd_cke(O_sdram_cke),
    .sd_data(IO_sdram_dq),
    .sd_addr(O_sdram_addr),
    .sd_dqm(O_sdram_dqm),
    .sd_ba(O_sdram_ba),
    .sd_cs(O_sdram_cs_n),
    .sd_we(O_sdram_wen_n),
    .sd_ras(O_sdram_ras_n),
    .sd_cas(O_sdram_cas_n),

    .flash_clk(flash_clk),
    .mspi_cs(mspi_cs),
    .mspi_di(mspi_di),
    .mspi_hold(mspi_hold),
    .mspi_wp(mspi_wp),
    .mspi_do(mspi_do),    

    .led(led),

    .mdin (16'h0000)
  );

endmodule
