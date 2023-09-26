/* verilator lint_off UNOPTFLAT */

module sndcnt (
    input         porb,
    input         lresb,
    input         sndclk,
    input         sframe,
    input  [21:1] sfb,
    output [21:1] snd
);

wire c = sndclk;
wire xr = porb & lresb;
wire l = ~sframe;
wire [21:0] co;

// counter
// 1-7

lt2 ph017 (
	.c(c),
	.l(l),
	.dl(sfb[1]),
	.dc(~snd[1]),
	.xr(xr),
	.q(snd[1]),
	.xq()
);

cb1 ph018 (
	.c(c),
	.l(l),
	.d(sfb[2]),
	.ch(snd[1]),
	.xr(xr),
	.q(snd[2]),
	.xq(),
	.co(co[2])
);

cbn ph019 (
	.c(c),
	.l(l),
	.d(sfb[3]),
	.ci(co[2]),
	.xr(xr),
	.q(snd[3]),
	.xq(),
	.co(co[3])
);


cbn ph020 (
	.c(c),
	.l(l),
	.d(sfb[4]),
	.ci(co[3]),
	.xr(xr),
	.q(snd[4]),
	.xq(),
	.co(co[4])
);

cbn ph021 (
	.c(c),
	.l(l),
	.d(sfb[5]),
	.ci(co[4]),
	.xr(xr),
	.q(snd[5]),
	.xq(),
	.co(co[5])
);

cbn ph022 (
	.c(c),
	.l(l),
	.d(sfb[6]),
	.ci(co[5]),
	.xr(xr),
	.q(snd[6]),
	.xq(),
	.co(co[6])
);

cbn ph023 (
	.c(c),
	.l(l),
	.d(sfb[7]),
	.ci(co[6]),
	.xr(xr),
	.q(snd[7]),
	.xq(),
	.co(co[7])
);

//8-15

cbn ph042 (
	.c(c),
	.l(l),
	.d(sfb[8]),
	.ci(co[7]),
	.xr(xr),
	.q(snd[8]),
	.xq(),
	.co(co[8])
);

cbn ph043 (
	.c(c),
	.l(l),
	.d(sfb[9]),
	.ci(co[8]),
	.xr(xr),
	.q(snd[9]),
	.xq(),
	.co(co[9])
);

cbn ph044 (
	.c(c),
	.l(l),
	.d(sfb[10]),
	.ci(co[9]),
	.xr(xr),
	.q(snd[10]),
	.xq(),
	.co(co[10])
);

cbn ph045 (
	.c(c),
	.l(l),
	.d(sfb[11]),
	.ci(co[10]),
	.xr(xr),
	.q(snd[11]),
	.xq(),
	.co(co[11])
);

cbn ph046 (
	.c(c),
	.l(l),
	.d(sfb[12]),
	.ci(co[11]),
	.xr(xr),
	.q(snd[12]),
	.xq(),
	.co(co[12])
);

cbn ph047 (
	.c(c),
	.l(l),
	.d(sfb[13]),
	.ci(co[12]),
	.xr(xr),
	.q(snd[13]),
	.xq(),
	.co(co[13])
);

cbn ph048 (
	.c(c),
	.l(l),
	.d(sfb[14]),
	.ci(co[13]),
	.xr(xr),
	.q(snd[14]),
	.xq(),
	.co(co[14])
);

cbn ph049 (
	.c(c),
	.l(l),
	.d(sfb[15]),
	.ci(co[14]),
	.xr(xr),
	.q(snd[15]),
	.xq(),
	.co(co[15])
);

//16-21

cbn ph065 (
	.c(c),
	.l(l),
	.d(sfb[16]),
	.ci(co[15]),
	.xr(xr),
	.q(snd[16]),
	.xq(),
	.co(co[16])
);

cbn ph066 (
	.c(c),
	.l(l),
	.d(sfb[17]),
	.ci(co[16]),
	.xr(xr),
	.q(snd[17]),
	.xq(),
	.co(co[17])
);

cbn ph067 (
	.c(c),
	.l(l),
	.d(sfb[18]),
	.ci(co[17]),
	.xr(xr),
	.q(snd[18]),
	.xq(),
	.co(co[18])
);

cbn ph068 (
	.c(c),
	.l(l),
	.d(sfb[19]),
	.ci(co[18]),
	.xr(xr),
	.q(snd[19]),
	.xq(),
	.co(co[19])
);

cbn ph069 (
	.c(c),
	.l(l),
	.d(sfb[20]),
	.ci(co[19]),
	.xr(xr),
	.q(snd[20]),
	.xq(),
	.co(co[20])
);

cbn ph070 (
	.c(c),
	.l(l),
	.d(sfb[21]),
	.ci(co[20]),
	.xr(xr),
	.q(snd[21]),
	.xq(),
	.co()
);

endmodule

