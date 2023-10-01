// ====================================================================
//
// gstmcu/shifter testbench
//
//============================================================================

module ste_tb (
    input 	  clk32,
    input 	  flash_clk,
    input 	  resb,
    input 	  porb,
    input 	  BR_N,
    input 	  FC0,
    input 	  FC1,
    input 	  FC2,
    output 	  AS_N,
    output 	  RW,
    output 	  UDS_N,
    output 	  LDS_N,
    input 	  VMA_N,
    input 	  MFPINT_N,
    output [23:0] A, // from CPU
    output [15:0] DIN,
    output [15:0] DOUT,
    output 	  MHZ8,
    output 	  MHZ8_EN1,
    output 	  MHZ8_EN2,
    output 	  MHZ4,
    output 	  MHZ4_EN,
    output 	  BERR_N,
    output 	  IPL0_N,
    output 	  IPL1_N,
    output 	  IPL2_N,
    output 	  DTACK_N,
    output 	  IACK_N,
    output 	  ROM0_N,
    output 	  ROM1_N,
    output 	  ROM2_N,
    output 	  ROM3_N,
    output 	  ROM4_N,
    output 	  ROM5_N,
    output 	  ROM6_N,
    output 	  ROMP_N,
    output 	  RAM_N,
    output 	  RAS0_N,
    output 	  RAS1_N,
    output 	  CAS0L_N,
    output 	  CAS0H_N,
    output 	  CAS1L_N,
    output 	  CAS1H_N,
    output 	  RAM_LDS,
    output 	  RAM_UDS,
    output 	  REF,
    output 	  VPA_N,
    output 	  MFPCS_N,
    output 	  SNDIR,
    output 	  SNDCS,
    output 	  N6850,
    output 	  FCS_N,
    output 	  RTCCS_N,
    output 	  RTCRD_N,
    output 	  RTCWR_N,
    output 	  HSYNC_N,
    output 	  VSYNC_N,
    output 	  BLANK_N,
    output 	  SINT,

    output 	  vreset,
    output    vpal,    

    input 	  ntsc,
    output 	  MONO,
    output [5:0]  R,
    output [5:0]  G,
    output [5:0]  B,

    output [23:1] ram_a,
    output 	  we_n,
    output [15:0] mdout,
    input [15:0]  mdin,

    // sdram interface
    output 	  sd_clk,
    output 	  sd_cke,
    inout [31:0]  sd_data, 
`ifdef VERILATOR
    input [31:0]  sd_data_in,
`endif 
    output [10:0] sd_addr,
    output [3:0]  sd_dqm,
    output [1:0]  sd_ba,
    output 	  sd_cs,
    output 	  sd_we,
    output 	  sd_ras,
    output 	  sd_cas,

    // SPI flash interface
    output 	  mspi_cs,
    inout 	  mspi_di,
    inout 	  mspi_hold,
    inout 	  mspi_wp,
    inout 	  mspi_do,
	       
`ifdef VERILATOR		
    input [1:0]   mspi_din, 
`endif

    output [5:0]  led,

    output 	  bus_free
   );

