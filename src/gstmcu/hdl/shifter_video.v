
// Atari ST shifter implementation, sync to 32 MHz clock

module shifter_video (
    input clk32,
    input nReset,
    input pixClkEn,
    input DE,
    input LOAD,
    input [1:0] rez,
    input monocolor,
    input [15:0] DIN,
    input scroll,
    output reg Reload,
    output [3:0] color_index
);

// edge detectors
reg LOAD_D;

always @(posedge clk32) begin : edgedetect
	// edge detectors
	LOAD_D <= LOAD;
end

// shift array
reg [15:0] shdout0, shdout1, shdout2, shdout3;
reg [15:0] shcout0, shcout1, shcout2, shcout3;
reg [15:0] shdout_next0, shdout_next1, shdout_next2, shdout_next3;
always @(*) begin : shiftarray1
	shdout_next0 = shdout0;
	shdout_next1 = shdout1;
	shdout_next2 = shdout2;
	shdout_next3 = shdout3;
	if (~LOAD_D & LOAD) begin
		shdout_next3 = DIN;
		shdout_next2 = shdout3;
		shdout_next1 = shdout2;
		shdout_next0 = shdout1;
	end
end

always @(negedge clk32) begin : shiftarray2
	if (pixClkEn) begin
		shcout3 <= Reload ? shdout_next3 : {shcout3[14:0], shftCin3};
		shcout2 <= Reload ? shdout_next2 : {shcout2[14:0], shftCin2};
		shcout1 <= Reload ? shdout_next1 : {shcout1[14:0], shftCin1};
		shcout0 <= Reload ? shdout_next0 : {shcout0[14:0], shftCin0};
	end
	shdout3 <= shdout_next3;
	shdout2 <= shdout_next2;
	shdout1 <= shdout_next1;
	shdout0 <= shdout_next0;
end

// shift array logic
wire notlow = rez[0] | rez[1];
wire shftCout3 = shcout3[15];
wire shftCout2 = shcout2[15];
wire shftCout1 = shcout1[15];
wire shftCout0 = shcout0[15];
wire shftCin3  = ~monocolor & rez[1];
wire shftCin2  = shftCout3 & rez[1] & notlow;
wire shftCin1  = (shftCout3 & ~rez[1] & notlow) | (shftCout2 & rez[1] & notlow);
wire shftCin0  = (shftCout2 & ~rez[1] & notlow) | (shftCout1 & rez[1] & notlow);
assign color_index = { shftCout3, shftCout2, shftCout1, shftCout0 };

// reload control
reg        load_d1_reg;
reg        load_d1;
reg  [3:0] rdelay_reg;
reg  [3:0] rdelay;
reg        reload_delay_n;

always @(*) begin
    load_d1 = load_d1_reg;

    if (!DE) load_d1 = 1'b0;
    else if (~LOAD_D & LOAD) load_d1 = 1'b1;

    rdelay = rdelay_reg;
    if (~reload_delay_n) rdelay = 4'b0000;
    else if (~LOAD_D & LOAD) rdelay = { 1'b1, rdelay[3:1] };
end

always @(posedge clk32, negedge nReset) begin : reloadctrl

	reg load_d2;
	reg reload_delay_d;
	reg [3:0] pixCntr;
	reg pxCtrEn;

	if (!nReset) begin
		reload_delay_n <= 1'b0;
		pxCtrEn <= 1'b0;
		pixCntr <= 4'h4;
		rdelay_reg <= 4'b0000;
		load_d1_reg <= 1'b0;
	end else begin
		if (pixClkEn) begin
			if (Reload & ~&pixCntr) pxCtrEn <= load_d2; // negedge of Reload
			load_d2 <= load_d1;
			if (load_d1) pxCtrEn <= 1'b1; // async set of pxCtrEn from load_d2
			pixCntr <= pxCtrEn ? pixCntr + 1'h1 : 4'h4;
			reload_delay_n <= ~Reload;
			Reload <= &pixCntr;
		end

		// originally async sets
		if (!rdelay[0] && 
		   !(scroll & !DE)) // mid and hi res leave 2 or 1 words unloaded when STe hard scroll is used
			 Reload <= 1'b0;

		load_d1_reg <= load_d1;
		rdelay_reg <= rdelay;
	end
end

endmodule
