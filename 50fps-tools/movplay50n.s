pupbt1	equ	$33d
pupbt2	equ	$33e
pupbt3	equ	$33f

hposp0	equ	$d000
hposm0	equ	$d004
hposm1	equ	$d005
grafm	equ	$d011
colpm0	equ	$d012
colpm1	equ	$d013
pal		equ	$d014
colbk	equ	$d01a
prior	equ	$d01b
consol	equ	$d01f
audf1	equ	$d200
audc1	equ	$d201
audf2	equ	$d202
audc2	equ	$d203
audf3	equ	$d204
audc3	equ	$d205
audf4	equ	$d206
audc4	equ	$d207
audctl	equ	$d208
stimer	equ	$d209
kbcode	equ	$d209
random	equ	$d20a
serout	equ	$d20d
irqen	equ	$d20e
irqst	equ	$d20e
skctl	equ	$d20f
skstat	equ	$d20f
porta	equ	$d300
portb	equ	$d301
pactl	equ	$d302
pbctl	equ	$d303
dmactl	equ	$d400
chactl	equ	$d401
dlistl	equ	$d402
dlisth	equ	$d403
hscrol	equ	$d404
vscrol	equ	$d405
pmbase	equ	$d407
chbase	equ	$d409
wsync	equ	$d40a
vcount	equ	$d40b
nmien	equ	$d40e
nmist	equ	$d40f
nmires	equ	$d40f

SOUND_PAGE_MASK = $fe
FRAME_PAGES = 30

;SOUND_PAGE_MASK = $f8
;FRAME_PAGES = 28

;IDE_BASE = $d500
IDE_BASE = $d5f0

side_sdx_control	equ	$d5e0
side_cart_control	equ	$d5e4

ide_data	equ	IDE_BASE+0
ide_feature	equ	IDE_BASE+1
ide_errors	equ	IDE_BASE+1
ide_nsecs	equ	IDE_BASE+2
ide_lba0	equ	IDE_BASE+3
ide_lba1	equ	IDE_BASE+4
ide_lba2	equ	IDE_BASE+5
ide_lba3	equ	IDE_BASE+6
ide_cmd		equ	IDE_BASE+7
ide_status	equ	IDE_BASE+7

IDE_CMD_READ			equ		$20
IDE_CMD_READ_MULTIPLE	equ	$c4
IDE_CMD_SET_MULTIPLE_MODE	equ	$c6
IDE_CMD_SET_FEATURES	equ		$ef
;============================================================================

	org	$0
	opt	o-
zpsndbuf:
	
	org	$c0
zp_start:
msgptr	dta		0
pages	dta		0
vblanks	dta		0
waitcnt	dta		0
nextpg	dta		0
delycnt	dta		0
pending	dta		0
sector	dta	0
	dta	0
	dta	0
	dta	0

zp_end:

	opt	o+

;============================================================================

		org		$2800
		opt		o-
		
		opt		o+

.proc	main		

		;shut off all interrupts and kill display
		sei
		mva		#0 nmien
		mva		#0 dmactl
		sta		nmires

		;nuke startup bytes to force cold reset
		sta		pupbt1
		sta		pupbt2
		sta		pupbt3
		
		;clear playfield page
		mwa		#framebuf0 msgptr
		lda		#[(ide_data&$3ff)/8]
		ldy		#0
		ldx		#16
clear_loop:
		sta:rne	(msgptr),y+
		inc		msgptr+1
		dex
		bne		clear_loop	
		
		;prime memory scan counter to $4000
		lda		#124
		cmp:rne	vcount
		
		mwx		#dlist_init dlistl
		mva		#$20 dmactl

		sta		wsync
		sta		wsync
		cmp:rne	vcount

		mva		#0 dmactl
		mva		#$18 colbk

		;turn off SIDE cart
		mva		#$c0 side_sdx_control
		mva		#$80 side_cart_control

		;clear PIA interrupts
		mva		#$3c pactl
		lda		porta
		lda		portb

		mva		#$38 colbk
		
		;zero working variables
		ldx		#zp_end-zp_start
		lda		#0
clear_zp:
		sta		zp_start,x
		dex
		bpl		clear_zp

		;move sprites out of the way
		ldx		#7
		lda		#0
sprclear:
		sta		hposp0,x
		dex
		bpl		sprclear	

		mva		#$58 colbk

		;set up audio
		; timer 1: 16-bit linked, audio enabled
		; timer 2: 16-bit linked, audio disabled
		mva		#$af audc1
		lda		#$a0
		sta		audc2
		sta		audc3
		sta		audc4
		mva		#$ff audf2
		mva		#$71 audctl

		mva		#$00 colbk


		;reset drive
		ldx		#$7e
		stx		$d5f8
		sta		wsync
		sta		wsync
		ldx		#$7f
		stx		$d5f8

		ldy		#$40
		ldx		#0
