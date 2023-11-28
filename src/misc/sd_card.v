//
// sd_card.v - sd card wrapper currently used to interface to sd_reader.v
//

module sd_card # (
    parameter [2:0] CLK_DIV = 3'd2,
    parameter       SIMULATE = 0
) (
    // rstn active-low, 1:working, 0:reset
    input	     rstn,
    input	     clk,
    output	     sdclk,
`ifdef VERILATOR
    output	     sdcmd,
    input	     sdcmd_in,
`else
    inout	     sdcmd, 
`endif   
    input	     sddat0, // FPGA only read SDDAT signal but never drive it

    // mcu interface
    input	     data_strobe,
    input	     data_start,
    input [7:0]	     data_in,
    output reg [7:0] data_out,

    // export sd image size
    output reg [31:0] image_size,
    output reg [1:0]  image_mounted,

    // read sector command interface (sync with clk), this once was directly tied to the
    // sd card. Now this goes to the MCU via the MCU interface as the MCU translates sector
    // numbers from those the core tries to use to physical ones inside the file system
    // of the sd card
    input [1:0]  rstart, 
    input [31:0] rsector,
    output	     rbusy,
    output	     rdone,

    // sector data output interface (sync with clk)
    output	     outen, // when outen=1, a byte of sector content is read out from outbyte
    output [8:0]     outaddr, // outaddr from 0 to 511, because the sector size is 512
    output [7:0]     outbyte   // a byte of sector content
);

wire [3:0] card_stat;  // show the sdcard initialize status
wire [1:0] card_type;  // 0=UNKNOWN    , 1=SDv1    , 2=SDv2  , 3=SDHCv2

reg [7:0] command;
reg [3:0] byte_cnt;  

reg [7:0] image_target; 

reg	  lstart;   
reg [31:0] lsector;  

// local buffer to hold one sector to be forwarded to the MCU
reg 	   mcu_tx_data;  
reg [8:0]  mcu_tx_cnt;  
reg [7:0] buffer [512];  

// Keep track of current sector destination. We cannot use the command
// directly as the MCU may alter this during sector transfer
reg read_to_mcu;

always @(posedge clk) begin
   if(read_to_mcu && louten)
     buffer[outaddr] <= outbyte;   
end

// register the rising edge of rstart and clear it once
// it has been reported to the MCU

always @(posedge clk) begin
   if(!rstn) begin
      byte_cnt <= 4'd15;
      command <= 8'hff;
      lstart <= 1'b0;
      image_size <= 32'd0;
      image_mounted <= 2'b00;      
   end else begin
      // done from sd reader acknowledges/clears start
      if(rdone) lstart <= 1'b0;

      if(data_strobe) begin
        if(data_start) begin
	    command <= data_in;

        // differentiate between the two reads
        if(data_in == 8'd2 || data_in == 8'd3)
            read_to_mcu <= (data_in == 8'd3);

	    byte_cnt <= 4'd0;	    
	    data_out <= { card_stat, card_type, rbusy, 1'b0 };
	 end else begin
	    if(command == 8'd1) begin
            // request byte
	       if(byte_cnt == 4'd0) data_out <= { 6'b00000, rstart };
	       if(byte_cnt == 4'd1) data_out <= rsector[31:24];
	       if(byte_cnt == 4'd2) data_out <= rsector[23:16];
	       if(byte_cnt == 4'd3) data_out <= rsector[15: 8];
	       if(byte_cnt == 4'd4) data_out <= rsector[ 7: 0];
	    end

	    if(command == 8'd2 || command == 8'd3) begin
            // inform MCU about read state once command has
            // been transferred. Return 0xff until command is
            // complete, then the state of lstart, so the MCU
            // can wait for 0 to be read when waiting for
            // sector data to become available
            if(byte_cnt <= 4'd3) data_out <= 8'hff;
            else	             data_out <= { 7'd0, lstart };
	       
            if(byte_cnt == 4'd0) lsector[31:24] <= data_in;
            if(byte_cnt == 4'd1) lsector[23:16] <= data_in;
            if(byte_cnt == 4'd2) lsector[15: 8] <= data_in;
            if(byte_cnt == 4'd3) begin 
                lsector[ 7: 0] <= data_in;
                lstart <= 1'b1;
                mcu_tx_data <= 1'b0;		  
            end

            // If sector has been requested from sd card, lstart
            // has thus been set and all data has arrived, so
            // lstart is reset again, then start mcu transfer
            if(byte_cnt >= 4'd4) begin
                if(!lstart) begin
                    mcu_tx_data <= 1'b1;
                    mcu_tx_cnt <= 9'd0;
                end
	       
                if(mcu_tx_data) begin
                    data_out <= buffer[mcu_tx_cnt];
                    mcu_tx_cnt <= mcu_tx_cnt + 9'd1;
                end
            end	       
	    end
	       
	    if(command == 8'd4) begin
	       // MCU reports that some image has been inserted. If the image size
	       // is 0, then no image is inserted
	       if(byte_cnt == 4'd0) image_target <= data_in;
	       if(byte_cnt == 4'd1) image_size[31:24] <= data_in;
	       if(byte_cnt == 4'd2) image_size[23:16] <= data_in;
	       if(byte_cnt == 4'd3) image_size[15:8]  <= data_in;
	       if(byte_cnt == 4'd4) begin 
		  image_size[7:0]   <= data_in;
            if(image_target <= 8'd1)
                image_mounted[image_target] <= (image_size[31:8] != 24'd0 || data_in != 8'd0)?1'b1:1'b0;            
	       end
	    end
	    
	    if(byte_cnt != 4'd15) byte_cnt <= byte_cnt + 4'd1;    
        end
      end
   end
end

// only export outen if the resulting data is for the core
wire louten;  
assign outen = read_to_mcu?1'b0:louten;   
   
sd_reader #(.CLK_DIV(CLK_DIV), .SIMULATE(SIMULATE)) sd_reader (
   // rstn active-low, 1:working, 0:reset
   .rstn(rstn),
   .clk(clk),

   .sdclk(sdclk),
   .sdcmd(sdcmd),
`ifdef VERILATOR
   .sdcmd_in(sdcmd_in),
`endif   
   .sddat0(sddat0),
							       
   .card_stat(card_stat),
   .card_type(card_type),

   // lsector is the translated rsector into the file on the FAT fs
   .rstart( lstart ), 
   .rsector( lsector ),
   .rbusy( rbusy ),
   .rdone( rdone ),
   
   .outen(louten),
   .outaddr(outaddr),
   .outbyte(outbyte)
);

endmodule
