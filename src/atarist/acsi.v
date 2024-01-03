// acsi.v
//
// Atari ST ACSI implementation for the MIST board
// https://github.com/mist-devel/mist-board
//
// Copyright (c) 2015 Till Harbaum <till@harbaum.org>
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

// TODO:
// - migrate from rd[x]/wr[x] to  req/rw/dev

module acsi (
    // clocks and system interface
	input 			  clk,
	input 			  clk_en,
	input 			  reset,

	input [7:0] 	  enable,

	// SD card interface
	output reg [1:0]  data_rd_req, // request read from sd card
	output reg [1:0]  data_wr_req, // request write to sd card
	output reg [31:0] data_lba,    // lba requested
	input 			  data_busy,   // sd card has accepted request and now loads sector
	input 			  data_done,   // sd card ready in reply to req
	input 			  dma_done,    // DMA transfer finished
	input 			  data_next,   // DMA requests another sector to be tranferred
	     
	// old IO controller interface
	input 			  dma_ack,     // IO controller answers request
	input 			  dma_nak,     // IO controller rejects request
	input [7:0] 	  dma_status,

	
	input [3:0] 	  status_sel,  // 10 command bytes + 1 status byte
	output [7:0] 	  status_byte,

   // cpu interface
	input 			  cpu_a1,
	input 			  cpu_sel,
	input 			  cpu_rw,
	input [7:0] 	  cpu_din,
	output [7:0] 	  cpu_dout,

	output reg 		  irq
);

reg cpu_selD;
always @(posedge clk) if (clk_en) cpu_selD <= cpu_sel;
wire cpu_req = ~cpu_selD & cpu_sel;

// acsi always returns dma status on cpu_read
assign cpu_dout = dma_status;

// Total number of command bytes:
// cmd 0..1f  -> 6 
// cmd 20..5f -> 10
// cmd 80..9f -> 16
// cmd a0..bf -> 12

wire [7:0] cmd_code = cmd_parameter[0];
wire [3:0] parms =
	((cmd_code >= 8'h00)&&(cmd_code <= 8'h1f))?4'd5:
	((cmd_code >= 8'h20)&&(cmd_code <= 8'h5f))?4'd9:
	((cmd_code >= 8'h80)&&(cmd_code <= 8'h9f))?4'd15:
	4'd11;
   
reg [2:0] target;
reg [3:0] byte_counter;
reg [7:0] cmd_parameter [15:0];
reg busy;

