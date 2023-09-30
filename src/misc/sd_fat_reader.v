//
// sd_fat_reader.v
//
// wrapper between fdc1772.v and sd_reader.v that accesses data inside
// an image stored on a regular FAT formatted SD card. Partitions with
// 128, 64, 32 or 16 sectors per cluster are supported.
//

// example:
// At 64 sectors per cluster, a cluster can hold 32kBytes. A disk image of 720k
// thus consists of 23 clusters of which the last one is only half used

// TODO
// - search more than the first (root) directory sectors
// - verify cluster chain crossing FAT sector boundaries

module sd_fat_reader # (
    parameter [2:0] CLK_DIV = 3'd2,
    parameter       SIMULATE = 0
) (
    // rstn active-low, 1:working, 0:reset
    input	  rstn,
    input	  clk,
    output	  sdclk,
`ifdef VERILATOR
    output	  sdcmd,
    input	  sdcmd_in,
`else
    inout	  sdcmd, 
`endif   
    input	  sddat0, // FPGA only read SDDAT signal but never drive it
    // show card status
    output [ 3:0] card_stat, // show the sdcard initialize status
    output [ 1:0] card_type, // 0=UNKNOWN    , 1=SDv1    , 2=SDv2  , 3=SDHCv2
    // user read sector command interface (sync with clk)
    input	  rstart, 
    input [31:0]  rsector,
    output	  rbusy,
    output	  rdone,

    output reg [31:0] file_len,   // length of file
    output reg [1:0]  file_ready, // 

    // sector data output interface (sync with clk)
    output	  outen, // when outen=1, a byte of sector content is read out from outbyte
    output [ 8:0] outaddr, // outaddr from 0 to 511, because the sector size is 512
    output [ 7:0] outbyte            // a byte of sector content
);

// export sd card signals when FAT setup is done
assign rbusy = (state == STATE_READY)?ibusy:1'b0;
assign rdone = (state == STATE_READY)?idone:1'b0;  
   
// https://wiki.osdev.org/Partition_Table
// https://de.wikipedia.org/wiki/Volume_Boot_Record
  
localparam [7:0] STATE_RESET     = 8'd0,
                 STATE_MBR       = 8'd1,   // reading master boot record
                 STATE_VBR       = 8'd2,   // reading volume boot record 
                 STATE_RD_DIR    = 8'd3,   // reading directory
                 STATE_SCAN_FILE = 8'd4,   // scan file cluster chain
                 STATE_READY     = 8'd5,
                 STATE_ERROR     = 8'h80;  // + error code

// internally generated signals that match the external r...... signal names
reg		 istart;
reg		 iwaiting;    // waiting for a sector to be read
reg [31:0]	 isector;  
wire		 idone;
wire		 ibusy;  

// filename to search for
wire [7:0]	 search_name [0:10];  
assign search_name = "DISK_A  ST ";  
     
// various "variables" collected during FAT analysis
reg		 mbr_vbr_ok;  // used e.g. to verify the aa/55 marker at the end of the mbr
reg [15:0]	 bps;    // bytes per sector, should be 512
reg [31:0]	 spf;    // sectors per FAT
reg [7:0]	 spc;    // sectors per cluster   
reg [15:0]	 rsvd;   // reserved sectors   
reg [31:0]	 pstart; // start sector of partition
reg [31:0]	 rdirc;  // start cluster of root directory (always 2).
reg	         dir_entry_mismatch;
reg 		 file_found;   
reg [31:0] 	 fcluster;  // start cluster of file

// calculate first data sector which is also the first sector of the root directory
wire [31:0] first_data_sector = pstart + rsvd + 2*spf;

// determine FAT sector, the given file cluster is in
// a cluster entry has 4 bytes in FAT32, thus 128 cluster are stored in a 512 byte sector
reg [31:0]  current_cluster; 
wire [31:0] current_fat_sector = pstart + rsvd + current_cluster[31:7];   
wire [6:0]  current_fat_offset = current_cluster[6:0];   
reg [31:0]  fat [128];  // 512 bytes buffer to hold one FAT sector   
wire [31:0] next_cluster = fat[current_fat_offset];
wire	    end_of_chain = (next_cluster[27:4] == 24'hffffff);

// file cluster table itself
reg [6:0] cluster_table_write_index;

// a cluster table with 128 entries is needed for a cluster size of 16 sectors per
// cluster and a image/file size of up to 1MB
reg [23:0] cluster_table [128];  

// The cluster table length depends on the cluster size. The max ST floppy disk image length
// supported by the fdc1772.v is 1020 sectors per side which is a 12 sectors per track
// disk with 85 tracks. The resulting image size is < 1MB.
// With 64 sectors per cluster (e.g. on a 16GB SD card) this is a cluster size of 32k and
// a total of 32 clusters per st floppy disk image. We also support a cluster size of 128,
// 32 and 16 sectors. Thus max clusters used per floppy disk image is 128 with a cluster
// size of 16 sectors or 8kBytes.

// lcluster and lsector are the current "local" variants of the incoming rsector.
// They map the incoming image sector into a sector on the SD card taking the FAT fs into account
reg [23:0] lcluster;
reg lstart;

// 
wire [6:0] cluster_table_index = (state == STATE_RD_DIR)?7'd0:cluster_table_write_index;
wire [6:0] cluster_table_read_index = 
          (spc == 8'd128)?{ 3'b000, rsector[10:7] }:
          (spc ==  8'd64)?{  2'b00, rsector[10:6] }:
          (spc ==  8'd32)?{   1'b0, rsector[10:5] }:
          /* spc == 16 */           rsector[10:4];  

always @(posedge clk) begin
    lstart <= rstart;
    if(rstart) lcluster <= cluster_table[cluster_table_read_index]-24'd2;

    // not in reset and not waiting for a sector from sd card
    if(rstn && !iwaiting) begin
        // write first cluster table entry as read from the files directory entry
        if(state == STATE_RD_DIR && fcluster != 0)
            cluster_table[cluster_table_index ] <= fcluster;

        // write further cluster table entries as read from FAT
        else if(state == STATE_SCAN_FILE && isector == current_fat_sector && !end_of_chain)
		    cluster_table[cluster_table_index] <= next_cluster;		    
    end
end

wire [31:0] lsector = (first_data_sector + ( 
          (spc == 8'd128)?{    1'b0, lcluster, rsector[6:0] }:
          (spc ==  8'd64)?{   2'b00, lcluster, rsector[5:0] }:
          (spc ==  8'd32)?{  3'b000, lcluster, rsector[4:0] }:
          /* spc == 16 */ { 4'b0000, lcluster, rsector[3:0] }));  

always @(posedge clk) begin
   if(outen) begin

      if(state == STATE_SCAN_FILE) begin
	 if(outaddr[1:0] == 2'b00) fat[outaddr[8:2]][ 7: 0] <= outbyte;	 
	 if(outaddr[1:0] == 2'b01) fat[outaddr[8:2]][15: 8] <= outbyte;	 
	 if(outaddr[1:0] == 2'b10) fat[outaddr[8:2]][23:16] <= outbyte;	 
	 if(outaddr[1:0] == 2'b11) fat[outaddr[8:2]][31:24] <= outbyte;	 
      end
      
      if(state == STATE_MBR || state == STATE_VBR) begin
        if(outaddr == 9'd0) mbr_vbr_ok <= 1'b1; // initially assume mbr/vbr is ok

	 // verify markers at end of mbr and vbr
	 if(outaddr == 9'd510 && outbyte != 8'h55) mbr_vbr_ok <= 1'b0;
	 if(outaddr == 9'd511 && outbyte != 8'haa) mbr_vbr_ok <= 1'b0;   
      end
      
      if(state == STATE_MBR) begin
	 // first partition table entry is at 0x1be
	 
	 // this implementation only deals with FAT32
	 if((outaddr == 9'h1be +  9'd4) && (outbyte != 8'h0c)) mbr_vbr_ok <= 1'b0;   
	 
	 // start sector is at offset 8
	 if(outaddr == 9'h1be +  9'd8) pstart[ 7: 0] <= outbyte;
	 if(outaddr == 9'h1be +  9'd9) pstart[15: 8] <= outbyte;
	 if(outaddr == 9'h1be + 9'd10) pstart[23:16] <= outbyte;
	 if(outaddr == 9'h1be + 9'd11) pstart[31:24] <= outbyte;
      end
      
      if(state == STATE_VBR) begin
	 // bytes per sector (bps)
	 if(outaddr == 9'h0b)  bps[ 7:0] <= outbyte;
	 if(outaddr == 9'h0c)  bps[15:8] <= outbyte;
	 
	 // sectors per cluster
	 if(outaddr == 9'h0d)  spc <= outbyte;
	 
	 // reserved sectors
	 if(outaddr == 9'h0e)  rsvd[ 7:0] <= outbyte;
	 if(outaddr == 9'h0f)  rsvd[15:8] <= outbyte;
	 
	 // number of FATs must be 2
	 if(outaddr == 9'h10 && outbyte != 8'd2) mbr_vbr_ok <= 1'b0;      
	 
	 // sectors per FAT
	 if(outaddr == 9'h24)  spf[ 7: 0] <= outbyte;
	 if(outaddr == 9'h25)  spf[15: 8] <= outbyte;
	 if(outaddr == 9'h26)  spf[23:16] <= outbyte;
	 if(outaddr == 9'h27)  spf[31:24] <= outbyte;
	 
	 // start cluster of root directory
	 if(outaddr == 9'h2c)  rdirc[ 7: 0] <= outbyte;
	 if(outaddr == 9'h2d)  rdirc[15: 8] <= outbyte;
	 if(outaddr == 9'h2e)  rdirc[23:16] <= outbyte;
	 if(outaddr == 9'h2f)  rdirc[31:24] <= outbyte;      

	 // prepare for file search
	 fcluster <= 32'd0;
	 file_found <= 1'b0;	 
      end // if (state == STATE_VBR)
      
      if(state == STATE_RD_DIR) begin
        // initially assume dir entry is fine
        if(outaddr == 9'h00) dir_entry_mismatch <= 1'b0;
	 // reading directory in order to find a file
	 
	 // a directory entry is 32 bytes in size
	 // 0..0a: 8+3 file name, name[0] == 0/0xe5 -> unused
	 // 0b: attribute
	 // 14/15/1a/1b first cluster

	 // there are 16 directory entries per sector
	 // -> outaddr[4:0] are the byte offsets within the entry
	 // -> outaddr[9:5] are index of the entry
	 
	 if(!file_found) begin      
	    // check if this is the file we are searching for
	    if(outaddr[4:0] <= 5'h0a) begin
	       if (outbyte != search_name[outaddr[4:0]])
		 dir_entry_mismatch <= 1'b1;
	    end
	    
	    // don't accept files with hidden/system/volume/directory flags set
	    if(outaddr[4:0] == 5'h0b && (outbyte & 8'h1e))
	      dir_entry_mismatch <= 1'b1;
	    
	    // if "mismatch" is not set when reaching the last byte, then
	    // this was a match
	    if(!dir_entry_mismatch) begin
	       if(outaddr[4:0] == 5'h14) fcluster[23:16] <= outbyte;
	       if(outaddr[4:0] == 5'h15) fcluster[31:24] <= outbyte;
	       if(outaddr[4:0] == 5'h1a) fcluster[ 7: 0] <= outbyte;
	       if(outaddr[4:0] == 5'h1b) fcluster[15: 8] <= outbyte; 

	       if(outaddr[4:0] == 5'h1c) file_len[ 7: 0] <= outbyte;
	       if(outaddr[4:0] == 5'h1d) file_len[15: 8] <= outbyte; 
	       if(outaddr[4:0] == 5'h1e) file_len[23:16] <= outbyte;
	       if(outaddr[4:0] == 5'h1f) file_len[31:24] <= outbyte;
	    end
	 end // if (!file_found)
	 
	 // try with next directory entry
	 if(outaddr[4:0] == 5'h1f) begin
	    if(!dir_entry_mismatch) file_found <= 1'b1;
	    dir_entry_mismatch <= 1'b0;
	 end	 
      end // if (state == STATE_RD_DIR)
   end // if (outen)   
end
   
reg [7:0]	 debug; 

// once rbusy falls for the first time the SD card is configured to read sectors
reg [7:0]	  state;  
always @(posedge clk) begin
   if(!rstn) begin
      state <= STATE_RESET;
      istart <= 1'b0;
      iwaiting <= 1'b0;
      file_ready <= 2'b00;      
   end else begin
      if(iwaiting) begin
	 if(istart) begin
	    if(ibusy) istart <= 1'b0;
	 end else begin
	    if(!ibusy) iwaiting <= 1'b0;	    
	 end
      end else begin
	 // ! iwaiting
	 case(state)
	   STATE_RESET: begin
	      if(ibusy == 1'b0) begin
		 // next: read master boot record sector 0 (MBR)
		 state <= STATE_MBR;
		 istart <= 1'b1;
		 isector <= 32'd0;
		 iwaiting <= 1'b1;
	      end	   
	   end
	   STATE_MBR: begin
	      // analyze MBR
	      if(!mbr_vbr_ok)
		state <= STATE_ERROR + 8'h01;  // error 1: mbr error
	      else begin
		 // next: read volume boot record 
		 state <= STATE_VBR;
		 istart <= 1'b1;
		 isector <= pstart;		 
		 iwaiting <= 1'b1;
	      end
	   end
	   STATE_VBR: begin
	      // analyze partition boot record
	      if(!mbr_vbr_ok)
              state <= STATE_ERROR + 8'h02;  // error 2: vbr error
          else if(spc != 8'd128 && spc != 8'd64 && spc != 8'd32 && spc != 8'd16) 
              state <= STATE_ERROR + 8'h03;  // error 3: unsupported cluster size
	      else begin
		 // next: read root directory
		 state <= STATE_RD_DIR;
		 istart <= 1'b1;
		 isector <= first_data_sector;
		 iwaiting <= 1'b1;
	      end
	   end
	   STATE_RD_DIR: begin
	      if(!file_found)
		// TODO: search in next directory sector
		state <= STATE_ERROR + 8'h04;  // error 3: file not found
	      else begin
		 // next: scan the cluster chain of the file
		 state <= STATE_SCAN_FILE;
		 current_cluster <= fcluster;	     // scan current file chain
		 istart <= 1'b1;
		 isector <= current_fat_sector;		 
		 iwaiting <= 1'b1;

		 // save first cluster in cluster table
//		 cluster_table[0] <= fcluster;
		 cluster_table_write_index <= 7'd1;
	      end
	   end
	   STATE_SCAN_FILE: begin
	      // check if the matching fat sector is buffered
	      if(isector == current_fat_sector) begin
		 // check if end of chain was reached
		 if(end_of_chain) state <= STATE_READY;
		 else begin
		    current_cluster <= next_cluster;

		    // save entry in cluster table
//		    cluster_table[cluster_table_write_index] <= next_cluster;		    
		    cluster_table_write_index <= cluster_table_write_index + 7'd1;
		 end
	      end else begin
		 // a different sector of the FAT is needed for the current entry
		 istart <= 1'b1;
		 isector <= current_fat_sector;
		 iwaiting <= 1'b1;	 		 
	      end
	   end
	   STATE_READY: begin
	      file_ready <= 2'b01;
	   end
	 endcase // case (state)
      end
   end
end
   
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
   .rstart((state == STATE_READY)?lstart:istart), 
   .rsector((state == STATE_READY)?lsector:isector),
   .rbusy(ibusy),
   .rdone(idone),
   
   .outen(outen),
   .outaddr(outaddr),
   .outbyte(outbyte)
);
  

endmodule
