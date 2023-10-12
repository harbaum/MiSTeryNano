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

  output [5:0] 	   osd_dir_entries_used,
  input [7:0] 	   osd_dir_row,
  input [3:0] 	   osd_dir_col,
  output [7:0] 	   osd_dir_chr,
  input 	   osd_file_selected,
  input [7:0] 	   osd_file_index,
   
  // interface to read data for fake sd card		 
  output 	   rdreq,
  output [39:0]    rdaddr,
  input [15:0] 	   rddata
);

reg [1:0] cnt_8mhz;  
always @(posedge clk)
  cnt_8mhz <= cnt_8mhz + 2'd1; 

assign clk8m_en = cnt_8mhz == 2'd0;

wire	  sd_rd;   // fdc requests sector read
wire [7:0] sd_rd_data;
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
 .img_wp(1'b1),         // write protect
 .img_ds(1'd0),         // double-sided image (for BBC Micro only)
 .img_size(32'd737280), // size of image in bytes

 .sd_lba(sd_lba),
 .sd_rd(sd_rd),
 .sd_wr(),
 .sd_ack(sd_busy),
 .sd_buff_addr(sd_byte_index),
 .sd_dout(sd_rd_data),
 .sd_din(),
 .sd_dout_strobe(sd_rd_byte_strobe)
);
   
wire	 sdclk, sdcmd, sdcmd_in, sddat0;  
wire [3:0] sddat;

assign sddat0 = sddat[0];
 
	 
sd_fake sd_fake 
(
 .rstn_async(reset),
 .sdclk(sdclk),
 .sdcmd(sdcmd),
 .sdcmd_out(sdcmd_in),
 .sddat( sddat ),

 .rdreq(rdreq),
 .rdaddr(rdaddr),
 .rddata(rddata)
 );

sd_fat_reader #(
    .CLK_DIV(3'd1),                    // for 32 Mhz clock
    .SIMULATE(1'b1)
) sd_fat_reader (
    .rstn(reset),                  // rstn active-low, 1:working, 0:reset
    .clk(clk),                     // clock

    // output directory listing for display in OSD
    .dir_entries_used(osd_dir_entries_used),
    .dir_row(osd_dir_row),
    .dir_col(osd_dir_col),
    .dir_chr(osd_dir_chr),
    .file_selected(osd_file_selected),
    .file_index(osd_file_index),

    // SD card signals
    .sdclk(sdclk),
    .sdcmd(sdcmd),
    .sdcmd_in(sdcmd_in),
    .sddat0(sddat0),

    // show card status
    .card_stat(),         // show the sdcard initialize status
    .card_type(),         // 0=UNKNOWN    , 1=SDv1    , 2=SDv2  , 3=SDHCv2
    // user read sector command interface (sync with clk)
    .rstart(sd_rd), 
    .rsector(sd_lba),
    .rbusy(sd_busy),
    .rdone(sd_done),
    // sector data output interface (sync with clk)
    .outen(sd_rd_byte_strobe), // when outen=1, a byte of sector content is read out from outbyte
    .outaddr(sd_byte_index),   // outaddr from 0 to 511, because the sector size is 512
    .outbyte(sd_rd_data)       // a byte of sector content
);

endmodule



