
module hsyncgen (
    input m2clock,
    input resb,
    input porb,
    input mde1b,
    input mde1,
    input interlace,
    input ntsc,
    output reg iihsync,
    output vertclk
);

wire [6:0] hsc;
wire [6:0] hscb;
wire       resbl = ~(~resb | ~porb);
wire       co1,co2,co3,co4,co5;
reg        load;
wire       vss = 0;

assign     vertclk = ~load;

wire ihsync_set_n = ((hsc[0] & hscb[1] &  hsc[2]) & (hscb[3] & hscb[4] & mde1b) & (hsc[5] & hsc[6])) | // 1100101 = 101
                    ((hsc[0] & hscb[1] & hscb[2]) & ( hsc[3] &  hsc[4] & mde1 ) & (hsc[5] & hsc[6]));  // 1111001 = 121
wire ihsync_res_n = ((hsc[0] &  hsc[1] &  hsc[2]) & ( hsc[3] & hscb[4] & mde1b) & (hsc[5] & hsc[6])) | // 1101111 = 111
                    ((hsc[0] &  hsc[1] &  hsc[2]) & ( hsc[3] &  hsc[4] & mde1 ) & (hsc[5] & hsc[6]));  // 1111111 = 127


always @(posedge m2clock, negedge resbl) begin
    if (!resbl) load <= 0;
    else load <= ~hscb[6] & ~co5;

    if (!resbl) iihsync <= 1;
    else if (ihsync_set_n) iihsync <= 0;
    else if (ihsync_res_n) iihsync <= 1;
end

lt2 cnt0 (
	.c(m2clock),
	.l(load),
	.dl(~(ntsc & mde1b)),
	.dc(hscb[0]),
	.xr(resbl),
	.q(hsc[0]),
	.xq(hscb[0])
);

cb1 cnt1 (
	.c(m2clock),
	.l(load),
	.d(ntsc & mde1b),
	.ch(hsc[0]),
	.xr(resbl),
	.q(hsc[1]),
	.xq(hscb[1]),
	.co(co1)
);

cbn cnt2 (
	.c(m2clock),
	.l(load),
	.d(vss),
	.ci(co1),
	.xr(resbl),
	.q(hsc[2]),
	.xq(hscb[2]),
	.co(co2)
);

cbn cnt3 (
	.c(m2clock),
	.l(load),
	.d(mde1),
	.ci(co2),
	.xr(resbl),
	.q(hsc[3]),
	.xq(hscb[3]),
	.co(co3)
);

cbn cnt4 (
	.c(m2clock),
	.l(load),
	.d(vss),
	.ci(co3),
	.xr(resbl),
	.q(hsc[4]),
	.xq(hscb[4]),
	.co(co4)
);

cbn cnt5 (
	.c(m2clock),
	.l(load),
	.d(vss),
	.ci(co4),
	.xr(resbl),
	.q(hsc[5]),
	.xq(hscb[5]),
	.co(co5)
);

cbms cnt6 (
	.c(m2clock),
	.l(load),
	.d(mde1 | interlace),
	.ci(co5),
	.xr(resbl),
	.q(hsc[6]),
	.xq(hscb[6])
);
endmodule

