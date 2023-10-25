/*
    osd_ascii.v
 
    ASCII text mode on-screen-display for MiSTeryNano. This works unlike 
    the graphic OSD which is entirely controlled via SPI from the IO controller.
 
    This instead also includes the basic button handling, the selection of 
    entries and the like.
 */

module osd_ascii 
 (
  input	       clk,
  input     reset,

  // directory listing interface
  input [1:0]  btn_in,
  output       btn_out,
  output [7:0] dir_row,         // current row to be displayed
  output [3:0] dir_col,         // current column to be displayed
  input [7:0]  dir_chr,
  input [5:0]  dir_len,         // up to 32 entries 
  output       file_selected,
  output reg [7:0] file_index,

  input	       hs,
  input	       vs, 
  input [5:0]  r_in,
  input [5:0]  g_in,
  input [5:0]  b_in,
  
  output [5:0] r_out,
  output [5:0] g_out,
  output [5:0] b_out
);

// OSD is enabled and visible
reg enabled;

// ---------------------- button handling ------------------------------

// debounce buttons
reg [31:0] btn_cnt [2];
wire [1:0] btn;
wire [1:0] lbtn;   // long press (1 sec)

// each button press gives one event once the button is
// stable for 1ms
assign btn[0] = btn_cnt[0] == 32'd32000;
assign btn[1] = btn_cnt[1] == 32'd32000;
assign lbtn[0] = btn_cnt[0] == 32'd32000000;
assign lbtn[1] = btn_cnt[1] == 32'd32000000;

always @(posedge clk) begin
    if(reset) begin
        btn_cnt[0] <= 32'd0;
        btn_cnt[1] <= 32'd0;
    end else begin

        if(!btn_in[0]) 
            btn_cnt[0] <= 32'd0;
        else if(!(&btn_cnt[0]))
            btn_cnt[0] <= btn_cnt[0] + 32'd1;

        if(!btn_in[1]) 
            btn_cnt[1] <= 32'd0;
        else if(!(&btn_cnt[1]))
            btn_cnt[1] <= btn_cnt[1] + 32'd1;
    end
end

// Button 0 may be used to select and file and thus close the OSD.
// Block btn_out until the button has been released. Otherwise the
// machine would immedietaly be reset after a file selection.
reg [31:0] btn0_block;

always @(posedge clk) begin
    if(reset)
        btn0_block <= 32'd0;
    else begin
        if(btn_in[0] && enabled)                  // start blocking button 0 if it's pressed while the OSD is enabled
            btn0_block <= 32'd8000000;
        else if(btn_in[0] && btn0_block != 32'd0) // keep blocking it while btn is pressed
            btn0_block <= 32'd8000000;            
        else if(btn0_block > 32'd0)               // keep blocking for at least 1/4 sec
            btn0_block <= btn0_block - 32'd1;
    end
end

// return button 0 (reset) while the OSD is invisible and while it's not blocked
assign btn_out = (enabled || (btn0_block != 32'd0))?1'b0:btn_in[0];

// -------------------------- OSD painting -------------------------------

reg vsD, hsD;
reg [11:0] hcnt;    // signal ranges 0..1023
reg [11:0] hcntL;
reg [9:0] vcnt;    // signal ranges 0..626
reg [9:0] vcntL;

wire [7:0] title [16];
//              0123456789abcdef
assign title = ">>> DRIVE A: <<<"; 
   
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

// row and column
wire [11:0] pcol = hcnt - hstart;
wire [9:0]  prow = vcnt - vstart;
assign dir_col = pcol[7:4] + 4'd1;  

// file_index is the index of the currently selected directory row
// first is the index of the first directory row currently being displayed
wire [7:0] first = (file_index <= 8'd3 || dir_len < 8'd8)?8'd0:
                   (file_index > (dir_len-8'd4))?(dir_len-8'd7):
                   (file_index - 8'd3);

assign dir_row = first + {5'd0,  prow[6:4] - 3'd1};  

wire [7:0] dout;  
   
reg [7:0] cbyte;
   
assign	  osd_pix     = ~{3{|prow[6:4]}} ^ cbyte[7];  // invert top line
assign	  osd_pix_col = (dir_row==file_index)?6'd63:6'd48;  

assign file_selected = enabled && btn[0];

always @(posedge clk) begin
    if(reset) begin
        enabled <= 1'b0;
        file_index <= 8'd0;
    end else begin
        // long press on button[1] or short
        // press of button[0] (file selected) closes OSD
        if((lbtn[1] || btn[0]) && enabled)
            enabled <= 1'b0;

        if(btn[1]) begin
            // button[1] opens the OSD if it's not open
            if(!enabled) begin
                enabled <= 1'b1;
                file_index <= 8'd0;
            end else begin
                // otherwise it advances the selection
                if(file_index < dir_len-1)
                    file_index <= file_index + 8'd1;
                else
                    file_index <= 8'd0;
            end
        end
    end
end

wire [7:0] content_chr = (dir_row < dir_len)?dir_chr:" ";

// top line is title, other lines contain data received from sd_fat_reader   
wire [7:0] chr = (prow[6:4] == 3'd0)?title[dir_col]:content_chr;
   
always @(posedge clk)
  if(pcol[3:0] == 4'hf)  // latch one pixel before output starts
    cbyte <= dout;
  else if(pcol[0])
    cbyte <= {cbyte[6:0], 1'b0};   
   
`ifdef VERILATOR
font_8x8_fnt font_8x8_fnt (
  .clk(clk),
  .addr( { chr, prow[3:1] }),
  .dout(dout)
);  
`else
font_8x8_fnt font_8x8_fnt (
  .clk(clk),
  .reset(reset),
  .oce(1'b1),
  .ce(1'b1),
  .ad( { chr, prow[3:1] }),
  .dout(dout)
);  
`endif

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
