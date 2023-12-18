module floppy_tb(
  input 	   clk,
  input 	   reset,
  output 	   clk8m_en,

  // fdc interface		 
  input [1:0] 	   cpu_addr,
  input 	   cpu_sel,
  input 	   cpu_rw,
  input [7:0] 	   cpu_din,
  output reg [7:0] cpu_dout,

  output 	   irq,
  output 	   drq,
		   
  input 	   mcu_strobe, // byte strobe for sc card target  
  input 	   mcu_start,
  input [7:0] 	   mcu_dout,
  output [7:0] 	   mcu_din,

  output 	   sdclk,
  output 	   sdcmd,
  input 	   sdcmd_in,
  output [3:0] 	   sddat,
  input [3:0] 	   sddat_in
);

reg [1:0] cnt_8mhz;  
always @(posedge clk)
  cnt_8mhz <= cnt_8mhz + 2'd1; 

assign clk8m_en = cnt_8mhz == 2'd0;

wire	  sd_rd;   // fdc requests sector read
wire	  sd_wr;   // fdc requests sector write
wire [7:0] sd_rd_data;
wire [7:0] sd_wr_data;
wire [31:0] sd_lba;  
wire [8:0] sd_byte_index;
wire	   sd_rd_byte_strobe;
wire	   sd_busy, sd_done; 
  
fdc1772 #( .FD_NUM(1'b1) ) fdc1772 
(
 .clkcpu(clk), // system cpu clock.
 .clk8m_en(cnt_8mhz == 2'd2),

 // external set signals
 .floppy_drive(1'b0),
 .floppy_side(1'b1), 
 .floppy_reset(reset),
 .floppy_step(),
 .floppy_motor(1'b1),   // not used in ST
 .floppy_ready(),
 
 // interrupts
 .irq(irq),
 .drq(drq), // data request
 
 .cpu_addr(cpu_addr),
 .cpu_sel(cpu_sel),
 .cpu_rw(cpu_rw),
 .cpu_din(cpu_din),
 .cpu_dout(cpu_dout),
 
 // place any signals that need to be passed up to the top after here.
 .img_type(3'd1),       // atari st
 .img_mounted(1'b1),    // signaling that new image has been mounted
 .img_wp(1'b0),         // write protect
 .img_ds(1'd0),         // double-sided image (for BBC Micro only)
 .img_size(32'd737280), // size of image in bytes

 .sd_lba(sd_lba),
 .sd_rd(sd_rd),
 .sd_wr(sd_wr),
 .sd_ack(sd_busy),
 .sd_buff_addr(sd_byte_index),
 .sd_dout(sd_rd_data),
 .sd_din(sd_wr_data),
 .sd_dout_strobe(sd_rd_byte_strobe)
);
   
sd_card #(
    .CLK_DIV(3'd1),                    // for 32 Mhz clock
    .SIMULATE(1'b1)
) sd_card (
    .rstn(reset),                  // rstn active-low, 1:working, 0:reset
    .clk(clk),                     // clock

    // SD card signals
    .sdclk(sdclk),
    .sdcmd(sdcmd),
    .sdcmd_in(sdcmd_in),
    .sddat(sddat),
    .sddat_in(sddat_in),

    // MCU interface
    .data_strobe(mcu_strobe), // byte strobe for sc card target  
    .data_start(mcu_start),
    .data_in(mcu_dout),
    .data_out(mcu_din),

    .image_mounted(),
    .image_size(),
	   
    // user read sector command interface (sync with clk)
    .rstart({1'b0,sd_rd}), 
    .wstart({1'b0,sd_wr}), 
    .rsector(sd_lba),
    .rbusy(sd_busy),
    .rdone(sd_done),
		 
    // sector data output interface (sync with clk)
    .inbyte(sd_wr_data),
    .outen(sd_rd_byte_strobe), // when outen=1, a byte of sector content is read out from outbyte
    .outaddr(sd_byte_index),   // outaddr from 0 to 511, because the sector size is 512
    .outbyte(sd_rd_data)       // a byte of sector content
);

endmodule



