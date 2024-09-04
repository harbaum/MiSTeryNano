/***************************************************************************
       This file is part of "HD63701V0 Compatible Processor Core".
****************************************************************************/
`timescale 1ps / 1ps

`include "HD63701_defs.i"

module HD63701_SEQ
(
	input						CLK,
	input						EN,
	input						RST,

	input						NMI,
	input						IRQ,

	input						IRQ2_SCI,
	input						IRQ2_TIM,

	input 	[7:0]			DI,

	output `mcwidth		mcout,
	input		[7:0]			vect,
	input						inte,
	output					fncu
);

`define MC_SEI {`mcSCB,   `bfI    ,`mcrC,`mcpN,`amPC,`pcN}
`define MC_YLD {`mcNOP,`mcrn,`mcrn,`mcrn,`mcpK,`amPC,`pcN} 

reg [7:0]   opcode;
reg `mcwidth mcode;
reg  mcside;
   


wire bIRQ  = IRQ & inte;
wire bIRQ2_TIM = IRQ2_TIM & inte;
wire bIRQ2_SCI = IRQ2_SCI & inte;

wire  	   bINT = NMI|bIRQ|bIRQ2_TIM|bIRQ2_SCI;
wire [7:0] vINT = NMI ? `vaNMI :        // NMI     $fc
	   bIRQ       ? `vaIRQ :        // ext IRQ $f8
	   bIRQ2_TIM  ? 8'hf4 :         // TIM OCF $f4
	   bIRQ2_SCI  ? 8'hf0 :         // SCI     $f0
	   0;

reg [5:0] PHASE;
always @( posedge CLK or posedge RST ) begin
	if (RST) begin
		opcode <= 0;
		mcode  <= 0;
		mcside <= 0;
	end
	else if(EN) begin


		case (PHASE)

		// Reset
		`phRST :	mcside <= 1;

		// Load Vector
		`phVECT: mcside <= 1;

		// Execute
		`phEXEC: begin
						opcode <= DI;
						if ( bINT & (opcode[7:1]!=7'b0000111) ) begin
							mcside <= 0;
							mcode  <= {`mcINT,vINT,`mcrn,`mcpI,`amPC,`pcN};
						end
						else mcside <= 1;
					end

		// Interrupt (TRAP/IRQ/NMI/SWI/WAI)
		`phINTR:  mcside <= 1; 
		`phINTR8: begin
						mcside <= 0;
						if (vect==`vaWAI) begin
							if (bINT) begin
								mcode  <= `MC_SEI;
								opcode <= vINT;
							end
							else mcode <= `MC_YLD;
						end
						else begin
							opcode <= vect;
							mcode  <= `MC_SEI;
						end
					 end
		`phINTR9: mcode <= {`mcLDV, opcode,`mcrn,`mcpV,`amE0,`pcN};	//(Load Vector)

		// Sleep
		`phSLEP: begin
						mcside <= 0;
						if (bINT) begin
							mcode  <= {`mcINT,vINT,`mcrn,`mcpI,`amPC,`pcN};
						end
						else mcode <= `MC_YLD;
					end

		// HALT (Bug in MicroCode)
//		`phHALT: $stop;

		default:;
		endcase // case (PHASE)


	end
end

// Update Phase
wire [2:0] mcph = mcout[6:4];
always @( negedge CLK or posedge RST ) begin
	if (RST) PHASE <= 0;
	else if(EN) begin
		case (mcph)
			`mcpN: PHASE <= PHASE+6'h1;
			`mcp0: PHASE <=`phEXEC;
			`mcpI: PHASE <=`phINTR;
			`mcpV: PHASE <=`phVECT;
			`mcpH: PHASE <=`phHALT;
			`mcpS: PHASE <=`phSLEP;
		 default: PHASE <= PHASE;
		endcase
	end
end

// Output MicroCode
wire `mcwidth mcoder;
HD63701_MCROM mcr( CLK, EN, PHASE, (PHASE==`phEXEC) ? DI : opcode, mcoder );
assign mcout = mcside ? mcoder : mcode;

assign fncu = ( opcode[7:4]==4'h2)|
				  ((opcode[7:4]==4'h3)&(opcode[3:0]!=4'hD));

endmodule

