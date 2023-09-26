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

// DC removal filter
// input is unsigned
// output is signed

module jt49_dcrm(
    input                clk,
    input                cen,
    input                rst,
    input         [7:0]  din,
    output reg signed [7:0]  dout
);

wire signed [7:0] ave0, ave1;

jt49_mave u_mave0(
    .clk    ( clk           ),
    .cen    ( cen           ),
    .rst    ( rst           ),
    .din    ( {1'b0, din[7:1] }  ),
    .dout   ( ave0          )
);

jt49_mave u_mave1(
    .clk    ( clk    ),
    .cen    ( cen    ),
    .rst    ( rst    ),
    .din    ( ave0   ),
    .dout   ( ave1   )
);

always @(posedge clk)
    if( cen )
        dout <= ({1'b0,din} - {ave1,1'b0})>>>1;

endmodule