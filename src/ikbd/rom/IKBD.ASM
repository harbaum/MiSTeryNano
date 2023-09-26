************************************************************
* This disassembly of the Atari ST's HD6301V1 ROM was made *
* by Sim6xxx as modified for Steem                         *
* Comment by Steven Seagal                                 *
************************************************************

f000	96 88		ldaa 88
f002	81 aa		cmpa #aa			; init? ($AA = code init OK)
f004	27 0a		beq  0a (F010)
f006	cc 00 80	ldd  #0080			; specify: all RAM must be cleared
f009	20 09		bra  09 (F014)
;wait for activity (WU)
f00b	7b 01 11	tim 0111			; TRCSR bit1: wakeup (1 = sleeping)
f00e	26 fb		bne  fb (F00B)			; loop
;RESET (command 80-01 comes here)
f010	0f		sei				; disable interrupts
f011	cc 00 89	ldd  #0089			; specify: save clock and init code
f014	8e 00 ff	lds  #00ff			; stack=$FF
f017	4f		clra			;A=0
f018	97 00		staa 00				; DDR1=0, P1 = input from matrix
f01a	4c		inca
f01b	97 03		staa 03				; DR2=1,
f01d	97 01		staa 01				; DDR2=1, only P20 is output, others are inputs 
f01f	ce ff ff	ldx  #ffff
f022	df 06		stx  06				; DR3=DR4=FF
f024	df 04		stx  04				; DDR3=DDR4=FF
f026	86 05		ldaa #05			; $5=b0101 = 4MHz, 7812.5 bits/s
f028	97 10		staa 10				; write '5' in $10 RMCR
f02a	86 1a		ldaa #1a			; $1A=Receive Interrupt Enable,Receive Enable,Transmit Enable
f02c	97 11		staa 11				; write '1A' in $11 TRCSR
f02e	96 11		ldaa 11				; TRCSR		
f030	96 12		ldaa 12				; RDR
f032	c1 89		cmpb #89
f034	27 12		beq  12 (F048)
f036	4f		clra			        ; A=0
f037	4a		deca
f038	01		nop
f039	26 fc		bne  fc (F037)
f03b	72 01 11	oim 111				; TRCSR
f03e	86 20		ldaa #20
f040	4a		deca
f041	26 fd		bne  fd (F040)			; little waiting loop
;wait for activity (WU)
f043	7b 01 11	tim 0111			; TRCSR bit1: wakeup (1 = sleeping)
f046	26 fb		bne  fb (F043)			; loop
;enable interrupt OCF
f048	86 08		ldaa #08
f04a	97 08		staa 08				; TCSR=8
;test RAM
f04c	86 5a		ldaa #5a			; init RAM loop (with $5A)
f04e	ce 00 00	ldx  #0000
f051	3a		abx
f052	a7 00		staa 00,x
f054	08		inx
f055	8c 01 00	cpx  #0100
f058	26 f8		bne  f8 (F052)
f05a	ce 00 00	ldx  #0000			; read RAM as test
f05d	3a		abx
f05e	a1 00		cmpa 00,x
f060	26 ea		bne  ea (F04C)			; error: init RAM again
f062	08		inx
f063	8c 01 00	cpx  #0100
f066	26 f6		bne  f6 (F05E)
f068	81 a5		cmpa #a5
f06a	27 04		beq  04 (F070)			; OK
f06c	86 a5		ldaa #a5
f06e	20 de		bra  de (F04E)			; do test again
f070	4f		clra			        ; A=0
;test ROM
f071	ce f0 00	ldx  #f000			; start of ROM
f074	a9 00		adca 00,x
f076	08		inx
f077	27 0a		beq  0a (F083)			; all ROM has been read?
f079	8c ff 6f	cpx  #ff6f			; reached end of code?
f07c	26 f6		bne  f6 (F074)
f07e	ce ff f0	ldx  #fff0			; skip part of ROM
f081	20 f1		bra  f1 (F074)
f083	43		coma				; NOT A
f084	26 c6		bne  c6 (F04C)			; must be 0 or redo RAM+ROM test

f086	c6 01		ldab #01
f088	d7 8a		stab 8a				; $8A=1
f08a	4f		clra				; A=0
f08b	5c		incb

; initial matrix scan
f08c	dd 8c		std  8c                         ; $8C - current column
f08e	43		coma				; NOT A
f08f	53		comb				; NOT B
f090	d7 06		stab 06				; DR3		keyboard rows
f092	97 07		staa 07				; DR4
f094	96 02		ldaa 02				; DR1, read matrix output
f096	43		coma				; NOT A
f097	26 0a		bne  0a (F0A3)
f099	7c 00 8a	inc 008a
f09c	dc 8c		ldd  8c                         ; $8C - current column
f09e	05		asld 				; store column
f09f	24 eb		bcc  eb (F08C)			; loop until a columns scanned

f0a1	20 2c		bra  2c (F0CF)

f0a3	d6 8a		ldab 8a
f0a5	c1 05		cmpb #05
f0a7	24 11		bcc  11 (F0BA)
f0a9	85 01		bita #01
f0ab	26 0d		bne  0d (F0BA)
f0ad	85 f0		bita #f0
f0af	27 e8		beq  e8 (F099)
f0b1	5a		decb
f0b2	ce f2 06	ldx  #f206			;data table
f0b5	3a		abx
f0b6	a6 00		ldaa 00,x
f0b8	20 0b		bra  0b (F0C5)
f0ba	c6 01		ldab #01
f0bc	6d 58		tst 58,x
f0be	44		lsra
f0bf	24 fc		bcc  fc (F0BD)
f0c1	17		tba
f0c2	bd f2 f7	jsr  f2f7
f0c5	8a 80		oraa #80
f0c7	d6 11		ldab 11				;TRCSR
f0c9	c5 20		bitb #20			;bit5 TDRE
f0cb	27 fa		beq  fa (F0C7)
f0cd	97 13		staa 13
;
f0cf	cc ff ff	ldd  #ffff
f0d2	dd 06		std  06				;DR3+DR4 (init for KBD)
f0d4	96 11		ldaa 11				;TRCSR
f0d6	85 20		bita #20			;bit5 TDRE
f0d8	27 fa		beq  fa (F0D4)			;wait 
f0da	86 f1		ldaa #f1
f0dc	97 13		staa 13				;TDR=F1 (post reset message)
f0de	4f		clra			;A=0
f0df	ce 00 00	ldx  #0000
f0e2	d6 82		ldab 82
f0e4	c1 a5		cmpb #a5			;check if RAM was zeroed already		
f0e6	26 04		bne  04 (F0EC)
f0e8	c6 80		ldab #80			;pre init
f0ea	20 02		bra  02 (F0EE)
f0ec	c6 89		ldab #89			;post init
;clear ram starting from 80 or 89
f0ee	3a		abx
f0ef	a7 00		staa 00,x
f0f1	08		inx
f0f2	8c 01 00	cpx  #0100
f0f5	26 f8		bne  f8 (F0EF)
;set init flag
f0f7	c6 aa		ldab #aa             
f0f9	d7 88		stab 88				; write $88=$AA: init done
f0fb	c6 80		ldab #80
f0fd	d7 8b		stab 8b				
f0ff	c6 01		ldab #01
f101	d7 8a		stab 8a		
f103	5c		incb
f104	dd 8c		std  8c                         ; $8C - current column
f106	4c		inca
f107	97 b0		staa b0
f109	97 b1		staa b1
f10b	97 b2		staa b2
f10d	97 b3		staa b3
f10f	86 98		ldaa #98
f111	97 c9		staa c9				;Mouse mode = 98, GEM default?
f113	86 28		ldaa #28
f115	97 ca		staa ca
f117	86 06		ldaa #06
f119	97 9b		staa 9b
f11b	86 95		ldaa #95
f11d	97 d7		staa d7
f11f	86 fe		ldaa #fe
f121	97 03		staa 03
f123	4f		clra			;A=0
f124	97 05		staa 05
f126	bd fb 8e	jsr  fb8e			;Read Mouse
f129	dc 09		ldd  09
f12b	cb 13		addb #13
f12d	d1 0c		cmpb 0c
f12f	26 01		bne  01 (F132)
f131	01		nop
f132	dc 09		ldd  09				;FRC
f134	c3 00 10	addd #0010
f137	dd 0b		std  0b				;OCR
f139	0e		cli				;enable interrupts
f13a	96 cb		ldaa cb			;command status
f13c	2a 03		bpl  03 (F141)		;bit7?
f13e	bd f8 d4	jsr  f8d4		;check commands
f141	d6 c9		ldab c9			;Mouse mode
f143	c5 02		bitb #02		
f145	26 2a		bne  2a (F171)
f147	5d		tstb	
f148	2a 0d		bpl  0d (F157)
f14a	bd f1 86	jsr  f186
f14d	7e f3 71	jmp f371

f150	96 cb		ldaa cb				;command status
f152	2a 1d		bpl  1d (F171)
f154	bd f8 d4	jsr  f8d4		;check commands
f157	7b 20 ca	tim 20ca		;Joystick mode on?
f15a	27 de		beq  de (F13A)
f15c	96 c9		ldaa c9	         
f15e	2a 0b		bpl  0b (F16B)		;positive?
f160	96 07		ldaa 07			;DR4
f162	91 07		cmpa 07
f164	26 fa		bne  fa (F160)
f166	84 f0		anda #f0
f168	7e f6 81	jmp f681

; mouse is off
f16b	bd f1 86	jsr  f186		
f16e	7e f6 81	jmp f681

f171	96 ca		ldaa ca
f173	85 20		bita #20
f175	27 c3		beq  c3 (F13A)
f177	85 03		bita #03
f179	27 f0		beq  f0 (F16B)
f17b	7b 08 cb	tim #08,cb
f17e	26 ba		bne  ba (F13A)
f180	44		lsra
f181	24 e8		bcc  e8 (F16B)
f183	7e f8 a2	jmp f8a2

;; this is used during "joystick monitoring" and "interrogate joystick"
f186	96 03		ldaa 03			; read p2 (DR2)
f188	91 03		cmpa 03                 ; read again an compare
f18a	26 fa		bne  fa (F186)		; repeat while not equal
f18c	84 06		anda #06		; mask p21 and p22 (fire j0 and j1)
f18e	d6 9d		ldab 9d
f190	27 15		beq  15 (F1A7)
f192	c1 0a		cmpb #0a
f194	25 1a		bcs  1a (F1B0)
f196	5f		clrb			; B=0
f197	d7 9d		stab 9d
f199	97 c5		staa c5
f19b	16		tab
f19c	98 9c		eora 9c
f19e	94 9b		anda 9b
f1a0	d4 9c		anda 9c
f1a2	1b		aba
f1a3	97 9b		staa 9b
f1a5	96 c5		ldaa c5
f1a7	91 9b		cmpa 9b
f1a9	27 05		beq  05 (F1B0)
f1ab	97 9c		staa 9c
f1ad	7c 00 9d	inc 009d
f1b0	96 07		ldaa 07			; read mouse/joystick
f1b2	91 07		cmpa 07              	; read again to see change
f1b4	26 fa		bne  fa (F1B0)       	; loop while it is changing
f1b6	39		rts

