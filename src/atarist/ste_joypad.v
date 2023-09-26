module ste_joypad (
	input      [15:0] joy,   // R3,L3,R2,L2
	                         // R,L,Y,X
	                         // Start, Select, B, A
	                         // UDLR
	input      [3:0] din,    // pins 1-4
	output reg [7:0] dout,   // pins 11-14, 1-4
	output reg [1:0] buttons // pins 10,6
);

// To account for users with a procontroller,
// X is mapped to 9, Y to 8 and Z to 7.
// L and R are mapped to 4 and 6 respectively.

always @(*) begin
	dout = 8'hff;
	buttons = 2'b11;

	//#0*U
	dout[4] = ~(/*(~din[3] & joy[xx]) | (~din[2] & joy[xx]) | (~din[1] & joy[xx]) |*/ (~din[0] & joy[3]));
	//987D
	dout[5] = ~((~din[3] & joy[8]) | (~din[2] & joy[9]) | (~din[1] & joy[12]) | (~din[0] & joy[2]));
	//654L
	dout[6] = ~((~din[3] & joy[11]) |/* (~din[2] & joy[xx]) |*/ (~din[1] & joy[10]) | (~din[0] & joy[1]));
	//321R
	dout[7] = ~(/*(~din[3] & joy[xx]) | (~din[2] & joy[xx]) | (~din[1] & joy[xx]) |*/ (~din[0] & joy[0]));
	//OCBA
	buttons[1] = ~((~din[3] & joy[7]) | (~din[2] & joy[6]) | (~din[1] & joy[5]) | (~din[0] & joy[4]));
	//Pause
	buttons[0] = ~((~din[0] & joy[13]));
end

endmodule
