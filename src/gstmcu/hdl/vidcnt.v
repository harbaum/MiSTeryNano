
module vidcnt (
    input         porb,
    input         vidb,
    input         vidclkb,
    input  [ 7:0] hoff,
    input  [21:1] vld,
    input         frame,
    input         wloclb,
    input         wlocmb,
    input         wlochb,
    output [21:1] vid
);

reg pf071;
wire c = ~vidclkb;
wire r = pf071 & vidb;
wire xll = !(!wloclb | !frame);
wire xlm = !(!wlocmb | !frame);
wire xlh = !(!wlochb | !frame);

/* verilator lint_off UNOPTFLAT */

wire rr = ~(!porb | !frame | !wlochb | !wlocmb | !wloclb);
wire [21:0] co;
wire [21:0] ao;

always @(posedge vidb, negedge rr)
    if (!rr) pf071 <= 0; else pf071 <= 1;

// counter
// 1-7
rlc0 pf010 (
    .dl(vld[1]),
    .dr(hoff[0]),
    .prb(porb),
    .xl(xll),
    .r(r),
    .xr(~r),
    .c(c),
    .q(vid[1]),
    .xq(co[1]),
    .ao(ao[1])
);

rlc1 pf011 (
    .dl(vld[2]),
    .dr(hoff[1]),
    .ai(ao[1]),
    .i(vid[1]),
    .prb(porb),
    .xl(xll),
    .r(r),
    .xr(~r),
    .c(c),
    .q(vid[2]),
    .ao(ao[2]),
    .co(co[2])
);

rlc2 pf012 (
    .dl(vld[3]),
    .dr(hoff[2]),
    .ai(ao[2]),
    .xi(co[2]),
    .prb(porb),
    .xl(xll),
    .r(r),
    .xr(~r),
    .c(c),
    .q(vid[3]),
    .ao(ao[3]),
    .co(co[3])
);

rlc2 pf013 (
    .dl(vld[4]),
    .dr(hoff[3]),
    .ai(ao[3]),
    .xi(co[3]),
    .prb(porb),
    .xl(xll),
    .r(r),
    .xr(~r),
    .c(c),
    .q(vid[4]),
    .ao(ao[4]),
    .co(co[4])
);

rlc2 pf014 (
    .dl(vld[5]),
    .dr(hoff[4]),
    .ai(ao[4]),
    .xi(co[4]),
    .prb(porb),
    .xl(xll),
    .r(r),
    .xr(~r),
    .c(c),
    .q(vid[5]),
    .ao(ao[5]),
    .co(co[5])
);

rlc2 pf015 (
    .dl(vld[6]),
    .dr(hoff[5]),
    .ai(ao[5]),
    .xi(co[5]),
    .prb(porb),
    .xl(xll),
    .r(r),
    .xr(~r),
    .c(c),
    .q(vid[6]),
    .ao(ao[6]),
    .co(co[6])
);

rlc2 pf016 (
    .dl(vld[7]),
    .dr(hoff[6]),
    .ai(ao[6]),
    .xi(co[6]),
    .prb(porb),
    .xl(xll),
    .r(r),
    .xr(~r),
    .c(c),
    .q(vid[7]),
    .ao(ao[7]),
    .co(co[7])
);

// 8-15
rlc2 pf026 (
    .dl(vld[8]),
    .dr(hoff[7]),
    .ai(ao[7]),
    .xi(co[7]),
    .prb(porb),
    .xl(xll),
    .r(r),
    .xr(~r),
    .c(c),
    .q(vid[8]),
    .ao(ao[8]),
    .co(co[8])
);

rlc3 pf027 (
    .dl(vld[9]),
    .ai(ao[8]),
    .xi(co[8]),
    .prb(porb),
    .xl(xll),
    .r(r),
    .xr(~r),
    .c(c),
    .q(vid[9]),
    .ao(ao[9]),
    .co(co[9])
);

rlc3 pf029 (
    .dl(vld[10]),
    .ai(ao[9]),
    .xi(co[9]),
    .prb(porb),
    .xl(xll),
    .r(r),
    .xr(~r),
    .c(c),
    .q(vid[10]),
    .ao(ao[10]),
    .co(co[10])
);

rlc3 pf031 (
    .dl(vld[11]),
    .ai(ao[10]),
    .xi(co[10]),
    .prb(porb),
    .xl(xll),
    .r(r),
    .xr(~r),
    .c(c),
    .q(vid[11]),
    .ao(ao[11]),
    .co(co[11])
);

rlc3 pf033 (
    .dl(vld[12]),
    .ai(ao[11]),
    .xi(co[11]),
    .prb(porb),
    .xl(xll),
    .r(r),
    .xr(~r),
    .c(c),
    .q(vid[12]),
    .ao(ao[12]),
    .co(co[12])
);

rlc3 pf035 (
    .dl(vld[13]),
    .ai(ao[12]),
    .xi(co[12]),
    .prb(porb),
    .xl(xll),
    .r(r),
    .xr(~r),
    .c(c),
    .q(vid[13]),
    .ao(ao[13]),
    .co(co[13])
);

rlc3 pf037 (
    .dl(vld[14]),
    .ai(ao[13]),
    .xi(co[13]),
    .prb(porb),
    .xl(xll),
    .r(r),
    .xr(~r),
    .c(c),
    .q(vid[14]),
    .ao(ao[14]),
    .co(co[14])
);

rlc3 pf039 (
    .dl(vld[15]),
    .ai(ao[14]),
    .xi(co[14]),
    .prb(porb),
    .xl(xll),
    .r(r),
    .xr(~r),
    .c(c),
    .q(vid[15]),
    .ao(ao[15]),
    .co(co[15])
);

// 16-21

rlc3 pf050 (
    .dl(vld[16]),
    .ai(ao[15]),
    .xi(co[15]),
    .prb(porb),
    .xl(xll),
    .r(r),
    .xr(~r),
    .c(c),
    .q(vid[16]),
    .ao(ao[16]),
    .co(co[16])
);

rlc3 pf052 (
    .dl(vld[17]),
    .ai(ao[16]),
    .xi(co[16]),
    .prb(porb),
    .xl(xll),
    .r(r),
    .xr(~r),
    .c(c),
    .q(vid[17]),
    .ao(ao[17]),
    .co(co[17])
);

rlc3 pf054 (
    .dl(vld[18]),
    .ai(ao[17]),
    .xi(co[17]),
    .prb(porb),
    .xl(xll),
    .r(r),
    .xr(~r),
    .c(c),
    .q(vid[18]),
    .ao(ao[18]),
    .co(co[18])
);

rlc3 pf056 (
    .dl(vld[19]),
    .ai(ao[18]),
    .xi(co[18]),
    .prb(porb),
    .xl(xll),
    .r(r),
    .xr(~r),
    .c(c),
    .q(vid[19]),
    .ao(ao[19]),
    .co(co[19])
);

rlc3 pf058 (
    .dl(vld[20]),
    .ai(ao[19]),
    .xi(co[19]),
    .prb(porb),
    .xl(xll),
    .r(r),
    .xr(~r),
    .c(c),
    .q(vid[20]),
    .ao(ao[20]),
    .co(co[20])
);

rlc3 pf059 (
    .dl(vld[21]),
    .ai(ao[20]),
    .xi(co[20]),
    .prb(porb),
    .xl(xll),
    .r(r),
    .xr(~r),
    .c(c),
    .q(vid[21]),
    .ao(),
    .co()
);

endmodule
