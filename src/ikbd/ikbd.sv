//
// ikbd.v
//
// Atari ST ikbd/keyboard implementation
//

module ikbd (
	     // 2MHz clock (equals 4Mhz on a real 6301) and system reset
		input	    clk,
		input	    res,

	     // ikbd rx/tx to be connected to the 6850
		output	    tx,
 		input	    rx,

	     // caps lock output. This is present in the schematics
	     // but it is not implemented nor used in the Atari ST
		output	    caps_lock,

	     // keyboard matrix
        output [14:0] matrix_out,
		input [7:0] matrix_in,
	     
		// digital joystick with one fire button (FRLDU) or mouse with two buttons
		input [4:0] joystick1,  // regular joystick
		input [5:0] joystick0   // joystick that can replace mouse
		);

   // this implements the 74ls244. This is technically not needed in the FPGA since
   // in and out are seperate lines.
   wire [7:0] pi4 = po2[0]?8'hff:~{joystick1[3:0], joystick0[3:0]};
   // right mouse button and joystick1 fire button are connected
   wire [1:0] fire_buttons = { joystick0[5] | joystick1[4], joystick0[4] };

   // hd6301 output ports
   wire [7:0] po2, po3, po4;
   
   // P24 of the ikbd is its TX line
   assign tx = po2[4];
   // caps lock led is on P30, but isn't implemented in IKBD ROM
   assign caps_lock = po3[0];   

   HD63701V0_M6 HD63701V0_M6 (
			      .CLKx2(clk),
			      .RST(res),
			      .NMI(1'b0),
			      .IRQ(1'b0),

			      // in mode7 the cpu bus becomes
			      // io ports 3 and 4
			      .RW(),
			      .AD({po4, po3}),
			      .DO(),
			      .DI(8'h00),
			      
                  .PI1(matrix_in),
			      .PI2({po2[4], rx, ~fire_buttons, po2[0]}),
                  .PI4(pi4),
			      .PO1(),
			      .PO2(po2)
	      );

   assign matrix_out = { po4, po3[7:1] }; 
   
endmodule