reset_loop:
		sta:dex:rne	wsync
		dey
		bne		reset_loop

		;set LBA 0 and select drive 0
		mva		#$e0 ide_lba3
		sta		sector+3
		mva		#$00 ide_lba2
		sta		sector+2
		mva		#$00 ide_lba1
		sta		sector+1
		mva		#$00 ide_lba0
		sta		sector+0

		;set up for PIO 6 transfers
		mva		#$03 ide_feature
		mva		#$0c ide_nsecs
		lda		#IDE_CMD_SET_FEATURES
		jsr		IdeDoCmd
		bcs		err

		;set up for 8-bit transfers
		mva		#32 ide_nsecs
		lda		#IDE_CMD_SET_MULTIPLE_MODE
		jsr		IdeDoCmd
;		bcs		err

		;set up for 8-bit transfers
		mva		#$01 ide_feature
		lda		#IDE_CMD_SET_FEATURES
		jsr		IdeDoCmd
		bcs		err
		
		mva		#17 ide_nsecs
		
		;start on sector 16 (-15 for first inc)
		mva		#16 sector
		
		;set up buffering indicators
		mva		#$00 grafm
		mva		#$0f colpm0
		mva		#$0f colpm1
		
		;set up for reading
		lda		#248/2
		cmp:req	vcount
		cmp:rne	vcount
		
		mwa		#dlist_wait dlistl
		mva		#$22 dmactl
		
		mva		#>ide_base chbase
		mva		#12 hscrol
		mva		#7 vscrol
		sta		nmires

		sta		wsync
		jmp		main_loop_start
		
err:
		jmp		FatalReadError

main_loop_delay:
		mva		#0 dmactl
		
		lda		#124
		cmp:rne	vcount
		mwa		#dlist dlistl
		
		mva		#$22 dmactl

main_loop:

		;MAIN KERNEL
		;
		;With normal width lines (40 bytes), we need some pad bytes to ensure that
		;sector boundaries are maintained.
		
		;DLI should be on by now; if not, wait for it.
		lda:rpl	nmist
		sta		nmires
		
		;if the drive is busy, we need to blow a frame (BOO)
		lda		ide_status
		bmi		main_loop
		lsr
		bcs		err
		and		#$04
		beq		main_loop

		ldx		#$40
		lda		#$c7			;2
		
		pha:pla
		
		sta		wsync
		bit		$00
		
		
;          1         2         3         4         5         6         7         8         9         0         1   
;012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123
;===========================================================================================================....... -> 7+16 = 23 cycles
;.D..............F.FCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCRVV.V... -> 7+16 = 23 cycles
;.D..............F.FCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCRVV.V... -> 7+25 = 32 cycles
;.D................F.FCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCFCRC..............


.rept 192
		;jump to right before even line (start vscrol region - vscrol=7)
		;jump to right before odd line (end vscrol region - vscrol=0)
		;24 cycles
		
