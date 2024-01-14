module cubase3_dongle (
	input clk,
	input reset, // POR actually
	input rom3_n,
	input a8,
	output reg d8
);

//File generated from rainbow unicorn farts
//
//From the source file SRD_OK.JED
//
//No rights reserved
//
//Device 5c060
// pin02          = 2
// pin03          = 3
// pin04          = 4
// pin05          = 5
// pin06          = 6
// pin07          = 7
// pin08          = 8
// pin09          = 9
// pin10          = 10
// pin11          = 11
// pin14          = 14
// pin15          = 15
// pin16          = 16
// pin17          = 17
// pin18          = 18
// pin19          = 19
// pin20          = 20
// pin21          = 21
// pin22          = 22
// pin23          = 23
//
//turbo
//
//start
//
// pin03          ^:=  /pin03*/pin14
//                 +   pin03* pin14;
//
// pin04          ^:=  /pin04* pin14
//                 +   pin03*/pin04*/pin14
//                 +   pin03* pin04* pin14;
//
// pin05          ^:=   pin03*/pin05* pin14
//                 +   pin04* pin05* pin14
//                 +   pin03* pin04*/pin05*/pin14;
//
// pin06          ^:=   pin03*/pin06*/pin14
//                 +   pin04*/pin05* pin06
//                 +   pin03* pin04* pin05*/pin06*/pin14;
//
// pin07          ^:=  /pin03* pin05*/pin07
//                 +  /pin04*/pin06* pin07* pin14
//                 +   pin03* pin04* pin05* pin06*/pin07*/pin14;
//
// pin08          ^:=  /pin03*/pin05* pin07*/pin08
//                 +  /pin04* pin06* pin08* pin14
//                 +   pin03* pin04* pin05* pin06* pin07*/pin08*/pin14;
//
// pin09          ^:=  /pin07* pin08*/pin09
//                 +   pin04*/pin05*/pin06* pin09
//                 +   pin03* pin04* pin05* pin06* pin07* pin08*/pin09*/pin14;
//
// pin10          ^:=  /pin04* pin07*/pin08*/pin10
//                 +   pin05* pin06*/pin09* pin10
//                 +   pin03* pin04* pin05* pin06* pin07* pin08* pin09*/pin10*/pin14;
//
// pin15          ^:=  /pin07* pin08*/pin15
//                 +  /pin06* pin09*/pin10* pin15
//                 +   pin03* pin04* pin05* pin06* pin07* pin08* pin09* pin10*/pin14*/pin15;
//
// pin16          ^:=  /pin09*/pin15* pin16
//                 +  /pin08* pin10*/pin16
//                 +   pin03* pin04* pin05* pin06* pin07* pin08* pin09* pin10*/pin14* pin15*/pin16;
//
// pin17          ^:=  /pin08* pin17
//                 +  /pin10*/pin16*/pin17
//                 +   pin03* pin04* pin05* pin06* pin07* pin08* pin09* pin10*/pin14* pin15* pin16*/pin17;
//
// pin18          ^:=  /pin15* pin16* pin18
//                 +   pin08*/pin10* pin17*/pin18
//                 +   pin03* pin04* pin05* pin06* pin07* pin08* pin09* pin10*/pin14* pin15* pin16* pin17*/pin18;
//
// pin19          ^:=   pin10*/pin15*/pin19
//                 +   pin16*/pin17* pin18* pin19
//                 +   pin03* pin04* pin05* pin06* pin07* pin08* pin09* pin10*/pin14* pin15* pin16* pin17* pin18*/pin19;
//
// pin20          ^:=  /pin16*/pin19*/pin20
//                 +   pin17*/pin18* pin20
//                 +   pin03* pin04* pin05* pin06* pin07* pin08* pin09* pin10*/pin14* pin15* pin16* pin17* pin18* pin19*/pin20;
//
// pin21          ^:=  /pin17* pin18*/pin21
//                 +  /pin16* pin19*/pin20* pin21
//                 +   pin03* pin04* pin05* pin06* pin07* pin08* pin09* pin10*/pin14* pin15* pin16* pin17* pin18* pin19* pin20*/pin21;
//
// pin22.ena       =  /pin02;
// pin22          ^:=  /pin04* pin22
//                 +   pin05* pin14*/pin22
//                 +   pin09*/pin14*/pin16*/pin18* pin22
//                 +  /pin06* pin09* pin14* pin17*/pin21* pin22
//                 +   pin03* pin04* pin05* pin06* pin07* pin08* pin09* pin10*/pin14* pin15* pin16* pin17* pin18* pin19* pin20* pin21*/pin22;
//
//
//end

reg pin03;
reg pin04;
reg pin05;
reg pin06;
reg pin07;
reg pin08;
reg pin09;
reg pin10;
reg pin15;
reg pin16;
reg pin17;
reg pin18;
reg pin19;
reg pin20;
reg pin21;

