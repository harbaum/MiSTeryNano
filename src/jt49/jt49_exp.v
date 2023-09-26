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


// Compression vs dynamic range
// 0 -> 43.6dB
// 1 -> 29.1
// 2 -> 21.8
// 3 -> 13.4

module jt49_exp(
    input            clk,
    input      [1:0] comp,  // compression
    input      [4:0] din,
    output reg [7:0] dout 
);

reg [7:0] lut[0:127];

always @(posedge clk)
    dout <= lut[ {comp,din} ];

initial begin
    lut[0] = 8'd0;
    lut[1] = 8'd1;
    lut[2] = 8'd1;
    lut[3] = 8'd1;
    lut[4] = 8'd2;
    lut[5] = 8'd2;
    lut[6] = 8'd3;
    lut[7] = 8'd3;
    lut[8] = 8'd4;
    lut[9] = 8'd5;
    lut[10] = 8'd6;
    lut[11] = 8'd7;
    lut[12] = 8'd9;
    lut[13] = 8'd11;
    lut[14] = 8'd13;
    lut[15] = 8'd15;
    lut[16] = 8'd18;
    lut[17] = 8'd22;
    lut[18] = 8'd26;
    lut[19] = 8'd31;
    lut[20] = 8'd37;
    lut[21] = 8'd45;
    lut[22] = 8'd53;
    lut[23] = 8'd63;
    lut[24] = 8'd75;
    lut[25] = 8'd90;
    lut[26] = 8'd107;
    lut[27] = 8'd127;
    lut[28] = 8'd151;
    lut[29] = 8'd180;
    lut[30] = 8'd214;
    lut[31] = 8'd255;
    lut[32] = 8'd0;
    lut[33] = 8'd7;
    lut[34] = 8'd8;
    lut[35] = 8'd10;
    lut[36] = 8'd11;
    lut[37] = 8'd12;
    lut[38] = 8'd14;
    lut[39] = 8'd15;
    lut[40] = 8'd17;
    lut[41] = 8'd20;
    lut[42] = 8'd22;
    lut[43] = 8'd25;
    lut[44] = 8'd28;
    lut[45] = 8'd31;
    lut[46] = 8'd35;
    lut[47] = 8'd40;
    lut[48] = 8'd45;
    lut[49] = 8'd50;
    lut[50] = 8'd56;
    lut[51] = 8'd63;
    lut[52] = 8'd71;
    lut[53] = 8'd80;
    lut[54] = 8'd90;
    lut[55] = 8'd101;
    lut[56] = 8'd113;
    lut[57] = 8'd127;
    lut[58] = 8'd143;
    lut[59] = 8'd160;
    lut[60] = 8'd180;
    lut[61] = 8'd202;
    lut[62] = 8'd227;
    lut[63] = 8'd255;
    lut[64] = 8'd0;
    lut[65] = 8'd18;
    lut[66] = 8'd20;
    lut[67] = 8'd22;
    lut[68] = 8'd24;
    lut[69] = 8'd26;
    lut[70] = 8'd29;
    lut[71] = 8'd31;
    lut[72] = 8'd34;
    lut[73] = 8'd37;
    lut[74] = 8'd41;
    lut[75] = 8'd45;
    lut[76] = 8'd49;
    lut[77] = 8'd53;
    lut[78] = 8'd58;
    lut[79] = 8'd63;
    lut[80] = 8'd69;
    lut[81] = 8'd75;
    lut[82] = 8'd82;
    lut[83] = 8'd90;
    lut[84] = 8'd98;
    lut[85] = 8'd107;
    lut[86] = 8'd116;
    lut[87] = 8'd127;
    lut[88] = 8'd139;
    lut[89] = 8'd151;
    lut[90] = 8'd165;
    lut[91] = 8'd180;
    lut[92] = 8'd196;
    lut[93] = 8'd214;
    lut[94] = 8'd233;
    lut[95] = 8'd255;
    lut[96] = 8'd0;
    lut[97] = 8'd51;
    lut[98] = 8'd54;
    lut[99] = 8'd57;
    lut[100] = 8'd60;
    lut[101] = 8'd63;
    lut[102] = 8'd67;
    lut[103] = 8'd70;
    lut[104] = 8'd74;
    lut[105] = 8'd78;
    lut[106] = 8'd83;
    lut[107] = 8'd87;
    lut[108] = 8'd92;
    lut[109] = 8'd97;
    lut[110] = 8'd103;
    lut[111] = 8'd108;
    lut[112] = 8'd114;
    lut[113] = 8'd120;
    lut[114] = 8'd127;
    lut[115] = 8'd134;
    lut[116] = 8'd141;
    lut[117] = 8'd149;
    lut[118] = 8'd157;
    lut[119] = 8'd166;
    lut[120] = 8'd175;
    lut[121] = 8'd185;
    lut[122] = 8'd195;
    lut[123] = 8'd206;
    lut[124] = 8'd217;
    lut[125] = 8'd229;
    lut[126] = 8'd241;
    lut[127] = 8'd255;

end
endmodule
