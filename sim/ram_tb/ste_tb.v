// ====================================================================
//
//  Atari STE GSTMCU
//  Based on ST4081S.PDF recovered by Christian Zietz
//
//  Copyright (C) 2019 Gyorgy Szombathelyi <gyurco@freemail.hu>
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module ste_tb (
    input 	  clk32,
    input 	  resb,
    input 	  porb,
	       
    output 	  E, 
    output 	  FC0,
    output 	  FC1,
    output 	  FC2,
    output 	  AS_N,
    output 	  RW,
    output 	  UDS_N,
    output 	  LDS_N,
    output 	  VMA_N,
    output 	  HALTED_N,
    output 	  MFPINT_N,
    output [23:0] A, // from CPU
    output [15:0] DIN,
    output [15:0] DOUT,
    input [15:0]  ROM_DOUT,
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
    output    DE,
    output 	  SINT,

    output 	  MONO,
    output [3:0]  R,
    output [3:0]  G,
    output [3:0]  B,

    // use this with ras/cas
    output [23:1] ram_a,
    output 	  we_n,
    output [15:0] mdout,
    input [15:0]  mdin,

    input 	  tos192k,
    input 	  turbo,
    output 	  bus_free
);

   wire [15:0] 	  cpu_data_in =
		  (!ROM_N)?ROM_DOUT:
		  mdin;  // DOUT     

   assign	  MFPINT_N = 1'b1;   
   
wire resetn_D = (rst_cnt == 255);
reg [7:0] rst_cnt;
always @(posedge clk32) begin
    if(resb == 0 || porb == 0)
        rst_cnt <= 0;
    else begin
        if(rst_cnt < 255)
            rst_cnt <= rst_cnt + 8'd1;
    end
end

// include fx68k
fx68k fx68k (
     .clk ( clk32 ),
`ifndef VERILATOR
     .HALTn(1'b1),
`endif 

     // These two signals don't need to be registered. They are not async reset.
//     .extReset(!resb),                     // External sync reset on emulated system
     .extReset(!resetn_D),                    // External sync reset on emulated system
     .pwrUp(!porb),                        // Asserted together with reset on emulated system coldstart
     .enPhi1(MHZ8_EN1),.enPhi2(MHZ8_EN2), // Clock enables. Next cycle is PHI1 or PHI2

     .eRWn(RW),
     .ASn(AS_N),
     .LDSn(LDS_N), .UDSn(UDS_N),
     .E(E),
     .VMAn(VMA_N),

     .FC0(FC0), .FC1(FC1), .FC2(FC2),
     .BGn(),
     .oRESETn(), .oHALTEDn(HALTED_N),
     .DTACKn(DTACK_N), .VPAn(VPA_N),
     .BERRn(BERR_N),
     .BRn(1'b1), .BGACKn(1'b1),
     .IPL0n(IPL0_N), .IPL1n(IPL1_N), .IPL2n(IPL2_N),
     .iEdb( cpu_data_in ), .oEdb(DIN),
     .eab(A[23:1])
);

// work with 24 bits for better readability in traces
assign A[0] = 1'b0; 
   
// shifter signals
wire        cmpcs_n, latch, rdat_n, wdat_n, dcyc_n, sreq, sload_n;

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
   
gstmcu gstmcu (
    .clk32(clk32),
    .resb(resb),
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
    .DTACK_N_I(1'b1),
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
    .HSYNC_N(HSYNC_N),
    .VSYNC_N(VSYNC_N),
    .DE(DE),
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
    .tos192k(tos192k),
    .turbo(1'b0),
    .viking_at_e8(1'b0),
    .viking_at_c0(1'b0),
    .bus_cycle()
);

wire [15:0] shifter_dout;

gstshifter gstshifter (
    .clk32(clk32),
    .ste(1'b0),
    .resb(resb),

    // CPU/RAM interface
    .CS(~cmpcs_n),
    .A(A[6:1]),
    .DIN(mbus_din),
    .DOUT(shifter_dout),
    .LATCH(latch),
    .RDAT_N(rdat_n),   // latched MDIN -> DOUT
    .WDAT_N(wdat_n),   // DIN  -> MDOUT
    .RW(RW),
    .MDIN(mdin),
    .MDOUT(mdout),

    // VIDEO
    .MONO_OUT(MONO),
    .LOAD_N(dcyc_n),
    .DE(DE),
    .BLANK_N(BLANK_N),
    .R(R),
    .G(G),
    .B(B),

    // DMA SOUND
    .SLOAD_N(sload_n),
    .SREQ(sreq),
    .audio_left(),
    .audio_right()
);

endmodule
