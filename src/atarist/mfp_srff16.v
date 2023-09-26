//
// mfp_srff16.v
//
// 16 bit set/reset flip flop. Each bit is set on the rising edge of set
// and asynchronoulsy cleared by the corresponding reset bit.
// Asynchronous operation is emulated in a synchronous way by using the
// 32 MHz clock.
//
// https://github.com/mist-devel/mist-board
//
// Copyright (c) 2014 Till Harbaum <till@harbaum.org>
// Copyright (c) 2019-2020 Gyorgy Szombathelyi
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

module mfp_srff16 (
        input        clk,
        input [15:0] set,
        input [15:0] mask,
        input [15:0] reset,
        output reg [15:0] out
);

integer i;
always @(posedge clk) begin
	reg [15:0] setD;

	setD <= set;
	for(i=0; i<16; i=i+1) begin
		if (reset[i]) out[i] <= 0;
		else if (~setD[i] & set[i] & mask[i]) out[i] <= 1;
	end
end

endmodule
