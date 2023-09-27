/* toplevel */

module top(
  input clk,

  input reset,
  input user,

  output reg [5:0] leds_n,

  // (m)spi flash interface
  output mspi_cs,
  output mspi_clk,
  inout  mspi_di,
  inout  mspi_hold,
  inout  mspi_wp,
  inout  mspi_do,

  output [7:0] io,

  // hdmi/tdms
  output       tmds_clk_n,
  output       tmds_clk_p,
  output [2:0] tmds_d_n,
  output [2:0] tmds_d_p
);

`define PLL pll_160m 
`define PIXEL_CLOCK 32000000

wire clk_pixel_x5;
wire clk32;
wire pll_lock;

`PLL pll_inst (
        .clkout(clk_pixel_x5), //output clkout
        .lock(pll_lock),
        .clkin(clk)
    );

Gowin_CLKDIV clk_div_5 (
        .clkout(clk32)   ,    // output clkout
        .hclkin(clk_pixel_x5), // input hclkin
        .resetn(pll_lock)      // input resetn
    );

wire clk_flash;      // 100.265 MHz SPI flash clock
wire pll_lock_flash;   
flash_pll flash_pll (
        .clkout( clk_flash ),
        .clkoutp( mspi_clk ),   // shifted by -22.5/335.5 deg
        .lock(pll_lock_flash),
        .clkin(clk)
    );

reg cs;

wire ready = pll_lock  && pll_lock_flash;

wire [15:0] flash_dout;

reg [21:0] address;
reg [31:0] counter;
always @(posedge clk32 or negedge ready) begin
    if(!ready) begin
        counter <= 32'd0;
        cs <= 1'b0;
        leds_n <= 6'b000000;
        address <= 22'h80000;
    end else begin
        counter <= counter + 32'd1;

        // trigger flash read after 1s
        cs <= 1'b0;
        if(counter == 32'd320000) begin
            cs <= 1'b1;
        end

        if(counter == 32'd3300000)
            leds_n <= ~flash_dout[5:0];

        // restart after 2 sec
        if(counter == 32'd6400000) begin
            counter <= 32'd0;
            address <= address + 22'd1;
        end
    end
end

flash flash (
    .clk(clk_flash),
    .resetn(ready),

    .address( address ),
    .cs( cs ),
    .dout( flash_dout ),

    .mspi_cs(mspi_cs),
    .mspi_di(mspi_di),
    .mspi_hold(mspi_hold),
    .mspi_wp(mspi_wp),
    .mspi_do(mspi_do)
);

endmodule
