
module hdegen (
    input m2clock,
    input porb,
    input mde0,
    input mde0b,
    input mde1,
    input mde1b,
    input ntsc,
    input ihsync,
    input vblank,
    input vde,
    input noscroll,
    input cpal,
    input cntsc,
    output reg hde1,
    output reg blank_n,
    output reg de
);

wire [7:0] hdec;
wire [7:0] hdecb;
wire       co1,co2,co3,co4,co5,co6;
wire       ihsyncb = porb & ~ihsync;
wire       xr = ihsyncb;
wire       m2clockb = ~m2clock;
reg        hdec0;
assign     hdec[0] = hdec0;
assign     hdecb[0] = ~hdec0;
wire       vdd = 1;
reg        hblank;

wire       hblank_set = (cntsc & hdecb[7] & hdecb[6] & hdecb[5] & hdecb[4] & hdec[3] & hdecb[2] & hdecb[1] & hdecb[0]) | // 00001000 = 8
                        (cpal  & hdecb[7] & hdecb[6] & hdecb[5] & hdecb[4] & hdec[3] & hdecb[2] & hdecb[1] &  hdec[0]);  // 00001001 = 9
wire       hblank_reset = mde1 |
                        (cntsc & hdecb[7] & hdec[6] & hdec[5] & hdec[4] & hdecb[3] & hdecb[2] & hdec[1] & hdecb[0]) |    // 01110010 = 114
                        (cpal  & hdecb[7] & hdec[6] & hdec[5] & hdec[4] & hdecb[3] & hdecb[2] & hdec[1] & hdecb[0]);     // 01110010 = 114

always @(posedge m2clockb, negedge ihsyncb) begin
	if (!ihsyncb) hblank <= 0;
	else begin
	    if (hblank_set) hblank <= 1;
	    if (hblank_reset) hblank <= 0;
	end
end

reg        hde;
wire       hde_set   = (cntsc & hdecb[7] & hdecb[6] & hdecb[5] & hdecb[4] &  hdec[3] & hdecb[2] &  hdec[1] &  hdec[0]) | // 00001011 = 11
                       (cpal  & hdecb[7] & hdecb[6] & hdecb[5] & hdecb[4] &  hdec[3] &  hdec[2] & hdecb[1] & hdecb[0]) | // 00001100 = 12
                       (mde1  & hdecb[7] & hdecb[6] & hdecb[5] & hdecb[4] & hdecb[3] & hdecb[2] &  hdec[1] & hdecb[0]);  // 00000010 = 2
wire       hde_reset = (cntsc & hdecb[7] &  hdec[6] & hdecb[5] &  hdec[4] &  hdec[3] &  hdec[2] &  hdec[1] &  hdec[0]) | // 01011101 = 95
                       (cpal  & hdecb[7] &  hdec[6] &  hdec[5] & hdecb[4] & hdecb[3] & hdecb[2] & hdecb[1] & hdecb[0]) | // 01100000 = 96
                       (mde1  & hdecb[7] & hdecb[6] &  hdec[5] & hdecb[4] &  hdec[3] & hdecb[2] &  hdec[1] &  hdec[0]);  // 00101011 = 43

reg        hde_set_r1, hde_set_r2, hde_set_r3, hde_set_r4, hde_set_r5, hde_reset_r;

always @(posedge m2clockb, negedge ihsyncb) begin
	if (!ihsyncb) begin
	    { hde_set_r1, hde_set_r2, hde_set_r3, hde_set_r4, hde_set_r5 } <= 0;
	    hde_reset_r <= 1;
	    hde <= 0;
	end else begin
	    hde_set_r1 <= hde_set;
	    hde_set_r2 <= hde_set_r1;
	    hde_set_r3 <= hde_set_r2;
	    hde_set_r4 <= hde_set_r3;
	    hde_reset_r <= hde_reset;
	    if (hde_reset) hde <= 0;
	    else if ( noscroll && ((mde1b & hde_set_r4) || (mde1 && hde_set_r1))) hde <= 1;
	    else if (!noscroll && ((mde0b & hde_set) || (mde0 && hde_set_r2))) hde <= 1;
	end
end

always @(posedge m2clock, negedge porb) begin
    if (!porb) blank_n <= 1;
    else blank_n <= hblank & vblank;

    if (!porb) hde1 <= 0;
    else hde1 <= hde;

    if (!porb) de <= 1;
    else de <= hde & vde;
end

// counter

always @(posedge m2clockb, negedge xr) begin
    if (!xr) hdec0 <= 0;
    else hdec0 <= ~hdec0;
end

nlcb1 cnt1 (
	.c(m2clockb),
	.xr(xr),
	.xs(vdd),
	.ch(hdec[0]),
	.co(co1),
	.q(hdec[1]),
	.xq(hdecb[1])
);

nlcbn cnt2 (
	.c(m2clockb),
	.xr(xr),
	.xs(vdd),
	.ci(co1),
	.co(co2),
	.q(hdec[2]),
	.xq(hdecb[2])
);

nlcbn cnt3 (
	.c(m2clockb),
	.xr(xr),
	.xs(vdd),
	.ci(co2),
	.co(co3),
	.q(hdec[3]),
	.xq(hdecb[3])
);

nlcbn cnt4 (
	.c(m2clockb),
	.xr(xr),
	.xs(vdd),
	.ci(co3),
	.co(co4),
	.q(hdec[4]),
	.xq(hdecb[4])
);

nlcbn cnt5 (
	.c(m2clockb),
	.xr(xr),
	.xs(vdd),
	.ci(co4),
	.co(co5),
	.q(hdec[5]),
	.xq(hdecb[5])
);

nlcbn cnt6 (
	.c(m2clockb),
	.xr(xr),
	.xs(vdd),
	.ci(co5),
	.co(co6),
	.q(hdec[6]),
	.xq(hdecb[6])
);

ncbms cnt7 (
	.c(m2clockb),
	.xr(xr),
	.xs(vdd),
	.ci(co6),
	.q(hdec[7]),
	.xq(hdecb[7])
);

endmodule

