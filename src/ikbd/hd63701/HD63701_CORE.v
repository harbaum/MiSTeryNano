/***************************************************************************
       This file is part of "HD63701V0 Compatible Processor Core".
****************************************************************************/
`timescale 1ps / 1ps
`include "HD63701_defs.i"

module HD63701_Core
(
	input					CLKx2,

	input					RST,
	input					NMI,
	input					IRQ,
	input					IRQ2_TIM,
	input					IRQ2_SCI,

	output 				RW,
	output 	[15:0]	AD,
	output	 [7:0]	DO,
	input     [7:0]	DI
);

reg CLK = 0;
always @( negedge CLKx2 ) CLK <= ~CLK;

wire `mcwidth mcode;
wire [7:0] 	  vect;
wire		  	  inte, fncu;

HD63701_SEQ   SEQ(.CLK(CLK),.RST(RST),
						.NMI(NMI),.IRQ(IRQ),.IRQ2_TIM(IRQ2_TIM),.IRQ2_SCI(IRQ2_SCI),
						.DI(DI),
						.mcout(mcode),.vect(vect),.inte(inte),.fncu(fncu));

HD63701_EXEC EXEC(.CLK(CLK),.RST(RST),.DI(DI),.AD(AD),.RW(RW),.DO(DO),
						.mcode(mcode),.vect(vect),.inte(inte),.fncu(fncu));

endmodule


