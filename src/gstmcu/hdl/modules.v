

module ncbms (
	input       c,
	input       xs,
	input       xr,
	input       ci,
	output      q,
	output      xq
);

reg dprs;
wire d = ci ? dprs : ~dprs;
assign q = dprs;
assign xq = ~dprs;

always @(posedge c, negedge xr, negedge xs) begin

	if (!xr) dprs <= 0;
	else if (!xs) dprs <= 1;
	else dprs <= d;
end

endmodule


module nlcbn (
	input       c,
	input       xs,
	input       xr,
	input       ci,
	output      co,
	output      q,
	output      xq
);

reg dprs;
wire d = ci ? dprs : ~dprs;
assign co = ~(~ci & dprs);
assign q = dprs;
assign xq = ~dprs;

always @(posedge c, negedge xr, negedge xs) begin

	if (!xr) dprs <= 0;
	else if (!xs) dprs <= 1;
	else dprs <= d;
end

endmodule

module nlcb1 (
	input       c,
	input       xs,
	input       xr,
	input       ch,
	output      co,
	output      q,
	output      xq
);

wire d = ch ? ~dprs : dprs;
assign co = ~(ch & dprs);
assign q = dprs;
assign xq = ~dprs;
reg dprs;

always @(posedge c, negedge xr, negedge xs) begin

	if (!xr) dprs <= 0;
	else if (!xs) dprs <= 1;
	else dprs <= d;
end

endmodule

module cbms (
	input       c,
	input       l,
	input       d,
	input       ci,
	input       xr,
	output      q,
	output      xq
);

reg dc;

lt2 lt2 (
	.xr(xr),
	.c(c),
	.l(l),
	.dl(d),
	.dc(dc),
	.q(q),
	.xq(xq)
);

always @(*) begin
    dc = ci ? q : xq;
end

endmodule

module cbn (
	input       c,
	input       l,
	input       d,
	input       ci,
	input       xr,
	output      q,
	output      xq,
	output reg  co
);

reg dc;

lt2 lt2 (
	.xr(xr),
	.c(c),
	.l(l),
	.dl(d),
	.dc(dc),
	.q(q),
	.xq(xq)
);

always @(*) begin
    dc = ci ? q : xq;
    co = ~(~ci & q);
end

endmodule


module cb1 (
	input       c,
	input       l,
	input       d,
	input       ch,
	input       xr,
	output      q,
	output      xq,
	output reg  co
);

reg dc;

lt2 lt2 (
	.xr(xr),
	.c(c),
	.l(l),
	.dl(d),
	.dc(dc),
	.q(q),
	.xq(xq)
);

always @(*) begin
    dc = ch ? xq : q;
    co = ~(ch & q);
end

endmodule

/* verilator lint_off UNOPTFLAT */

module lt2 (
	input       c,
	input       dc,
	input       l,
	input       dl,
	input       xr,
	output      q,
	output reg  xq
);

assign q = ~xq;

/* 4081ORG.PDF - dc and load are sync */
/*
always @(posedge c, negedge xr) begin
    if (!xr) xq <= 1;
    else xq <= l ? ~dl : ~dc;
end;
*/
/* ST4081S.PDF - dc is sync, load is async */
/*
wire mc104 = xr & (c ? mc105 : dc);
wire mc105 = l ? dl : mc104;
assign xq = !xr ? 1 : (c ? ~mc104 : xq);
*/

/* And this works the best... */
always @(posedge c, posedge l, negedge xr) begin
    if (!xr) xq <= 1;
    else if (l) xq <= ~dl;
    else xq <= ~dc;
end;

endmodule

module rlc0 (
	input	dr,
	input	r,
	input	dl,
	input	xl,
	input	xr,
	input	c,
//	input	xc,
	input	prb,
	output	ao,
	output	q,
	output xq
);

wire xc = ~c;

wire mc907 = ~(xl ? mc909 : dl);
wire mc909 = xr ? mc912 : mc903;
wire mc912 = ~(c ? mc907 : ~mc908);
wire mc908 = !prb ? 0 : (c ? mc907 : mc908);
wire mc903 = !prb ? 0 : (!r ? ~mc908 ^ dr : mc903);
assign q = ~mc908;
assign xq = mc909;
assign ao = dr & ~mc908;
/*

assign ao = dr & q;
assign xq = ~q;

always @(posedge c, negedge prb, negedge r, negedge xl) begin
    if (!prb) q <= 1;
    else if(!r) q <= dr ^ q;
    else if(!xl) q <= dl;
    else q <= ~q;
end
*/

endmodule

module rlc1 (
	input	dl,
	input	dr,
	input	ai,
	input	i,
//	input	xi,
	input	xl,
	input	r,
	input	xr,
	input	c,
//	input	xc,
	input	prb,
	output	ao,
	output	q,
	output co
);

wire xc = ~c;
wire xi = ~i;

wire mca04 = !prb ? 0 : (!r ? (dr ^ q) ^ ai : mca04);
wire mca09 = ~(xl ? mca12 : dl);
wire mca12 = xr ? mca16 : mca04;
wire mca16 = ~(c ? mca09 : mca11);
wire mca11 = i ? ~mca10 : mca10;
wire mca10 = !prb ? 0 : (c ? mca09 : mca10);
assign q = ~mca10;
assign co = ~(i & q);
assign ao = (dr & q) | (dr & ai) | (q & ai); // MAND gate

/*
assign ao = dr & q;

always @(posedge c, negedge prb, negedge r, negedge xl) begin
    if (!prb) q <= 1;
    else if(!r) q <= dr ^ q;
    else if(!xl) q <= dl
    else q <= ~q;
end
*/
endmodule

module rlc2 (
	input	dl,
	input	dr,
	input	ai,
//	input	i,
	input	xi,
	input	xl,
	input	r,
	input	xr,
	input	c,
//	input	xc,
	input	prb,
	output	ao,
	output	q,
	output co
);

wire mcb04 = !prb ? 0 : (!r ? dr ^ q ^ ai : mcb04);
wire mcb08 = ~(xl ? mcb11 : dl);
wire mcb11 = xr ? mcb15 : mcb04;
wire mcb15 = ~(c ? mcb08 : mcb12);
wire mcb12 = xi ? mcb09 : q;
wire mcb09 = !prb ? 0 : (c ? mcb08 : mcb09);

assign q = ~mcb09;
assign co = ~(~xi & q);
assign ao = (dr & q) | (dr & ai) | (q & ai); // MAND gate

endmodule

module rlc3 (
	input	dl,
	input	ai,
//	input	i,
	input	xi,
	input	xl,
	input	r,
	input	xr,
	input	c,
//	input	xc,
	input	prb,
	output	ao,
	output	q,
	output co
);

wire mcc03 = !prb ? 0 : (!r ? ai ^ q : mcc03);
wire mcc07 = ~(xl ? mcc09 : dl); // bug on schematic?
wire mcc09 = xr ? mcc13 : mcc03;
wire mcc13 = ~(c ? mcc07 : mcc10);
wire mcc10 = xi ? mcc08 : ~mcc08;
wire mcc08 = !prb ? 0 : (c ? mcc07 : mcc08);
assign q = ~mcc08;
assign co = ~(~xi & q);
assign ao = q & ai;

endmodule
