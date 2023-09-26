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
		input [7:0] keyboard_matrix[14:0],
	     
		// digital joystick with one fire button (FRLDU) or mouse with two buttons
		input [4:0] joystick1, // regular joystick
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
			      .DI(),
			      
                              .PI1(matrix_out),
			      .PI2({po2[4], rx, ~fire_buttons, po2[0]}),
                              .PI4(pi4),
			      .PO1(),
			      .PO2(po2)
	      );

   wire [7:0] matrix_out =
	      (!po3[1]?keyboard_matrix[0]:8'hff)&
	      (!po3[2]?keyboard_matrix[1]:8'hff)&
	      (!po3[3]?keyboard_matrix[2]:8'hff)&
	      (!po3[4]?keyboard_matrix[3]:8'hff)&
	      (!po3[5]?keyboard_matrix[4]:8'hff)&
	      (!po3[6]?keyboard_matrix[5]:8'hff)&
	      (!po3[7]?keyboard_matrix[6]:8'hff)&
	      (!po4[0]?keyboard_matrix[7]:8'hff)&
	      (!po4[1]?keyboard_matrix[8]:8'hff)&
	      (!po4[2]?keyboard_matrix[9]:8'hff)&
	      (!po4[3]?keyboard_matrix[10]:8'hff)&
	      (!po4[4]?keyboard_matrix[11]:8'hff)&
	      (!po4[5]?keyboard_matrix[12]:8'hff)&
	      (!po4[6]?keyboard_matrix[13]:8'hff)&
	      (!po4[7]?keyboard_matrix[14]:8'hff);
   
endmodule
