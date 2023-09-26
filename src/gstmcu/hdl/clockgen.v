/* verilator lint_off UNOPTFLAT */

module clockgen (
	input clk32,
	input resb,
	input porb,
	input turbo,
	output clk,
	output mhz8,
	output reg mhz8_en1,
	output reg mhz8_en2,
	output mhz4,
	output reg mhz4_en,
	output time0,
	output time1,
	output time2,
	output time3,
	output time4,
	output time5,
	output time6,
	output time7,
	output m2clock,
	output m2clock_en_p,
	output m2clock_en_n,
	output clk4,
	output latch
);

assign clk          = mhz16_s;
assign mhz8         = mhz8_s;
assign mhz4         = mhz4_s;
assign time0        = time0_s;
assign time1        = time1_s;
assign time2        = time2_s;
assign time3        = time3_s;
assign time4        = time4_s;
assign time5        = time5_s;
assign time6        = time6_s;
assign time7        = time7_s;
assign m2clock      = ~time6_s;
assign m2clock_en_p = ~time5_s &  time6_s;
assign m2clock_en_n =  time5_s & ~time6_s;
assign clk4         = l2_s;
assign latch        = ~latchb_s;

`ifdef VERILATOR

// timing signals according to the original schematics

wire mhz8_a = !porb ? 0 : (clk ? l1 : mhz8_a);
wire mhz4_a = !porb ? 1 : (clk ? ~l2 : mhz4_a);
wire time0_a = !porb ? 0 : ( clk ? ~l3 : time0_a);
wire time1_a = !porb ? 0 : (~clk ? time0_a : time1_a);
wire time2_a = !porb ? 0 : ( clk ? time1_a : time2_a);
wire time3_a = !porb ? 0 : (~clk ? time2_a : time3_a);
wire time4_a = !porb ? 0 : ( clk ? time3_a : time4_a);
wire time5_a = !porb ? 0 : (~clk ? time4_a : time5_a);
wire time6_a = !porb ? 1 : ( clk ? time5_a : time6_a);
wire m2clock_a = ~time6_a;
wire cycsel_a = !porb ? 0 : (~clk ? time6_a : cycsel_a);
wire latchb_a = !porb ? 1 : (clk ? ~(time5_a & ~time1) : latchb_a);
wire latch_a = ~latchb_a;
//assign lcycselb = !porb ? 0 : (~clk ? ~time6 : lcycselb);

reg l1, l2, l3;

always @(negedge clk, negedge resb) begin
	if (!resb) begin
		{l1, l2} <= 0;
		l3 <= 1;
	end else begin
		l1 <= ~l1;
		l2 <= l1 ? l2 : ~l2;
		l3 <= (~l1 & ~l2) ? ~l3 : l3;
	end
end

`endif

// timing signals synchronous to clk32
// output waveforms are identical to the original

reg mhz16_s;
reg mhz8_sD, mhz8_s;
reg l2_s, l3_s;
reg mhz4_s;
reg time0_s;
reg time1_s;
reg time2_s;
reg time3_s;
reg time4_s;
reg time5_s; // addrsel
reg time6_s;
reg time7_s; // cycsel
reg latchb_s;

always @(posedge clk32, negedge resb, negedge porb) begin
	if (!porb) begin
		{ mhz16_s, mhz8_sD, mhz8_s, mhz8_en1, mhz8_en2, mhz4_s } <= 0;
		{ time0_s, time1_s, time2_s, time3_s, time4_s, time5_s, time6_s, time7_s } <= 0;
		latchb_s <= 1;
	end else if (!resb) begin
		{ mhz16_s, mhz8_sD, mhz8_s, mhz8_en1, mhz8_en2, mhz4_s } <= 0;
		l2_s <= 0;
		l3_s <= 1;
	end else begin
		{ mhz8_en1, mhz8_en2, mhz4_en } <= 0;
		mhz16_s <= ~mhz16_s;
		if ( mhz16_s) mhz8_sD <= ~mhz8_sD;
		if (~mhz16_s) mhz8_s <= mhz8_sD;
		if ( mhz16_s & ~mhz8_s) mhz8_en1 <= 1;
		if ( mhz16_s &  mhz8_s) mhz8_en2 <= 1;

		if ( mhz16_s & ~mhz8_s) l2_s <= ~l2_s;
		if (~mhz16_s & ~mhz8_s) mhz4_s <= ~l2_s;
		if ( mhz16_s & ~mhz8_s & l2_s) mhz4_en <= 1;

		if (mhz16_s & ~l2_s & ~mhz8_s) l3_s <= ~l3_s;
		if (~mhz16_s) time0_s <= turbo ? ~l2_s : ~l3_s;
		if ( mhz16_s) time1_s <= time0_s;
		if (~mhz16_s) time2_s <= time1_s;
		if ( mhz16_s) time3_s <= time2_s;
		if (~mhz16_s) time4_s <= time3_s;
		if ( mhz16_s) time5_s <= time4_s;
		if (~mhz16_s) time6_s <= time5_s;
		if ( mhz16_s) time7_s <= time6_s;

		if (~mhz16_s) latchb_s <= turbo ? ~(time2_s & ~time0_s) : ~(time5_s & ~time1_s);

	end
end

endmodule
