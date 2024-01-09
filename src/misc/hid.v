/*
    hid.v
 
    hid (keyboard, mouse etc) interface to the IO MCU
  */

module hid (
  input		   clk,
  input		   reset,

  input		   data_in_strobe,
  input		   data_in_start,
  input [7:0]      data_in,
  output reg [7:0] data_out,

  output [5:0]     mouse,
  output reg [7:0] keyboard[14:0],
  output reg [7:0] joystick0,
  output reg [7:0] joystick1
);

reg [1:0] mouse_btns;
reg [1:0] mouse_x;
reg [1:0] mouse_y;

assign mouse = { mouse_btns, mouse_x, mouse_y };

// limit the rate at which mouse movement data is sent to the
// ikbd
reg [13:0] mouse_div;
reg [3:0] state;
reg [7:0] command;  
reg [7:0] device;   // used for joystick
   
reg [7:0] mouse_x_cnt;
reg [7:0] mouse_y_cnt;
     
// process mouse events
always @(posedge clk) begin
   if(reset) begin
      state <= 4'd0;
      mouse_div <= 14'd0;

      // reset entire keyboard to 1's
      keyboard[ 0] <= 8'hff; keyboard[ 1] <= 8'hff; keyboard[ 2] <= 8'hff;
      keyboard[ 3] <= 8'hff; keyboard[ 4] <= 8'hff; keyboard[ 5] <= 8'hff;
      keyboard[ 6] <= 8'hff; keyboard[ 7] <= 8'hff; keyboard[ 8] <= 8'hff;
      keyboard[ 9] <= 8'hff; keyboard[10] <= 8'hff; keyboard[11] <= 8'hff;
      keyboard[12] <= 8'hff; keyboard[13] <= 8'hff; keyboard[14] <= 8'hff;      

   end else begin
      if(data_in_strobe) begin      
        if(data_in_start) begin
            state <= 4'd1;
            command <= data_in;
        end else if(state != 4'd0) begin
            if(state != 4'd15) state <= state + 4'd1;
	    
            // CMD 0: status data
            if(command == 8'd0) begin
                // return some dummy data for now ...
                if(state == 4'd1) data_out <= 8'h5c;
                if(state == 4'd2) data_out <= 8'h42;
            end
	   
            // CMD 1: keyboard data
            if(command == 8'd1) begin
                if(state == 4'd1) keyboard[data_in[3:0]][data_in[6:4]] <= data_in[7]; 
            end
	       
            // CMD 2: mouse data
            if(command == 8'd2) begin
                if(state == 4'd1) mouse_btns <= data_in[1:0];
                if(state == 4'd2) mouse_x_cnt <= mouse_x_cnt + data_in;
                if(state == 4'd3) mouse_y_cnt <= mouse_y_cnt + data_in;
            end

            // CMD 3: digital joystick data
            if(command == 8'd3) begin
                if(state == 4'd1) device <= data_in;
                if(state == 4'd2) begin
                    if(device == 8'd0) joystick0 <= data_in;
                    if(device == 8'd1) joystick1 <= data_in;
                end 
            end
        end
      end else begin // if (data_in_strobe)
        mouse_div <= mouse_div + 14'd1;      
        if(mouse_div == 14'd0) begin
            if(mouse_x_cnt != 8'd0) begin
                if(mouse_x_cnt[7]) begin
                    mouse_x_cnt <= mouse_x_cnt + 8'd1;
                    // 2 bit gray counter to emulate the mouse's light barriers
                    mouse_x[0] <=  mouse_x[1];
                    mouse_x[1] <= ~mouse_x[0];		  
                end else begin
                    mouse_x_cnt <= mouse_x_cnt - 8'd1;
                    mouse_x[0] <= ~mouse_x[1];
                    mouse_x[1] <=  mouse_x[0];
                end	    
            end // if (mouse_x_cnt != 8'd0)
	    
            if(mouse_y_cnt != 8'd0) begin
                if(mouse_y_cnt[7]) begin
                    mouse_y_cnt <= mouse_y_cnt + 8'd1;
                    mouse_y[0] <=  mouse_y[1];
                    mouse_y[1] <= ~mouse_y[0];		  
                end else begin
                    mouse_y_cnt <= mouse_y_cnt - 8'd1;
                    mouse_y[0] <= ~mouse_y[1];
                    mouse_y[1] <=  mouse_y[0];
                end	    
            end
        end
      end
   end
end
    
endmodule
