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

module jt49_eg(
  (* direct_enable *) input cen,
  input           clk, // this is the divided down clock from the core
  input           step,
  input           null_period,
  input           rst_n,
  input           restart,
  input [3:0]     ctrl,
  output reg [4:0]env
);

reg inv, stop;
reg [4:0] gain;

wire CONT = ctrl[3];
wire ATT  = ctrl[2];
wire ALT  = ctrl[1];
wire HOLD = ctrl[0];

wire will_hold = !CONT || HOLD;

always @(posedge clk)
    if( cen ) env <= inv ? ~gain : gain;

reg  last_step;
wire step_edge = (step && !last_step) || null_period;
wire will_invert = (!CONT&&ATT) || (CONT&&ALT);
reg  rst_latch, rst_clr;

always @(posedge clk) begin
    if( restart ) rst_latch <= 1;
    else if(rst_clr ) rst_latch <= 0;
end

always @( posedge clk, negedge rst_n )
    if( !rst_n) begin
        gain    <= 5'h1F;
        inv     <= 0;
        stop    <= 0;
        rst_clr <= 0;
    end
    else if( cen ) begin
        last_step <= step;
        if( rst_latch ) begin
            gain    <= 5'h1F;
            inv     <= ATT;
            stop    <= 1'b0;
            rst_clr <= 1;
        end
        else begin
            rst_clr <= 0;
            if (step_edge && !stop) begin
                if( gain==5'h00 ) begin
                    if( will_hold )
                        stop <= 1'b1;
                    else
                        gain <= gain-5'b1;
                    if( will_invert ) inv<=~inv;
                end
                else gain <= gain-5'b1;
            end
        end
    end

endmodule
