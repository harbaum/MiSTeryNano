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

// Delay stage
// use for long delays

module jt49_dly #(parameter DW=8, depth=10)(
    input                clk,
    input                cen,
    input                rst,
    input         [7:0]  din,
    output reg    [7:0]  dout,
    output reg    [7:0]  pre_dout

);

reg [depth-1:0] rdpos, wrpos;


// memory
reg [DW-1:0] ram[0:2**depth-1];
always @(posedge clk) 
    if(rst)
        pre_dout <= {DW{1'b0}};
    else begin
        pre_dout <= ram[rdpos];
        if( cen ) ram[wrpos] <= din;
    end

`ifdef SIMULATION
integer k;
initial begin
    for(k=0;k<=2**depth-1;k=k+1)
        ram[k] = 0;
end
`endif

always @(posedge clk)
    if( rst ) begin
        rdpos <= { {depth-1{1'b0}}, 1'b1};
        wrpos <= {depth{1'b1}};
        dout <= {DW{1'b0}};
    end else if(cen) begin
        dout <= pre_dout;
        rdpos <= rdpos+1'b1;
        wrpos <= wrpos+1'b1;
    end

endmodule // jt49_dly