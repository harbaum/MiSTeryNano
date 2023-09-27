	ORG $fc000

	bra.s	start
	dc.w	$0142
	
	dc.l	$fc0030
	dc.l    $fc0008 

	ORG $fc030
start:
	move.l	#$1000,sp  	; setup stack
	
	;; wait until after first frame
	move.l	#20000,d0
waitl:	dbra 	d0,waitl
	
	move.w 	#8,$ff8000    	; memory conrol reg, bankl 0 2mb
	move.w  #$1f,$ff8200  	; video base hi 
	move.w  #$80,$ff8202  	; video base mid 	
	
	move.w  #0,$ff8260    	; 320x200
	move.w  #$200,$ff820a 	; PAL

	move.l	#$ff8240,a0	; setup colormap
	move.l	#colormap,a1
	move	#15,d0
cloop:	move.w	(a1)+,(a0)+
	dbra	d0,cloop

mainloop:		
	
	move.l	#$1f8000,a0
	move.l	#199,d0
floop:
	;; 0
	move.w	#$0000,(a0)+
	move.w	#$0000,(a0)+
	move.w	#$0000,(a0)+
	move.w	#$0000,(a0)+

	;; 1
	move.w	#$ffff,(a0)+
	move.w	#$0000,(a0)+
	move.w	#$0000,(a0)+
	move.w	#$0000,(a0)+

	;; 2
	move.w	#$0000,(a0)+
	move.w	#$ffff,(a0)+
	move.w	#$0000,(a0)+
	move.w	#$0000,(a0)+

	;; 3
	move.w	#$ffff,(a0)+
	move.w	#$ffff,(a0)+
	move.w	#$0000,(a0)+
	move.w	#$0000,(a0)+
	
	;; 4
	move.w	#$0000,(a0)+
	move.w	#$0000,(a0)+
	move.w	#$ffff,(a0)+
	move.w	#$0000,(a0)+

	;; 5
	move.w	#$ffff,(a0)+
	move.w	#$0000,(a0)+
	move.w	#$ffff,(a0)+
	move.w	#$0000,(a0)+

	;; 6
	move.w	#$0000,(a0)+
	move.w	#$ffff,(a0)+
	move.w	#$ffff,(a0)+
	move.w	#$0000,(a0)+

	;; 7
	move.w	#$ffff,(a0)+
	move.w	#$ffff,(a0)+
	move.w	#$ffff,(a0)+
	move.w	#$0000,(a0)+
	
	;; 8
	move.w	#$0000,(a0)+
	move.w	#$0000,(a0)+
	move.w	#$0000,(a0)+
	move.w	#$ffff,(a0)+

	;; 9
	move.w	#$ffff,(a0)+
	move.w	#$0000,(a0)+
	move.w	#$0000,(a0)+
	move.w	#$ffff,(a0)+

	;; 10
	move.w	#$0000,(a0)+
	move.w	#$ffff,(a0)+
	move.w	#$0000,(a0)+
	move.w	#$ffff,(a0)+

	;; 11
	move.w	#$ffff,(a0)+
	move.w	#$ffff,(a0)+
	move.w	#$0000,(a0)+
	move.w	#$ffff,(a0)+
	
	;; 12
	move.w	#$0000,(a0)+
	move.w	#$0000,(a0)+
	move.w	#$ffff,(a0)+
	move.w	#$ffff,(a0)+

	;; 13
	move.w	#$ffff,(a0)+
	move.w	#$0000,(a0)+
	move.w	#$ffff,(a0)+
	move.w	#$ffff,(a0)+

	;; 14
	move.w	#$0000,(a0)+
	move.w	#$ffff,(a0)+
	move.w	#$ffff,(a0)+
	move.w	#$ffff,(a0)+

	;; 15
	move.w	#$ffff,(a0)+
	move.w	#$ffff,(a0)+
	move.w	#$ffff,(a0)+
	move.w	#$ffff,(a0)+

	;; fill remainng 64 pixel
	move.l	#15,d1
floop1: move.w	#0,(a0)+
	dbra	d1,floop1
	
	dbra	d0,floop

	;; test byte writing
	;; x top left
	move.b  #$81,$1f8088+0*160
	move.b  #$42,$1f8088+1*160
	move.b  #$24,$1f8088+2*160
	move.b  #$18,$1f8088+3*160	
	move.b  #$18,$1f8088+4*160
	move.b  #$24,$1f8088+5*160
	move.b  #$42,$1f8088+6*160
	move.b  #$81,$1f8088+7*160

	;; + right below
	move.b  #$18,$1f8089+8*160
	move.b  #$18,$1f8089+9*160
	move.b  #$18,$1f8089+10*160
	move.b  #$ff,$1f8089+11*160	
	move.b  #$ff,$1f8089+12*160
	move.b  #$18,$1f8089+13*160
	move.b  #$18,$1f8089+14*160
	move.b  #$18,$1f8089+15*160

	bsr	delay
	
	;; draw something
	move.l	#$1f8000,a0

	move	#24,d1
sloop0:	move.l	#159,d0
sloop1:	move.l	#$f0f0f0f0,(a0)+
	dbra	d0,sloop1
	move.l	#159,d0
sloop2:	move.l	#$0f0f0f0f,(a0)+
	dbra	d0,sloop2
	dbra	d1,sloop0

	bsr	delay
	
	bra	mainloop

delay:
	move.l	#10,d1
lp1:	move.l	#20000,d0
lp2:	dbra 	d0,lp2
	dbra	d1,lp1
	rts
	
colormap:
	dc.w 	$0777, $0700, $0070, $0770
	dc.w 	$0007, $0707, $0077, $0555
	dc.w	$0333, $0733, $0373, $0773
	dc.w	$0337, $0737, $0377, $0000

