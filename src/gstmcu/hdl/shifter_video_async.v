
// Atari ST Shifter implementation, async

module shifter_video_async (
    input clk32,
    input nReset,
    input pixClk,
    input DE,
    input LOAD,
    input [1:0] rez,
    input monocolor,
    input [15:0] DIN,
    output [3:0] color_index
);

// shift array

wire [15:0] shdout0, shdout1, shdout2, shdout3;
wire [15:0] shcout0, shcout1, shcout2, shcout3;
genvar i;
for(i=0; i<16; i=i+1) begin:sharray
    shifter_cell_a c3(clk32, pixClk, LOAD, Reload, (i == 0) ? shftCin3 : shcout3[i-1], shcout3[i], DIN[i], shdout3[i]);
    shifter_cell_a c2(clk32, pixClk, LOAD, Reload, (i == 0) ? shftCin2 : shcout2[i-1], shcout2[i], shdout3[i], shdout2[i]);
    shifter_cell_a c1(clk32, pixClk, LOAD, Reload, (i == 0) ? shftCin1 : shcout1[i-1], shcout1[i], shdout2[i], shdout1[i]);
    shifter_cell_a c0(clk32, pixClk, LOAD, Reload, (i == 0) ? shftCin0 : shcout0[i-1], shcout0[i], shdout1[i], shdout0[i]);
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
reg Reload;

reg load_d1;
always @(posedge LOAD, negedge DE) begin
	if (!DE) load_d1 <= 1'b0;
	else load_d1 <= 1'b1;
end

reg load_d2;
reg reload_delay_n;
always @(posedge pixClk, negedge nReset) begin
	if (!nReset) reload_delay_n <= 1'b0;
	else begin
		reload_delay_n <= ~Reload;
		load_d2 <= load_d1;
	end
end

reg pxCtrEn;
always @(negedge Reload, negedge nReset, posedge load_d2) begin
	if (!nReset) pxCtrEn <= 1'b0;
	else if (load_d2) pxCtrEn <= 1'b1;
	else pxCtrEn <= load_d2;
end

/* verilator lint_off UNOPTFLAT */
reg [3:0] rdelay;
always @(posedge LOAD, negedge reload_delay_n) begin
	if (!reload_delay_n) rdelay <= 4'b0;
	else rdelay <= { 1'b1, rdelay[3:1] };
end
/* verilator lint_on UNOPTFLAT */

reg [3:0] pixCntr;
always @(posedge pixClk, negedge rdelay[0]) begin
	if (!rdelay[0]) Reload <= 1'b0;
	else Reload <= &pixCntr;
end

always @(posedge pixClk) begin
	if (pxCtrEn) pixCntr <= pixCntr + 1'h1;
	else pixCntr <= 4'h4;
end

endmodule

////////////////////////////////

module shifter_cell_a (
    input clk32,
    input pixClk,
    input LOAD,
    input Reload,
    input Shin,
    output reg Shout,
    input Din,
    output reg Dout
);

always @(posedge LOAD) begin
	Dout <= Din;
end

always @(posedge pixClk) begin
	Shout <= Reload ? Dout : Shin;
end

endmodule
