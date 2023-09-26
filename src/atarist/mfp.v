// mfp.v
//
// Atari ST multi function peripheral (MFP) for the MiST board
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
//

module mfp (
	// cpu register interface
	input            clk,
	input            clk_en,
	input            reset,
	input      [7:0] din,
	input            sel,
	input      [4:0] addr,
	input            ds,
	input            rw,
	output reg [7:0] dout,
	output reg       irq,
	input            iack,
	output           dtack,

	// serial rs232 connection to io controller
	output           serial_data_out_available,
	input            serial_strobe_out,
	output     [7:0] serial_data_out,
	output    [63:0] serial_status_out,

	// serial rs223 connection from io controller
	input            serial_strobe_in,
	input      [7:0] serial_data_in,

	// inputs
	input            clk_ext,   // external 2.457MHz
	input      [1:0] t_i,  // timer input
	input      [7:0] i     // input port
);

wire serial_data_out_fifo_full;
wire serial_data_in_full;

wire write = clk_en & ~bus_selD & bus_sel & ~rw;

// --- mfp output fifo ---
// filled by the CPU when writing to the mfp uart data register
// emptied by the io controller when reading via SPI
io_fifo mfp_out_fifo (
	.reset            ( reset ),

	.in_clk           ( clk ),
	.in               ( din ),
	.in_strobe        ( 1'b0 ),
	.in_enable        ( write && (addr == 5'h17) ),

	.out_clk          ( clk ),
	.out              ( serial_data_out ),
	.out_strobe       ( serial_strobe_out ),
	.out_enable       ( 1'b0 ),

	.full             ( serial_data_out_fifo_full ),
	.data_available   ( serial_data_out_available )
);

reg serial_cpu_data_read, serial_cpu_data_readD;
wire serial_data_in_available;
wire [7:0] serial_data_in_cpu;
wire serial_data_in_empty;
wire [3:0] serial_data_in_space;

// --- mfp input fifo ---
// filled by the io controller when writing via SPI
// emptied by CPU when reading the mfp uart data register
io_fifo mfp_in_fifo (
	.reset            ( reset ),

	.in_clk           ( clk ),
	.in               ( serial_data_in ),
	.in_strobe        ( serial_strobe_in ),
	.in_enable        ( 1'b0 ),

	.out_clk          ( clk ),
	.out              ( serial_data_in_cpu ),
	.out_strobe       ( 1'b0 ),
	.out_enable       ( serial_cpu_data_read && serial_data_in_available ),

	.space            ( serial_data_in_space ),
	.empty            ( serial_data_in_empty ),
	.full             ( serial_data_in_full ),
	.data_available   ( serial_data_in_available )
);

// ---------------- mfp uart data to/from io controller ------------

always @(posedge clk) begin
	serial_cpu_data_read <= 1'b0;
	if (clk_en) begin
		serial_cpu_data_readD <= serial_cpu_data_read;

		// read on uart data register
		if(bus_sel && rw && (addr == 5'h17))
			serial_cpu_data_read <= 1'b1;
	end
end

wire bus_sel = sel & ~ds;
reg  bus_selD;
reg  bus_dtack;

always @(posedge clk) begin
	if (clk_en) begin
		bus_selD <= bus_sel;
		if (bus_selD & bus_sel) bus_dtack <= 1'b1;
		if (~bus_sel) bus_dtack <= 1'b0;
	end
end

reg iack_dtack;
reg iack_sel;
reg iack_ack;
always @(posedge clk) begin
	iack_sel <= 1'b0;
	if (clk_en) begin
		if (iack && !iack_ack && highest_irq_pending_mask != 16'h0000) iack_sel <= 1'b1;
		if (iack_ack) iack_dtack <= 1'b1;
		if (~iack) iack_dtack <= 1'b0;
	end
end

assign dtack = bus_dtack || iack_dtack;

// timer a/b is in pulse mode
wire [1:0] pulse_mode;
// timer a/b is in event mode
wire [1:0] event_mode;
   
wire timera_done;
wire [7:0] timera_dat_o;
wire [3:0] timera_ctrl_o;

mfp_timer timer_a (
	.CLK        ( clk                      ),
	.DS         ( ds                       ),
	.XCLK_I     ( clk_ext                  ),
	.RST        ( reset                    ),
	.CTRL_I     ( din[4:0]                 ),
	.CTRL_O     ( timera_ctrl_o            ),
	.CTRL_WE    ( (addr == 5'h0c) && write ),
	.DAT_I      ( din                      ),
	.DAT_O      ( timera_dat_o             ),
	.DAT_WE     ( (addr == 5'h0f) && write ),
	.PULSE_MODE ( pulse_mode[1]            ),
	.EVENT_MODE ( event_mode[1]            ),
	.T_I        ( t_i[0] ^ ~aer[4]         ),
	.T_O_PULSE  ( timera_done              )
);

wire timerb_done;
wire [7:0] timerb_dat_o;
wire [3:0] timerb_ctrl_o;

mfp_timer timer_b (
	.CLK        ( clk                      ),
	.DS         ( ds                       ),
	.XCLK_I     ( clk_ext                  ),
	.RST        ( reset                    ),
	.CTRL_I     ( din[4:0]                 ),
	.CTRL_O     ( timerb_ctrl_o            ),
	.CTRL_WE    ( (addr == 5'h0d) && write ),
	.DAT_I      ( din                      ),
	.DAT_O      ( timerb_dat_o             ),
	.DAT_WE     ( (addr == 5'h10) && write ),
	.PULSE_MODE ( pulse_mode[0]            ),
	.EVENT_MODE ( event_mode[0]            ),
	.T_I        ( t_i[1] ^ ~aer[3]         ),
	.T_O_PULSE  ( timerb_done              )
);

wire timerc_done;
wire [7:0] timerc_dat_o;
wire [3:0] timerc_ctrl_o;

mfp_timer timer_c (
	.CLK        ( clk                      ),
	.DS         ( ds                       ),
	.XCLK_I     ( clk_ext                  ),
	.RST        ( reset                    ),
	.CTRL_I     ( {2'b00, din[6:4]}        ),
	.CTRL_O     ( timerc_ctrl_o            ),
	.CTRL_WE    ( (addr == 5'h0e) && write ),
	.DAT_I      ( din                      ),
	.DAT_O      ( timerc_dat_o             ),
	.DAT_WE     ( (addr == 5'h11) && write ),
	.T_O_PULSE  ( timerc_done              )
);

wire timerd_done;
wire [7:0] timerd_dat_o;
wire [3:0] timerd_ctrl_o;
wire [7:0] timerd_set_data;

mfp_timer timer_d (
	.CLK        ( clk                      ),
	.DS         ( ds                       ),
	.XCLK_I     ( clk_ext                  ),
	.RST        ( reset                    ),
	.CTRL_I     ( {2'b00, din[2:0]}        ),
	.CTRL_O     ( timerd_ctrl_o            ),
	.CTRL_WE    ( (addr == 5'h0e) && write ),
	.DAT_I      ( din                      ),
	.DAT_O      ( timerd_dat_o             ),
	.DAT_WE     ( (addr == 5'h12) && write ),
	.T_O_PULSE  ( timerd_done              ),
	.SET_DATA_OUT ( timerd_set_data        )
);

reg [7:0] aer, ddr, gpip;

// the mfp can handle 16 irqs, 8 internal and 8 external
reg [15:0] imr, ier;   // interrupt registers
reg [7:0] vr;

// generate irq signal if an irq is pending and no other irq of same or higher prio is in service
wire irq_trigger = ((ipr & imr) != 16'h0000) && (highest_irq_pending > irq_in_service);

// Delay to Falling XINTR from External Input Active Transition: max 380ns
// Let's try with one clock enable cycle (250ns on ST)
always @(posedge clk) if (clk_en) irq <= irq_trigger;

wire [15:0] ipr;
wire [15:0] isr;

// check number of current interrupt in service
wire [3:0] irq_in_service;
mfp_hbit16 irq_in_service_index (
	.value  ( isr            ),
	.index  ( irq_in_service )
);

// check the number of the highest pending irq 
wire  [3:0] highest_irq_pending;
wire [15:0] highest_irq_pending_mask;
mfp_hbit16 irq_pending_index (
	.value  ( ipr & imr                 ),
	.index  ( highest_irq_pending       ),
	.mask   ( highest_irq_pending_mask  )
);

// gpip as output to the cpu (ddr bit == 1 -> gpip pin is output)
wire [7:0] gpip_cpu_out = (i & ~ddr) | (gpip & ddr);

// assemble output status structure. Adjust bitrate endianess
assign serial_status_out = { 
	bitrate[7:0], bitrate[15:8], bitrate[23:16], bitrate[31:24], 
	databits, parity, stopbits, input_fifo_status };

wire [11:0] timerd_state = { timerd_ctrl_o, timerd_set_data };

// Atari RTS: YM-A-4 ->
// Atari CTS: mfp gpio-2 <-

// --- export bit rate ---
// try to calculate bitrate from timer d config
// bps is 2.457MHz/2/16/prescaler/datavalue
wire [31:0] bitrate = 
	(uart_ctrl[6] !=    1'b1)?32'h80000000:    // uart prescaler not 1
	(timerd_state == 12'h101)?32'd19200:       // 19200 bit/s
	(timerd_state == 12'h102)?32'd9600:        // 9600 bit/s
	(timerd_state == 12'h104)?32'd4800:        // 4800 bit/s
	(timerd_state == 12'h105)?32'd3600:        // 3600 bit/s (?? isn't that 3840?)
	(timerd_state == 12'h108)?32'd2400:        // 2400 bit/s
	(timerd_state == 12'h10a)?32'd2000:        // 2000 bit/s (exact 1920)
	(timerd_state == 12'h10b)?32'd1800:        // 1800 bit/s (exact 1745)
	(timerd_state == 12'h110)?32'd1200:        // 1200 bit/s
	(timerd_state == 12'h120)?32'd600:         // 600 bit/s
	(timerd_state == 12'h140)?32'd300:         // 300 bit/s
	(timerd_state == 12'h160)?32'd200:         // 200 bit/s
	(timerd_state == 12'h180)?32'd150:         // 150 bit/s
	(timerd_state == 12'h18f)?32'd134:         // 134 bit/s
	(timerd_state == 12'h18f)?32'd134:         // 134 bit/s (134.27)
	(timerd_state == 12'h1af)?32'd110:         // 110 bit/s (109.71)
	(timerd_state == 12'h240)?32'd75:          // 75 bit/s (120)
	(timerd_state == 12'h260)?32'd50:          // 50 bit/s (80)
	32'h80000001;                              // unsupported bit rate	

wire [7:0] input_fifo_status = { serial_data_in_space, 1'b0,
	serial_data_in_empty, serial_data_in_full, serial_data_in_available };
	
wire [7:0] parity = 
	(uart_ctrl[1] == 1'b0)?8'h00:    // no parity
	(uart_ctrl[0] == 1'b0)?8'h01:    // odd parity
	8'h02;                           // even parity

wire [7:0] stopbits = 
	(uart_ctrl[3:2] == 2'b00)?8'hff: // sync mode not supported
	(uart_ctrl[3:2] == 2'b01)?8'h00: // async 1 stop bit
	(uart_ctrl[3:2] == 2'b10)?8'h01: // async 1.5 stop bits
	8'h11;                           // async 2 stop bits

wire [7:0] databits = 
	(uart_ctrl[5:4] == 2'b00)?8'd8:  // 8 data bits
	(uart_ctrl[5:4] == 2'b01)?8'd7:  // 7 data bits
	(uart_ctrl[5:4] == 2'b10)?8'd6:  // 6 data bits
	8'd5;                            // 5 data bits

// cpu controllable uart control bits
reg [1:0] uart_rx_ctrl;
reg [3:0] uart_tx_ctrl;
reg [6:0] uart_ctrl;
reg [7:0] uart_sync_chr;

// cpu read interface
always @(*) begin

	dout = 8'd0;
	if(bus_sel && rw) begin
		if(addr == 5'h00) dout = gpip_cpu_out;
		if(addr == 5'h01) dout = aer;
		if(addr == 5'h02) dout = ddr;

		if(addr == 5'h03) dout = ier[15:8];
		if(addr == 5'h04) dout = ier[7:0];
		if(addr == 5'h06) dout = ipr[7:0];
		if(addr == 5'h05) dout = ipr[15:8];
		if(addr == 5'h07) dout = isr[15:8];
		if(addr == 5'h08) dout = isr[7:0];
		if(addr == 5'h09) dout = imr[15:8];
		if(addr == 5'h0a) dout = imr[7:0];
		if(addr == 5'h0b) dout = vr;

		// timers
		if(addr == 5'h0c) dout = { 4'h0, timera_ctrl_o};
		if(addr == 5'h0d) dout = { 4'h0, timerb_ctrl_o};
		if(addr == 5'h0e) dout = { timerc_ctrl_o, timerd_ctrl_o};
		if(addr == 5'h0f) dout = timera_dat_o;
		if(addr == 5'h10) dout = timerb_dat_o;
		if(addr == 5'h11) dout = timerc_dat_o;
		if(addr == 5'h12) dout = timerd_dat_o;

		// uart: report "tx buffer empty" if fifo is not full
		if(addr == 5'h13) dout = uart_sync_chr; 
		if(addr == 5'h14) dout = { uart_ctrl, 1'b0 }; 
		if(addr == 5'h15) dout = {  serial_data_in_available, 5'b00000 , uart_rx_ctrl}; 
		if(addr == 5'h16) dout = { !serial_data_out_fifo_full, 3'b000 , uart_tx_ctrl}; 
		if(addr == 5'h17) dout = serial_data_in_cpu;

	end else if(iack) begin
		dout = irq_vec;
	end
end

// mask of input irqs which are overwritten by timer a/b inputs
// In normal operation, programming the active edge bit to a one will produce an interrupt on the zero-
// to-one transition of the associated input signal. Alternately, programming the edge bit to a zero will
// produce an interrupt on the one-to-zero transition of the input signal.
// However, in the pulse width measurement mode, the interrupt generated by a transition on TAI or TBI will occur
// on the opposite transition as that normally defined by the edge bit.
// Like the pulse width measurement mode, the event count mode requires an auxiliary input signal, TAI or TBI.
// General purpose lines I3 and I4 can be used for I/O or as interrupt producing inputs.

wire [7:0] ti_irq_mask = { 3'b000, pulse_mode, 3'b000};
wire [7:0] ti_irq      = { 3'b000, pulse_mode[1] ^ t_i[0], pulse_mode[0] ^ t_i[1], 3'b000};

// latch to keep irq vector stable during irq ack cycle
reg [7:0] irq_vec;

// IPR bits are always set on the rising edge of their input and are cleared asynchronously
wire [7:0] gpio_irq = ~aer ^ ((i & ~ti_irq_mask) | (ti_irq & ti_irq_mask));

// ------------------------ IPR register --------------------------
reg [15:0] ipr_reset;

// the cpu reading data clears rx irq. It may raise again immediately if there's more
// data in the input fifo. Use a delayed cpu read signal to make sure the fifo finishes
// removing the byte before
wire uart_rx_irq = serial_data_in_available && !serial_cpu_data_readD;

// the io controller reading data clears tx irq. It may raus again immediately if 
// there's more data in the output fifo
wire uart_tx_irq = !serial_data_out_fifo_full && !serial_strobe_out;

// map the 16 interrupt sources onto the 16 interrupt register bits
wire [15:0] ipr_set = {
	gpio_irq[7:6], timera_done, uart_rx_irq,
	1'b0 /* rcv err */, uart_tx_irq, 1'b0 /* tx err */, timerb_done,
	gpio_irq[5:4], timerc_done, timerd_done, gpio_irq[3:0]
};

mfp_srff16 ipr_latch (
	.clk    ( clk        ),
	.set    ( ipr_set    ),
	.mask   ( ier        ),
	.reset  ( ipr_reset  ),
	.out    ( ipr        )
);

// ------------------------ ISR register --------------------------
reg [15:0] isr_reset;
reg [15:0] isr_set;

// move highest pending irq into isr when s bit set and iack raises
mfp_srff16 isr_latch (
	.clk    ( clk        ),
	.set    ( isr_set    ),
	.mask   ( 16'hffff   ),
	.reset  ( isr_reset  ),
	.out    ( isr        )
);

always @(posedge clk) begin
	ipr_reset <= 0;
	isr_reset <= 0;
	isr_set <= 0;

	if(reset) begin
		ipr_reset <= 16'hffff;
		isr_reset <= 16'hffff;
		ier <= 16'h0000; 
		imr <= 16'h0000;
		isr_set <= 16'h0000;
		iack_ack <= 1'b0;
	end else begin 
		// remove active bit from ipr and set it in isr
		if(iack_sel) begin
			ipr_reset[highest_irq_pending] <= 1'b1;
			isr_set <= vr[3]?highest_irq_pending_mask:16'h0000;    // non auto-end
			isr_reset <= !vr[3]?highest_irq_pending_mask:16'h0000; // auto-end
			irq_vec <= { vr[7:4], highest_irq_pending };
			iack_ack <= 1'b1;
		end
		if (~iack) iack_ack <= 1'b0;

		if(write) begin
			// -------- GPIO ---------
			if(addr == 5'h00) gpip <= din;
			if(addr == 5'h01) aer <= din;
			if(addr == 5'h02) ddr <= din;

			// ------ IRQ handling -------
			if(addr == 5'h03) begin
				ier[15:8] <= din;
				ipr_reset[15:8] <= ipr_reset[15:8] | ~din;
			end

			if(addr == 5'h04) begin
				ier[7:0] <= din;
				ipr_reset[7:0] <= ipr_reset[7:0] | ~din;
			end
			
			if(addr == 5'h05) ipr_reset[15:8] <= ipr_reset[15:8] | ~din;
			if(addr == 5'h06) ipr_reset[7:0]  <= ipr_reset[7:0]  | ~din;
			if(addr == 5'h07) isr_reset[15:8] <= isr_reset[15:8] | ~din;  // zero bits are cleared
			if(addr == 5'h08) isr_reset[7:0]  <= isr_reset[7:0]  | ~din;  // -"-
			if(addr == 5'h09) imr[15:8] <= din;
			if(addr == 5'h0a) imr[7:0]  <= din;
			if(addr == 5'h0b) begin
				vr <= din;
				// clear all in-service bits when switching to auto-end mode
				if (!din[3]) isr_reset <= 16'hffff;
			end

			// ------- uart ------------
			if(addr == 5'h13) uart_sync_chr <= din[1:0];
			if(addr == 5'h14) uart_ctrl     <= din[7:1];
			if(addr == 5'h15) uart_rx_ctrl  <= din[1:0];
			if(addr == 5'h16) uart_tx_ctrl  <= din[3:0];

			// write to addr == 5'h17 is handled by the output fifo
		end
	end
end

endmodule