// acsi status as reported to the io controller
assign status_byte =
    (status_sel == 0)?cmd_parameter[0]:
    (status_sel == 1)?cmd_parameter[1]:
    (status_sel == 2)?cmd_parameter[2]:
    (status_sel == 3)?cmd_parameter[3]:
    (status_sel == 4)?cmd_parameter[4]:
    (status_sel == 5)?cmd_parameter[5]:
    (status_sel == 6)?cmd_parameter[6]:
    (status_sel == 7)?cmd_parameter[7]:
    (status_sel == 8)?cmd_parameter[8]:
    (status_sel == 9)?cmd_parameter[9]:
    (status_sel == 10)?{ target, 4'b0000, busy }:
    8'h00;

// CPU write interface
always @(posedge clk) begin
   if(reset) begin
      target <= 3'd0;
      irq <= 1'b0;
      busy <= 1'b0;
      data_rd_req <= 2'b00;
      data_wr_req <= 2'b00;
   end else begin
      
      // DMA transfer has been ack'd by io controller
      if(dma_ack && busy) begin
		 irq <= 1'b1;   // set acsi irq			
		 busy <= 1'd0;
      end

      // SD card has delivered data to DMA
      if(data_busy) begin
		 data_rd_req <= 2'b00;
		 data_wr_req <= 2'b00;
	  end
      
      if(data_next) begin
		 // check if a read or write is to be continued		 
		 // target can only be 0 or 1
		 if(cmd_parameter[0][3:0] == 4'h8)
		   data_rd_req[target] <= 1'b1;
		 
		 if(cmd_parameter[0][3:0] == 4'ha)
		   data_wr_req[target] <= 1'b1;		 
		 
		 // request next sector
		 data_lba <= data_lba + 32'd1;	 
      end
      
      // entire DMA transfer is done
      if(dma_done) irq <= 1'b1;	 

      // DMA transfer has been rejected by io controller (no such device)
      if(dma_nak)
		busy <= 1'd0;
      
      // cpu is accessing acsi bus -> clear acsi irq
      // status itself is returned by the io controller with the dma_ack.
      if(clk_en && cpu_req)
		irq <= 1'b0;
      
      // acsi register access
      if(clk_en && cpu_req && !cpu_rw) begin
		 if(!cpu_a1) begin
			// a0 == 0 -> first command byte
			target <= cpu_din[7:5];
			busy <= 1'b0;
			
			// icd command?
			if(cpu_din[4:0] == 5'h1f)
			  byte_counter <= 3'd0;   // next byte will contain first command byte
			else begin
			   cmd_parameter[0] <= { 3'd0, cpu_din[4:0] };
			   byte_counter <= 3'd1;   // next byte will contain second command byte
			end
			
			// allow ACSI target 0 and 1 only
			// check if this acsi device is enabled
			if(cpu_din[7:5] < 2 && enable[cpu_din[7:5]] == 1'b1)
			  irq <= 1'b1;
		 end else begin
			
			// further bytes
			cmd_parameter[byte_counter] <= cpu_din;
			byte_counter <= byte_counter + 3'd1;
			
			// check if this acsi device is enabled
			if(enable[target] == 1'b1) begin
			   // auto-ack first 5 bytes, 6 bytes in case of icd command
			   if(byte_counter < parms)
				 irq <= 1'b1;		  
			   else begin
				  // command complete
				  case( cmd_parameter[0] )
					
					// read(6)
					8'h08: begin
					   // target can only be 0 or 1
					   data_rd_req[target] <= 1'b1;
					   // read(6) has a 21 bit sector address
					   data_lba <= { 10'b0000000000,
									 cmd_parameter[1][4:0],
									 cmd_parameter[2],
									 cmd_parameter[3] };
					   // data length is ignored as it's implicitely encoded
					   // in the DMA length
					end
					
					// read(10)
					8'h28: begin
					   // target can only be 0 or 1
					   data_rd_req[target] <= 1'b1;
					   // read(10) has a 32 bit sector address
					   data_lba <= { cmd_parameter[2],
									 cmd_parameter[3],
									 cmd_parameter[4],
									 cmd_parameter[5] };     
					   // data length is ignored as it's implicitely encoded
					   // in the DMA length
					end
					
					// write(6)
					8'h0a: begin
					   // trigger DMA read from RAM into fifo to write to
					   // device. target can only be 0 or 1
					   data_wr_req[target] <= 1'b1;
					   // write(6) has a 21 bit sector address
					   data_lba <= { 10'b0000000000,
									 cmd_parameter[1][4:0],
									 cmd_parameter[2],
									 cmd_parameter[3] };
					   // data length is ignored as it's implicitely encoded
					   // in the DMA length
					end
					
					// write(10)
					8'h2a: begin
					   // target can only be 0 or 1
					   data_wr_req[target] <= 1'b1;
					   // write(10) has a 32 bit sector address
					   data_lba <= { cmd_parameter[2],
									 cmd_parameter[3],
									 cmd_parameter[4],
									 cmd_parameter[5] };     
					   // data length is ignored as it's implicitely encoded
					   // in the DMA length
					end
					
					default:		  
					  // the command is now complete and we expect bytes to arrive
					  // in the fifo and an interrupt in the end
					  busy <= 1'b1;  // raise request io cntroller
					
				  endcase
			   end
			end
		 end
      end
   end
end
   
endmodule // acsi

// To match emacs with gw_ide default
// Local Variables:
// tab-width: 4
// End:

