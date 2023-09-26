/* verilator lint_off UNOPTFLAT */

module mcucontrol (
    input clk32,
    input porb,
    input resb,
    input turbo,
    input clk,
    input ias,
    input idev,
    input iram,
    input iuds,
    input ilds,
    input irwz,
    input ixdmab,
    input vmapb,
    input smapb,
    input ideb,
    input hde1,
    input addrselb,
    input time0,
    input time1,
    input lcycsel,
    input cycsel_en,
    input ivsync,
    input sreq,
    input sndon,
    input sfrep,
    input [21:1] snd,
    input [21:1] sft,
    output cmpcycb,
    output ramcycb,
    output refb,
    output frame,
    output reg vidb,
    output viden,
    output vos,
    output sndclk,
    output snden, // sadsel
    output sframe,
    output stoff,
    output rdat_n,
    output we_n,
    output wdat_n,
    output cmpcs_n,
    output dcyc_n,
    output sload_n,
    output sint
);

wire c1 = ~(lcycsel & time1); // pk033
wire c1_en_p = lcycsel & time1 & clk;
wire c1_en_n = cycsel_en;
reg c1_rise, c1_fall;
always @(posedge clk32) begin
    c1_rise <= c1_en_p;
    c1_fall <= c1_en_n;
end

//////////// VIDEO CONTROL //////////
assign frame = ~pk005;
assign viden = ~vidb; // pk010
assign refb = pk016 | pk024;
assign vos = ~(vidb & ~snden);

`ifdef VERILATOR

// async implementation from the original schematic
reg pk005_a,vidb_a,pk016_a;
always @(posedge c1, negedge porb) begin
	if (!porb) { pk005_a, vidb_a, pk016_a } <= { 1'b0, 1'b1, 1'b0 };
	else begin
		pk005_a <= ivsync;
		vidb_a  <= ideb;
		pk016_a <= hde1;
	end
end

`endif

// sync to clk32 implementation
reg pk005,pk016;
always @(posedge clk32, negedge porb) begin
	if (!porb) { pk005, vidb, pk016 } <= { 1'b0, 1'b1, 1'b0 };
	else if (c1_en_p) begin
		pk005 <= ivsync;
		vidb  <= ideb;
		pk016 <= hde1;
	end
end

///////// SOUND DMA CONTROL //////

assign sndclk = ~(addrselb & snden);
assign snden = ~pk016 & pk024;


wire pk061 = (snd == sft) & ~c1;
wire sintsb = sframe;
assign stoff = pk061 & ~sfrep;

`ifdef VERILATOR

// async implementation from the original schematic
reg pk024_a,pk031_a,sint_a,sframe_a;

always @(posedge c1) begin
    pk031_a <= sndon;
end

always @(negedge clk, negedge pk031_a) begin
    if (!pk031_a) sframe_a <= 0;
    else sframe_a <= ~(pk061 & sfrep);
end;

always @(negedge c1, negedge sintsb) begin
    if (!sintsb) sint_a <= 1;
    else sint_a <= 0;
end;

always @(posedge c1, negedge pk031_a) begin
    if (!pk031_a) pk024_a <= 0;
    else pk024_a <= sreq;
end;

wire sload_n_a = !porb ? 1 : (clk ? ~(addrselb & time1 & snden) : sload_n_a); // pl031

`endif

// sync to clk32 implementation
reg pk024, pk031;

always @(posedge clk32) begin
    if (c1_en_p) pk031 <= sndon;
end

mlatch sframe_l(clk32, 1'b0, !pk031, !clk ^ turbo, ~(pk061 & sfrep), sframe);

mlatch sint_l(clk32, !sintsb, 1'b0, c1_fall, 1'b0, sint);
//always @(posedge clk32, negedge sintsb) begin
//    if (!sintsb) sint <= 1;
//    else if (c1_en_n) sint <= 0;
//end

//latch pk024_l(clk32, 0, !pk031, c1_rise, sreq, pk024);
always @(posedge clk32, negedge pk031) begin
    if (!pk031) pk024 <= 0;
    else if (c1_en_p) pk024 <= sreq;
end

mlatch sload_n_l(clk32, !porb, 1'b0, clk, ~(time1 & addrselb & snden), sload_n); // pl031

///////////////////// RAM/SHIFTER ////////////////

wire cmap = (~irwz | iuds | ilds) & (~vmapb | ~smapb) & idev & ias;
wire ramsel = (~irwz | ilds | iuds) & ias & iram;

`ifdef VERILATOR

// async implementation from the original schematic
reg ramcyc_a,cmpcyc_a;

always @(posedge lcycsel, negedge cmap) begin
    if (!cmap) cmpcyc_a <= 0;
    else cmpcyc_a <= cmap;
end;

always @(posedge lcycsel, negedge ramsel) begin
    if (!ramsel) ramcyc_a <= 0;
    else ramcyc_a <= ramsel;
end;

wire dcyc_a = !porb ? 1 : (clk ? !resb | (time1 & addrselb & viden) : dcyc_a); // pl025

`endif

// sync to clk32 implementation
reg ramcyc,cmpcyc;

always @(posedge clk32, negedge cmap) begin
    if (!cmap) cmpcyc <= 0;
    else if(cycsel_en) cmpcyc <= cmap;
end

always @(posedge clk32, negedge ramsel) begin
    if (!ramsel) ramcyc <= 0;
    else if (cycsel_en) ramcyc <= ramsel;
end

wire dcyc;
mlatch dcyc_l(clk32, !porb, 1'b0, clk ^ turbo, !resb | (time1 & addrselb & viden), dcyc); // pl025

/////

assign dcyc_n = ~dcyc;
assign cmpcycb = ~cmpcyc;
assign ramcycb = ~ramcyc;
assign we_n = ~(ramcyc & cmpcycb & ~irwz & ~time0 & ~addrselb);
assign rdat_n = ~((cmpcyc & ramcycb & irwz) | (ramcyc & cmpcycb & irwz));
assign wdat_n = ~(~we_n | (cmpcyc & ramcycb & ~irwz & ~time1 & ~addrselb));
assign cmpcs_n =~((cmpcyc & ramcycb & ~irwz & ~time1 & ~addrselb) | (cmpcyc & ramcycb & irwz & lcycsel & ~time1) | ~resb);

endmodule