; this is used for joystick interrogate
f1b7	86 01		ldaa #01		; disable mouse/joy0 direction input via 74LS244
f1b9	97 03		staa 03			; this only toggles P2.0
f1bb	dc 8c		ldd  8c			; $8C - current column
f1bd	43		coma			; NOT A
f1be	53		comb			; NOT B
f1bf	d7 06		stab 06			; DR3		keyboard rows
f1c1	c6 ff		ldab #ff
f1c3	d7 05		stab 05			; DDR4		output mode
f1c5	97 07		staa 07			; DR4 
f1c7	96 02		ldaa 02			; DR1		read keyboard
f1c9	91 02		cmpa 02
f1cb	26 fa		bne  fa (F1C7)
f1cd	ce ff ff	ldx  #ffff
f1d0	df 06		stx  06			; DR3
f1d2	c6 fe		ldab #fe		; disable -"-
f1d4	d7 03		stab 03			; DR2
f1d6	5f		clrb			; B=0
f1d7	d7 05		stab 05
f1d9	43		coma			; NOT A
f1da	26 07		bne  07 (F1E3)
f1dc	d6 89		ldab 89
f1de	26 03		bne  03 (F1E3)
f1e0	7e f2 d5	jmp f2d5
f1e3	97 8e		staa 8e
f1e5	d6 8a		ldab 8a
f1e7	c1 05		cmpb #05
f1e9	24 55		bcc  55 (F240)
f1eb	5a		decb
f1ec	ce f1 fe	ldx  #f1fe
f1ef	3a		abx
f1f0	a6 00		ldaa 00,x
f1f2	97 93		staa 93
f1f4	c6 04		ldab #04
f1f6	3a		abx
f1f7	a6 00		ldaa 00,x
f1f9	3a		abx
f1fa	e6 00		ldab 00,x
f1fc	20 0c		bra  0c (F20A)
f1fe	04		lsrd  ;probably data??
f1ff	08		inx
f200	10		sba
f201	20 10		bra  10 (F213)
f203	20 40		bra  40 (F245)
f205	80 1d		suba #1d        ; 1D	CTRL 
f207	2a 38		bpl  38 (F241)  ; 2A	(LEFT) SHIFT   38	ALT		    
f209	36		psha  ;36	(RIGHT) SHIFT
f20a	95 8e		bita 8e
f20c	27 12		beq  12 (F220)
f20e	43		coma			;NOT A
f20f	94 8e		anda 8e
f211	97 8e		staa 8e
f213	96 93		ldaa 93
f215	95 89		bita 89
f217	26 1e		bne  1e (F237)
f219	9a 89		oraa 89
f21b	97 89		staa 89
f21d	4f		clra			;A=0
f21e	20 0f		bra  0f (F22F)
f220	96 89		ldaa 89
f222	95 93		bita 93
f224	27 11		beq  11 (F237)
f226	96 93		ldaa 93
f228	43		coma			;NOT A
f229	94 89		anda 89
f22b	97 89		staa 89
f22d	86 80		ldaa #80
f22f	d7 93		stab 93
f231	9a 93		oraa 93
f233	5f		clrb			;B=0
f234	bd fd 34	jsr  fd34			;send
f237	96 8a		ldaa 8a
f239	81 01		cmpa #01
f23b	26 03		bne  03 (F240)
f23d	7e f2 d5	jmp f2d5
f240	96 11		ldaa 11				;TRCSR
f242	85 c0		bita #c0			;test bit6&7 OVR & RDRF
f244	27 0c		beq  0c (F252)			;
f246	85 40		bita #40			;test bit6 OVR
f248	27 05		beq  05 (F24F)
f24a	bd ff 40	jsr  ff40			;OVR->OVR routine
f24d	20 03		bra  03 (F252)
f24f	bd ff 04	jsr  ff04			;!OVR->receive routine
f252	d6 8b		ldab 8b				;
f254	2b 44		bmi  44 (F29A)
f256	86 01		ldaa #01
f258	d6 89		ldab 89
f25a	c4 03		andb #03
f25c	5a		decb
f25d	c1 02		cmpb #02
f25f	26 0a		bne  0a (F26B)
f261	4f		clra			;A=0
f262	5f		clrb			;B=0
f263	20 06		bra  06 (F26B)
f265	d6 93		ldab 93
f267	26 66		bne  66 (F2CF)
f269	5c		incb
f26a	17		tba
f26b	97 93		staa 93
f26d	ce 00 91	ldx  #0091
f270	3a		abx
f271	a6 00		ldaa 00,x
f273	91 8a		cmpa 8a
f275	26 ee		bne  ee (F265)
f277	09		dex
f278	09		dex
f279	a6 00		ldaa 00,x
f27b	95 8e		bita 8e
f27d	27 07		beq  07 (F286)
f27f	43		coma			;NOT A
f280	94 8e		anda 8e
f282	97 8e		staa 8e
f284	20 df		bra  df (F265)
f286	5c		incb
f287	53		comb			;NOT B
f288	d4 89		anda 89
f28a	d7 89		stab 89
f28c	bd f2 e8	jsr  f2e8
f28f	bd f2 f7	jsr  f2f7
f292	8a 80		oraa #80
f294	5f		clrb			;B=0
f295	bd fd 34	jsr  fd34			;send
f298	20 cb		bra  cb (F265)
f29a	96 8e		ldaa 8e
f29c	27 37		beq  37 (F2D5)
f29e	c6 01		ldab #01
f2a0	20 01		bra  01 (F2A3)
f2a2	58		lslb
f2a3	44		lsra
f2a4	24 fc		bcc  fc (F2A2)
f2a6	17		tba
f2a7	d7 93		stab 93
f2a9	53		comb			;NOT B
f2aa	d4 8e		anda 8e
f2ac	d7 8e		stab 8e
f2ae	d6 8b		ldab 8b
f2b0	c4 03		andb #03
f2b2	ce 00 8f	ldx  #008f
f2b5	3a		abx
f2b6	a7 00		staa 00,x
f2b8	08		inx
f2b9	08		inx
f2ba	96 8a		ldaa 8a
f2bc	a7 00		staa 00,x
f2be	5c		incb
f2bf	da 89		orab 89
f2c1	d7 89		stab 89
f2c3	bd f2 e8	jsr  f2e8
f2c6	96 93		ldaa 93
f2c8	bd f2 f7	jsr  f2f7
f2cb	5f		clrb			;B=0
f2cc	bd fd 34	jsr  fd34			;send
f2cf	96 8b		ldaa 8b
f2d1	81 02		cmpa #02
f2d3	26 c5		bne  c5 (F29A)
f2d5	dc 8c		ldd  8c                 ; $8C - current column
f2d7	05		asld
f2d8	25 05		bcs  05 (F2DF)
f2da	7c 00 8a	inc 008a
f2dd	20 04		bra  04 (F2E3)
f2df	5c		incb
f2e0	d7 8a		stab 8a
f2e2	5c		incb
f2e3	dd 8c		std  8c                 ; $8C - current column
f2e5	7e fe cc	jmp fecc
f2e8	c4 03		andb #03
f2ea	ce f2 f3	ldx  #f2f3			; base of scancodes
f2ed	3a		abx				; index
f2ee	e6 00		ldab 00,x
f2f0	d7 8b		stab 8b				; -> 8B
f2f2	39		rts

