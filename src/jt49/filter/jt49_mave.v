/*  This file is part of JT49.

    JT49 is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT49 is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT49.  If not, see <http://www.gnu.org/licenses/>.
    
    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-Jan-2019
    
    */

// Moving averager

module jt49_mave #(parameter depth=8, DW=8)(
    input                   clk,
    input                   cen,
    input                   rst,
    input  signed [DW-1:0]  din,
    output signed [DW-1:0]  dout
);

wire [DW-1:0] dly0;
wire [DW-1:0] pre_dly0;

jt49_dly #(.depth(depth),.DW(DW)) u_dly0(
    .clk        ( clk       ),
    .cen        ( cen       ),
    .rst        ( rst       ),
    .din        ( din       ),
    .dout       ( dly0      ),
    .pre_dout   ( pre_dly0  )
);

// moving average
// D=2048 
reg signed [DW:0] diff;
reg signed [DW+depth-1:0] sum;


always @(posedge clk)
    if( rst ) begin
        diff <= {DW+1{1'd0}};
        sum  <= {DW+depth+1{1'd0}};
    end else if(cen) begin
        diff <= {1'b0,din } - { 1'b0, dly0 };
        sum  <= { {depth{diff[DW]}}, diff } + sum;
    end
assign dout = sum[DW+depth-1:depth];

endmodule