assign led = { !flash_ready, 2'b11, mspi_cs, !flash_cs, !flash_busy };

   wire		  sdram_ready;  
   wire		  flash_ready;  
   wire		  mem_ready = sdram_ready && flash_ready && porb;  
   
   reg		  trigger;
   reg		  mem_ready_D;
   
    // geneate a trigger signal once flash and SDRAM are initialized
   always @(posedge clk32 or negedge porb) begin
      if(!porb) begin
        trigger <= 1'b0;
        mem_ready_D <= 1'b0;
	 
     end else begin
        mem_ready_D <= mem_ready;  
        trigger <= 1'b0;	 

        if(mem_ready && !mem_ready_D)
            trigger <= 1'b1;	 
      end
   end

   wire flash_busy;   

   // generate RAM write signals whenever a word is received from
   // flash
   wire [15:0] flash_dout;
   reg [15:0] flash_doutD;
   reg [21:0] flash_addr;           // word address
   reg [21:0] ram_addr;           // word address
   reg [2:0]  state;
   wire       flash_data_strobe;
   reg        ram_write;
   reg [21:0] word_count;      

   reg	      flash_cs;
   reg	      flash_busy_D;	      

    reg [5:0] flash_cnt;

   // start copy state machine once flash and sdram are ready
   always @(posedge clk32 or negedge mem_ready) begin
      if(!mem_ready) begin
        flash_addr <= 22'h80000;     // start reading at 1MB
        ram_addr <= 22'hfc000;       // only write video ram area
        word_count <= 22'd16000;     // only read 32k image data

        state <= 3'h0;
        ram_write <= 1'b0;
        flash_cs <= 1'b0;	 
        flash_cnt <= 6'd0;
      end else begin
        flash_busy_D <= flash_busy;	 

        if((trigger || state == 7) && (word_count != 0)) begin
            flash_cs <= 1'b1;
`ifdef VERILATOR
	    // the flash is simulated at 32 MHz only and thus reacts much slower
            flash_cnt <= 6'd30; // >= 30 @ 32MHz
`else
            flash_cnt <= 6'd9;  // >= 9 @ 104MHz
`endif
        end else begin
            if(flash_cnt != 0) flash_cnt <= flash_cnt - 6'd1;
            if(flash_busy)     flash_cs <= 1'b0;

            // falling edge of flash busy indicates data ready, or ...
            // if(!flash_busy && flash_busy_D) begin

            // ... static timing with fixed counter
            if(flash_cnt == 6'd1) begin
                state <= 1;
                flash_addr <= flash_addr + 22'd1;
                word_count <= word_count - 22'd1;

                // we don't necessarily need to latch the data. But latching it here
                // allows to exactly determine the real access time by adjusting flash_cnt
                // to the lowest value that gives a stable image
                flash_doutD <= flash_dout;
            end
        end

        // advance ram write state
        if(state != 0)  state <= state + 3'd1;
        if(state == 1)  ram_write <= 1'b1;
        if(state == 6)  ram_write <= 1'b0;
        if(state == 7)  ram_addr <= ram_addr + 22'd1;
      end      
   end   
   
   flash flash (
    .clk(flash_clk),
    .resetn(porb),
    .ready(flash_ready),

    .address(flash_addr),      // 22 bit word address
    .cs(flash_cs), 
    .dout(flash_dout),
    .busy(flash_busy),

`ifdef VERILATOR		
    .mspi_din(mspi_din),
`endif
 
    .mspi_cs(mspi_cs),
    .mspi_di(mspi_di),
    .mspi_hold(mspi_hold),
    .mspi_wp(mspi_wp),
    .mspi_do(mspi_do)      
    );

   // synthesizable "register writer" to be able to run the simulation on real hw
   reg [1:0]	  wrstate;	  
   reg [7:0]	  regaddr;   
   var [39:0]	  wrdata;
   
   always @* begin
      case( regaddr )
         0: wrdata = { 24'hff8000, 16'h0008 }; // memory conrol reg, bankl 0 2mb
	 1: wrdata = { 24'hff8200, 16'h001f }; // video base hi    \ 
	 2: wrdata = { 24'hff8202, 16'h0080 }; // video base mid   / below 2MB top

	 3: wrdata = { 24'hff8260, 16'h0000 }; // 320x200
	 4: wrdata = { 24'hff820a, ntsc?16'h0000:16'h0200 }; // NTSC/PAL
	 5: wrdata = { 24'hff8240, 16'h0777 }; // default palette
	 6: wrdata = { 24'hff8242, 16'h0700 }; // for 4bpp
	 7: wrdata = { 24'hff8244, 16'h0070 };
	 8: wrdata = { 24'hff8246, 16'h0770 };
	 9: wrdata = { 24'hff8248, 16'h0007 };
	10: wrdata = { 24'hff824a, 16'h0707 };
	11: wrdata = { 24'hff824c, 16'h0077 };
	12: wrdata = { 24'hff824e, 16'h0555 };
	13: wrdata = { 24'hff8250, 16'h0333 };
	14: wrdata = { 24'hff8252, 16'h0733 };
	15: wrdata = { 24'hff8254, 16'h0373 };
	16: wrdata = { 24'hff8256, 16'h0773 };
	17: wrdata = { 24'hff8258, 16'h0337 };
	18: wrdata = { 24'hff825a, 16'h0737 };
	19: wrdata = { 24'hff825c, 16'h0377 };
	20: wrdata = { 24'hff825e, 16'h0000 };
	
	default: wrdata = 40'h00000000;          // -- stop -- 
      endcase
   end

   reg wract;   
   assign AS_N = !wract;
   assign UDS_N = !wract;
   assign LDS_N = !wract;
   assign RW = !wract;	 	    

   reg [31:0] setup_wait;   
   
   always @(posedge MHZ4 or negedge atari_reset_n) begin
      if(!atari_reset_n) begin
         regaddr <= 8'h00;
         wrstate <= 0;
         wract <= 1'b0;
         setup_wait <= 0;	 
      end else begin
         // delay setup to not bring shifter out of sync
         // 65000 ticks is shortly after the first full frame
         if(setup_wait < 65000) begin
            setup_wait <= setup_wait + 1;
            regaddr <= 8'h00;
            wrstate <= 0;
            wract <= 1'b0;
         end else begin      	 
            if(wrstate == 0) begin
              if(wrdata != 0)
                wrstate <= wrstate + 1;
            end else if(wrstate == 1) begin
               wrstate <= wrstate + 1;
               wract <= 1'b1;
            end else if(wrstate == 2) begin
               if(!DTACK_N) begin
                  wrstate <= wrstate + 1;
                  wract <= 1'b0;
               end
            end else begin
               regaddr <= regaddr + 1; 
               wrstate <= wrstate + 1;
            end
         end
      end
   end
   
assign A = wrdata[39:16];
assign DIN = wrdata[15:0];   
   
// shifter signals
wire        cmpcs_n, latch, st_de, rdat_n, wdat_n, dcyc_n, sreq, sload_n;

reg         bg_n = 1'b1;
wire        br_n_i, br_n_o, bgack_n_i, bgack_n_o, rdy_n_i, rdy_n_o;
wire        ROM_N = ROM0_N & ROM1_N & ROM2_N & ROM3_N & ROM4_N & ROM5_N & ROM6_N & ROMP_N;
assign      DOUT = ROM_N ? (rdat_n ? mcu_dout : shifter_dout) : mdin;
wire [15:0] mcu_dout;
wire [15:0] mbus_din = DIN;

assign br_n_i = 1;
assign bgack_n_i = bgack_n_o;
assign bus_free = bg_n & bgack_n_o;

always @(posedge clk32) if (MHZ8_EN1 && AS_N) bg_n <= br_n_o;

// ST video signals to be sent through the scan doubler
wire st_hs_n, st_vs_n, st_bl_n;
wire [3:0] st_r;
wire [3:0] st_g;
wire [3:0] st_b;

// the atari might be started when the spi is done initializing the sdram.
wire	   rom_ready = word_count == 0;  

// debounce atari reset a little bit
reg [4:0] atari_reset_cnt;
wire atari_reset_n = &atari_reset_cnt;     
always @(posedge clk32) begin
   if(!resb || !rom_ready)
     atari_reset_cnt <= 0;
   else begin
      atari_reset_cnt <= atari_reset_cnt + !(&atari_reset_cnt);
   end   
end
   
gstmcu gstmcu (
    .clk32(clk32),
    .resb(atari_reset_n),
    .porb(porb),
    .FC0(FC0),
    .FC1(FC1),
    .FC2(FC2),
    .AS_N(AS_N),
    .RW(RW),
    .UDS_N(UDS_N),
    .LDS_N(LDS_N),
    .VMA_N(VMA_N),
    .MFPINT_N(MFPINT_N),
    .A(A[23:1]),    // from CPU
    .ADDR(ram_a), // to RAM
    .DIN(mbus_din),
    .DOUT(mcu_dout),
    .OE_L(),
    .OE_H(),
    .CLK_O(),
    .MHZ8(MHZ8),
    .MHZ8_EN1(MHZ8_EN1),
    .MHZ8_EN2(MHZ8_EN2),
    .MHZ4(MHZ4),
    .MHZ4_EN(MHZ4_EN),
    .BR_N_I(br_n_i),
    .BR_N_O(br_n_o),
    .BG_N(bg_n),
    .BGACK_N_I(bgack_n_i),
    .BGACK_N_O(bgack_n_o),
    .RDY_N_I(rdy_n_i),
    .RDY_N_O(rdy_n_o),
    .BERR_N(BERR_N),
    .IPL0_N(IPL0_N),
    .IPL1_N(IPL1_N),
    .IPL2_N(IPL2_N),
    .DTACK_N_I(1'b0),
    .DTACK_N_O(DTACK_N),
    .IACK_N(IACK_N),
    .ROM0_N(ROM0_N),
    .ROM1_N(ROM1_N),
    .ROM2_N(ROM2_N),
    .ROM3_N(ROM3_N),
    .ROM4_N(ROM4_N),
    .ROM5_N(ROM5_N),
    .ROM6_N(ROM6_N),
    .ROMP_N(ROMP_N),
    .RAM_N(RAM_N),
    .RAS0_N(RAS0_N),
    .RAS1_N(RAS1_N),
    .CAS0L_N(CAS0L_N),
    .CAS0H_N(CAS0H_N),
    .CAS1L_N(CAS1L_N),
    .CAS1H_N(CAS1H_N),
    .RAM_LDS(RAM_LDS),
    .RAM_UDS(RAM_UDS),
    .REF(REF),
    .VPA_N(VPA_N),
    .MFPCS_N(MFPCS_N),
    .SNDIR(SNDIR),
    .SNDCS(SNDCS),
    .N6850(N6850),
    .FCS_N(FCS_N),
    .RTCCS_N(RTCCS_N),
    .RTCRD_N(RTCRD_N),
    .RTCWR_N(RTCWR_N),
    .LATCH(latch),
    .HSYNC_N(st_hs_n),
    .VSYNC_N(st_vs_n),
    .DE(st_de),
    .BLANK_N(BLANK_N),
    .RDAT_N(rdat_n),
    .WE_N(we_n),
    .WDAT_N(wdat_n),
    .CMPCS_N(cmpcs_n),
    .DCYC_N(dcyc_n),
    .SREQ(sreq),
    .SLOAD_N(sload_n),
    .SINT(SINT),

    .BUTTON_N(),
    .JOYWE_N(),
    .JOYRL_N(),
    .JOYWL(),
    .JOYRH_N(),

    .st(1'b1),
    .extra_ram(1'b0),
    .tos192k(1'b0),
    .turbo(1'b0),
    .viking_at_e8(1'b0),
    .viking_at_c0(1'b0),
    .bus_cycle()
);

wire [15:0] shifter_dout;

reg [21:0] dummy_d;
reg rd;
always @(negedge clk32) begin
    if(!VSYNC_N) dummy_d <= 0;
    else dummy_d <= dummy_d + 1;
end

wire [15:0] ram_dout; 
   
gstshifter gstshifter (
    .clk32(clk32),
    .ste(1'b0),
    .resb(atari_reset_n),

    // CPU/RAM interface
    .CS(~cmpcs_n),
    .A(A[6:1]),
    .DIN(mbus_din),
    .DOUT(shifter_dout),
    .LATCH(latch),
    .RDAT_N(rdat_n),   // latched MDIN -> DOUT
    .WDAT_N(wdat_n),   // DIN  -> MDOUT
    .RW(RW),

    // feed address right back for static test signal
    .MDIN(ram_dout),  // mdin
    .MDOUT(mdout),

    // VIDEO
    .MONO_OUT(MONO),
    .LOAD_N(dcyc_n),
    .DE(st_de),
    .BLANK_N(BLANK_N),
    .R(st_r),
    .G(st_g),
    .B(st_b),

    // DMA SOUND
    .SLOAD_N(sload_n),
    .SREQ(sreq),
    .audio_left(),
    .audio_right()
);

video_analyzer video_analyzer (
   .clk(clk32),
   .vs(st_vs_n),
   .hs(st_hs_n),
   .de(st_de),

   .pal(vpal),        // pal video detected
   .vreset(vreset)  // reset signal
);  
   
scandoubler scandoubler (
        // system interface
        .clk_sys(clk32),
        .bypass(1'b0),
        .ce_divider(1'b0),   // /4
        .pixel_ena(),

        // scanlines (00-none 01-25% 10-50% 11-75%)
        .scanlines(2'b00),

        // shifter video interface
        .hs_in(st_hs_n),
        .vs_in(st_vs_n),
        .r_in( st_r ),
        .g_in( st_g ),
        .b_in( st_b ),

        // output interface
        .hs_out(HSYNC_N),
        .vs_out(VSYNC_N),
        .r_out(R),
        .g_out(G),
        .b_out(B)
);

wire [21:0] sdram_addr =
	    (!atari_reset_n)?(ram_addr):
	    ram_a[22:1];
   
wire sdram_refresh =
     (!atari_reset_n)?1'b0:
     REF;  
   
wire sdram_cs =
     (!atari_reset_n)?ram_write:
     (!(RAS0_N && RAS1_N));   
   
wire sdram_we =
     (!atari_reset_n)?ram_write:
     !we_n;

wire [1:0] sdram_ds =
     (!atari_reset_n)?2'b00:
     { !(CAS0H_N && CAS1H_N), !(CAS0L_N && CAS1L_N) };

wire [15:0] sdram_din =
	    (!atari_reset_n)?flash_doutD:
	    16'h55aa;

sdram sdram (
        .clk(clk32),
	.reset_n(porb),

	.sd_clk(sd_clk),       // clock
	.sd_cke(sd_cke),       // clock enable
	.sd_data(sd_data),     // 32 bit bidirectional data bus
`ifdef VERILATOR
	.sd_data_in(sd_data_in),
`endif 
	.sd_addr(sd_addr),     // 11 bit multiplexed address bus
	.sd_dqm(sd_dqm),       // two byte masks
	.sd_ba(sd_ba),         // two banks
	.sd_cs(sd_cs),         // a single chip select
	.sd_we(sd_we),         // write enable
	.sd_ras(sd_ras),       // row address select
	.sd_cas(sd_cas),       // columns address select

	.refresh(sdram_refresh),
	.ready(sdram_ready),     // ram is done initialzing
	.din(sdram_din),        // data input from chipset/cpu
	.dout(ram_dout),
	.addr( sdram_addr ),    // 22 bit word address
	.ds( sdram_ds ),       // upper/lower data strobe
	.cs( sdram_cs ), // cpu/chipset requests read/write
	.we( sdram_we)                // cpu/chipset requests write
);
   
endmodule
