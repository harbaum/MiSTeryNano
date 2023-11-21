/*
    osd_u8g2.v
 
    on-screen-display using a memory layout that matches the 
    one of 128x64 OLED displays and is thus supported by u8g2
  */

module osd_u8g2 (
  input        clk,
  input        reset,

  input        data_in_strobe,
  input        data_in_start,
  input [7:0]  data_in,
	    
  input        hs,
  input        vs, 
  input [5:0]  r_in,
  input [5:0]  g_in,
  input [5:0]  b_in,

  // values that can be configured by the user
  output reg [1:0] system_chipset,
  output reg system_memory,
  output reg system_video,
  output reg system_reset,

  output [5:0] r_out,
  output [5:0] g_out,
  output [5:0] b_out
);

// OSD is enabled and visible
reg enabled;

// -------------------------- OSD painting -------------------------------

reg vsD, hsD;
reg [11:0] hcnt;    // signal ranges 0..1023
reg [11:0] hcntL;
reg [9:0] vcnt;    // signal ranges 0..626
reg [9:0] vcntL;

// OSD is active on current pixel, the shadow is active or the text area is active
wire active, sactive, tactive;
   
// draw active osd, add some shadow to those parts outside osd
// that are covered by shadow
assign r_out = !enabled?r_in:active?osd_r:sactive?{1'b0, r_in[5:1]}:r_in;
assign g_out = !enabled?g_in:active?osd_g:sactive?{1'b0, g_in[5:1]}:g_in;
assign b_out = !enabled?b_in:active?osd_b:sactive?{1'b0, b_in[5:1]}:b_in;   

wire	   osd_pix;  
wire [5:0] osd_pix_col;

// background is darker where "shadow" is active
wire [5:0] osd_r = (tactive && osd_pix)?osd_pix_col:sactive?{4'b0000, r_in[5:4]}:{3'b000, r_in[5:3]};
wire [5:0] osd_g = (tactive && osd_pix)?osd_pix_col:sactive?{4'b0100, g_in[5:4]}:{3'b010, g_in[5:3]};
wire [5:0] osd_b = (tactive && osd_pix)?osd_pix_col:sactive?{4'b0000, b_in[5:4]}:{3'b000, b_in[5:3]};  
   
`define BORDER 2
`define SHADOW 4
`define SCALE  2
`define WIDTH 16   // OSD width in characters
`define HEIGHT 8   // OSD height in characters

wire [11:0] hstart = (hcntL/2)-8*`WIDTH*`SCALE/2;
wire [9:0]  vstart = (vcntL/2)-8*`HEIGHT*`SCALE/2;

// entire OSD area incl border
wire	    hactive = hcnt >= hstart-`SCALE*`BORDER && hcnt < hstart+`SCALE*`BORDER+8*`WIDTH*`SCALE;
wire	    vactive = vcnt >= vstart-`SCALE*`BORDER && vcnt < vstart+`SCALE*`BORDER+8*`HEIGHT*`SCALE;
assign      active = hactive && vactive;  

// text area of OSD
wire	    thactive = hcnt >= hstart && hcnt < hstart+8*`WIDTH*`SCALE;
wire	    tvactive = vcnt >= vstart && vcnt < vstart+8*`HEIGHT*`SCALE;
assign 	    tactive = thactive && tvactive;  

// shadow area of OSD
wire	    shactive = hcnt >= hstart-`SCALE*`BORDER+`SCALE*`SHADOW && hcnt < hstart+`SCALE*`BORDER+`SCALE*`SHADOW+8*`WIDTH*`SCALE;
wire	    svactive = vcnt >= vstart-`SCALE*`BORDER+`SCALE*`SHADOW && vcnt < vstart+`SCALE*`BORDER+`SCALE*`SHADOW+8*`HEIGHT*`SCALE;
assign	    sactive = shactive && svactive;  

// 1024 bytes = 8192 pixels = 128 x 64 pixels
reg [7:0] buffer [1024];  

// external data interface to write to buffer
reg [9:0] data_cnt;
reg [7:0] command;
reg data_addr_state;
   
always @(posedge clk) begin
    if(reset) begin
        enabled <= 1'b0;

        // OSD value defaults. These should be the same
        // as what the BL616 assumes the defaults are
        system_chipset = 2'b0;
        system_memory = 1'b0;
        system_video = 1'b0;
    end else begin

      if(data_in_strobe) begin
        if(data_in_start) begin
            command <= data_in;
            data_addr_state <= 1'b1;
            data_cnt <= 10'd0;
        end else begin
            data_addr_state <= 1'b0;

            // OSD command 1: enabled (show) or disable (hide) OSD
            if((command == 8'd1) && data_addr_state)
                enabled <= data_in[0];   // en/disable

            // OSD command 2: display data for give tile
            if(command == 8'd2) begin
                if(data_addr_state)
                    data_cnt <= { data_in[6:0], 3'b000 };
                else begin	 
                    buffer[data_cnt] <= data_in;
                    data_cnt <= data_cnt + 10'd1;
                end
            end

            // OSD command 3: config values set by user via OSD
            if(command == 8'd3) begin
                if(data_cnt == 10'd0) begin 
                    // first byte must be "S"
                    if(data_in == "S") data_cnt <= 10'd1;
                    else               command  <= 8'h00;
                end
                    
                // second byte can be any character 
                if(data_cnt == 10'd1) data_cnt <= { 2'b00, data_in };

                // Value "SC": chipset ST(0), MegaST(1) or STE(2)
                if(data_cnt == { 2'b00, "C" }) system_chipset <= data_in[1:0];
                // Value "SM": 4MB(0) or 8MB(1)
                if(data_cnt == { 2'b00, "M" }) system_memory <= data_in[0];
                // Value "SV": color(0) or monochrome(1)
                if(data_cnt == { 2'b00, "V" }) system_video <= data_in[0];
                // Value "SR": reset(1) or run(0)
                if(data_cnt == { 2'b00, "R" }) system_reset <= data_in[0];
            end
        end
      end
   end
end
   
wire [7:0] hpix  = hcnt-hstart;  // horizontal pixel position inside OSD   
wire [7:0] hpixD = hpix+1;       // latch byte one pixel in advance
wire [6:0] vpix  = vcnt-vstart;  // vertical pixel position inside OSD   

assign osd_pix = buffer_byte[vpix[3:1]];

reg [7:0] buffer_byte;
always @(posedge clk)
   buffer_byte <= buffer[{ vpix[6:4], hpixD[7:1] }];
   
assign osd_pix_col = 6'd63;

// -------------------------- video signal analysis -------------------------
   
// analyze video timing to determine center of screen

always @(posedge clk) begin
   // ---- hsync processing -----
   hsD <= hs;

   // end of hsync, rising edge
   if(hs && !hsD) begin
      hcntL <= hcnt;
      hcnt <= 0;
   end else
     hcnt <= hcnt + 12'd1;
   
   if(hs && !hsD) begin
      // ---- vsync processing -----
      vsD <= vs;
      // begin of vsync, falling edge
      if(!vs && vsD) begin
         vcntL <= vcnt;
         vcnt <= 0;
      end else
        vcnt <= vcnt + 10'd1;
   end
end
   
endmodule
