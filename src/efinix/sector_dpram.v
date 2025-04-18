module sector_dpram 
(
		  output reg [7:0] douta,
		  output reg [7:0] doutb,
		  input	       clka,
		  input	       ocea,     // unused by sdc
		  input	       cea,      // unused by sdc
		  input	       reseta,   // unused by sdc
		  input	       wrea,
		  input	       clkb,     // same as clka in sdc
		  input	       oceb,     
		  input	       ceb,      // unused by sdc
		  input	       resetb,   // unused by sdc
		  input	       wreb,
		  input [9:0]  ada,
		  input [7:0]  dina,
		  input [9:0]  adb,
		  input [7:0]  dinb
);

reg [7:0] ram [512];

always @(posedge clka) begin
   if(wrea) begin
      ram[ada] <= dina;
      douta <= dina;
   end else begin
      douta <= ram[ada];
   end
end
   
always @(posedge clka) begin
   if(wreb) begin
      ram[adb] <= dinb;
      doutb <= dinb;
   end else begin
      doutb <= ram[adb];
   end
end

endmodule
