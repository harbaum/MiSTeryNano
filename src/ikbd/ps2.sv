//
// ps2.v
//

module ps2 (
 input 		  clk,
 input        ena_2m,
 input 		  reset,
	    
 input 		  kbd_clk,
 input 		  kbd_data,
 output reg [7:0] matrix[14:0],
	    
 input 		  mouse_clk,
 input 		  mouse_data,
 output [5:0] 	  mouse_atari,

 output reg joy_port_toggle // F11
);

// --------- registers for keyboard decoding ---------
   reg 		  kbd_last_clk;
   reg [3:0] 	  kbd_bit_cnt;
   reg [8:0] 	  kbd_sr;
   reg 		  kbd_parity;
   reg 		  kbd_release;   // 0xf0 release code received
   reg 		  kbd_ext;       // 0xe0 extended code received

   reg 		  mouse_z_up_d, mouse_z_down_d;

always @(posedge clk) begin
    
   if (reset === 1'b1) begin
      // signal analysis
      kbd_last_clk <= 1'b1;

      // byte decoding
      kbd_bit_cnt <= 'd0;
      kbd_sr <= 'd0;
      kbd_parity <= 1'b0;

      // message decoding
      kbd_release <= 1'b0;      
      kbd_ext <= 1'b0;      
      
      joy_port_toggle <= 1'b0;

      mouse_z_up_d <= 1'b0;
      mouse_z_down_d <= 1'b0;

      // reset entire matrix to 1's
      matrix[ 0] <= 8'hff; matrix[ 1] <= 8'hff; matrix[ 2] <= 8'hff; matrix[ 3] <= 8'hff;
      matrix[ 4] <= 8'hff; matrix[ 5] <= 8'hff; matrix[ 6] <= 8'hff; matrix[ 7] <= 8'hff;
      matrix[ 8] <= 8'hff; matrix[ 9] <= 8'hff; matrix[10] <= 8'hff; matrix[11] <= 8'hff;
      matrix[12] <= 8'hff; matrix[13] <= 8'hff; matrix[14] <= 8'hff;      
      
   end else if(ena_2m) begin
      // mouse wheel keyboard emulation
      mouse_z_up_d <= mouse_z_up;
      mouse_z_down_d <= mouse_z_down;

      if (mouse_z_up ^ mouse_z_up_d) matrix[12][1] <= ~mouse_z_up; // up
      if (mouse_z_down ^ mouse_z_down_d) matrix[12][4] <= ~mouse_z_down; // down

      //  Clear flags
      kbd_last_clk <= kbd_clk;
            
      if (!kbd_clk && kbd_last_clk) begin
	 
         //  We have a new bit from the keyboard for processing
         if (kbd_bit_cnt === 0) begin
	    
            //  Idle state, check for start bit (0) only and don't
            //  start counting bits until we get it
            kbd_parity <= 1'b0;
	    
            //  This is a start bit
            if (kbd_data == 1'b0)
               kbd_bit_cnt <= kbd_bit_cnt + 1'd1;
	    
	 end else begin
	    
            if (kbd_bit_cnt < 10) begin
	       
               //  Shift in data and parity (9 bits)
               kbd_bit_cnt <= kbd_bit_cnt + 1'd1;
               kbd_sr <= {kbd_data, kbd_sr[8:1]};
               kbd_parity <= kbd_parity ^ kbd_data;
               
	    end else if (kbd_data === 1'b1 ) begin
	       
               if (kbd_parity === 1'b1) begin

		  // Parity correct, decode into matrix
		  if(kbd_sr[7:0] == 8'hf0)
		     kbd_release <= 1'b1;
		  else if(kbd_sr[7:0] == 8'he0)
		     kbd_ext <= 1'b1;
		  else begin
		     kbd_release <= 1'b0;
		     kbd_ext <= 1'b0;
		     
		     // https://techdocs.altium.com/display/FPGA/PS2+Keyboard+Scan+Codes
		     // http://www.atari-forum.com/download/file.php?id=18610
  
		     if(!kbd_ext) begin		     
			// characters
			if(kbd_sr[7:0] == 8'h1c) matrix[ 4][5] <= kbd_release; // a
			if(kbd_sr[7:0] == 8'h32) matrix[ 7][6] <= kbd_release; // b
			if(kbd_sr[7:0] == 8'h21) matrix[ 6][6] <= kbd_release; // c
			if(kbd_sr[7:0] == 8'h23) matrix[ 5][6] <= kbd_release; // d
			if(kbd_sr[7:0] == 8'h24) matrix[ 5][4] <= kbd_release; // e
			if(kbd_sr[7:0] == 8'h2b) matrix[ 6][5] <= kbd_release; // f
			if(kbd_sr[7:0] == 8'h34) matrix[ 7][4] <= kbd_release; // g
			if(kbd_sr[7:0] == 8'h33) matrix[ 7][5] <= kbd_release; // h
			if(kbd_sr[7:0] == 8'h43) matrix[ 8][4] <= kbd_release; // i
			if(kbd_sr[7:0] == 8'h3b) matrix[ 8][5] <= kbd_release; // j
			if(kbd_sr[7:0] == 8'h42) matrix[ 8][6] <= kbd_release; // k
			if(kbd_sr[7:0] == 8'h4b) matrix[ 9][5] <= kbd_release; // l
			if(kbd_sr[7:0] == 8'h3a) matrix[ 8][7] <= kbd_release; // m
			if(kbd_sr[7:0] == 8'h31) matrix[ 7][7] <= kbd_release; // n
			if(kbd_sr[7:0] == 8'h44) matrix[ 9][3] <= kbd_release; // o
			if(kbd_sr[7:0] == 8'h4d) matrix[ 9][4] <= kbd_release; // p
			if(kbd_sr[7:0] == 8'h15) matrix[ 4][4] <= kbd_release; // q
			if(kbd_sr[7:0] == 8'h2d) matrix[ 6][3] <= kbd_release; // r
			if(kbd_sr[7:0] == 8'h1b) matrix[ 5][5] <= kbd_release; // s
			if(kbd_sr[7:0] == 8'h2c) matrix[ 6][4] <= kbd_release; // t
			if(kbd_sr[7:0] == 8'h3c) matrix[ 8][3] <= kbd_release; // u
			if(kbd_sr[7:0] == 8'h2a) matrix[ 6][7] <= kbd_release; // v
			if(kbd_sr[7:0] == 8'h1d) matrix[ 5][3] <= kbd_release; // w
			if(kbd_sr[7:0] == 8'h22) matrix[ 5][7] <= kbd_release; // x
			if(kbd_sr[7:0] == 8'h35) matrix[ 7][3] <= kbd_release; // y
			if(kbd_sr[7:0] == 8'h1a) matrix[ 4][7] <= kbd_release; // z

			// top number key row
			if(kbd_sr[7:0] == 8'h16) matrix[ 4][2] <= kbd_release; // 1
			if(kbd_sr[7:0] == 8'h1e) matrix[ 5][1] <= kbd_release; // 2
			if(kbd_sr[7:0] == 8'h26) matrix[ 5][2] <= kbd_release; // 3
			if(kbd_sr[7:0] == 8'h25) matrix[ 6][1] <= kbd_release; // 4
			if(kbd_sr[7:0] == 8'h2e) matrix[ 6][2] <= kbd_release; // 5
			if(kbd_sr[7:0] == 8'h36) matrix[ 7][1] <= kbd_release; // 6
			if(kbd_sr[7:0] == 8'h3d) matrix[ 7][2] <= kbd_release; // 7
			if(kbd_sr[7:0] == 8'h3e) matrix[ 8][1] <= kbd_release; // 8
			if(kbd_sr[7:0] == 8'h46) matrix[ 8][2] <= kbd_release; // 9
			if(kbd_sr[7:0] == 8'h45) matrix[ 9][1] <= kbd_release; // 0

			// function keys
			if(kbd_sr[7:0] == 8'h05) matrix[ 1][0] <= kbd_release; // F1
			if(kbd_sr[7:0] == 8'h06) matrix[ 2][0] <= kbd_release; // F2
			if(kbd_sr[7:0] == 8'h04) matrix[ 3][0] <= kbd_release; // F3
			if(kbd_sr[7:0] == 8'h0c) matrix[ 4][0] <= kbd_release; // F4
			if(kbd_sr[7:0] == 8'h03) matrix[ 5][0] <= kbd_release; // F5
			if(kbd_sr[7:0] == 8'h0b) matrix[ 6][0] <= kbd_release; // F6
			if(kbd_sr[7:0] == 8'h83) matrix[ 7][0] <= kbd_release; // F7
			if(kbd_sr[7:0] == 8'h0a) matrix[ 8][0] <= kbd_release; // F8
			if(kbd_sr[7:0] == 8'h01) matrix[ 9][0] <= kbd_release; // F9
			if(kbd_sr[7:0] == 8'h09) matrix[10][0] <= kbd_release; // F10
			if(kbd_sr[7:0] == 8'h78 && kbd_release) joy_port_toggle <= ~joy_port_toggle; // F11

			// other keys
			if(kbd_sr[7:0] == 8'h5a) matrix[11][5] <= kbd_release; // return
			if(kbd_sr[7:0] == 8'h29) matrix[ 9][7] <= kbd_release; // space
			if(kbd_sr[7:0] == 8'h76) matrix[ 4][1] <= kbd_release; // esc
			if(kbd_sr[7:0] == 8'h66) matrix[11][1] <= kbd_release; // backspace
			if(kbd_sr[7:0] == 8'h0d) matrix[ 4][3] <= kbd_release; // tab		

			// keypad
			if(kbd_sr[7:0] == 8'h7c) matrix[14][1] <= kbd_release; // KP *
			if(kbd_sr[7:0] == 8'h7b) matrix[14][3] <= kbd_release; // KP -
			if(kbd_sr[7:0] == 8'h79) matrix[14][5] <= kbd_release; // KP +
			if(kbd_sr[7:0] == 8'h70) matrix[12][7] <= kbd_release; // KP 0
			if(kbd_sr[7:0] == 8'h69) matrix[12][6] <= kbd_release; // KP 1
			if(kbd_sr[7:0] == 8'h72) matrix[13][6] <= kbd_release; // KP 2
			if(kbd_sr[7:0] == 8'h7a) matrix[14][6] <= kbd_release; // KP 3
			if(kbd_sr[7:0] == 8'h6b) matrix[13][4] <= kbd_release; // KP 4
			if(kbd_sr[7:0] == 8'h73) matrix[13][5] <= kbd_release; // KP 5
			if(kbd_sr[7:0] == 8'h74) matrix[14][4] <= kbd_release; // KP 6
			if(kbd_sr[7:0] == 8'h6c) matrix[13][2] <= kbd_release; // KP 7
			if(kbd_sr[7:0] == 8'h75) matrix[13][3] <= kbd_release; // KP 8
			if(kbd_sr[7:0] == 8'h7d) matrix[14][2] <= kbd_release; // KP 9
			if(kbd_sr[7:0] == 8'h71) matrix[13][7] <= kbd_release; // KP .
			
			if(kbd_sr[7:0] == 8'h0e) matrix[10][2] <= kbd_release; // `
			if(kbd_sr[7:0] == 8'h4e) matrix[ 9][2] <= kbd_release; // -
			if(kbd_sr[7:0] == 8'h55) matrix[10][1] <= kbd_release; // =
			if(kbd_sr[7:0] == 8'h54) matrix[10][3] <= kbd_release; // [			  
			if(kbd_sr[7:0] == 8'h5b) matrix[10][4] <= kbd_release; // ]
			if(kbd_sr[7:0] == 8'h5d) matrix[11][4] <= kbd_release; // \ 
			if(kbd_sr[7:0] == 8'h4c) matrix[10][5] <= kbd_release; // ;
			if(kbd_sr[7:0] == 8'h52) matrix[11][6] <= kbd_release; // ' 
			if(kbd_sr[7:0] == 8'h41) matrix[ 9][6] <= kbd_release; // ,
			if(kbd_sr[7:0] == 8'h49) matrix[10][6] <= kbd_release; // .
			if(kbd_sr[7:0] == 8'h4a) matrix[11][7] <= kbd_release; // /
			if(kbd_sr[7:0] == 8'h61) matrix[ 4][6] <= kbd_release; // EUR-2
			
			// modifiers
			if(kbd_sr[7:0] == 8'h12) matrix[ 1][5] <= kbd_release; // lshift
			if(kbd_sr[7:0] == 8'h59) matrix[ 3][7] <= kbd_release; // rshift
			if(kbd_sr[7:0] == 8'h11) matrix[ 2][6] <= kbd_release; // alt
			if(kbd_sr[7:0] == 8'h14) matrix[ 0][4] <= kbd_release; // ctrl
			if(kbd_sr[7:0] == 8'h58) matrix[10][7] <= kbd_release; // caps lock

		     end else begin
			/* extended PS keys */
			if(kbd_sr[7:0] == 8'h14) matrix[ 0][4] <= kbd_release; // ctrl (right)

			// cursor keys
			if(kbd_sr[7:0] == 8'h75) matrix[12][1] <= kbd_release; // up
			if(kbd_sr[7:0] == 8'h72) matrix[12][4] <= kbd_release; // down
			if(kbd_sr[7:0] == 8'h6b) matrix[12][3] <= kbd_release; // left
			if(kbd_sr[7:0] == 8'h74) matrix[12][5] <= kbd_release; // right

			if(kbd_sr[7:0] == 8'h4a) matrix[14][0] <= kbd_release; // KP /
			if(kbd_sr[7:0] == 8'h5a) matrix[14][7] <= kbd_release; // KP Enter
			
			if(kbd_sr[7:0] == 8'h70) matrix[11][3] <= kbd_release; // Insert
			if(kbd_sr[7:0] == 8'h6c) matrix[12][2] <= kbd_release; // Home
			if(kbd_sr[7:0] == 8'h7d) matrix[11][0] <= kbd_release; // PageUp -> HELP
			if(kbd_sr[7:0] == 8'h71) matrix[11][2] <= kbd_release; // Delete
			if(kbd_sr[7:0] == 8'h7c) matrix[13][0] <= kbd_release; // PrtScr -> KP-(
			if(kbd_sr[7:0] == 8'h69) matrix[13][1] <= kbd_release; // End -> KP-)
			if(kbd_sr[7:0] == 8'h7a) matrix[12][0] <= kbd_release; // PageDown -> UNDO
		     end
		  end
	       end
               kbd_bit_cnt <= 'd0;
	    end
         end
      end
   end
end
   
// --------- registers for mouse decoding ---------
   reg 		  mouse_last_clk;
   reg [3:0] 	  mouse_bit_cnt;
   reg [8:0] 	  mouse_sr;
   reg 		  mouse_parity;
   reg [1:0] 	  mouse_state;
   reg [8:0] 	  mouse_x;
   reg [8:0] 	  mouse_y;
   reg [8:0] 	  mouse_z;
   reg [1:0] 	  mouse_sign;   
   reg [1:0] 	  mouse_btn;   
   reg [1:0] 	  mouse_x_cnt;   
   reg [1:0] 	  mouse_y_cnt;   
   reg  	  mouse_z_up;
   reg  	  mouse_z_down;
   reg [9:0] 	  mouse_ev_cnt;

assign mouse_atari = { mouse_btn, mouse_y_cnt, mouse_x_cnt };   
      
always @(posedge clk) begin
    
   if (reset === 1'b1) begin
      // signal analysis
      mouse_last_clk <= 1'b1;

      // byte decoding
      mouse_bit_cnt <= 'd0;
      mouse_sr <= 'd0;
      mouse_parity <= 1'b0;

      // mouse command decoding
      mouse_state <= 2'd0;
      mouse_btn <= 2'b00;
      mouse_x <= 9'd0;
      mouse_y <= 9'd0; 
      mouse_z <= 9'd0; 

      // atari mouse signal generation
      mouse_x_cnt <= 2'b00;   
      mouse_y_cnt <= 2'b00;      
      mouse_ev_cnt <= 10'd0;
      mouse_z_up <= 1'b0;
      mouse_z_down <= 1'b0;

   end else if(ena_2m) begin

      // generate atari st like mouse pulses
      // This happens at clk (2mhz) / 1024 = ~2000 steps/s
      // https://www.kernel.org/doc/Documentation/input/atarikbd.txt
      // "The mouse port should be capable of supporting a mouse with resolution of
      // approximately 200 counts (phase changes or 'clicks') per inch of travel. The
      // mouse should be scanned at a rate that will permit accurate tracking at
      // velocities up to 10 inches per second."
      mouse_ev_cnt <= mouse_ev_cnt + 10'd1;
      if(mouse_ev_cnt == 10'd0) begin
	 // x direction
	 if(mouse_x[8]) begin
	    // mouse_x is lower than 0
	    mouse_x <= mouse_x + 1'd1;
	    // grey counter
	    mouse_x_cnt[0] <= ~mouse_x_cnt[1];
	    mouse_x_cnt[1] <=  mouse_x_cnt[0];
	 end else if(mouse_x[7:0] != 8'd0) begin
	    // mouse_x is greater than 0
	    mouse_x <= mouse_x - 1'd1;
	    // grey counter
	    mouse_x_cnt[0] <=  mouse_x_cnt[1];
	    mouse_x_cnt[1] <= ~mouse_x_cnt[0];
	 end
	 // y direction
	 if(mouse_y[8]) begin
	    // mouse_y is lower than 0
	    mouse_y <= mouse_y + 1'd1;
	    // grey counter
	    mouse_y_cnt[0] <= ~mouse_y_cnt[1];
	    mouse_y_cnt[1] <=  mouse_y_cnt[0];
	 end else if(mouse_y[7:0] != 8'd0) begin
	    // mouse_y is greater than 0
	    mouse_y <= mouse_y - 1'd1;
	    // grey counter
	    mouse_y_cnt[0] <=  mouse_y_cnt[1];
	    mouse_y_cnt[1] <= ~mouse_y_cnt[0];
	 end
	 // z direction
	 if(mouse_z[8]) begin
	    // mouse_z is lower than 0
	    mouse_z <= mouse_z + 1'd1;
	    mouse_z_up <= 1;
	 end else if(mouse_z[8:0] != 9'd0) begin
	    // mouse_z is greater than 0
	    mouse_z <= mouse_z - 1'd1;
	    mouse_z_down <= 1;
	 end else begin
	    mouse_z_up <= 0;
	    mouse_z_down <= 0;
	 end 
      end
      
      
      //  Clear flags
      mouse_last_clk <= mouse_clk;
            
      if (!mouse_clk && mouse_last_clk) begin
	 
         //  We have a new bit from the keyboard for processing
         if (mouse_bit_cnt === 0) begin
	    
            //  Idle state, check for start bit (0) only and don't
            //  start counting bits until we get it
            mouse_parity <= 1'b0;
	    
            //  This is a start bit
            if (mouse_data == 1'b0)
               mouse_bit_cnt <= mouse_bit_cnt + 1'd1;
	    
	 end else begin
	    
            if (mouse_bit_cnt < 10) begin
	       
               //  Shift in data and parity (9 bits)
               mouse_bit_cnt <= mouse_bit_cnt + 1'd1;
               mouse_sr <= {mouse_data, mouse_sr[8:1]};
               mouse_parity <= mouse_parity ^ mouse_data;
               
	    end else if (mouse_data === 1'b1 ) begin
               if (mouse_parity === 1'b1) begin
		  if(mouse_state == 2'd0) begin
		     if(mouse_sr[3]) begin
			mouse_btn <= mouse_sr[1:0];
			mouse_sign <= mouse_sr[5:4];
			mouse_state <= 2'd1;
		     end
		  end else if(mouse_state == 2'd1) begin
		     mouse_x <= { mouse_sign[0], mouse_sr[7:0] };
		     mouse_state <= 2'd2;		     		       
		  end else if(mouse_state == 2'd2) begin
		     mouse_y <= ~{ mouse_sign[1], mouse_sr[7:0] } + 1'd1;
		     mouse_state <= 2'd3;
		  end else begin
		     mouse_z <= {~{ mouse_sr[4:0] } + 1'd1, 4'h0};
		     mouse_state <= 2'd0;		     		       
		  end		  
	       end
               mouse_bit_cnt <= 'd0;
	    end
         end
      end
   end
end
   
endmodule // module ps2

