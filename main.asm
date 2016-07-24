.feature c_comments
.include "lib/nes_constants.asm"
.include "lib/project_constants.asm"
.include "lib/nes_macros.asm"

.segment "INESHDR"
	
	.byte	"NES", $1A	; iNES header identifier
	.byte 4 		; 4x 16KB PRG code.
	.byte 0			; 0x  8KB CHR data (chr ram)
	.byte $21        ; lower mapper nibble, enable SRAM
	.byte $00        ; upper mapper nibble

.segment "ZEROPAGE"
	temp0: 				.res 1
	frameCounter: 		.res 1
	graphicsState:		.res 1
	ppuCtrlBuffer: 		.res 1
	ppuMaskBuffer: 		.res 1
	tempAddr: 			.res 2
	scrollX:			.res 1
	scrollY:			.res 1
	
	CHAR_TABLE_START 	= $e0
	NUM_SYM_TABLE_START = $d0
	CHAR_SPACE			= $ff
	
	
	
	SHOW_VERSION_STRING = 1
	
.segment "STUB"
	resetstub:
		sei
		ldx #$FF
		txs
		stx $FFF2
		jmp reset
.segment "VECTORS"
	.addr nmi, resetstub, $0000

.segment "CODE"
reset:


	sei			; disable IRQs
	cld			; disable decimal mode

	ldx	#$40
	stx	$4017		; disable APU frame IRQ
	ldx	#$ff		; set up stack
	txs			;  .
	inx			; now X = 0
	stx	$2000		; disable NMI
	stx	$2001		; disable rendering
	stx	$4010		; disable DMC IRQs


	;; first wait for vblank to make sure PPU is ready
vblankwait1:
	bit	$2002
	bpl	vblankwait1

clear_memory:
	lda	#$00
	sta	$0000, x
	sta	$0100, x
	sta	$0300, x
	sta	$0400, x
	sta	$0500, x
	sta	$0600, x
	sta	$0700, x
	lda	#$ff
	sta	$0200, x	; move all sprites off screen
	inx
	bne	clear_memory
	lda #0
	sta scrollX
	sta scrollY
	
	;; second wait for vblank, PPU is ready after this
vblankwait2:
	bit	$2002
	bpl	vblankwait2
	
clear_nametables:
	lda	$2002		; read PPU status to reset the high/low latch
	lda	#$20		; write the high byte of $2000
	sta	$2006		;  .
	lda	#$00		; write the low byte of $2000
	sta	$2006		;  .
	ldx	#$08		; prepare to fill 8 pages ($800 bytes)
	ldy	#$00		;  x/y is 16-bit counter, high byte in x
	lda	#$27		; fill with tile $27 (a solid box)
@loop:
	sta	$2007
	dey
	bne	@loop
	dex
	bne	@loop
	
vblankwait3:	
	bit	$2002
	bpl	vblankwait3
	
	
	
jsr disable_all
lda	#%10010000	; enable NMI, sprites from pattern table 0,
sta	PPU_CTRL	;  background from pattern table 1
jsr enable_all

jmp show_title

forever: 
	jmp forever

disable_all:
	ldx #$00
	stx ppuMaskBuffer	; disable rendering
	ldx #1
	stx graphicsState
	rts

enable_all:
	lda	#%00011110	; enable sprites, enable background,
	clc
	sta	ppuMaskBuffer	;  no clipping on left
	; If you're running this, we have to assume you are not currently running... so skip the buffer.
	sta PPU_MASK
	sta graphicsState
	rts

vblank_wait: 
	lda frameCounter
	@vblank_loop:
		cmp frameCounter
		beq @vblank_loop
	rts
	
;;; 
;;; Nmi handler
;;; 
nmi:
    pha ; back up registers
    txa
    pha
    tya
    pha
		
	; Reminder: NO shared variables here. If you share them, make damn sure you save them before, and pop em after!
	inc frameCounter
	lda	#$00		; set the low byte (00) of the RAM address
	sta	$2003
	; Game sprites
	lda	#$02		; set the high byte (02) of the RAM address 
	sta	$4014		; start the transfer
	
	lda graphicsState
	cmp #0
	beq @nochange
		lda ppuCtrlBuffer
		sta PPU_CTRL
		lda ppuMaskBuffer
		sta PPU_MASK
		lda #0
		sta graphicsState
	@nochange: 
	
    pla ; restore regs
    tay
    pla
    tax
    pla
	
	rti				; return from interrupt
	
	.include "title.asm"
	
.segment "CHUNK"
	; Nothing here. Just reserving it...
	.byte $ff
	
.segment "RODATA"
; To avoid bus conflicts, bankswitch needs to write a value
; to a ROM address that already contains that value.
identity16:
  .repeat 16, I
    .byte I
  .endrepeat
  
  
.segment "BANK0"
	jmp reset
.segment "BANK1"
	jmp reset
.segment "BANK2"
	jmp reset