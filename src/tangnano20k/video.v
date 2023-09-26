// video.v

module video (
	      input 	   clk,
	      
	      output 	   clk_32,
	      output 	   pll_lock,

	      input 	   vs_in_n,
	      input 	   hs_in_n,
	      input 	   de_in,
	      input [3:0]  r_in,
	      input [3:0]  g_in,
	      input [3:0]  b_in,

          input [15:0] audio_l,
          input [15:0] audio_r,

	      // hdmi/tdms
	      output 	   tmds_clk_n,
	      output 	   tmds_clk_p,
	      output [2:0] tmds_d_n,
	      output [2:0] tmds_d_p  
	      );
   
wire clk_pixel_x5;   // 160 MHz HDMI clock
wire clk_pixel;      // at 800x576@50Hz the pixel clock is 32 MHz

assign clk_32 = clk_pixel;
    
`define PIXEL_CLOCK 32000000
pll_160m pll_hdmi (
               .clkout(clk_pixel_x5),
               .lock(pll_lock),
               .clkin(clk)
	       );
   
Gowin_CLKDIV clk_div_5 (
        .hclkin(clk_pixel_x5), // input hclkin
        .resetn(pll_lock),     // input resetn
        .clkout(clk_pixel)     // output clkout
    );


/* -------------------- HDMI video and audio -------------------- */

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

wire vreset;

video_analyzer video_analyzer (
   .clk(clk_pixel),
   .vs(vs_in_n),
   .hs(hs_in_n),
   .de(de_in),

   .vreset(vreset)  // reset signal
);  

wire sd_hs_n, sd_vs_n; 
wire [5:0] sd_r;
wire [5:0] sd_g;
wire [5:0] sd_b;
  
scandoubler #(10) scandoubler (
        // system interface
        .clk_sys(clk_pixel),
        .bypass(1'b0),
        .ce_divider(1'b1),   // /2
        .pixel_ena(),

        // scanlines (00-none 01-25% 10-50% 11-75%)
        .scanlines(2'b00),

        // shifter video interface
        .hs_in(hs_in_n),
        .vs_in(vs_in_n),
        .r_in( r_in ),
        .g_in( g_in ),
        .b_in( b_in ),

        // output interface
        .hs_out(sd_hs_n),
        .vs_out(sd_vs_n),
        .r_out(sd_r),
        .g_out(sd_g),
        .b_out(sd_b)
);

wire [2:0] tmds;
wire tmds_clock;

hdmi #( .VIDEO_ID_CODE(17), .VIDEO_REFRESH_RATE(50),
    .AUDIO_RATE(48000), .AUDIO_BIT_WIDTH(16),
    .VENDOR_NAME( { "MiSTle", 16'd0} ),
    .PRODUCT_DESCRIPTION( {"Atari ST", 64'd0} )
) hdmi(
  .clk_pixel_x5(clk_pixel_x5),
  .clk_pixel(clk_pixel),
  .clk_audio(clk_audio),
  .audio_sample_word( { audio_l, audio_r } ),
  .tmds(tmds),
  .tmds_clock(tmds_clock),

  // video input
  .reset(vreset),    // signal to synchronize HDMI

  // Atari STE outputs 4 bits per color. Scandoubler outputs 6 bits (to be
  // able to implement dark scanlines) and HDMI expects 8 bits per color
  .rgb( { sd_r, 2'b00, sd_g, 2'b00, sd_b, 2'b00 } )
);

// differential output
ELVDS_OBUF tmds_bufds [3:0] (
        .I({tmds_clock, tmds}),
        .O({tmds_clk_p, tmds_d_p}),
        .OB({tmds_clk_n, tmds_d_n})
);

endmodule
