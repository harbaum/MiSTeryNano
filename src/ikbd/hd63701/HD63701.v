/******************************************************
    HD63701V0(Mode6) Compatible Processor Core
              Written by Tsuyoshi HASEGAWA 2013-14
*******************************************************/
module HD63701V0_M6
(
 input 	       CLKx2, // XTAL/EXTAL (200K~2.0MHz)

 input 	       RST, // RES
 input 	       NMI, // NMI
 input 	       IRQ, // IRQ1

 output        RW, // CS2
 output [15:0] AD, //  AS ? {PO4,PO3}
 output [7:0]  DO, // ~AS ? {PO3}
 input [7:0]   DI, //       {PI3}

 input [7:0]   PI4, //
 
 input [7:0]   PI1, // Port1 IN
 output [7:0]  PO1, //       OUT

 input [4:0]   PI2, // Port2 IN
 output [7:0]  PO2  //       OUT
);

// map sci tx onto PO3 if transmitter is enabled
assign PO2 = te?{PO2I[7:5],txd,PO2I[3:0]}:PO2I;      
wire [7:0] 	  PO2I;
      
wire [15:0] ADI;
wire [7:0] PO3;   
wire [7:0] PO4;   

// Multiplex PO3 and PO4 onto external AD port in mode 7
assign AD = (PO2I[7:5] == 3'b111)?{ PO4, PO3 }:ADI;  
   
// Built-In Instruction ROM TODO: include mode (POI[7:5]) here
wire en_birom = (ADI[15:12]==4'b1111);			// $F000-$FFFF
wire [7:0] biromd;
MCU_BIROM irom( CLKx2, ADI[11:0], biromd );


// Built-In WorkRAM
wire		  en_biram;
wire [7:0] biramd;
HD63701_BIRAM biram( CLKx2, ADI, RW, DO, en_biram, biramd );


// Built-In I/O Ports
wire		  en_biio;
wire [7:0] biiod;
HD63701_IOPort iopt( RST, CLKx2, ADI, RW, DO, en_biio, biiod, PI1, PI2, DI, PI4, PO1, PO2I, PO3, PO4 );


// Built-In Serial Communication Hardware
wire		  irq2_sci;
wire		  txd;
wire		  te;
wire		  en_bisci;
wire [7:0] biscid;
HD63701_SCI sci( RST, CLKx2, ADI, RW, DO, PI2[3], txd, te, irq2_sci, en_bisci, biscid );


// Built-In Timer
wire		  irq2_tim;
wire		  en_bitim;
wire [7:0] bitimd;
HD63701_Timer timer( RST, CLKx2, ADI, RW, DO, irq2_tim, en_bitim, bitimd );


// Built-In Devices Data Selector
wire [7:0] biddi;
HD63701_BIDSEL bidsel
(
 biddi,
 en_birom, biromd,
 en_biram, biramd,
 en_biio , biiod, 
 en_bisci, biscid,
 en_bitim, bitimd,
 DI
 );

// Processor Core
HD63701_Core core
  (
   .CLKx2(CLKx2),.RST(RST),
   .NMI(NMI),.IRQ(IRQ),.IRQ2_TIM(irq2_tim),.IRQ2_SCI(irq2_sci),
   .RW(RW),.AD(ADI),.DO(DO),.DI(biddi)
   );
  
endmodule

module HD63701_BIDSEL 
(
 output [7:0] o,

 input 	      e0, input [7:0] d0,
 input 	      e1, input [7:0] d1,
 input 	      e2, input [7:0] d2,
 input 	      e3, input [7:0] d3,
 input 	      e4, input [7:0] d4,

 input [7:0]  dx
);

assign o = e0 ? d0 :
	   e1 ? d1 :
	   e2 ? d2 :
	   e3 ? d3 :
	   e4 ? d4 :
	   dx;
   
endmodule


module HD63701_BIRAM
(
 input 		  mcu_clx2,
 input [15:0] 	  mcu_ad,
 input 		  mcu_wr,
 input [7:0] 	  mcu_do,
 output 	  en_biram,
 output reg [7:0] biramd
);

assign en_biram = (mcu_ad[15: 7]==9'b000000001);	// $0080-$00FF
wire [6:0] biad = mcu_ad[6:0];

reg [7:0] bimem[0:127];
always @( posedge mcu_clx2 ) begin
	if (en_biram & mcu_wr) bimem[biad] <= mcu_do;
	else biramd <= bimem[biad];
end

endmodule


module HD63701_IOPort
(
 input 		  mcu_rst,
 input 		  mcu_clx2,
 input [15:0] 	  mcu_ad,
 input 		  mcu_wr,
 input [7:0] 	  mcu_do,

 output 	  en_io,
 output [7:0] 	  iod,
	
 input [7:0] 	  PI1,
 input [4:0] 	  PI2,
 input [7:0] 	  PI3,
 input [7:0] 	  PI4,

 output [7:0] 	  PO1,
 output [7:0] 	  PO2,
 output [7:0] 	  PO3,
 output [7:0] 	  PO4
);

   assign PO1 = (~DDR1) | PO1R;
   assign PO2 = ({3'b000, ~DDR2}) | PO2R;
   assign PO3 = (~DDR3) | PO3R;
   assign PO4 = (~DDR4) | PO4R;
   
   reg [7:0] 	  DDR1;
   reg [4:0] 	  DDR2;
   reg [7:0] 	  DDR3;
   reg [7:0] 	  DDR4;
   
   reg [7:0] 	  PO1R;   
   reg [7:0] 	  PO2R;
   reg [7:0] 	  PO3R;   
   reg [7:0] 	  PO4R;
  
always @( posedge mcu_clx2 ) begin
   if (mcu_rst) begin
      DDR1 <= 8'h00;
      DDR2 <= 5'h00;      
      DDR3 <= 8'h00;
      DDR4 <= 8'h00;      
      PO2R[7:5] <= PI2[2:0];
      // other output registers are undefined after reset
   end
   else begin
      if (mcu_wr) begin
	 if (mcu_ad==16'h0) DDR1 <= mcu_do;
	 if (mcu_ad==16'h1) DDR2 <= mcu_do[4:0];
	 if (mcu_ad==16'h2) PO1R <= mcu_do;
	 if (mcu_ad==16'h3) PO2R[4:0] <= mcu_do[4:0];
	 if (mcu_ad==16'h4) DDR3 <= mcu_do;
	 if (mcu_ad==16'h5) DDR4 <= mcu_do;
	 if (mcu_ad==16'h6) PO3R <= mcu_do;
	 if (mcu_ad==16'h7) PO4R <= mcu_do;
      end
   end
end // always @ ( posedge mcu_clx2 or posedge mcu_rst )
   
// IO from 0x0000 to 0x0007
assign en_io = (mcu_ad[15:3] == 13'h0);
// only addresses 2 and 3 return data
assign iod = 
	     (mcu_ad==16'h0) ? DDR1 : 
	     (mcu_ad==16'h1) ? {3'hF,DDR2} : 
	     (mcu_ad==16'h2) ? PI1 : 
	     (mcu_ad==16'h3) ? {3'hF,PI2}:
	     (mcu_ad==16'h4) ? DDR3 : 
	     (mcu_ad==16'h5) ? DDR4 : 
	     (mcu_ad==16'h6) ? PI3 :
	     PI4;

endmodule


module HD63701_SCI
(
 input 	      mcu_rst,
 input 	      mcu_clx2,
 input [15:0] mcu_ad,
 input 	      mcu_wr,
 input [7:0]  mcu_do,

 input 	      rx,
 output reg   tx,
 output       te,
 output       mcu_irq2_sci,
 output       en_sci,
 output [7:0] iod
);

   reg [7:0]  RMCR;   // Rate and Mode Control Register
   reg [7:0]  TRCSR;  // Transmit/Receive Control and Status Register   
   reg [7:0]  RDR;    // Receive Data Register
   reg [7:0]  TDR;    // Transmit Data Register 	     

   reg 	      RDRF;   // receive data register full  
   reg 	      TDRE;   // transmit data register empty
   reg 	      ORFE;   // over run framing error
   
   reg 	      last_rx;

   reg [8:0]  rxsr;   // receive shift register    
   reg [7:0]  rxcnt;  // 9 bit receive counter
   
   reg [11:0] txcnt;  // 12 bit transmit counter
   reg [8:0]  txsr;
   reg        clr_rd;
   reg        clr_td;
      
   always @( posedge mcu_clx2 or posedge mcu_rst ) begin
      if (mcu_rst) begin
	 RMCR  <= 8'h00;
	 TRCSR <= 8'h00;
	 RDR   <= 8'h00;
	 TDR   <= 8'h00;
	 TDRE  <= 1'b1;
	 RDRF  <= 1'b0;
	 ORFE  <= 1'b0;
	 clr_rd <= 1'b0;
	 clr_td <= 1'b0;
	 last_rx <= 1'b1;
	 rxcnt <= 8'h00;
	 txcnt <= 12'h000;
	 rxsr <= 9'h1ff;
	 txsr <= 9'h000;
	 tx <= 1'b1;
      end
      else begin

	 if(en_sci && !mcu_wr) begin
	    if (mcu_ad==16'h11) {clr_rd, clr_td} <= 2'b11;
	    if (mcu_ad==16'h12 && clr_rd) begin
	        RDRF <= 1'b0;
	        ORFE <= 1'b0;
	        clr_rd <= 1'b0;
	    end
	 end

	 if(re) begin
	 
	    // sync rx clock on first falling data (start bit)
	    last_rx <= rx;
	    rxcnt <= rxcnt + 1;	 
	    if((rxsr == 9'h1ff) && last_rx && !rx)
	       rxcnt <= 8'h00;	    

	    // sample serial bit in the middle of the 256 clock
	    // cycle @ 7812.5 bit/s and shift it into rx buffer
	    if(rxcnt == 8'd128) begin
	       rxsr <= { rx, rxsr[8:1] };
	       // a full byte has been received whenever the
	       // lowest bit would become '0' due to the start bit.
	       // rx must be 1 due to stop bit, otherwise this
	       // is a framing error
	       if(rxsr[0] == 1'b0) begin
		  if(rx == 1'b1) begin
		     rxsr <= 9'h1ff;
		     if (RDRF == 1'b1) ORFE <= 1'b1; // overrun error, data is not transferred to RDR
		     else RDR <= rxsr[8:1];
		     RDRF <= 1'b1;
		     clr_rd <= 1'b0;
		  end else begin
		     ORFE <= 1'b1;
		     // framing error, data is transferred to RDR
		     RDR <= rxsr[8:1];
		  end
	       end
	    end
	 end

	 if (mcu_wr) begin
	    if (mcu_ad==16'h10) RMCR <= mcu_do;
	    if (mcu_ad==16'h11) TRCSR <= mcu_do;
	    if (mcu_ad==16'h13) begin
	       if (clr_td) begin
	         TDRE <= 1'b0;
	         clr_td <= 1'b0;
	       end
	       TDR <= mcu_do;
	    end
	 end

	 txcnt <= txcnt + 1;
	 if(txcnt == 12'haff) txcnt <= 12'h000;
	 if(txcnt[7:0] == 8'hff) begin
	    // if txsr == 0x000 then no transmission is in progress
	    // start the transmission only at specific time slots
	    if((txsr == 9'h000) && !TDRE && txcnt == 12'haff) begin
	       TDRE <= 1'b1;
	       txcnt <= 12'h000;        // start tx bit timer
	       txsr <= { 1'b1, TDR }; // data incl stop bit
	       tx <= 1'b0;	      // send start bit
	       clr_td <= 1'b0;
	    end

	    // transmit byte if txsr is not empty
	    if(txsr != 9'h000) begin
	       tx <= txsr[0];
	       txsr <= { 1'b0, txsr[8:1] };
	    end
	 end
      end
   end
   
   // bit 0 (wakeup) is cleared by the hardware after seeing 10 1's on RX,
   // we always return 0
   wire [7:0] TRCSR_O = { RDRF, ORFE, TDRE, TRCSR[4:1], 1'b0 };

   wire       wu = TRCSR[0];   // wake up
   assign     te = TRCSR[1];   // transmitter enable
   wire       tie = TRCSR[2];  // transmitter interrupt enable
   wire       re = TRCSR[3];   // receiver enable
   wire       rie = TRCSR[4];  // receiver interrupt enable

   // interrupt on receive or transmit
   assign mcu_irq2_sci = (rie && (RDRF | ORFE)) || (tie && TDRE); 
   
   assign en_sci = (mcu_ad[15:2] == 14'h004);
   assign iod = (mcu_ad==16'h10) ? RMCR :
		(mcu_ad==16'h11) ? TRCSR_O :
		(mcu_ad==16'h12) ? RDR :
		TDR;
   
endmodule


module HD63701_Timer
(
	input			 mcu_rst,
	input			 mcu_clx2,
	input [15:0] mcu_ad,
	input 		 mcu_wr,
	input  [7:0] mcu_do,

	output		 mcu_irq2_tim,

	output		 en_timer,
	output [7:0] timerd
);

reg		  oci, oce;
reg [15:0] ocr, icr;
reg [16:0] frc;
reg  [7:0] frt;
reg  [7:0] rmc;

always @( posedge mcu_clx2 or posedge mcu_rst ) begin
	if (mcu_rst) begin
		oce <= 0;
		ocr <= 16'hFFFF;
		icr <= 16'hFFFF;
		frc <= 0;
		frt <= 0;
		rmc <= 8'h40;
	end
	else begin
		frc <= frc+1;
		if (mcu_wr) begin
			case (mcu_ad)
				16'h08: oce <= mcu_do[3];
				16'h09: frt <= mcu_do;
				16'h0A: frc <= {frt,mcu_do,1'h0};
				16'h0B: ocr[15:8] <= mcu_do;
				16'h0C: ocr[ 7:0] <= mcu_do;
				16'h0D: icr[15:8] <= mcu_do;
				16'h0E: icr[ 7:0] <= mcu_do;
				16'h14: rmc <= {mcu_do[7:6],6'h0};
				default:;
			endcase
		end
	end
end

always @( negedge mcu_clx2 or posedge mcu_rst ) begin
	if (mcu_rst) begin
		oci <= 1'b0;
	end
	else begin
		case (mcu_ad)
			16'h0B: oci <= 1'b0;
			16'h0C: oci <= 1'b0;
			default: if (frc[16:1]==ocr) oci <= 1'b1;
		endcase
	end
end

assign mcu_irq2_tim  = oci & oce;

assign en_timer = ((mcu_ad>=16'h8)&(mcu_ad<=16'hE))|(mcu_ad==16'h14);

assign   timerd = (mcu_ad==16'h08) ? {1'b0,oci,2'b10,oce,3'b000}:
		  (mcu_ad==16'h09) ? frc[16:9] :
		  (mcu_ad==16'h0A) ? frc[ 8:1] :
		  (mcu_ad==16'h0B) ? ocr[15:8] :
		  (mcu_ad==16'h0C) ? ocr[ 7:0] :
		  (mcu_ad==16'h0D) ? icr[15:8] :
		  (mcu_ad==16'h0E) ? icr[ 7:0] :
		  (mcu_ad==16'h14) ? rmc :
		  8'h0;

endmodule