.if (#%2)==0
		sta		prior			;106, 107, 108, 109
		sta		vscrol			;110, 111, 112, 113
		sta		chactl			;0, 2, 3, 4
.else	
		stx		prior			;4
		stx		vscrol			;4
		stx		chactl			;4
.endif
		
		ldy		zpsndbuf+#		;5, 6, 7
		sty		audf1			;8, 9, 10, 11
		sty		stimer			;12, 13, 14, 15
		
.if [(#%3)==2 && #!=191]
		bit.w	$0100
		bit.b	$0
		nop
.endif

.endr
			
		;With 182 scanlines, there are 320 bytes left over. 262 of these are used for
		;sound, and the other 58 we toss. We read 10 bytes a scanline and so this
		;takes 32 scanlines.
				
		ldx		#$e0
		
		;we are coming in hot from the last visible scanline, so we need to skip
		;the wsync
		bne		sndread_loop_start
		
sndread_loop:
		sta		wsync						;4
sndread_loop_start:
		ldy		ide_data					;4
		mva		ide_data zpsndbuf+$20,x		;9
		lda		ide_data					;4
		bit		$00
		sty		audf1						;4
		sty		stimer						;4
		sta		zpsndbuf+$40,x				;4
		mva		ide_data zpsndbuf+$60,x		;9
		mva		ide_data zpsndbuf+$80,x		;9
		mva		ide_data zpsndbuf+$a0,x		;9
		mva		ide_data zpsndbuf+$c0,x		;9
		mva		ide_data soundbuf-$e0,x		;9
		mva		ide_data soundbuf-$c0,x		;9
		lda		ide_data					;4

		inx									;2
		bne		sndread_loop				;3
		
		ldx		#<(-19)
eat_loop:
		sta		wsync
		ldy		ide_data
		mva		ide_data soundbuf+$40-<(-19),x
		lda		ide_data
		nop
		sty		audf1
		sty		stimer
		:7 lda	ide_data
		inx
		bne		eat_loop
		
		;Do a line of audio, so we get some time again.
		sta		wsync
		ldy		ide_data
		lda		ide_data
		pha:pla
		bit		$100
		sty		audf1
		sty		stimer
		
main_loop_start:				
		;Okay, now we can issue the next read. Bump the sector number at
		;this point.
		lda		sector			;4
		sta		ide_lba0		;4
		ldx		sector+1		;3
		stx		ide_lba1		;4
		ldx		sector+2		;3
		stx		ide_lba2		;4
		ldx		sector+3		;3
		stx		ide_lba3		;4
		
		add		#17				;3
		sta		sector			;4
		bcc		no_carry		;2+1
		inc		sector+1		;5
		bne		no_carry		;2+1
		inc		sector+2		;5
no_carry:
		
		;Kick the read.
		mva		#17 ide_nsecs
;		lda		#IDE_CMD_READ_MULTIPLE
		lda		#IDE_CMD_READ
		sta		ide_cmd
		
		;We have 47 scanlines to wait (~4ms), so in the meantime let's play
		;some audio.
		ldx		#<(-68)
wait_loop:
		sta		wsync
		ldy		soundbuf-$100+68,x

		bit		$0100
		bit		$0100
		
		lda		consol
		lsr
		
		sty		audf1
		sty		stimer
		
		bcs		no_start
		lda		#16
		sta		sector
		lda		#0
		sta		sector+1
		sta		sector+2
		lda		#$e0
		sta		sector+3
no_start:
		
		inx
		bne		wait_loop
		jmp		main_loop
.endp

;============================================================================
.proc	IdeDoCmd
		sta		ide_cmd
		
		;wait for BSY to go low or for ERR to go high
		lda		#0
		sta		delycnt
		tax
		mva		#4 waitcnt		;~2 seconds
wait_loop:
		lda		ide_status
		bpl		wait_done
		lsr
		bcs		wait_error
		dex
		bne		wait_loop
		dec		delycnt
		bne		wait_loop
		dec		waitcnt
		bne		wait_loop
		
		;timeout!
		sec
wait_error:
		rts
wait_done:
		clc
		rts
.endp

;============================================================================
.proc FatalReadError
		sei

		mwa		#msg msgptr
		ldy		#0
		ldx		#0
		jsr		WriteMsg
		jmp		Fatal

msg		dta		d"Read error",$ff
.endp

;============================================================================
.proc Fatal
		;kill audio and VBI
		sei
		lda		#0
		sta		nmien
		sta		audc1
		
		;kill VBI
		mva		#0 nmien
		
		;turn ROM back on
		mva		#$ff portb
		
		lda		#248/2
		cmp:rne	vcount
		
		;reset display list
		mwa		#dlisterr dlistl
		lda		#0
		sta		prior
		sta		colbk
		mva		#$22 dmactl
		mva		#$e0 chbase
		
		ldy		#12
		lda		ide_status
		jsr		WriteHex
		lda		ide_errors
		jsr		WriteHex
		iny
		lda		ide_lba3
		jsr		WriteHex
		lda		ide_lba2
		jsr		WriteHex
		lda		ide_lba1
		jsr		WriteHex
		lda		ide_lba0
		jsr		WriteHex
		
		jmp		*
.endp

;============================================================================
.proc WriteMsg
		lda		(msgptr),y
		bmi		done
		iny
		sta		framebuf,x
		inx
		jmp		WriteMsg
done:
		rts
.endp

;============================================================================
.proc WriteHex
		pha
		lsr
		lsr
		lsr
		lsr
		tax
		lda		hexdig,x
		sta		framebuf,y
		iny
		pla
		and		#$0f
		tax
		lda		hexdig,x
		sta		framebuf,y
		iny
		rts
hexdig:
		dta		d"0123456789ABCDEF"
.endp

;============================================================================
		org		$3b00
soundbuf:

;============================================================================
		org		$3c00
dlist:
		dta		$70
		dta		$70
		dta		$f0

.rept 16
		dta		$32,$12,$22
		dta		$12,$32,$02
		dta		$32,$12,$22
		dta		$12,$32,$02
.endr

dlist_wait:
		dta		$41,a(dlist)
		
dlist_init:
		dta		$4f,a(framebuf0)
		dta		$41,a(dlist_init)
		
		org		$3f00
dlisterr:
		dta		$70
		dta		$70
		dta		$70
		dta		$42,a(framebuf)
		dta		$41,a(dlisterr)
framebuf:
		:40 dta $00
		
		org		$4000
framebuf0:

		run	main

	end
