/***************************************************************************
       This file is part of "HD63701V0 Compatible Processor Core".
****************************************************************************/
`timescale 1ps / 1ps
`include "HD63701_defs.i"

module HD63701_ALU
(
	input   [4:0] op,
	input	  [7:0] cf,
	input			  bw,

	input	 [15:0] R0,
	input	 [15:0] R1,
	input			  C,

	output [15:0] RR,
	output  [5:0] RC
);

wire [16:0] r = 
	    (op==`mcTST) ? {1'b0, (R0)}:
	    (op==`mcLDR) ? {1'b0, (R0)}:
	    (op==`mcLDN) ? {1'b0, (R0)}:
	    (op==`mcPSH) ? {1'b0, (R0)}:
	    (op==`mcPUL) ? {1'b0, (R0)}:
	    (op==`mcINT) ? {1'b0, (R0)}:
	    (op==`mcDAA) ? {1'b0, (R0)}:			// todo: DAA
	    (op==`mcINC) ? (R0+16'h1):
	    (op==`mcADD) ? (R0+R1):
	    (op==`mcADC) ? (R0+R1+{15'd0,C}):
	    (op==`mcDEC) ? (R0-16'h1):
	    (op==`mcSUB) ? (R0-R1):
	    (op==`mcSBC) ? (R0-R1-{15'd0,C}):
	    (op==`mcMUL) ? (R0*R1):
	    (op==`mcNEG) ? ({1'b0,~R0}+17'h1):
	    (op==`mcNOT) ? ({1'b0,~R0}):
	    (op==`mcAND) ? {1'b0,(R0&R1)}:
	    (op==`mcLOR) ? {1'b0,(R0|R1)}:
	    (op==`mcEOR) ? {1'b0,(R0^R1)}:
	    (op==`mcASL) ? {R0[15:0],1'b0}:
	    (op==`mcASR) ? (bw ? {1'b0,R0[15],R0[15:1]}:{9'b0,R0[7],R0[7:1]}):
	    (op==`mcLSR) ? {2'b0,R0[15:1]}:
	    (op==`mcROL) ? {R0[15:0],C}:
	    (op==`mcROR) ? (bw ? {1'b0,C,R0[15:1]} : {9'b0,C,R0[7:1]}):
	    (op==`mcCCB) ? {11'h3,(R0[5:0]&cf[5:0])}:
	    (op==`mcSCB) ? {11'h3,(R0[5:0]|cf[5:0])}:
	    (17'h0);

assign RR = r[15:0];

wire	chCarryL = (op==`mcASL)|(op==`mcROL)|
					  (op==`mcADD)|(op==`mcADC)|
					  (op==`mcSUB)|(op==`mcSBC)|
					  (op==`mcMUL);

wire	chCarryR = (op==`mcASR)|(op==`mcLSR)|(op==`mcROR);

wire    fC =	(op==`mcNOT) ? 1'b1 : 
				chCarryL ? ( bw ? r[16] : r[8] ) :
				chCarryR ? R0[0] :
				C ;

wire   fZ = bw ?(RR[15:0]==0) : (RR[7:0]==0);
wire   fN = bw ? RR[15] : RR[7];

wire   fV = (op==`mcLDR) ? 1'b0 : (bw ?(R0[15]^R1[15]^RR[15]^RR[14]) : (R0[7]^R1[7]^RR[7]^RR[6]));
wire   fH = (op==`mcLDR) ? 1'b0 : R0[4]^R1[4]^RR[4];

assign RC = {fH,1'b0,fN,fZ,fV,fC};

endmodule

