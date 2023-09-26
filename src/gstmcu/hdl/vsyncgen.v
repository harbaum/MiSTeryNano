
module vsyncgen (
    input vertclk,
    input resb,
    input porb,
    input mde1b,
    input mde1,
    input interlace,
    input ntsc,
    output reg iivsync
);

wire [8:0] vsc;
wire [8:0] vscb;
wire       resbm = ~(~resb | ~porb);
wire       co1,co2,co3,co4,co5,co6,co7;
reg        load;
wire       vss = 0;
wire       vdd = 1;

wire ivsync_set_n = ((vscb[0] & vsc[1] & mde1) & (vsc[2] & vsc[3] & vsc[4]) & (vsc[5] & vsc[6] & vsc[7] & vsc[8])) |  //111111110
                    ((vscb[0] & vscb[1] & mde1b) & (vsc[2] & vsc[3] & vsc[4]) & (vsc[5] & vsc[6] & vsc[7] & vsc[8])); //111111100


always @(posedge vertclk, negedge resbm) begin
    if (!resbm) load <= 1;
    else load <= ~vscb[8] & ~co7;

    if (!resbm) iivsync <= 1;
    else if (~vscb[8] & ~co7) iivsync <= 1;
    else if (ivsync_set_n) iivsync <= 0;
end

lt2 cnt0 (
	.c(vertclk),
	.l(load),
	.dl(vss),
	.dc(vscb[0]),
	.xr(resbm),
	.q(vsc[0]),
	.xq(vscb[0])
);

cb1 cnt1 (
	.c(vertclk),
	.l(load),
	.d(mde1b & ntsc),
	.ch(vsc[0]),
	.xr(resbm),
	.q(vsc[1]),
	.xq(vscb[1]),
	.co(co1)
);

cbn cnt2 (
	.c(vertclk),
	.l(load),
	.d(mde1),
	.ci(co1),
	.xr(resbm),
	.q(vsc[2]),
	.xq(vscb[2]),
	.co(co2)
);

cbn cnt3 (
	.c(vertclk),
	.l(load),
	.d(vdd),
	.ci(co2),
	.xr(resbm),
	.q(vsc[3]),
	.xq(vscb[3]),
	.co(co3)
);

cbn cnt4 (
	.c(vertclk),
	.l(load),
	.d(mde1b & ntsc),
	.ci(co3),
	.xr(resbm),
	.q(vsc[4]),
	.xq(vscb[4]),
	.co(co4)
);

cbn cnt5 (
	.c(vertclk),
	.l(load),
	.d(mde1b & ntsc),
	.ci(co4),
	.xr(resbm),
	.q(vsc[5]),
	.xq(vscb[5]),
	.co(co5)
);

cbn cnt6 (
	.c(vertclk),
	.l(load),
	.d(mde1b),
	.ci(co5),
	.xr(resbm),
	.q(vsc[6]),
	.xq(vscb[6]),
	.co(co6)
);

cbn cnt7 (
	.c(vertclk),
	.l(load),
	.d(mde1b),
	.ci(co6),
	.xr(resbm),
	.q(vsc[7]),
	.xq(vscb[7]),
	.co(co7)
);

cbms cnt8 (
	.c(vertclk),
	.l(load),
	.d(vss),
	.ci(co7),
	.xr(resbm),
	.q(vsc[8]),
	.xq(vscb[8])
);
endmodule

