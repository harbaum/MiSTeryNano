// simulate latches in the 'clock' domain

module mlatch (
    input clock,
    input s,    // set
    input r,    // reset
    input g,    // gate
    input  [WIDTH-1:0] d, // input
    output reg [WIDTH-1:0] q  // output
);

parameter WIDTH = 1;

reg [WIDTH-1:0] val_reg;

always @(*) begin
    if (r)
        q = 0;
    else if (s)
        q = 1;
    else if (g)
        q = d;
    else
        q = val_reg;
end

always @(posedge clock) begin
    val_reg <= q;
end

endmodule