;eg Scancodes are here below
f2f3	80 01 00 02 ce f3 11 d6 8a c1 05 25 0d c0  ...........%..
f301	04 58 58 58 3a 5f 20 01 5c 44 24 fc 3a a6  .XXX:_ .\D$.:.
f30f	00 39 00 00 3b 3c 3d 00 00 00 3e 01 02 0f  .9..;<=...>...
f31d	10 1e 60 2c 3f 03 04 11 12 1f 20 2d 40 05  ..`,?..... -@.
f32b	06 13 14 21 2e 2f 41 07 08 15 22 23 30 31  ...!./A..."#01
f339	42 09 0a 16 17 24 25 32 43 0b 0c 18 19 26  B....$%2C....&
f347	33 39 44 0d 29 1a 1b 27 34 3a 62 0e 53 52  39D.)..'4:b.SR
f355	2b 1c 28 35 61 48 47 4b 50 4d 6d 70 63 64  +.(5aHGKPMmpcd
f363	67 68 6a 6b 6e 71 65 66 69 4a 6c 4e 6f 72  ghjknqefiJlNor


f371	84 0f		anda #0f
f373	97 c6		staa c6
f375	84 03		anda #03
f377	ce 00 be	ldx  #00be
f37a	7f 00 c8	clr 00c8
f37d	d6 c3		ldab c3
f37f	bd f3 e3	jsr  f3e3
f382	97 c3		staa c3
f384	96 c6		ldaa c6
f386	44		lsra
f387	44		lsra
f388	84 03		anda #03
f38a	ce 00 bf	ldx  #00bf
f38d	c6 01		ldab #01
f38f	d7 c8		stab c8
f391	d6 c4		ldab c4
f393	bd f3 e3	jsr  f3e3
f396	97 c4		staa c4
f398	7f 00 c1	clr 00c1
f39b	d6 9b		ldab 9b
f39d	c4 06		andb #06
f39f	27 04		beq  04 (F3A5)
f3a1	c1 06		cmpb #06
f3a3	26 02		bne  02 (F3A7)
f3a5	c8 06		eorb #06
f3a7	17		tba
f3a8	d8 c0		eorb c0
f3aa	27 1f		beq  1f (F3CB)
f3ac	97 c0		staa c0
f3ae	d7 c5		stab c5
f3b0	16		tab
f3b1	d4 c5		anda c5
f3b3	d7 c6		stab c6
f3b5	54		lsrb
f3b6	da c6		orab c6
f3b8	c4 05		andb #05
f3ba	d7 c1		stab c1
f3bc	43		coma			;NOT A
f3bd	16		tab				;B=A  
f3be	d4 c5		anda c5
f3c0	d7 c6		stab c6
f3c2	58		lslb
f3c3	da c6		orab c6
f3c5	c4 0a		andb #0a
f3c7	da c1		orab c1
f3c9	d7 c1		stab c1
f3cb	96 c9		ldaa c9				;check Mouse/Joystick mode on $C9
f3cd	48		lsla                            ;bit7 out                            
f3ce	48		lsla                            ;bit6 out
f3cf	24 03		bcc  03 (F3D4)			;test bit6
f3d1	7e f5 eb	jmp f5eb                        ;if set
f3d4	48		lsla                            ;bit5 out
f3d5	24 03		bcc  03 (F3DA)			;test bit5
f3d7	7e f4 39	jmp f439			;if set abs mouse routine
f3da	48		lsla                            ;bit4 out
f3db	24 03		bcc  03 (F3E0)                  ;test bit4
f3dd	7e f4 ba	jmp f4ba                        ;if set joystick evt routine
f3e0	7e f1 50	jmp f150

f3e3	c4 e0		andb #e0
f3e5	97 c5		staa c5
f3e7	a8 00		eora 00,x
f3e9	27 49		beq  49 (F434)
f3eb	81 03		cmpa #03
f3ed	26 05		bne  05 (F3F4)
f3ef	ca 02		orab #02
f3f1	17		tba
f3f2	20 3b		bra  3b (F42F)
f3f4	37		pshb
f3f5	e6 00		ldab 00,x
f3f7	27 07		beq  07 (F400)
f3f9	c1 03		cmpb #03
f3fb	27 03		beq  03 (F400)
f3fd	43		coma			;NOT A
f3fe	84 03		anda #03
f400	33		pulb
f401	81 01		cmpa #01
f403	26 0e		bne  0e (F413)
f405	c5 60		bitb #60
f407	27 16		beq  16 (F41F)
f409	86 01		ldaa #01
f40b	c0 20		subb #20
f40d	c5 60		bitb #60
f40f	27 0e		beq  0e (F41F)
f411	20 23		bra  23 (F436)
f413	c5 40		bitb #40
f415	26 06		bne  06 (F41D)
f417	cb 20		addb #20
f419	c5 40		bitb #40
f41b	27 19		beq  19 (F436)
f41d	86 c1		ldaa #c1
f41f	d6 c8		ldab c8
f421	27 0a		beq  0a (F42D
f423	7b 40 c9	tim 40c9
f426	26 07		bne  07 (F42F)
f428	7b 01 c9	tim 01c9
f42b	26 02		bne  02 (F42F)
f42d	88 80		eora #80
f42f	d6 c5		ldab c5
f431	e7 00		stab 00,x
f433	39		rts

f434	17		tba
f435	39		rts

f436	17		tba
f437	20 f6		bra  f6 (F42F)

f439	ce 00 b8	ldx  #00b8
f43c	dc ac		ldd  ac 			;WORD parameter abs mouse Y
f43e	dd c5		std  c5
f440	96 b3		ldaa b3
f442	d6 c4		ldab c4
f444	bd f4 88	jsr  f488
f447	ce 00 b6	ldx  #00b6
f44a	dc aa		ldd  aa				;WORD parameter abs mouse X
f44c	dd c5		std  c5
f44e	96 b2		ldaa b2
f450	d6 c3		ldab c3
f452	bd f4 88	jsr  f488
f455	d6 c1		ldab c1
f457	27 2c		beq  2c (F485)
f459	17		tba
f45a	9a c2		oraa c2
f45c	97 c2		staa c2
f45e	7b 04 b4	tim 04b4
f461	27 03		beq  03 (F466)
f463	7e f6 2b	jmp f62b

f466	4f		clra			;A=0
f467	c5 05		bitb #05
f469	27 02		beq  02 (F46D)
f46b	8a 01		oraa #01
f46d	c5 0a		bitb #0a
f46f	27 02		beq  02 (F473)
f471	8a 02		oraa #02
f473	94 b4		anda b4
f475	27 0e		beq  0e (F485)
f477	d7 b5		stab b5
f479	c6 05		ldab #05			;5byte parameters
f47b	ce 00 b5	ldx  #00b5			;at $B5
f47e	0f		sei				;disable interrupts
f47f	86 f7		ldaa #f7			;'F7' absolute mouse position record
f481	bd fd 34	jsr  fd34			;send
f484	0e		cli				;enable interrupts
f485	7e f1 50	jmp f150
f488	c5 03		bitb #03
f48a	27 2d		beq  2d (F4B9)
f48c	37		pshb
f48d	58		lslb
f48e	16		tab
f48f	86 00		ldaa #00
f491	dd c7		std  c7
f493	ec 00		ldd  00,x
f495	24 09		bcc  09 (F4A0)
f497	93 c7		subd c7
f499	24 07		bcc  07 (F4A2)
f49b	cc 00 00	ldd  #0000
f49e	20 16		bra  16 (F4B6)
f4a0	d3 c7		addd c7
f4a2	dd c7		std  c7
f4a4	93 c5		subd c5
f4a6	24 0c		bcc  0c (F4B4)
f4a8	dc c7		ldd  c7
f4aa	ed 00		std  00,x
f4ac	33		pulb
f4ad	c0 01		subb #01
f4af	c5 01		bitb #01
f4b1	26 d9		bne  d9 (F48C)
f4b3	39		rts
;data?
f4b4	dc c5		ldd  c5
f4b6	ed 00		std  00,x
f4b8	33		pulb
f4b9	39		rts

; joystick event routine?
f4ba	7f 00 c6	clr 00c6
f4bd	d6 c4		ldab c4
f4bf	d7 c8		stab c8
f4c1	71 03 c8	aim 03c8
f4c4	96 bd		ldaa bd
f4c6	58		lslb
f4c7	24 25		bcc  25 (F4EE)
f4c9	90 c8		suba c8
f4cb	81 81		cmpa #81
f4cd	24 08		bcc  08 (F4D7)
f4cf	81 7f		cmpa #7f
f4d1	25 04		bcs  04 (F4D7)
f4d3	86 80		ldaa #80
f4d5	97 c6		staa c6
f4d7	97 bd		staa bd
f4d9	2a 0a		bpl  0a (F4E5)
f4db	40		nega
f4dc	91 b1		cmpa b1
f4de	25 1f		bcs  1f (F4FF)
f4e0	72 02 c6	oim 2c6
f4e3	20 1a		bra  1a (F4FF)
f4e5	91 b1		cmpa b1
f4e7	25 16		bcs  16 (F4FF)
f4e9	72 01 c6	oim 1c6
f4ec	20 11		bra  11 (F4FF)
f4ee	9b c8		adda c8
f4f0	81 7f		cmpa #7f
f4f2	25 e3		bcs  e3 (F4D7)
f4f4	81 81		cmpa #81
f4f6	24 df		bcc  df (F4D7)
f4f8	72 40 c6	oim 40c6
f4fb	86 7f		ldaa #7f
f4fd	20 d8		bra  d8 (F4D7)
f4ff	d6 c3		ldab c3
f501	d7 c8		stab c8
f503	71 03 c8	aim 03c8
f506	96 bc		ldaa bc
f508	58		lslb
f509	24 26		bcc  26 (F531)
f50b	90 c8		suba c8
f50d	81 81		cmpa #81
f50f	24 09		bcc  09 (F51A)
f511	81 7f		cmpa #7f
f513	25 05		bcs  05 (F51A)
f515	86 80		ldaa #80
f517	72 80 c6	oim 80c6
f51a	97 bc		staa bc
f51c	2a 0a		bpl  0a (F528)
f51e	40		nega
f51f	91 b0		cmpa b0
f521	25 1f		bcs  1f (F542)
f523	72 02 c6	oim 2c6
f526	20 1a		bra  1a (F542)
f528	91 b0		cmpa b0
f52a	25 16		bcs  16 (F542)
f52c	72 01 c6	oim 1c6
f52f	20 11		bra  11 (F542)
f531	9b c8		adda c8
f533	81 7f		cmpa #7f
f535	25 e3		bcs  e3 (F51A)
f537	81 81		cmpa #81
f539	24 df		bcc  df (F51A)
f53b	72 40 c6	oim 40c6
f53e	86 7f		ldaa #7f
f540	20 d8		bra  d8 (F51A)
f542	96 c6		ldaa c6
f544	27 15		beq  15 (F55B)
f546	84 c0		anda #c0
f548	26 37		bne  37 (F581)
f54a	7b 08 c9	tim 08c9		;test bit3 of mouse mode (set by RESUME)
f54d	26 07		bne  07 (F556)
f54f	7b 0f c1	tim 0fc1		;test buttons
f552	27 51		beq  51 (F5A5)
f554	20 2b		bra  2b (F581)
f556	7b 80 d7	tim 80d7		;test bit7 of output buffer counter
f559	26 26		bne  26 (F581)
f55b	7b 0f c1	tim 0fc1		;test buttons
f55e	27 45		beq  45 (F5A5)
f560	7b 04 b4	tim 04b4		;test button action
f563	27 03		beq  03 (F568)
f565	7e f6 2b	jmp f62b
f568	96 c0		ldaa c0			;buttons are at $C0
f56a	44		lsra			;shift<<
f56b	8a f8		oraa #f8		;"F8" mouse packet + buttons
f56d	ce 00 bc	ldx  #00bc		;bytes are at $BC
f570	0f		sei			;disable interrupts
f571	c6 02		ldab #02		;2byte parameters (x,y)
f573	bd fd 34	jsr  fd34		;send
f576	24 06		bcc  06 (F57E)
f578	7f 00 bd	clr 00bd
f57b	7f 00 bc	clr 00bc
f57e	0e		cli				;enable interrupts
f57f	20 24		bra  24 (F5A5)

f581	96 c0		ldaa c0				;buttons are at $C0
f583	44		lsra				;shift<<
f584	8a f8		oraa #f8			;"F8" mouse packet + buttons
f586	ce 00 bc	ldx  #00bc			;bytes are at $BC
f589	0f		sei				;disable interrupts
f58a	c6 02		ldab #02			;2byte parameters (x,y)
f58c	bd fd 34	jsr  fd34			;send
f58f	24 06		bcc  06 (F597)
f591	7f 00 bd	clr 00bd
f594	7f 00 bc	clr 00bc
f597	0e		cli				;enable interrupts
f598	7b 0f c1	tim 0fc1
f59b	27 08		beq  08 (F5A5)
f59d	7b 04 b4	tim 04b4
f5a0	27 03		beq  03 (F5A5)
f5a2	7e f6 2b	jmp f62b

f5a5	7e f1 50	jmp f150

f5a8	7f 00 c6	clr 00c6
f5ab	d7 c8		stab c8
f5ad	71 03 c8	aim 03c8
f5b0	a6 00		ldaa 00,x
f5b2	58		lslb
f5b3	24 25		bcc  25 (F5DA)
f5b5	90 c8		suba c8
f5b7	81 81		cmpa #81
f5b9	24 09		bcc  09 (F5C4)
f5bb	81 7f		cmpa #7f
f5bd	25 05		bcs  05 (F5C4)
f5bf	72 80 c6	oim 80c6
f5c2	86 80		ldaa #80
f5c4	a7 00		staa 00,x
f5c6	2a 0a		bpl  0a (F5D2)
f5c8	40		nega
f5c9	91 c5		cmpa c5
f5cb	25 0c		bcs  0c (F5D9)
f5cd	72 02 c6	oim 2c6
f5d0	20 07		bra  07 (F5D9)
f5d2	91 c5		cmpa c5
f5d4	25 03		bcs  03 (F5D9)
f5d6	72 01 c6	oim 1c6
f5d9	39		rts

f5da	9b c8		adda c8
f5dc	81 7f		cmpa #7f
f5de	25 e4		bcs  e4 (F5C4)
f5e0	81 81		cmpa #81
f5e2	24 e0		bcc  e0 (F5C4)
f5e4	72 40 c6	oim 40c6
f5e7	86 7f		ldaa #7f
f5e9	20 d9		bra  d9 (F5C4)

f5eb	96 af		ldaa af
f5ed	97 c5		staa c5
f5ef	ce 00 bb	ldx  #00bb
f5f2	d6 c4		ldab c4
f5f4	bd f5 a8	jsr  f5a8
f5f7	96 c6		ldaa c6
f5f9	27 10		beq  10 (F60B)
f5fb	84 82		anda #82
f5fd	27 04		beq  04 (F603)
f5ff	c6 01		ldab #01
f601	20 02		bra  02 (F605)
f603	c6 00		ldab #00
f605	bd f6 56	jsr  f656
f608	7f 00 bb	clr 00bb
f60b	96 ae		ldaa ae
f60d	97 c5		staa c5
f60f	ce 00 ba	ldx  #00ba
f612	d6 c3		ldab c3
f614	bd f5 a8	jsr  f5a8
f617	96 c6		ldaa c6
f619	27 10		beq  10 (F62B)
f61b	84 82		anda #82
f61d	27 04		beq  04 (F623)
f61f	c6 03		ldab #03
f621	20 02		bra  02 (F625)
f623	c6 02		ldab #02
f625	bd f6 56	jsr  f656
f628	7f 00 ba	clr 00ba
f62b	d6 c1		ldab c1
f62d	27 24		beq  24 (F653)
f62f	c4 03		andb #03
f631	27 0c		beq  0c (F63F)
f633	54		lsrb
f634	24 04		bcc  04 (F63A)
f636	c6 05		ldab #05
f638	20 02		bra  02 (F63C)
f63a	c6 07		ldab #07
f63c	bd f6 56	jsr  f656
f63f	d6 c1		ldab c1
f641	c4 0c		andb #0c
f643	27 0e		beq  0e (F653)
f645	54		lsrb
f646	54		lsrb
f647	54		lsrb
f648	24 04		bcc  04 (F64E)
f64a	c6 04		ldab #04
f64c	20 02		bra  02 (F650)
f64e	c6 06		ldab #06
f650	bd f6 56	jsr  f656
f653	7e f1 50	jmp f150
f656	7f 00 c7	clr 00c7
f659	ce f6 79	ldx  #f679			;arrows table
f65c	3a		abx
f65d	a6 00		ldaa 00,x
f65f	81 60		cmpa #60
f661	24 02		bcc  02 (F665)
f663	97 c7		staa c7
f665	0f		sei				;disable interrupts
f666	5f		clrb			;B=0
f667	bd fd 34	jsr  fd34			;send
f66a	24 0b		bcc  0b (F677)
f66c	96 c7		ldaa c7				;C7
f66e	27 07		beq  07 (F677)
f670	8a 80		oraa #80
f672	7f 00 c7	clr 00c7
f675	20 ee		bra  ee (F665)
f677	0e		cli				;enable interrupts
f678	39		rts
;arrows 48 up 50 down 4D right 4B left
f679	48 50  HP
f67b	4d 4b  MK
f67d	74 75  tu ;?
f67f	f4     ..
;this address is jumped to, it's code
f681	43		coma			;NOT A
f682	d6 9e		ldab 9e
f684	27 15		beq  15 (F69B)
f686	c1 05		cmpb #05
f688	25 1a		bcs  1a (F6A4)
f68a	5f		clrb			;B=0
f68b	d7 9e		stab 9e
f68d	97 c5		staa c5
f68f	16		tab
f690	98 a0		eora a0
f692	94 9f		anda 9f
f694	d4 a0		anda a0
f696	1b		aba
f697	97 9f		staa 9f
f699	96 c5		ldaa c5
f69b	91 9f		cmpa 9f
f69d	27 05		beq  05 (F6A4)
f69f	97 a0		staa a0
f6a1	7c 00 9e	inc 009e
f6a4	7b 04 ca	tim 04ca
f6a7	27 03		beq  03 (F6AC)
f6a9	7e f7 a6	jmp f7a6
f6ac	96 9f		ldaa 9f			;A=($9F)
f6ae	91 a9		cmpa a9			;A<>($A9)?
f6b0	26 0e		bne  0e (F6C0)
f6b2	96 9b		ldaa 9b
f6b4	d6 c9		ldab c9	
f6b6	c5 02		bitb #02
f6b8	26 4d		bne  4d (F707)
f6ba	5d		tstb
f6bb	2a 48		bpl  48 (F705)
f6bd	7e f1 3a	jmp f13a
f6c0	97 a9		staa a9			;($A9)=A
f6c2	7b 02 c9	tim 02c9		;Mouse mode monitoring?
f6c5	26 05		bne  05 (F6CC)
f6c7	ce ff ff	ldx  #ffff
f6ca	20 1e		bra  1e (F6EA)
f6cc	ce 00 00	ldx  #0000
f6cf	84 0f		anda #0f
f6d1	e6 a4		ldab a4,x
f6d3	c4 0f		andb #0f
f6d5	11		cba
f6d6	27 1c		beq  1c (F6F4)
f6d8	e6 a4		ldab a4,x
f6da	48		lsla
f6db	58		lslb
f6dc	46		rora
f6dd	a7 a4		staa a4,x
f6df	09		dex
f6e0	26 05		bne  05 (F6E7)
f6e2	72 40 ca	oim 40ca
f6e5	20 10		bra  10 (F6F7)
f6e7	72 80 ca	oim 80ca
f6ea	96 a9		ldaa a9
f6ec	44		lsra
f6ed	44		lsra
f6ee	44		lsra
f6ef	44		lsra
f6f0	08		inx
f6f1	08		inx
f6f2	20 dd		bra  dd (F6D1)
f6f4	09		dex
f6f5	26 f3		bne  f3 (F6EA)
f6f7	96 9b		ldaa 9b
f6f9	d6 c9		ldab c9
f6fb	c5 02		bitb #02
f6fd	26 08		bne  08 (F707)
f6ff	5d		tstb
f700	2a 03		bpl  03 (F705)
f702	7e f7 41	jmp f741
f705	8a fb		oraa #fb
f707	43		coma			;NOT A
f708	91 a8		cmpa a8
f70a	27 35		beq  35 (F741)
f70c	97 a8		staa a8
f70e	46		rora
f70f	d6 c9		ldab c9
f711	c5 02		bitb #02
f713	26 07		bne  07 (F71C)
f715	ce 00 01	ldx  #0001
f718	46		rora
f719	0d		sec				;set carry
f71a	20 04		bra  04 (F720)
f71c	ce 00 00	ldx  #0000
f71f	0c		clc
f720	46		rora
f721	e6 a4		ldab a4,x
f723	24 06		bcc  06 (F72B)
f725	2b 10		bmi  10 (F737)
f727	ca 80		orab #80
f729	20 04		bra  04 (F72F)
f72b	2a 0a		bpl  0a (F737)
f72d	c4 7f		andb #7f
f72f	e7 a4		stab a4,x
f731	4d		tsta
f732	2b 0a		bmi  0a (F73E)
f734	72 80 ca	oim 80ca
f737	4d		tsta
f738	2b 07		bmi  07 (F741)
f73a	08		inx
f73b	0d		sec				;set carry
f73c	20 e2		bra  e2 (F720)
f73e	72 40 ca	oim 40ca
f741	96 ca		ldaa ca				;CA Joystick mode
f743	85 02		bita #02			;bit1 monitor
f745	26 31		bne  31 (F778)
f747	85 c0		bita #c0
f749	27 08		beq  08 (F753)
f74b	85 08		bita #08
f74d	26 07		bne  07 (F756)
f74f	0e		cli				;enable interrupts
f750	71 3f ca	aim 3fca
f753	7e f1 3a	jmp f13a

f756	85 80		bita #80
f758	27 0c		beq  0c (F766)
f75a	0f		sei				;disable interrupts
f75b	86 fe		ldaa #fe			;'FE' joystick 0 event
f75d	c6 01		ldab #01			;1byte parameter
f75f	ce 00 a4	ldx  #00a4			;at A4 (%x000yyyy)
f762	bd fd 34	jsr  fd34			;send
f765	0e		cli				;enable interrupts
f766	7b 40 ca	tim 40ca			;is there joysitck 1 event? ($CA bit6)
f769	27 e4		beq  e4 (F74F)
f76b	0f		sei				;disable interrupts
f76c	86 ff		ldaa #ff			;'FF' joystick 1 event
f76e	c6 01		ldab #01			;1byte parameter
f770	ce 00 a5	ldx  #00a5			;at $A5
f773	bd fd 34	jsr  fd34			;send (%x000yyyy)
f776	20 d7		bra  d7 (F74F)

;joystick monitor ?
f778	b6 00 a7	ldaa 00a7
f77b	26 d2		bne  d2 (F74F)
f77d	96 94		ldaa 94
f77f	b7 00 a7	staa 00a7
f782	4f		clra			;A=0
f783	d6 a4		ldab a4
f785	2a 02		bpl  02 (F789)
f787	8a 02		oraa #02
f789	58		lslb
f78a	58		lslb
f78b	58		lslb
f78c	58		lslb
f78d	d7 a9		stab a9
f78f	d6 a5		ldab a5
f791	2a 02		bpl  02 (F795)
f793	8a 01		oraa #01
f795	c4 7f		andb #7f
f797	da a9		orab a9
f799	d7 a9		stab a9
f79b	0f		sei				;disable interrupts
f79c	c6 01		ldab #01			;1 parameter
f79e	ce 00 a9	ldx  #00a9			;address $A9
f7a1	bd fd 34	jsr  fd34			;send
f7a4	20 a9		bra  a9 (F74F)

f7a6	71 7f a1	aim 7fa1
f7a9	ce 00 00	ldx  #0000
f7ac	86 0c		ldaa #0c
f7ae	97 c5		staa c5
f7b0	d6 9f		ldab 9f
f7b2	d4 c5		anda c5
f7b4	26 17		bne  17 (F7CD)
f7b6	d6 c5		ldab c5
f7b8	d5 94		bita 94
f7ba	27 0e		beq  0e (F7CA)
f7bc	4f		clra			;A=0
f7bd	a7 a4		staa a4,x
f7bf	a7 a6		staa a6,x
f7c1	a7 a8		staa a8,x
f7c3	53		comb			;NOT B
f7c4	d4 94		anda 94
f7c6	d7 94		stab 94
f7c8	8d 25		bsr  25 (F7EF)
f7ca	7e f8 5d	jmp f85d
f7cd	d1 c5		cmpb c5
f7cf	26 03		bne  03 (F7D4)
f7d1	7e f8 5d	jmp f85d
f7d4	96 94		ldaa 94
f7d6	94 c5		anda c5
f7d8	11		cba
f7d9	27 20		beq  20 (F7FB)
f7db	43		coma			;NOT A
f7dc	94 94		anda 94
f7de	1b		aba
f7df	97 94		staa 94
f7e1	8d 0c		bsr  0c (F7EF)
f7e3	86 64		ldaa #64
f7e5	a7 a2		staa a2,x
f7e7	a6 95		ldaa 95,x
f7e9	27 4c		beq  4c (F837)
f7eb	a7 a4		staa a4,x
f7ed	20 40		bra  40 (F82F)
f7ef	96 a1		ldaa a1
f7f1	2b 03		bmi  03 (F7F6)
f7f3	84 df		anda #df
f7f5	7d 84 bf	tst 84bf
f7f8	97 a1		staa a1
f7fa	39		rts

f7fb	96 a1		ldaa a1
f7fd	2b 06		bmi  06 (F805)
f7ff	85 20		bita #20
f801	26 0a		bne  0a (F80D)
f803	20 04		bra  04 (F809)
f805	85 40		bita #40
f807	26 04		bne  04 (F80D)
f809	e6 95		ldab 95,x
f80b	26 0a		bne  0a (F817)
f80d	e6 99		ldab 99,x
f80f	27 4c		beq  4c (F85D)
f811	e6 a8		ldab a8,x
f813	26 48		bne  48 (F85D)
f815	20 20		bra  20 (F837)
f817	e6 97		ldab 97,x
f819	27 04		beq  04 (F81F)
f81b	e6 a6		ldab a6,x
f81d	27 0c		beq  0c (F82B)
f81f	e6 a4		ldab a4,x
f821	26 3a		bne  3a (F85D)
f823	8d 4a		bsr  4a (F86F)
f825	e6 99		ldab 99,x
f827	e7 a8		stab a8,x
f829	20 32		bra  32 (F85D)
f82b	e6 a4		ldab a4,x
f82d	27 06		beq  06 (F835)
f82f	e6 97		ldab 97,x
f831	e7 a6		stab a6,x
f833	20 06		bra  06 (F83B)
f835	8d 38		bsr  38 (F86F)
f837	e6 99		ldab 99,x
f839	e7 a8		stab a8,x
f83b	d6 94		ldab 94
f83d	ce f8 7a	ldx  #f87a;data?
f840	96 a1		ldaa a1
f842	2b 04		bmi  04 (F848)
f844	08		inx
f845	08		inx
f846	54		lsrb
f847	54		lsrb
f848	54		lsrb
f849	c4 01		andb #01
f84b	3a		abx
f84c	a6 00		ldaa 00,x
f84e	0f		sei				;disable interrupts
f84f	16		tab
f850	ca 80		orab #80
f852	d7 c6		stab c6
f854	ce 00 c6	ldx  #00c6
f857	c6 01		ldab #01
f859	bd fd 34	jsr  fd34			;send
f85c	0e		cli				;enable interrupts
f85d	96 a1		ldaa a1
f85f	2b 1d		bmi  1d (F87E)
f861	8a 80		oraa #80
f863	97 a1		staa a1
f865	86 03		ldaa #03
f867	97 c5		staa c5
f869	ce 00 01	ldx  #0001
f86c	7e f7 b0	jmp f7b0
f86f	4d		tsta
f870	2b 03		bmi  03 (F875)
f872	8a 20		oraa #20
f874	7d 8a 40	tst 8a40
f877	97 a1		staa a1
f879	39		rts

;data, codes for arrows?
f87a	48 50  HP
f87c	4b 4d  KM

f87e	86 74		ldaa #74		;A=$74
f880	d6 a1		ldab a1			;B=(A1)
f882	7b 02 9b	tim 029b		;test bit1 of $9B (buttons)
f885	26 08		bne  08 (F88F)
f887	c5 02		bitb #02
f889	26 14		bne  14 (F89F)
f88b	ca 02		orab #02
f88d	20 08		bra  08 (F897)
f88f	c5 02		bitb #02
f891	27 0c		beq  0c (F89F)
f893	c4 fd		andb #fd
f895	8a 80		oraa #80
f897	d7 a1		stab a1
f899	0f		sei				;disable interrupts
f89a	5f		clrb			;B=0
f89b	bd fd 34	jsr  fd34			;send
f89e	0e		cli				;enable interrupts
f89f	7e f1 3a	jmp f13a

;; this is used in the fire button monitoring mode
f8a2	7b 10 cb	tim #10,cb
f8a5	26 2a		bne  2a (F8D1)
f8a7	d6 d7		ldab d7
f8a9	2a 26		bpl  26 (F8D1)
f8ab	86 16		ldaa #16			; 22 times ...
f8ad	4a		deca
f8ae	26 fd		bne  fd (F8AD)			; ... loop -> ~88us
f8b0	96 03		ldaa 03				; read p2 (dr2)
f8b2	91 03		cmpa 03				; read again an compare
f8b4	26 fa		bne  fa (F8B0)			; repeat until equal
f8b6	85 04		bita #04                        ; test TX??
f8b8	27 01		beq  01 (F8BB)			; ???
f8ba	6d 0d		tst 0d,x                        ; 0d is SEC
f8bc	96 a4		ldaa a4
f8be	49		rola
f8bf	97 a4		staa a4
f8c1	7a 00 a5	dec 00a5
f8c4	26 0b		bne  0b (F8D1)
f8c6	c6 08		ldab #08
f8c8	d7 a5		stab a5
f8ca	7b 20 11	tim 2011			;TRCSR
f8cd	27 fb		beq  fb (F8CA)
f8cf	97 13		staa 13
f8d1	7e f1 3a	jmp f13a

;routine check for commands 
f8d4	71 78 cb	aim 78cb		;($CB) clear bit7
f8d7	d6 cd		ldab cd			;B=($CD)=command
f8d9	17		tba			;A=B=command
f8da	2a 17		bpl  17 (F8F3)		;bit7=0?
; checking commands >=$80
f8dc	c1 80		cmpb #80		;command $80 (reset)?
f8de	26 03		bne  03 (F8E3)
f8e0	7e f9 90	jmp f990
f8e3	c1 87		cmpb #87		;min status command
f8e5	25 2f		bcs  2f (F916)
f8e7	c1 9b		cmpb #9b		;max status command
f8e9	24 2b		bcc  2b (F916)
f8eb	c4 7f		andb #7f
f8ed	c0 07		subb #07
f8ef	cb 1c		addb #1c		;<1=$C?
f8f1	20 0a		bra  0a (F8FD)
; checking commands <$80
f8f3	c1 07		cmpb #07		;min
f8f5	25 1f		bcs  1f (F916)
f8f7	c1 23		cmpb #23		;max
f8f9	24 1b		bcc  1b (F916)
f8fb	c0 07		subb #07		;make index...
f8fd	58		lslb
f8fe	ce f9 30	ldx  #f930		;routine table start
f901	3a		abx			;index with B
f902	ee 00		ldx  00,x		;load word in X
f904	27 10		beq  10 (F916)		;0->exit
f906	85 80		bita #80		;bit7
f908	27 0a		beq  0a (F914)
f90a	7b 08 cb	tim 08cb		;CB bit3 "output disabled"?
f90d	26 07		bne  07 (F916)
f90f	7b 03 ca	tim 03ca		;CA bit0,1 BUSY?
f912	26 02		bne  02 (F916)
f914	6e 00		jmp 00,x		;jump to one of handling routines
f916	71 18 cb	aim 18cb		;"no command"
f919	20 0e		bra  0e (F929)

;$11 RESUME
f91b	7b 08 cb	tim 08cb			;CB bit3 BUSY?
f91e	27 09		beq  09 (F929)			;no, exit
f920	71 f7 cb	aim f7cb			;CB clear bit3
f923	72 08 c9	oim 8c9				;Mouse mode set bit 3
f926	72 04 11	oim 411				;TRCSR set bit 2 TIE
f929	7f 00 cc	clr 00cc			;clear command
f92c	72 10 11	oim 1011			;TRCSR set bit4 RIE
f92f	39		rts

;data: routine addresses to handle IKBD commands
f930	fa a4  ..					;$7 SET MOUSE BUTTON ACTION
f932	fa b9  ..					;$8 SET RELATIVE MOUSE POSITION REPORTING
f934	fa cb  ..					;$9 SET ABSOLUTE MOUSE POSITIONING
f936	fa e8  ..					;$A SET MOUSE KEYCODE MOUSE
f938	fb 0b  ..					;$B SET MOUSE THRESHOLD
f93a	fb 25  .%					;$C SET MOUSE SCALE
f93c	fb 39  .9					;$D INTERROGATE MOUSE POSITION
f93e	fb 5f  ._					;$E LOAD MOUSE POSITION
f940	fb 7c  .|					;$F SET Y=0 AT BOTTOM
f942	fb 82  ..					;$10 SET Y=0 AT TOP
f944	f9 1b  ..					;$11 RESUME
f946	fb 88  ..					;$12 DISABLE MOUSE
f948	f9 af  ..					;$13 PAUSE OUTPUT
f94a	f9 c1  ..					;$14 SET JOYSTICK EVENT REPORTING
f94c	f9 c5  ..					;$15 SET JOYSTICK INTERROGATION MODE
f94e	f9 cc  ..					;$16 JOYSTICK INTERROGATE
f950	f9 f3  ..					;$17 SET JOYSTICK MONITORING
f952	fa 12  ..					;$18 SET FIRE BUTTON MONITORING
f954	fa 21  .!					;$19 SET JOYSTICK KEYCODE MODE
f956	fa 41  .A					;$1A DISABLE JOYSTICKS
f958	fa 5b  .[					;$1B TIME-OF-DAY CLOCK SET
f95a	fa 95  ..					;$1C INTERROGATE TIME-OF-DAT CLOCK
f95c	00 00  ..
f95e	00 00  ..
f960	00 00  ..
f962	fb d4  ..					;$20 MEMORY LOAD
f964	fc 16  ..					;$21 MEMORY READ
f966	fc 3b  .;					;$22 CONTROLLER EXECUTE
f968	fc 59  .Y					;0x87    mouse button action
f96a	fc 62  .b					;0x88 (or 0x89 or 0x8A)  ; request mouse mode
f96c	fc 62  .b
f96e	fc 62  .b
f970	fc 83  ..					;0x8B    mouse threshold
f972	fc 8c  ..					;0x8C    mouse scale
f974	00 00  ..
f976	00 00  ..
f978	fc 95  ..					;0x8F    mouse vertical coordinates
f97a	fc 95  ..					;0x90    (0x0F Y=0 at bottom  0x10 Y=0 at top)
f97c	00 00  ..
f97e	fc a2  ..					;0x92    mouse enable/disable (0x00 enabled 0x12 disabled)
f980	00 00  ..
f982	fc ae  ..					;0x94    joystick mode 
f984	fc ae  ..					;0x95    joystick mode
f986	00 00  ..					
f988	00 00  ..
f98a	00 00  ..
f98c	fc ae  ..					;0x99    joystick mode (and not $96)
f98e	fc c9  ..					;0x9A    joystick enable/disable (0x00 enabled 0x1A disabled)

;RESET
f990	71 ef 11	aim ef11			;TRCSR clear bit7 RDRF
f993	c6 02		ldab #02
f995	bd fc fe	jsr  fcfe			;check parameter in
f998	24 11		bcc  11 (F9AB)			;if C=0 then PC=PC+M if carry CLEARED, not ready
f99a	96 ce		ldaa ce				;load parameter 1 ($CE)
f99c	81 01		cmpa #01			;=1? (command 80-1 = reset)
f99e	26 08		bne  08 (F9A8)			;no, ignore
f9a0	8e 00 ff	lds  #00ff			;reset stack
f9a3	ce f0 10	ldx  #f010
f9a6	3c		pshx				;change return address
f9a7	39		rts				;go there ($F010)

f9a8	7e f9 29	jmp f929

f9ab	72 10 11	oim 1011			;TRCSR set bit4 RIE
f9ae	39		rts

;$13 PAUSE OUTPUT
f9af	7b 08 cb	tim 08cb			;test bit 3 of CB
f9b2	26 0a		bne  0a (F9BE)			;already disabled
f9b4	72 08 cb	oim 8cb				;disable ... (CB, set bit 3)
f9b7	71 f7 c9	aim f7c9			;disable mouse (C9, bit 7)
f9ba	96 d5		ldaa d5
f9bc	97 d8		staa d8				;D8=D5
f9be	7e f9 29	jmp f929			;done

;$14 SET JOYSTICK EVENT REPORTING
f9c1	86 28		ldaa #28			;bit5+3
f9c3	20 02		bra  02 (F9C7)
;$15 SET JOYSTICK INTERROGATION MODE
f9c5	86 30		ldaa #30			;bit5+4
f9c7	97 ca		staa ca				;CA joystick mode
f9c9	7e fa 47	jmp fa47

;$16 JOYSTICK INTERROGATE
f9cc	96 ca		ldaa ca				;($CA) joystick mode
f9ce	85 20		bita #20			;test bit5 (joystick enabled)
f9d0	26 03		bne  03 (F9D5)
f9d2	7e f9 29	jmp f929			;done
f9d5	85 18		bita #18			;
f9d7	27 17		beq  17 (F9F0)
f9d9	7b 02 c9	tim 02c9			;test Mouse mode bit1 button monitoring
f9dc	26 03		bne  03 (F9E1)                  ;
f9de	7f 00 a4	clr 00a4			;monitoring->A4=0 (A5 kept)
;send joystick info
f9e1	0f		sei				;disable interrupts
f9e2	86 fd		ldaa #fd			;joystick report header
f9e4	c6 02		ldab #02			;2 byte parameters
f9e6	ce 00 a4	ldx  #00a4			;address of parameters=A4
f9e9	bd fd 34	jsr  fd34			;send
f9ec	0e		cli				;enable interrupts
f9ed	7e f9 1b	jmp f91b			;command $11 RESUME
f9f0	7e f9 29	jmp f929

;$17 SET JOYSTICK MONITORING
f9f3	c6 02		ldab #02
f9f5	bd fc fe	jsr  fcfe
f9f8	24 14		bcc  14 (FA0E)
f9fa	71 f8 cb	aim f8cb
f9fd	96 ce		ldaa ce
f9ff	97 94		staa 94
fa01	97 a7		staa a7
fa03	86 0a		ldaa #0a
fa05	97 a6		staa a6
fa07	86 22		ldaa #22			;bit5+1
fa09	97 ca		staa ca				;CA joystick mode
fa0b	7e fa 47	jmp fa47
fa0e	72 10 11	oim 1011			;TRCSR set bit4 RIE
fa11	39		rts

;$18 SET FIRE BUTTON MONITORING
fa12	86 21		ldaa #21			;bit5+0
fa14	97 ca		staa ca				;CA joystick mode
fa16	72 02 c9	oim 2c9				;bit1 of C9 mouse mode
fa19	cc 00 08	ldd  #0008
fa1c	dd a4		std  a4
fa1e	7e f9 1b	jmp f91b			;command $11 RESUME

;$19 SET JOYSTICK KEYCODE MODE
fa21	c6 07		ldab #07
fa23	bd fc fe	jsr  fcfe
fa26	24 15		bcc  15 (FA3D)
fa28	ce 00 95	ldx  #0095
fa2b	bd fd 1e	jsr  fd1e			;copy parameters from input buffer to $95
fa2e	4f		clra			;A=0
fa2f	5f		clrb			;B=0
fa30	97 94		staa 94
fa32	97 a1		staa a1
fa34	dd a2		std  a2
fa36	86 24		ldaa #24			;bit5+2
fa38	97 ca		staa ca				;CA joystick mode
fa3a	7e fa 47	jmp fa47
fa3d	72 10 11	oim 1011			;TRCSR set bit4 RIE
fa40	39		rts

;$1A DISABLE JOYSTICKS
fa41	71 df ca	aim dfca			;$CA clear bit5
fa44	7e f9 1b	jmp f91b			;command $11 RESUME

;commands $14 and $15 (joystick) jump here
fa47	4f		clra			;A=0
fa48	5f		clrb			;B=0
fa49	dd a4		std  a4
fa4b	dd 9d		std  9d
fa4d	dd a8		std  a8
fa4f	97 9f		staa 9f
fa51	86 06		ldaa #06
fa53	97 9b		staa 9b				;$9B=6
fa55	72 02 c9	oim 2c9				;Mouse mode bit1 button monitoring
fa58	7e f9 1b	jmp f91b			;command $11 RESUME

;$1B TIME-OF-DAY CLOCK SET
fa5b	c6 07		ldab #07
fa5d	bd fc fe	jsr  fcfe
fa60	24 2f		bcc  2f (FA91)
fa62	71 f8 cb	aim f8cb
fa65	0f		sei				;disable interrupts
fa66	5f		clrb			;B=0
fa67	ce 00 ce	ldx  #00ce
fa6a	3a		abx
fa6b	a6 00		ldaa 00,x
fa6d	84 0f		anda #0f
fa6f	81 0a		cmpa #0a
fa71	24 10		bcc  10 (FA83)
fa73	a6 00		ldaa 00,x
fa75	84 f0		anda #f0
fa77	81 a0		cmpa #a0
fa79	24 08		bcc  08 (FA83)
fa7b	a6 00		ldaa 00,x
fa7d	ce 00 82	ldx  #0082
fa80	3a		abx
fa81	a7 00		staa 00,x
fa83	5c		incb
fa84	c1 06		cmpb #06
fa86	26 df		bne  df (FA67)
fa88	ce 03 e8	ldx  #03e8
fa8b	df 80		stx  80
fa8d	0e		cli				;enable interrupts
fa8e	7e f9 1b	jmp f91b			;command $11 RESUME
fa91	72 10 11	oim 1011			;TRCSR set bit4 RIE
fa94	39		rts

;$1C INTERROGATE TIME-OF-DAT CLOCK
fa95	0f		sei				;disable interrupts
fa96	c6 06		ldab #06			;6 byte parameters
fa98	86 fc		ldaa #fc			;time-of-day event header (command $1c)
fa9a	ce 00 82	ldx  #0082			;address of info
fa9d	bd fd 34	jsr  fd34			;send
faa0	0e		cli				;enable interrupts
faa1	7e f9 1b	jmp f91b			;command $11 RESUME

;$7 SET MOUSE BUTTON ACTION
faa4	c6 02		ldab #02			;total #bytes expected
faa6	bd fc fe	jsr  fcfe			;call parameter routine
faa9	24 0a		bcc  0a (FAB5)			;not ready->leave
faab	71 f8 cb	aim f8cb
faae	96 ce		ldaa ce				;read in input buffer
fab0	97 b4		staa b4				;store in $B4
fab2	7e f9 1b	jmp f91b			;command $11 RESUME
fab5	72 10 11	oim 1011			;TRCSR set bit4 RIE
fab8	39		rts

;$8 SET RELATIVE MOUSE POSITION REPORTING
fab9	bd fb 8e	jsr  fb8e			;Read Mouse
fabc	71 0f c9	aim 0fc9
fabf	72 90 c9	oim 90c9			;set bits 7 (mouse on) & 5 (relative mouse)
fac2	7f 00 bd	clr 00bd			;clear mouse event
fac5	7f 00 bc	clr 00bc			;clear mouse event
fac8	7e fb af	jmp fbaf

;SET ABSOLUTE MOUSE POSITIONING
facb	c6 05		ldab #05			;command $9 + 4 parameter bytes Absolute X&Y
facd	bd fc fe	jsr  fcfe
fad0	24 12		bcc  12 (FAE4)
fad2	ce 00 aa	ldx  #00aa
fad5	bd fd 1e	jsr  fd1e			;copy parameters from input buffer to $AA
fad8	bd fb 8e	jsr  fb8e			;Read Mouse
fadb	71 0f c9	aim 0fc9
fade	72 a0 c9	oim a0c9			;C9 Mouse mode bit7+5
fae1	7e fb af	jmp fbaf
fae4	72 10 11	oim 1011			;TRCSR set bit4 RIE
fae7	39		rts

;$A SET MOUSE KEYCODE MOUSE
fae8	c6 03		ldab #03			;command $A+ 2 parameter bytes
faea	bd fc fe	jsr  fcfe
faed	24 18		bcc  18 (FB07)
faef	ce 00 ae	ldx  #00ae
faf2	bd fd 1e	jsr  fd1e			;copy parameters from input buffer to $AE
faf5	bd fb 8e	jsr  fb8e			;Read Mouse
faf8	71 0f c9	aim 0fc9
fafb	72 c0 c9	oim c0c9			;C9 Mouse mode bit7+6
fafe	7f 00 ba	clr 00ba
fb01	7f 00 bb	clr 00bb
fb04	7e fb af	jmp fbaf
fb07	72 10 11	oim 1011			;TRCSR set bit4 RIE
fb0a	39		rts

;$B SET MOUSE THRESHOLD
fb0b	c6 03		ldab #03
fb0d	bd fc fe	jsr  fcfe
fb10	24 0f		bcc  0f (FB21)
fb12	ce 00 b0	ldx  #00b0
fb15	bd fd 1e	jsr  fd1e			;copy parameters from input buffer
fb18	7f 00 bc	clr 00bc
fb1b	7f 00 bd	clr 00bd
fb1e	7e f9 1b	jmp f91b			;command $11 RESUME
fb21	72 10 11	oim 1011			;TRCSR set bit4 RIE
fb24	39		rts

;$C SET MOUSE SCALE
fb25	c6 03		ldab #03
fb27	bd fc fe	jsr  fcfe
fb2a	24 09		bcc  09 (FB35)
fb2c	ce 00 b2	ldx  #00b2
fb2f	bd fd 1e	jsr  fd1e			;copy parameters from input buffer to $B2
fb32	7e f9 1b	jmp f91b			;command $11 RESUME
fb35	72 10 11	oim 1011			;TRCSR set bit4 RIE
fb38	39		rts

;$D INTERROGATE MOUSE POSITION
fb39	96 c9		ldaa c9				;$C9 Mouse mode
fb3b	85 02		bita #02			;
fb3d	26 1d		bne  1d (FB5C)			;bit1 (monitoring) set -> leave
fb3f	4d		tsta				;0?
fb40	2a 1a		bpl  1a (FB5C)			;not negative (bit 7 unset): leave
fb42	85 20		bita #20			;bit5? (Absolute mouse on)
fb44	27 16		beq  16 (FB5C)			;no: leave
fb46	0f		sei				;disable interrupts
fb47	96 c2		ldaa c2				;load buttons
fb49	97 b5		staa b5				;store buttons
fb4b	86 f7		ldaa #f7			;header
fb4d	c6 05		ldab #05			;#byte parameters
fb4f	ce 00 b5	ldx  #00b5			;address of parameters
fb52	bd fd 34	jsr  fd34			;send 'F7' + 5 bytes of parameters
fb55	0e		cli				;enable interrupts
fb56	71 f0 c2	aim f0c2			;clear buttons
fb59	7e f9 1b	jmp f91b			;command $11 RESUME
fb5c	7e f9 29	jmp f929

;$E LOAD MOUSE POSITION
fb5f	c6 06		ldab #06			;1 filler byte + 4 position bytes
fb61	bd fc fe	jsr  fcfe
fb64	24 12		bcc  12 (FB78)
fb66	ce 00 b5	ldx  #00b5
fb69	bd fd 1e	jsr  fd1e			;copy parameters from input buffer to $B5 (mouse position)
fb6c	71 f0 c2	aim f0c2
fb6f	71 0f c9	aim 0fc9
fb72	72 a0 c9	oim a0c9
fb75	7e f9 1b	jmp f91b			;command $11 RESUME
fb78	72 10 11	oim 1011			;TRCSR set bit4 RIE
fb7b	39		rts

;$F SET Y=0 AT BOTTOM
fb7c	72 01 c9	oim 1c9				;Mouse mode, set bit0
fb7f	7e f9 1b	jmp f91b			;command $11 RESUME

;$10 SET Y=0 AT TOP
fb82	71 fe c9	aim fec9			;Mouse mode, clear bit0
fb85	7e f9 1b	jmp f91b			;command $11 RESUME

;$12 DISABLE MOUSE
fb88	71 7f c9	aim 7fc9			;Mouse mode, clear bit7
fb8b	7e f9 1b	jmp f91b			;command $11 RESUME

;Read Mouse
fb8e	96 07		ldaa 07			;DR4 mouse & joysticks directions
fb90	16		tab			;B=A  
fb91	84 03		anda #03		;take only first 2 bits (port 0)
fb93	97 be		staa be			;store mouse X on 2 bits in $BE 
fb95	54		lsrb			;B<<
fb96	54		lsrb			;B<<
fb97	c4 03		andb #03		;isolate 2 bits for Y
fb99	d7 bf		stab bf			;store mouse Y on 2 bits in $BF 
fb9b	5f		clrb			;B=0
fb9c	d7 9d		stab 9d			;$9D=0
fb9e	96 03		ldaa 03			;DR2 buttons (mouse bit2 joystick bit1, 0 for on)
fba0	84 06		anda #06		;& b110
fba2	97 9b		staa 9b			;store buttons in $9B
fba4	27 04		beq  04 (FBAA)		;0 = both pressed
fba6	81 06		cmpa #06
fba8	26 02		bne  02 (FBAC)		;none pressed
fbaa	88 06		eora #06
fbac	97 c0		staa c0			;buttons 1=pressed
fbae	39		rts

;...joystick
fbaf	71 fd c9	aim fdc9
fbb2	7b 07 ca	tim 07ca
fbb5	26 0e		bne  0e (FBC5)
fbb7	71 f0 9f	aim f09f
fbba	71 f0 a9	aim f0a9
fbbd	71 f0 a0	aim f0a0
fbc0	71 04 a8	aim 04a8
fbc3	20 0c		bra  0c (FBD1)
fbc5	86 28		ldaa #28
fbc7	97 ca		staa ca
fbc9	4f		clra			;A=0
fbca	5f		clrb			;B=0
fbcb	dd a4		std  a4
fbcd	dd a8		std  a8
fbcf	dd 9e		std  9e
fbd1	7e f9 1b	jmp f91b			;command $11 RESUME

;$20 MEMORY LOAD
fbd4	c6 04		ldab #04
fbd6	bd fc fe	jsr  fcfe
fbd9	24 37		bcc  37 (FC12)
fbdb	ce 00 ee	ldx  #00ee
fbde	bd fd 1e	jsr  fd1e			;copy parameters from input buffer
fbe1	72 10 11	oim 1011			;TRCSR set bit4 RIE
fbe4	71 f7 08	aim f708
fbe7	de ee		ldx  ee
fbe9	96 f0		ldaa f0
fbeb	27 21		beq  21 (FC0E)
fbed	7f 00 cc	clr 00cc
fbf0	c6 64		ldab #64
fbf2	7b 80 cb	tim 80cb
fbf5	26 0a		bne  0a (FC01)
fbf7	86 c8		ldaa #c8
fbf9	4a		deca
fbfa	26 fd		bne  fd (FBF9)
fbfc	5a		decb
fbfd	27 0f		beq  0f (FC0E)
fbff	20 f1		bra  f1 (FBF2)
fc01	71 7f cb	aim 7fcb
fc04	96 cd		ldaa cd
fc06	a7 00		staa 00,x
fc08	08		inx
fc09	7a 00 f0	dec 00f0
fc0c	26 df		bne  df (FBED)
fc0e	72 08 08	oim 808
fc11	39		rts

fc12	72 10 11	oim 1011			;TRCSR set bit4 RIE
fc15	39		rts

;$21 MEMORY READ
fc16	c6 03		ldab #03
fc18	bd fc fe	jsr  fcfe
fc1b	24 1a		bcc  1a (FC37)
fc1d	ce 00 ee	ldx  #00ee			;temp buffer
fc20	bd fd 1e	jsr  fd1e			;copy parameters from input buffer
fc23	0f		sei				;disable interrupts
fc24	86 f6		ldaa #f6			;status header (command $21)
fc26	5f		clrb			;B=0
fc27	bd fd 34	jsr  fd34			;send 'F6'
fc2a	86 20		ldaa #20			;memory access code=$20
fc2c	c6 06		ldab #06			;6 byte parameters
fc2e	de ee		ldx  ee				;address of parameters
fc30	bd fd 34	jsr  fd34			;send '20' and 6 bytes at EE
fc33	0e		cli				;enable interrupts
fc34	7e f9 1b	jmp f91b			;command $11 RESUME
fc37	72 10 11	oim 1011			;TRCSR set bit4 RIE
fc3a	39		rts

;$22 CONTROLLER EXECUTE
fc3b	c6 03		ldab #03
fc3d	bd fc fe	jsr  fcfe
fc40	24 13		bcc  13 (FC55)
fc42	ce 00 ee	ldx  #00ee
fc45	bd fd 1e	jsr  fd1e			;copy parameters from input buffer
fc48	71 f7 08	aim f708
fc4b	de ee		ldx  ee				;load routine address
fc4d	ad 00		jsr  00,x			;execute routine
fc4f	72 08 08	oim 808				;TCSR set bit 3: OCF interrupt
fc52	7e f9 1b	jmp f91b			;command $11 RESUME
fc55	72 10 11	oim 1011			;TRCSR set bit4 RIE
fc58	39		rts

;STATUS INQUIRY
;0x87    mouse button action
fc59	86 07		ldaa #07
fc5b	ce 00 b4	ldx  #00b4			;
fc5e	c6 02		ldab #02
fc60	20 75		bra  75 (FCD7)

;0x88 (or 0x89 or 0x8A)  ; request mouse mode
fc62	96 c9		ldaa c9				;Mouse mode
fc64	48		lsla
fc65	48		lsla
fc66	25 09		bcs  09 (FC71)			;bit6
fc68	48		lsla
fc69	25 0f		bcs  0f (FC7A)
fc6b	86 08		ldaa #08
fc6d	c6 01		ldab #01
fc6f	20 66		bra  66 (FCD7)
fc71	86 0a		ldaa #0a			;0x0A is KEYCODE
fc73	ce 00 ae	ldx  #00ae
fc76	c6 03		ldab #03
fc78	20 5d		bra  5d (FCD7)			;send status report
fc7a	86 09		ldaa #09
fc7c	ce 00 aa	ldx  #00aa
fc7f	c6 05		ldab #05
fc81	20 54		bra  54 (FCD7)

;0x8B    mouse threshold				$B0,$B1
fc83	86 0b		ldaa #0b
fc85	ce 00 b0	ldx  #00b0
fc88	c6 03		ldab #03
fc8a	20 4b		bra  4b (FCD7)

;0x8C    mouse scale
fc8c	86 0c		ldaa #0c
fc8e	ce 00 b2	ldx  #00b2
fc91	c6 03		ldab #03
fc93	20 42		bra  42 (FCD7)

;0x8F    mouse vertical coordinates
;0x90    (0x0F Y=0 at bottom  0x10 Y=0 at top)
fc95	96 c9		ldaa c9
fc97	44		lsra
fc98	25 04		bcs  04 (FC9E)
fc9a	86 10		ldaa #10
fc9c	20 37		bra  37 (FCD5)
fc9e	86 0f		ldaa #0f
fca0	20 33		bra  33 (FCD5)

;0x92    mouse enable/disable (0x00 enabled 0x12 disabled)
fca2	96 c9		ldaa c9
fca4	48		lsla
fca5	25 04		bcs  04 (FCAB)
fca7	86 12		ldaa #12
fca9	20 2a		bra  2a (FCD5)
fcab	4f		clra			;A=0
fcac	20 27		bra  27 (FCD5)

;0x94    joystick mode (0x00 enabled 0x1A disabled)
;0x95
;0x99
fcae	96 ca		ldaa ca
fcb0	44		lsra
fcb1	44		lsra
fcb2	44		lsra
fcb3	25 07		bcs  07 (FCBC)
fcb5	44		lsra
fcb6	25 0d		bcs  0d (FCC5)
fcb8	86 15		ldaa #15
fcba	20 19		bra  19 (FCD5)
fcbc	86 19		ldaa #19
fcbe	ce 00 95	ldx  #0095
fcc1	c6 07		ldab #07
fcc3	20 12		bra  12 (FCD7)
fcc5	86 14		ldaa #14
fcc7	20 0c		bra  0c (FCD5)

;0x9A    joystick enable/disable
fcc9	7b 20 ca	tim 20ca		;Joystick mode on?
fccc	26 04		bne  04 (FCD2)		;
fcce	86 1a		ldaa #1a		;"disabled"
fcd0	20 03		bra  03 (FCD5)
fcd2	4f		clra			;A=0
fcd3	20 00		bra  00 (FCD5)

fcd5	c6 01		ldab #01

; send status report
; C6
fcd7	97 c6		staa c6				;
fcd9	d7 c5		stab c5				;$C5=1
fcdb	0f		sei				;disable interrupts
fcdc	3c		pshx
fcdd	86 f6		ldaa #f6			;F6=status report header
fcdf	5f		clrb			;B=0
fce0	bd fd 34	jsr  fd34			;send jut 'F6'
fce3	38		pulx
fce4	96 c6		ldaa c6				;first byte
fce6	d6 c5		ldab c5				;#bytes (7?)
fce8	5a		decb
fce9	bd fd 34	jsr  fd34			;send
fcec	d6 c5		ldab c5
fcee	5c		incb
fcef	c1 08		cmpb #08
fcf1	27 07		beq  07 (FCFA)
fcf3	d7 c5		stab c5
fcf5	cc 00 00	ldd  #0000
fcf8	20 ef		bra  ef (FCE9)
fcfa	0e		cli				;enable interrupts
fcfb	7e f9 29	jmp f929

;routine called when a parameter has been received
;B=# total expected #bytes for this command (command + parameters)
;carry flag = output, set when all parameters are in
fcfe	71 ef 11	aim ef11			;TRCSR clear bit7 RDRF
fd01	96 cb		ldaa cb				;A=input flags
fd03	85 40		bita #40			;bit6 of $CB
fd05	26 0f		bne  0f (FD16)			;buffer full? ?
fd07	d1 cc		cmpb cc				;compare # expected bytes with bytes in
fd09	25 0b		bcs  0b (FD16)			;bytes in>#expected bytes
fd0b	27 09		beq  09 (FD16)			;bytes in=#expected bytes
fd0d	d0 cc		subb cc				;B=B-($CC) ; #expected - bytes in
fd0f	da cb		orab cb				;B=B|M; adding the flags
fd11	d7 cb		stab cb				;store flags and #bytes missing
fd13	0c		clc				;no 'carry' (as signal still waiting for bytes)
fd14	20 07		bra  07 (FD1D)			;done
fd16	84 18		anda #18			;set bit3,4
fd18	5a		decb				;#parameters, excluding command
fd19	1b		aba				;B=B+A
fd1a	97 cb		staa cb				;store flags + #parameters
fd1c	0d		sec				;set carry (as signal command complete)
fd1d	39		rts

; copy values in buffer ($EE...)
fd1e	5f		clrb			;B=0
fd1f	3c		pshx				;save x
fd20	ce 00 cd	ldx  #00cd			;input buffer start
fd23	3a		abx
fd24	a6 01		ldaa 01,x			;read input buffer, skipping 1st byte (command)
fd26	38		pulx				;pull 
fd27	a7 00		staa 00,x			;push value on temp buffer EE
fd29	08		inx				;will point to next byte to write
fd2a	5c		incb				;will point to next byte to read
fd2b	7a 00 cb	dec 00cb			;[CB]--
fd2e	7b 07 cb	tim 07cb			; 7 to copy??
fd31	26 ec		bne  ec (FD1F)			;process other bytes
fd33	39		rts

;Prepare transmission of info through the serial line: copy into output buffer
;called a lot
;A = header
;B = #bytes to send after header
fd34	7b 10 cb	tim 10cb
fd37	26 2e		bne  2e (FD67)
fd39	d1 d7		cmpb d7
fd3b	24 2a		bcc  2a (FD67)
fd3d	3c		pshx
fd3e	18		xgdx
fd3f	4f		clra			;A=0
fd40	d6 d5		ldab d5
fd42	18		xgdx
fd43	a7 d9		staa d9,x			;header -> output buffer
fd45	96 d5		ldaa d5
fd47	4c		inca
fd48	81 15		cmpa #15
fd4a	26 01		bne  01 (FD4D)
fd4c	4f		clra			;A=0
fd4d	97 d5		staa d5
fd4f	7a 00 d7	dec 00d7
fd52	38		pulx
fd53	5d		tstb
fd54	27 06		beq  06 (FD5C)
fd56	a6 00		ldaa 00,x
fd58	08		inx
fd59	5a		decb
fd5a	20 e1		bra  e1 (FD3D)
fd5c	96 d7		ldaa d7				;check D7
fd5e	2a 06		bpl  06 (FD66)			;if negative don't transmit
fd60	71 7f d7	aim 7fd7
fd63	bd fd 68	jsr  fd68			;try to transmit one byte
fd66	0d		sec				;set carry
fd67	39		rts

;Transmit routine (called by SCI or "prepare transmission")
fd68	96 11		ldaa 11				;TRCSR
fd6a	85 20		bita #20			;bit5 TDRE
fd6c	27 2e		beq  2e (FD9C)			;not free, leave
fd6e	96 d6		ldaa d6				;A=output buffer index
fd70	d6 cb		ldab cb
fd72	c5 08		bitb #08
fd74	27 04		beq  04 (FD7A)
fd76	91 d8		cmpa d8
fd78	27 22		beq  22 (FD9C)
fd7a	ce 00 d9	ldx  #00d9			;output buffer start
fd7d	d6 d6		ldab d6
fd7f	3a		abx				;index with D6
fd80	e6 00		ldab 00,x			;fetch in B
fd82	d7 13		stab 13				;TDR=B transmit
fd84	72 04 11	oim 411 			;TRCSR bit 2 Transmit Interrupt Enable
fd87	4c		inca				;index++
fd88	81 15		cmpa #15
fd8a	26 01		bne  01 (FD8D)
fd8c	4f		clra			;A=0
fd8d	97 d6		staa d6				;D6=index
fd8f	96 d7		ldaa d7				;check D7
fd91	84 7f		anda #7f			;make positive
fd93	4c		inca				;++
fd94	81 15		cmpa #15
fd96	26 02		bne  02 (FD9A)
fd98	8a 80		oraa #80			;if =15 then make negative
fd9a	97 d7		staa d7				;save D7
fd9c	39		rts


OCF interrupt start (Timer)
fd9d	96 08		ldaa 08
fd9f	85 40		bita #40
fda1	26 03		bne  03 (FDA6)
fda3	7e fe cf	jmp fecf
fda6	dc 09		ldd  09
fda8	cb 13		addb #13
fdaa	d1 0c		cmpb 0c
fdac	26 01		bne  01 (FDAF)
fdae	01		nop
fdaf	dc 0b		ldd  0b				; read OCR
fdb1	c3 03 e8	addd #03e8			; + 1000 -> generate 1khz irq
fdb4	dd 0b		std  0b				; write OCR
fdb6	96 83		ldaa 83
fdb8	26 03		bne  03 (FDBD)
fdba	7e fe 29	jmp fe29
fdbd	de 80		ldx  80
fdbf	09		dex
fdc0	df 80		stx  80
fdc2	26 f6		bne  f6 (FDBA)
fdc4	ce 03 e8	ldx  #03e8
fdc7	df 80		stx  80
fdc9	ce 00 06	ldx  #0006
fdcc	c6 60		ldab #60
fdce	09		dex
fdcf	a6 82		ldaa 82,x
fdd1	8b 01		adda #01
fdd3	19		daa
fdd4	8c 00 00	cpx  #0000
fdd7	27 4e		beq  4e (FE27)
fdd9	11		cba
fdda	26 4b		bne  4b (FE27)
fddc	4f		clra			;A=0
fddd	a7 82		staa 82,x
fddf	8c 00 05	cpx  #0005
fde2	27 ea		beq  ea (FDCE)
fde4	8c 00 04	cpx  #0004
fde7	26 04		bne  04 (FDED)
fde9	c6 24		ldab #24
fdeb	20 e1		bra  e1 (FDCE)
fded	8c 00 03	cpx  #0003
fdf0	26 2c		bne  2c (FE1E)
fdf2	d6 83		ldab 83
fdf4	c1 02		cmpb #02
fdf6	26 18		bne  18 (FE10)
fdf8	c6 29		ldab #29
fdfa	96 84		ldaa 84
fdfc	81 28		cmpa #28
fdfe	25 ce		bcs  ce (FDCE)
fe00	96 82		ldaa 82
fe02	85 10		bita #10
fe04	27 02		beq  02 (FE08)
fe06	8b 0a		adda #0a
fe08	84 03		anda #03
fe0a	26 c2		bne  c2 (FDCE)
fe0c	c6 30		ldab #30
fe0e	20 be		bra  be (FDCE)
fe10	ce fe d0	ldx  #fed0		;table
fe13	d6 83		ldab 83			;B=($83) month
fe15	5a		decb			;B--
fe16	3a		abx			;index table
fe17	e6 00		ldab 00,x		;B=get in table
fe19	ce 00 03	ldx  #0003
fe1c	20 b0		bra  b0 (FDCE)
fe1e	86 01		ldaa #01
fe20	a7 82		staa 82,x		;update timer
fe22	c6 13		ldab #13
fe24	7e fd ce	jmp fdce
fe27	a7 82		staa 82,x		;update timer
fe29	96 d4		ldaa d4
fe2b	27 21		beq  21 (FE4E)
fe2d	81 cd		cmpa #cd
fe2f	26 0d		bne  0d (FE3E)
fe31	8e 00 ff	lds  #00ff
fe34	ce f0 0b	ldx  #f00b
fe37	3c		pshx
fe38	8e 00 f8	lds  #00f8
fe3b	7e fe cf	jmp fecf
fe3e	7b 01 11	tim 0111
fe41	26 08		bne  08 (FE4B)
fe43	4f		clra			;A=0
fe44	71 ef cb	aim efcb
fe47	72 04 11	oim 411
fe4a	6d 4c		tst 4c,x
fe4c	97 d4		staa d4
fe4e	d6 ca		ldab ca
fe50	96 c9		ldaa c9
fe52	85 02		bita #02
fe54	26 09		bne  09 (FE5F)
fe56	c5 20		bitb #20
fe58	26 0d		bne  0d (FE67)
fe5a	4d		tsta
fe5b	2b 11		bmi  11 (FE6E)
fe5d	20 66		bra  66 (FEC5)
fe5f	c5 20		bitb #20
fe61	27 62		beq  62 (FEC5)
fe63	c5 01		bitb #01
fe65	25 68		bcs  68 (FECF)
fe67	96 9e		ldaa 9e
fe69	27 03		beq  03 (FE6E)
fe6b	4c		inca
fe6c	97 9e		staa 9e
fe6e	96 9d		ldaa 9d
fe70	27 03		beq  03 (FE75)
fe72	4c		inca
fe73	97 9d		staa 9d
fe75	c5 20		bitb #20
fe77	27 4c		beq  4c (FEC5)
fe79	c5 04		bitb #04
fe7b	27 2b		beq  2b (FEA8)
fe7d	ce 00 00	ldx  #0000
fe80	a6 a2		ldaa a2,x
fe82	27 08		beq  08 (FE8C)
fe84	4a		deca
fe85	a7 a2		staa a2,x
fe87	09		dex
fe88	27 3b		beq  3b (FEC5)
fe8a	20 17		bra  17 (FEA3)
fe8c	86 64		ldaa #64
fe8e	a7 a2		staa a2,x
fe90	08		inx
fe91	08		inx
fe92	a6 a2		ldaa a2,x
fe94	27 03		beq  03 (FE99)
fe96	4a		deca
fe97	a7 a2		staa a2,x
fe99	8c 00 06	cpx  #0006
fe9c	25 f2		bcs  f2 (FE90)
fe9e	8c 00 07	cpx  #0007
fea1	27 22		beq  22 (FEC5)
fea3	ce 00 01	ldx  #0001
fea6	20 d8		bra  d8 (FE80)
fea8	c5 02		bitb #02
feaa	27 19		beq  19 (FEC5)
feac	7b 08 cb	tim 08cb
feaf	26 1e		bne  1e (FECF)
feb1	96 a6		ldaa a6
feb3	27 03		beq  03 (FEB8)
feb5	4a		deca
feb6	20 09		bra  09 (FEC1)
feb8	86 0a		ldaa #0a
feba	d6 a7		ldab a7
febc	27 03		beq  03 (FEC1)
febe	5a		decb
febf	d7 a7		stab a7
fec1	97 a6		staa a6
fec3	20 0a		bra  0a (FECF)
fec5	96 89		ldaa 89
fec7	2b 03		bmi  03 (FECC)
fec9	7e f1 b7	jmp f1b7
fecc	75 80 89	eim 8089
fecf	3b		rti

;data
fed0	32 29 32 31 32 31 32 32 31 00 00 00 00 00 00 32 31  2)2121221......21

SCI interrupt start (rx 0) (Serial line)
fee2	96 11		ldaa 11				;TRCSR
fee4	85 40		bita #40			;bit6 OVR
fee6	26 0c		bne  0c (FEF4)
fee8	85 80		bita #80			;bit7 RDRF
feea	26 05		bne  05 (FEF1)
feec	85 20		bita #20			;bit5 TDRE
feee	26 07		bne  07 (FEF7)
fef0	3b		rti

;to receive routine
fef1	8d 11		bsr  11 (FF04)
fef3	3b		rti

;to OVR routine
fef4	8d 4a		bsr  4a (FF40)
fef6	3b		rti

;check if byte to send
fef7	96 d7		ldaa d7				;check D7
fef9	2a 05		bpl  05 (FF00)			;not negative, try to transmit
fefb	71 fb 11	aim fb11			;negative, TRCSR clear bit2 TIE
fefe	20 03		bra  03 (FF03)			;exit
ff00	bd fd 68	jsr  fd68			;transmit routine
ff03	3b		rti

;receive routine
;CB	flags
;CC	byte in counter

ff04	d6 cc		ldab cc				;B=Input buffer counter
ff06	96 12		ldaa 12				;A=RDR
ff08	26 03		bne  03 (FF0D)			;test 0
ff0a	5d		tstb				;test 0
ff0b	27 32		beq  32 (FF3F)			;if new command=0 ignore byte in
ff0d	c1 07		cmpb #07			;
ff0f	27 2e		beq  2e (FF3F)			;if counter=7 ignore byte in
ff11	96 cb		ldaa cb				;A=Input flags
ff13	85 20		bita #20			;bit5: 
ff15	26 1c		bne  1c (FF33)			;if 
ff17	ce 00 cd	ldx  #00cd			;buffer start
ff1a	3a		abx				;index with B
ff1b	d6 12		ldab 12				;B=RDR
ff1d	e7 00		stab 00,x
ff1f	7c 00 cc	inc 00cc			;Input buffer counter++
ff22	85 07		bita #07			;Flags #para?
ff24	27 07		beq  07 (FF2D)			;none yet
ff26	4a		deca
ff27	85 07		bita #07
ff29	26 04		bne  04 (FF2F)
ff2b	8a 40		oraa #40			;bit6

ff2d	8a 80		oraa #80			;bit7 new command
ff2f	97 cb		staa cb				;store
ff31	20 0c		bra  0c (FF3F)			;exit

ff33	4a		deca				;A--
ff34	85 07		bita #07			;if<0????
ff36	26 f7		bne  f7 (FF2F)
ff38	84 18		anda #18			;bit3,4
ff3a	97 cb		staa cb
ff3c	4f		clra			;A=0
ff3d	97 cc		staa cc			;Input buffer counter=0
ff3f	39		rts

;OVR routine
ff40	d6 12		ldab 12			;RDR
ff42	72 01 11	oim 111			;set TRCSR bit0 WU (sleep)
ff45	86 20		ldaa #20		;wait some cycles
ff47	4a		deca
ff48	26 fd		bne  fd (FF47)
ff4a	7b 01 11	tim 0111		;TRCSR (WU?)
ff4d	27 09		beq  09 (FF58)
ff4f	7c 00 d4	inc 00d4
ff52	72 10 cb	oim 10cb
ff55	71 fb 11	aim fb11
ff58	96 cb		ldaa cb
ff5a	d6 cc		ldab cc
ff5c	27 05		beq  05 (FF63)
ff5e	4a		deca
ff5f	85 07		bita #07
ff61	26 06		bne  06 (FF69)
ff63	84 08		anda #08
ff65	5f		clrb			;B=0
ff66	d7 cc		stab cc			;command counter=0
ff68	7d 8a 20	tst 8a20
ff6b	97 cb		staa cb
ff6d	39		rts

ff6e	a6  .
ff6f	ff 00  ..
ff71	ff 00  ..
ff73	ff 00  ..
ff75	ff 00  ..
ff77	ff 00  ..
ff79	ff 00  ..
ff7b	ff 00  ..
ff7d	ff 00  ..
ff7f	ff 00  ..
ff81	ff 00  ..
ff83	ff 00  ..
ff85	ff 00  ..
ff87	ff 00  ..
ff89	ff 00  ..
ff8b	ff 00  ..
ff8d	ff 00  ..
ff8f	ff 00  ..
ff91	ff 00  ..
ff93	ff 00  ..
ff95	ff 00  ..
ff97	f1 14  ..
ff99	00 01  ..
ff9b	46 00  F.
ff9d	ff f1  ..
ff9f	14 00  ..
ffa1	01 46  .F
ffa3	7e 0a  ~.
ffa5	ff 00  ..
ffa7	ff 00  ..
ffa9	ff 00  ..
ffab	ff f1  ..
ffad	14 00  ..
ffaf	01 31  .1
ffb1	00 ff  ..
ffb3	f1 14  ..
ffb5	00 01  ..
ffb7	31 7e  1~
ffb9	0a 00  ..
ffbb	ff 00  ..
ffbd	ff 00  ..
ffbf	ff 00  ..
ffc1	f1 14  ..
ffc3	00 01  ..
ffc5	1c 00  ..
ffc7	ff f1  ..
ffc9	14 00  ..
ffcb	01 1c  ..
ffcd	7e 0a  ~.
ffcf	fe 00  ..
ffd1	df 00  ..
ffd3	ff 00  ..
ffd5	ff f1  ..
ffd7	1c 00  ..
ffd9	00 ff  ..
ffdb	01 02  ..
ffdd	f1 1c  ..
ffdf	00 00  ..
ffe1	ff 7e  .~
ffe3	81 f3  ..
ffe5	1c 00  ..
ffe7	00 ff  ..
ffe9	01 00  ..
ffeb	f3 1c  ..
ffed	00  .
ffee	00 ff  ..
fff0	fe e2  ..		;SCI vector
fff2	f0 00  ..
fff4	fd 9d  ..		;OCF vector
fff6	f0 00  ..
fff8	f0 00  ..
fffa	f0 00  ..
fffc	f0 00  ..
fffe	f0 00  ..
