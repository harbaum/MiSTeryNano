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
    Date: 10-Nov-2018
    
    Based on sqmusic, by the same author
    
    */


module jt49_noise(
  (* direct_enable *) input cen,
    input       clk,
    input       rst_n,
    input [4:0] period,
    output reg  noise
);

reg [5:0]count;
reg [16:0]poly17;
wire poly17_zero = poly17==17'b0;
wire noise_en;
reg last_en;

wire noise_up = noise_en && !last_en;

always @(posedge clk ) if(cen) begin
    noise <= ~poly17[0];
end

always @( posedge clk, negedge rst_n )
  if( !rst_n ) 
    poly17 <= 17'd0;
  else if( cen ) begin
    last_en <= noise_en;
    if( noise_up )
        poly17 <= { poly17[0] ^ poly17[3] ^ poly17_zero, poly17[16:1] };
  end

jt49_div #(5) u_div( 
  .clk    ( clk       ), 
  .cen    ( cen       ),
  .rst_n  ( rst_n     ), 
  .period ( period    ), 
  .div    ( noise_en  ) 
);

endmodule