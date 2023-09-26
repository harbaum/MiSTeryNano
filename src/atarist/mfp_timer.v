//
// mfp_timer.v
// 
// Single MFP68901 timer implementation
// https://github.com/mist-devel/mist-board
//
// Copyright (c) 2013 Stephen Leary
// Copyright (c) 2013-15 Till Harbaum <till@harbaum.org> 
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


module mfp_timer(
	input        CLK,
	input        RST, 
	input        DS,

	input        DAT_WE,
	input  [7:0] DAT_I,
	output [7:0] DAT_O,

	input        CTRL_WE,
	input  [4:0] CTRL_I,
	output [3:0] CTRL_O,

	input        XCLK_I,
	input        T_I, // ext. trigger in

	output       PULSE_MODE,  // pulse and event mode disables input port irq
	output       EVENT_MODE,

	output reg   T_O,
	output reg   T_O_PULSE,

	// current data bits are exported to allow mfp some rs232 bitrate
	// calculations
	output [7:0] SET_DATA_OUT
);

assign SET_DATA_OUT = data;

reg [7:0] data, down_counter, cur_counter;
reg [3:0] control;

assign PULSE_MODE = pulse_mode;
assign EVENT_MODE = event_mode;

wire[7:0] prescaler;         // prescaler value
reg [7:0] prescaler_counter; // prescaler counter
wire      prescaler_active;

reg       count;

wire      started;

wire      delay_mode;
wire      event_mode;
wire      pulse_mode;

// async clock edge detect
reg xclk, xclk_r, xclk_r2;

// generate xclk_en from async clock input
always @(posedge XCLK_I) xclk <= ~xclk;

wire xclk_en = xclk_r2 ^ xclk_r;
always @(posedge CLK) begin
	xclk_r <= xclk;
	xclk_r2 <= xclk_r;
end

// from datasheet: 
// read value when the DS pin last gone high prior to the current read cycle
always @(posedge CLK) begin
	reg DS_last;
	DS_last <= DS;
	if (~DS_last & DS) cur_counter <= down_counter;
end

reg [7:0] trigger_shift;
wire      trigger_pulse = trigger_shift[5:2] == 4'b0011; // maintain enough delay, and still allow 1/4 of clock freq

always @(posedge CLK) begin
	// In the datasheet, it's mentioned that T_I must be no more than 1/4 of the Timer Clock frequency
	// but a 4 stage shift register doesn't have enough delay for most of the bottom border opening code
	if (xclk_en) trigger_shift <= { trigger_shift[6:0], T_I };
end

always @(posedge CLK) begin
	reg       timer_tick;
	reg       timer_tick_r;
	reg       reload;

	if (RST === 1'b1) begin
		T_O     <= 1'b0;
		control <= 4'd0;
		data    <= 8'd0;
		down_counter <= 8'd0;
		count <= 1'b0;
		prescaler_counter <= 8'd0;
		reload <= 1'b0;
	end else begin

		if (xclk_en) timer_tick_r <= timer_tick;

		reload <= 1'b0;
		// if the timer is just stopped when oveflown, the MFP won't reload it from data
		// the next period will 256 timer cycles (from Hatari)
		if (started & reload) down_counter <= data;

		// if a write request comes from the main unit
		// then write the data to the appropriate register.
		if(DAT_WE) begin
			data <= DAT_I;
			// the counter itself is only loaded here if it's stopped
			if(!started) begin
				reload <= 1'b0;
				down_counter <= DAT_I;
			end
		end

		if(CTRL_WE) begin
			control <= CTRL_I[3:0];
			if (CTRL_I[4] == 1'b1)
				T_O <= 1'b0;
		end 

		count <= 1'b0;

		if (prescaler_active) begin
			if (xclk_en) begin
				// From datasheet:
				// If the prescaler value is changed while the timer is enabled, the first time out pulse will occur
				// at an indeterminate time no less than one or more than 200 timer clock cycles. Subsequent
				// time out pulses will then occur at the correct interval.
				// From this it can be guessed the prescaler resets at 200 unconditionally.
				if(prescaler_counter == prescaler || prescaler_counter == 8'd199) begin
					prescaler_counter <= 8'd0;
					timer_tick <= ~timer_tick;
				end else
					prescaler_counter <= prescaler_counter + 8'd1;
			end
		end else begin
			prescaler_counter <= 8'd0;
		end

		T_O_PULSE <= 1'b0;

		// handle event mode
		if (event_mode === 1'b1)
			if (xclk_en && trigger_pulse)
				count <= 1'b1;

		// handle delay mode
		if (delay_mode === 1'b1)
			if (xclk_en && (timer_tick_r ^ timer_tick))
				count <= 1'b1;

		// handle pulse mode
		if (pulse_mode === 1'b1)
			if (xclk_en && (timer_tick_r ^ timer_tick) && trigger_pulse)
				count <= 1'b1;

		if (count) begin
			down_counter <= down_counter - 8'd1;

			// timeout pulse
			if (down_counter === 8'd1) begin
				// pulse the timer out
				T_O <= ~T_O;
				T_O_PULSE <= 1'b1;
				reload <= 1'b1;
			end
		end
	end
end

assign prescaler = control[2:0] === 3'd1 ?  8'd03 :
                   control[2:0] === 3'd2 ?  8'd09 :
                   control[2:0] === 3'd3 ?  8'd15 :
                   control[2:0] === 3'd4 ?  8'd49 :
                   control[2:0] === 3'd5 ?  8'd63 :
                   control[2:0] === 3'd6 ?  8'd99 :
                   control[2:0] === 3'd7 ?  8'd199 : 8'd1;

assign prescaler_active = |control[2:0];
assign delay_mode = control[3] === 1'b0;
assign pulse_mode = control[3] === 1'b1 & !event_mode;
assign event_mode = control[3:0] === 4'b1000;

assign started = control[3:0] != 4'd0;
assign DAT_O = cur_counter;
assign CTRL_O = control;

endmodule // mfp_timer