reg rom3_nD;
always @(posedge clk) begin
	rom3_nD <= rom3_n;
	if (reset) begin
		pin03 <= 0;
		pin04 <= 0;
		pin05 <= 0;
		pin06 <= 0;
		pin07 <= 0;
		pin08 <= 0;
		pin09 <= 0;
		pin10 <= 0;
		pin16 <= 0;
		pin17 <= 0;
		pin18 <= 0;
		pin19 <= 0;
		pin20 <= 0;
		pin21 <= 0;
		d8 <= 0;
	end
	else
	if (rom3_n & !rom3_nD) begin
		pin03 <= pin03 ^ ( (!pin03&!a8)
		                   | (pin03& a8));

		pin04 <= pin04 ^ ( ((!pin04& a8)
		                   |  ( pin03&!pin04&!a8)
		                   |  ( pin03& pin04& a8)));

		pin05 <= pin05 ^ ( (( pin03&!pin05& a8)
		                   |  ( pin04& pin05& a8)
		                   |  ( pin03& pin04&!pin05&!a8)));

		pin06 <= pin06 ^ ( (( pin03&!pin06&!a8)
		                   |  ( pin04&!pin05& pin06)
		                   |  ( pin03& pin04& pin05&!pin06&!a8)));

		pin07 <= pin07 ^ ( ((!pin03& pin05&!pin07)
		                   |  (!pin04&!pin06& pin07& a8)
		                   |  ( pin03& pin04& pin05& pin06&!pin07&!a8)));

		pin08 <= pin08 ^ ( ((!pin03&!pin05& pin07&!pin08)
		                   |  (!pin04& pin06& pin08& a8)
		                   |  ( pin03& pin04& pin05& pin06& pin07&!pin08&!a8)));

		pin09 <= pin09 ^ ( ((!pin07& pin08&!pin09)
		                   |  ( pin04&!pin05&!pin06& pin09)
		                   |  ( pin03& pin04& pin05& pin06& pin07& pin08&!pin09&!a8)));

		pin10 <= pin10 ^ ( ((!pin04& pin07&!pin08&!pin10)
		                   |  ( pin05& pin06&!pin09& pin10)
		                   |  ( pin03& pin04& pin05& pin06& pin07& pin08& pin09&!pin10&!a8)));

		pin15 <= pin15 ^ (  ((!pin07& pin08&!pin15)
		                   |  (!pin06& pin09&!pin10& pin15)
		                   |  ( pin03& pin04& pin05& pin06& pin07& pin08& pin09& pin10&!a8&!pin15)));

		pin16 <= pin16 ^ (  ((!pin09&!pin15& pin16)
		                   |  (!pin08& pin10&!pin16)
		                   |  ( pin03& pin04& pin05& pin06& pin07& pin08& pin09& pin10&!a8& pin15&!pin16)));

		pin17 <= pin17 ^ ( ((!pin08& pin17)
		                   |  (!pin10&!pin16&!pin17)
		                   |  ( pin03& pin04& pin05& pin06& pin07& pin08& pin09& pin10&!a8& pin15& pin16&!pin17)));

		pin18 <= pin18 ^ (  ((!pin15& pin16& pin18)
		                   |  ( pin08&!pin10& pin17&!pin18)
		                   |  ( pin03& pin04& pin05& pin06& pin07& pin08& pin09& pin10&!a8& pin15& pin16& pin17&!pin18)));

		pin19 <= pin19 ^ (  (( pin10&!pin15&!pin19)
		                   |  ( pin16&!pin17& pin18& pin19)
		                   |  ( pin03& pin04& pin05& pin06& pin07& pin08& pin09& pin10&!a8& pin15& pin16& pin17& pin18&!pin19)));

		pin20 <= pin20 ^ (  ((!pin16&!pin19&!pin20)
		                   |  ( pin17&!pin18& pin20)
		                   |  ( pin03& pin04& pin05& pin06& pin07& pin08& pin09& pin10&!a8& pin15& pin16& pin17& pin18& pin19&!pin20)));

		pin21 <= pin21 ^ (  ((!pin17& pin18&!pin21)
		                   |  (!pin16& pin19&!pin20& pin21)
		                   |  ( pin03& pin04& pin05& pin06& pin07& pin08& pin09& pin10&!a8& pin15& pin16& pin17& pin18& pin19& pin20&!pin21)));

		d8          <= d8 ^ (  (!pin04& d8)
		                   |  ( pin05& a8&!d8)
		                   |  ( pin09&!a8&!pin16&!pin18& d8)
		                   |  (!pin06& pin09& a8& pin17&!pin21& d8)
		                   |  ( pin03& pin04& pin05& pin06& pin07& pin08& pin09& pin10&!a8& pin15& pin16& pin17& pin18& pin19& pin20& pin21&!d8));
	end

end

endmodule
