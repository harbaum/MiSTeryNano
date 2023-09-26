// dma.v
//
// Atari ST DMA controller for the MIST board
// https://github.com/mist-devel/mist-board
//
// Copyright (c) 2014 Till Harbaum <till@harbaum.org>
// Copyright (c) 2019 Gyorgy Szombathelyi
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

// ##############DMA/WD1772 Disk controller                           ###########
// -------+-----+-----------------------------------------------------+----------
// $FF8600|     |Reserved                                             |
// $FF8602|     |Reserved                                             |
// $FF8604|word |FDC access/sector count                              |R/W
// $FF8606|word |DMA mode/status                             BIT 2 1 0|R
//        |     |Condition of FDC DATA REQUEST signal -----------' | ||
//        |     |0 - sector count null,1 - not null ---------------' ||
//        |     |0 - no error, 1 - DMA error ------------------------'|
// $FF8606|word |DMA mode/status                 BIT 8 7 6 . 4 3 2 1 .|W
//        |     |0 - read FDC/HDC,1 - write ---------' | | | | | | |  |
//        |     |0 - HDC access,1 - FDC access --------' | | | | | |  |
//        |     |0 - DMA on,1 - no DMA ------------------' | | | | |  |
//        |     |Reserved ---------------------------------' | | | |  |
//        |     |0 - FDC reg,1 - sector count reg -----------' | | |  |
//        |     |0 - FDC access,1 - HDC access ----------------' | |  |
//        |     |0 - pin A1 low, 1 - pin A1 high ----------------' |  |
//        |     |0 - pin A0 low, 1 - pin A0 high ------------------'  |
	 
module dma (
	// clocks and system interface
	input             clk, // 32 MHz
	input             clk_en,
	input             reset,
	// cpu interface
	input      [15:0] cpu_din,
	input 		      cpu_sel,
	input             cpu_a1,
	input 		      cpu_rw,
	output reg [15:0] cpu_dout,

	// data interface for ACSI
	input             dio_data_in_strobe,
	input      [15:0] dio_data_in_reg,

	input             dio_data_out_strobe,
	output     [15:0] dio_data_out_reg,

	input             dio_dma_ack,
	input       [7:0] dio_dma_status,

	input             dio_dma_nak,
	output      [7:0] dio_status_in,
	input       [3:0] dio_status_index,

	// additional acsi control signals
	output            acsi_irq,
	input [7:0]       acsi_enable,

	// FDC interface
	output            fdc_sel,
	output [1:0]      fdc_addr,
	output            fdc_rw,
	output [7:0]      fdc_din,
	input  [7:0]      fdc_dout,
	input             fdc_drq,

	// ram interface for dma engine
	input             rdy_i,
	output            rdy_o,
	input [15:0]      ram_din
);

// some games access right after writing the sector count
// then this access won't be ack'ed if the DMA already started
assign rdy_o = cpu_sel ? cpu_rdy : ram_br;

// for debug: count irqs

reg [7:0] acsi_irq_count;
always @(posedge clk or posedge reset) begin
	reg acsi_irqD;
	if(reset) acsi_irq_count <= 8'd0;
	else begin
		acsi_irqD <= acsi_irq;
		if (~acsi_irqD & acsi_irq) acsi_irq_count <= acsi_irq_count + 8'd1;
	end
end

reg cpu_selD;
always @(posedge clk) if (clk_en) cpu_selD <= cpu_sel;
wire cpu_req = ~cpu_selD & cpu_sel;

reg cpu_rdy;
always @(posedge clk) begin
	if (!cpu_sel) cpu_rdy <= 1'b0;
	else if (clk_en && cpu_req ) cpu_rdy <= 1'b1;
end

// dma sector count and mode registers
reg [7:0]  dma_scnt;
reg [15:0] dma_mode;

// ============= FDC submodule ============   

