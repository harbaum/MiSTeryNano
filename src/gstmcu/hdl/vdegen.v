
module vdegen (
    input porb,
    input mde1,
    input cpal,
    input cntsc,
    input ihsync,
    input ivsync,
    output reg vde,
    output reg vblank
);

wire [8:0] vdec;
wire [8:0] vdecb;
wire       clk = ~ihsync;
wire       co1,co2,co3,co4,co5,co6,co7;
wire       xr = porb & ~ivsync;
reg        vdec0;
assign     vdec[0] = vdec0;
assign     vdecb[0] = ~vdec0;
wire       vdd = 1;

wire       wxx0 = vdecb[2] & vdecb[1] & vdecb[0];
wire       wxx1 = vdecb[2] & vdecb[1] &  vdec[0];
wire       wxx3 = vdecb[2] &  vdec[1] &  vdec[0];
wire       wxx6 =  vdec[2] &  vdec[1] & vdecb[0];
wire       wxx7 =  vdec[2] &  vdec[1] &  vdec[0];

wire       wx0x = vdecb[5] & vdecb[4] & vdecb[3];
wire       wx1x = vdecb[5] & vdecb[4] &  vdec[3];
wire       wx3x = vdecb[5] &  vdec[4] &  vdec[3];
wire       wx4x =  vdec[5] & vdecb[4] & vdecb[3];
wire       wx5x =  vdec[5] & vdecb[4] &  vdec[3];
wire       wx6x =  vdec[5] &  vdec[4] & vdecb[3];
wire       wx7x =  vdec[5] &  vdec[4] &  vdec[3];

wire       w0xx = vdecb[8] & vdecb[7] & vdecb[6];
wire       w3xx = vdecb[8] &  vdec[7] &  vdec[6];
wire       w4xx =  vdec[8] & vdecb[7] & vdecb[6];
wire       w6xx =  vdec[8] &  vdec[7] & vdecb[6];

wire       vblank_set =   (cpal & w0xx & wx3x & wxx0) | (cntsc & w0xx & wx1x & wxx7);        // 0030 = 24, 0017 = 15
wire       vblank_reset = mde1 | (cpal & w4xx & wx6x & wxx3) | (cntsc & w4xx & wx0x & wxx1); // 0463 = 307, 0401 = 257

wire       vde_set =      (mde1 & w0xx & wx4x & wxx3) | (cpal & w0xx & wx7x & wxx6) | (cntsc & w0xx & wx4x & wxx1); // 0043 = 35, 0076 = 62, 0041 = 33
wire       vde_reset =    (mde1 & w6xx & wx6x & wxx3) | (cpal & w4xx & wx0x & wxx6) | (cntsc & w3xx & wx5x & wxx1); // 0663 = 435, 0406 = 262, 0351 = 233


always @(posedge clk, negedge xr) begin
	if (!xr) vblank <= 0;
	else begin
	    if (vblank_set) vblank <= 1;
	    if (vblank_reset) vblank <= 0;
	end

	if (!xr) vde <= 0;
	else begin
	    if (vde_set) vde <= 1;
	    if (vde_reset) vde <= 0;
	end

end

// counter
always @(posedge clk, negedge xr) begin
	if (!xr) vdec0 <= 0;
	else vdec0 <= ~vdec0;
end

nlcb1 cnt1 (
	.c(clk),
	.xr(xr),
	.xs(vdd),
	.ch(vdec[0]),
	.co(co1),
	.q(vdec[1]),
	.xq(vdecb[1])
);

nlcbn cnt2 (
	.c(clk),
	.xr(xr),
	.xs(vdd),
	.ci(co1),
	.co(co2),
	.q(vdec[2]),
	.xq(vdecb[2])
);

nlcbn cnt3 (
	.c(clk),
	.xr(xr),
	.xs(vdd),
	.ci(co2),
	.co(co3),
	.q(vdec[3]),
	.xq(vdecb[3])
);

nlcbn cnt4 (
	.c(clk),
	.xr(xr),
	.xs(vdd),
	.ci(co3),
	.co(co4),
	.q(vdec[4]),
	.xq(vdecb[4])
);

nlcbn cnt5 (
	.c(clk),
	.xr(xr),
	.xs(vdd),
	.ci(co4),
	.co(co5),
	.q(vdec[5]),
	.xq(vdecb[5])
);

nlcbn cnt6 (
	.c(clk),
	.xr(xr),
	.xs(vdd),
	.ci(co5),
	.co(co6),
	.q(vdec[6]),
	.xq(vdecb[6])
);

nlcbn cnt7 (
	.c(clk),
	.xr(xr),
	.xs(vdd),
	.ci(co6),
	.co(co7),
	.q(vdec[7]),
	.xq(vdecb[7])
);

ncbms cnt8 (
	.c(clk),
	.xr(xr),
	.xs(vdd),
	.ci(co7),
	.q(vdec[8]),
	.xq(vdecb[8])
);

endmodule