assign  fdc_sel = fdc_dma_sel | (cpu_sel && !cpu_a1 && (dma_mode[4:3] == 2'b00));
assign  fdc_din = fdc_dma_sel ? (fdc_bs ? fifo_data_out[7:0] : fifo_data_out[15:8]) : cpu_din[7:0];
assign  fdc_rw  = fdc_dma_sel ? fdc_dma_rw : cpu_rw;
assign  fdc_addr = fdc_dma_sel ? 2'b11 : dma_mode[2:1];

reg [15:0] fdc_fifo_in;
reg        fdc_fifo_strobe;
reg        fdc_dma_sel;
wire       fdc_dma_rw = ~dma_direction_out;
reg        fdc_bs;

always @(posedge clk) begin
	reg fdc_drqD;
	reg fdc_state;

	if (reset | fifo_reset) begin
		fdc_fifo_strobe <= 1'b0;
		fdc_state <= 1'b0;
		fdc_bs <= 1'b0;
		fdc_dma_sel <= 1'b0;
	end else begin
		fdc_drqD <= fdc_drq;
		fdc_fifo_strobe <= 1'b0;

		case (fdc_state)
		0: if (~fdc_drqD & fdc_drq) begin
			fdc_dma_sel <= 1'b1;
			fdc_state <= 1'b1;
		   end
		1: if (clk_en) begin
			fdc_dma_sel <= 1'b0;
			fdc_bs <= ~fdc_bs;
			if (fdc_bs) begin
				fdc_fifo_in[7:0] <= fdc_dout;
				fdc_fifo_strobe <= 1'b1;
			end else
				fdc_fifo_in[15:8] <= fdc_dout;
			fdc_state <= 1'b0;
		   end
		endcase
	end
end

// ============= ACSI submodule ============   

// select signal for the acsi controller access (write only, status comes from io controller)
wire    acsi_reg_sel = cpu_sel && !cpu_a1 && (dma_mode[4:3] == 2'b01);
wire [7:0] acsi_dout;

wire io_dma_ack, io_dma_nak;

acsi acsi(
	 .clk         ( clk                   ),
	 .clk_en      ( clk_en                ),
	 .reset       ( reset                 ),
	 
	 .irq         ( acsi_irq              ),

	  // acsi target enable
	 .enable      ( acsi_enable           ),

	 // signals from/to io controller
	 .dma_ack     ( io_dma_ack            ),
	 .dma_nak     ( io_dma_nak            ),
	 .dma_status  ( dio_dma_status        ),

	 .status_sel  ( dio_status_index      ),
	 .status_byte ( dio_status_in         ),

	 // cpu interface, passed through dma in st
	 .cpu_sel     ( acsi_reg_sel          ),
	 .cpu_a1      ( dma_mode[1]           ),
	 .cpu_rw      ( cpu_rw                ),
	 .cpu_din     ( cpu_din[7:0]          ),
	 .cpu_dout    ( acsi_dout             )
);

wire [15:0] ram_dout;

// ============= CPU read interface ============
always @(cpu_sel, cpu_rw, cpu_a1, dma_mode, dma_scnt, fdc_dout, acsi_dout, ram_dout) begin
   cpu_dout = ram_dout;

   if(cpu_sel && cpu_rw) begin

      // register $ff8604
      if(!cpu_a1) begin
         if(dma_mode[4] == 1'b0) begin
            // controller access register
            if(dma_mode[3] == 1'b0)
					cpu_dout = { 8'h00, fdc_dout };
				else
					cpu_dout = { 8'h00, acsi_dout };
         end else
           cpu_dout = { 8'h00, dma_scnt };  // sector count register
      end

      // DMA status register $ff8606
      // bit 0 = 1: DMA_OK, bit 2 = state of FDC DRQ
      if(cpu_a1) cpu_dout = { 14'd0, dma_scnt != 0, 1'b1 };

   end
end

// ============= CPU write interface ============
// flags indicating the cpu is writing something. valid on rising edge
reg cpu_scnt_write_strobe;  
reg cpu_dma_mode_direction_toggle;
   
always @(posedge clk) begin
   if(reset) begin
      cpu_scnt_write_strobe <= 1'b0;      
      cpu_dma_mode_direction_toggle <= 1'b0;
   end else begin
		cpu_scnt_write_strobe <= 1'b0;      
		cpu_dma_mode_direction_toggle <= 1'b0;

		// cpu writes ...
		if(clk_en && cpu_req && !cpu_rw) begin

			// ... sector count register
			if(!cpu_a1 && (dma_mode[4] == 1'b1))
				cpu_scnt_write_strobe <= 1'b1;

			// ... dma mode register
			if(cpu_a1) begin
				dma_mode <= cpu_din;

				// check if cpu toggles direction bit (bit 8)
				if(dma_mode[8] != cpu_din[8])
					cpu_dma_mode_direction_toggle <= 1'b1;
			end
		end
   end
end

// =======================================================================
// ============================= DMA FIFO ================================
// =======================================================================

// 32 byte dma fifo (actually a 2x8 word fifo)
reg [15:0] fifo [15:0];
reg [3:0] fifo_wptr;         // word pointers
reg [3:0] fifo_rptr;

// Reset fifo via the dma mode direction bit toggling
wire fifo_reset = cpu_dma_mode_direction_toggle;

reg fifo_read_in_progress, fifo_write_in_progress;
wire ram_br = fifo_read_in_progress || fifo_write_in_progress;

wire ram_access_strobe = ~rdy_iD & rdy_i;
reg rdy_iD;
always @(posedge clk) begin
	rdy_iD <= rdy_i;
end


// ============= FIFO WRITE ENGINE ==================
// Fill the FIFO from RAM in 8 word chunks
wire fifo_write_start = dma_in_progress && dma_direction_out && !fifo_write_in_progress &&
     (fifo_wptr - fifo_rptr < 4'd8);
wire fifo_write_stop = dma_direction_out && fifo_write_in_progress &&
     (ram_access_strobe && (fifo_wptr == 4'd7 || fifo_wptr == 4'd15));

// state machine for DMA ram read access
always @(posedge clk or posedge fifo_reset) begin
	if(fifo_reset == 1'b1) begin
		fifo_write_in_progress <= 1'b0;
	end else begin
		if(fifo_write_start) fifo_write_in_progress <= 1'b1;
		else if (fifo_write_stop) fifo_write_in_progress <= 1'b0;
	end
end

wire [15:0] fifo_data_in = dma_direction_out?ram_din:(fdc_fifo_strobe?fdc_fifo_in:dio_data_in_reg);
wire fifo_data_in_strobe = dma_direction_out?ram_access_strobe:(io_data_in_strobe | fdc_fifo_strobe);

// write to fifo on rising edge of fifo_data_in_strobe
always @(posedge clk or posedge fifo_reset) begin
   if(fifo_reset == 1'b1)
     fifo_wptr <= 4'd0;
   else if (fifo_data_in_strobe) begin
      fifo[fifo_wptr] <= fifo_data_in;
      fifo_wptr <= fifo_wptr + 1'd1;
   end
end

// ============= FIFO READ ENGINE ==================
// start condition for fifo read
// allow to fill 8 words by the FDC/HDD, then transfer them to the CPU
wire fifo_read_start = dma_in_progress && !dma_direction_out && !fifo_read_in_progress &&
     ((fifo_rptr == 4'd0 && fifo_wptr == 4'd8) || (fifo_rptr == 4'd8 && fifo_wptr == 4'd0));
wire fifo_read_stop = !dma_direction_out && fifo_read_in_progress &&
     ram_access_strobe && (fifo_rptr == 4'd7 || fifo_rptr == 4'd15);

// state machine for DMA ram write access
always @(posedge clk or posedge fifo_reset) begin
	if(fifo_reset == 1'b1) begin
		// not reading from fifo, not writing into ram
		fifo_read_in_progress <= 1'b0;
	end else begin
		if (fifo_read_start) fifo_read_in_progress <= 1'b1;
		else if (fifo_read_stop) fifo_read_in_progress <= 1'b0;
	end
end

reg [15:0] fifo_data_out;
wire fifo_data_out_strobe = dma_direction_out?(io_data_out_strobe | fdc_fifo_strobe):ram_access_strobe;

always @(posedge clk)
   fifo_data_out <= fifo[fifo_rptr];

always @(posedge clk or posedge fifo_reset) begin
   if(fifo_reset == 1'b1)         fifo_rptr <= 4'd0;
   else if (fifo_data_out_strobe) fifo_rptr <= fifo_rptr + 1'd1;
end

// use fifo output directly as ram data
assign ram_dout = fifo_data_out;

// ==========================================================================
// =============================== internal registers =======================
// ==========================================================================
  
// ================================ DMA sector count ========================
// - register is decremented by one after 512 bytes being transferred
// - cpu can write this register directly
   
// keep track of bytes to decrement sector count register
// after 512 bytes (256 words)
reg [7:0] word_out_cnt;
reg       sector_done;   
reg       sector_strobe;
reg       sector_strobe_prepare;

always @(posedge clk) begin
	if(dma_scnt_write_strobe) begin
		word_out_cnt <= 8'd0;
		sector_strobe <= 1'b0;
		sector_done <= 1'b0;
	end else begin
		sector_strobe <= 1'b0;

		// wait a little after the last word
		if(sector_done) begin
			sector_done <= 1'b0;
			// trigger scnt decrement
			sector_strobe <= 1'b1;
		end

		// and ram read or write increases the word counter by one
		if(ram_access_strobe) begin
			word_out_cnt <= word_out_cnt + 8'd1;
			if(word_out_cnt == 8'd255) begin
				sector_done <= 1'b1;
			end
		end
	end 
end

// cpu can write the scnt register and it's decremented after 512 bytes
wire dma_scnt_write_strobe = cpu_scnt_write_strobe || sector_strobe;
// sector counter doesn't count below 0
wire [7:0] dma_scnt_dec = (dma_scnt != 0)?(dma_scnt-8'd1):8'd0;   
// multiplex new sector count data
wire [7:0] dma_scnt_next = cpu_scnt_write_strobe?cpu_din[7:0]:dma_scnt_dec;

// cpu set the sector count register
always @(posedge clk)
	if (dma_scnt_write_strobe) dma_scnt <= dma_scnt_next;

// DMA in progress flag:
// - cpu writing the sector count register starts the DMA engine if
//   dma enable bit 6 in mode register is clear
// - changing sector count to 0 (cpu or counter) stops DMA
// - cpu writing toggling dma direction stops dma
reg dma_in_progress;
wire dma_stop = cpu_dma_mode_direction_toggle;

// dma can be started if sector is not zero and if dma is enabled
// by a zero in bit 6 of dma mode register
wire cpu_starts_dma = cpu_scnt_write_strobe && (cpu_din[7:0] != 0) && !dma_mode[6];

always @(posedge clk or posedge dma_stop) begin
   if(dma_stop) dma_in_progress <= 1'b0;
   else if (dma_scnt_write_strobe) dma_in_progress <= cpu_starts_dma || (sector_strobe && dma_scnt_next != 0);   
end

// ========================== DMA direction flag ============================
reg dma_direction_out;  // == 1 when transferring from fpga to io controller

// bit 8 == 0 -> dma read -> dma_direction_out
always @(posedge clk)
  if (cpu_dma_mode_direction_toggle) dma_direction_out <= cpu_din[8];

// ====================================================================
// ======================= Client to IO controller ====================
// ====================================================================

assign dio_data_out_reg = fifo_data_out;

wire io_data_in_strobe = dio_data_in_strobe ^ dio_data_in_strobeD;
wire io_data_out_strobe = dio_data_out_strobe ^ dio_data_out_strobeD;

reg dio_data_in_strobeD;
reg dio_data_out_strobeD;
reg dio_dma_ackD;
reg dio_dma_nakD;

assign io_dma_ack = dio_dma_ack ^ dio_dma_ackD;
assign io_dma_nak = dio_dma_nak ^ dio_dma_nakD;

always@(posedge clk) begin
	dio_data_in_strobeD <= dio_data_in_strobe;
	dio_data_out_strobeD <= dio_data_out_strobe;
	dio_dma_ackD <= dio_dma_ack;
	dio_dma_nakD <= dio_dma_nak;
end

endmodule
