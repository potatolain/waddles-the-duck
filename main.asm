.feature c_comments
.include "lib/nes_constants.asm"
.include "lib/project_constants.asm"
.include "lib/nes_macros.asm"
.include "lib/tile_definitions.asm"

.segment "INESHDR"
	
	.byte	"NES", $1A	; iNES header identifier
	.byte 4 		; 4x 16KB PRG code.
	.byte 0			; 0x  8KB CHR data (chr ram)
	.byte $21        ; lower mapper nibble, enable SRAM
	.byte $00        ; upper mapper nibble

.segment "ZEROPAGE"
	; 6 "scratch" variables for whatever we may be doing at the time. 
	; A little hard to track honestly, but the NES has very limited ram. 
	; Other option is to have multiple names refer to one address, but that actually seems more confusing.
	temp0: 				.res 1
	temp1: 				.res 1
	temp2:				.res 1
	temp3: 				.res 1
	temp4: 				.res 1
	temp5:				.res 1
	frameCounter: 		.res 1
	ppuCtrlBuffer: 		.res 1
	ppuMaskBuffer: 		.res 1
	tempAddr: 			.res 2
	levelAddr: 			.res 2
	scrollX:			.res 1
	scrollY:			.res 1
	ctrlButtons:		.res 1
	lastCtrlButtons:	.res 1
	playerVelocity:		.res 1
	playerDirection:	.res 1
	
	CHAR_TABLE_START 		= $e0
	NUM_SYM_TABLE_START	 	= $d0
	CHAR_SPACE				= $ff
	SCREEN_1_DATA			= $600
	SCREEN_2_DATA			= $700
	SPRITE_DATA				= $200
	SPRITE_ZERO				= $200
	PLAYER_SPRITE			= $210
	
	PLAYER_VELOCITY_NORMAL 	= $01
	PLAYER_VELOCITY_FAST	= $03
	PLAYER_DIRECTION_LEFT	= $3
	PLAYER_DIRECTION_RIGHT	= $0
	SPRITE_ZERO_POSITION	= $27
	
	MIN_POSITION_LEFT_SCROLL		= $40
	MIN_POSITION_RIGHT_SCROLL		= $a0
	
	
	
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
lda	#%10001000	; enable NMI, sprites from pattern table 0,
sta	PPU_CTRL	;  background from pattern table 1
sta ppuCtrlBuffer
jsr enable_all

jmp show_title

load_graphics_data: 
	set_ppu_addr $3f00
	ldy #0
	@palette_loop:
		lda default_palettes, y
		sta PPU_DATA
		iny
		cpy #$20
		bne @palette_loop

	store #<(default_chr), tempAddr
	store #>(default_chr), tempAddr+1
	ldx #0
	ldy #0
	set_ppu_addr $0000
	@graphics_loop:
		lda (tempAddr), y
		sta PPU_DATA
		iny
		cpy #0
		bne @graphics_loop
		inx
		inc tempAddr+1
		cpx #$10
		bne @graphics_loop
		
	store #<(default_sprite_chr), tempAddr
	store #>(default_sprite_chr), tempAddr+1
	ldx #0
	ldy #0
	set_ppu_addr $1000
	@sprite_loop:
		lda (tempAddr), y
		sta PPU_DATA
		iny
		cpy #0
		bne @sprite_loop
		inx
		inc tempAddr+1
		cpx #$10
		bne @sprite_loop
		
	rts
	
load_level: 
	
	lda #0
	sta temp1
	
	ldx #0
	stx temp2
	; TODO: Consider levels > 255 tiles long. Are those realistic?
	; TODO: This hackishly assumes exactly a sane number of bytes are provided. How do we extend this to not draw more than 2xnametable?
	@loop:
		lda lvl1_compressed, x
		
		cmp #$ff
		beq @level_loaded
		
		sta tempAddr
		lda #0
		sta tempAddr+1
		
		.repeat 4
			asl tempAddr
			rol tempAddr+1
		.endrepeat
		
		lda tempAddr
		clc
		adc #<(lvl1_compressed_ids)
		sta tempAddr

		lda tempAddr+1
		adc #>(lvl1_compressed_ids)
		sta tempAddr+1
				
		ldy #0
		
		; In this inner loop, x must be 1-16 to avoid starting lower on the level than expected in cases
		; Where we load more than one screen at once. temp2 = x%16.
		stx temp1
		ldx temp2
		cpx #16
		bne @do_it
		ldx #0
		stx temp2
		
		@do_it:
		lda temp5
		cmp #0
		beq @inner_loop_nametable_1
		jmp @inner_loop_nametable_2
		
		@inner_loop_nametable_1:
			lda (tempAddr), y
			sta SCREEN_1_DATA, x
			iny
			txa
			clc
			adc #$10
			tax
			cpy #16
			bne @inner_loop_nametable_1
			jmp @done_it
			
		@inner_loop_nametable_2:
			lda (tempAddr), y
			sta SCREEN_2_DATA, x
			iny
			txa
			clc
			adc #$10
			tax
			cpy #16
			bne @inner_loop_nametable_2

		@done_it:
		inc temp2
		ldx temp1
		inx
		cpx #16
		bne @loop ; Switch to nametable 2 if we go over the first table's bytes.
			lda #1
			sta temp5
		jmp @loop
	
	@level_loaded: 
	rts
	
load_nametable:
	set_ppu_addr $20c0
	lda #<(SCREEN_1_DATA)
	sta tempAddr
	lda #>(SCREEN_1_DATA)
	sta tempAddr+1
	jsr vblank_wait
	ldx #0
	ldy #0
	sty temp5
	clc ; HAX: Don't want to clc during this thing repeatedly, so do it once to avoid an off-by-one error. (hopefully)
	@outer_loop:
		txa
		.repeat 4
			asl
		.endrepeat
		tay
		sty temp1
		stx temp0
		ldx #0
		@top_loop:
			lda (tempAddr), y
			asl
			sta PPU_DATA
			adc #1
			sta PPU_DATA
			
			iny
			inx
			cpx #16
			bne @top_loop
			
		ldx #0
		ldy temp1
			
		@bottom_loop:
			lda (tempAddr), y
			asl 
			adc #$10
			sta PPU_DATA
			adc #1
			sta PPU_DATA
			
			iny
			inx
			cpx #16
			bne @bottom_loop
			
		ldx temp0
		inx
		cpx #12
		bne @outer_loop
		
	lda temp5
	cmp #1
	beq @dont_reloop
	ldx #0
	ldy #0
	inc temp5
	lda #<(SCREEN_2_DATA)
	sta tempAddr
	lda #>(SCREEN_2_DATA)
	sta tempAddr+1
	set_ppu_addr $24c0
	jmp @outer_loop
	@dont_reloop:
		
	; FIXME: Replace this with real attr loading
	set_ppu_addr $23c0
	lda #0
	ldy #0
	@clear_attributes:
		sta PPU_DATA
		iny
		cpy #$40
		bne @clear_attributes
		
	set_ppu_addr $27c0
	lda #0
	ldy #0
	@clear_attributes2:
		sta PPU_DATA
		iny
		cpy #$40
		bne @clear_attributes2
		
	;@loop_pal
	;	lda SCREEN_1_DATA, x
	rts
	
initialize_player_sprite: 
	store #$af, PLAYER_SPRITE
	store #$01, PLAYER_SPRITE+1
	store #$0, PLAYER_SPRITE+2
	store #$20, PLAYER_SPRITE+3
	
	store #$b7, PLAYER_SPRITE+4
	store #$11, PLAYER_SPRITE+5
	store #$0, PLAYER_SPRITE+6
	store #$20, PLAYER_SPRITE+7
	rts

	
do_player_movement: 
	lda PLAYER_SPRITE+3
	clc
	adc playerVelocity
	sta PLAYER_SPRITE+3
	sta PLAYER_SPRITE+7
	
	lda playerVelocity
	cmp #0
	bne @continue
		lda playerDirection
		sta PLAYER_SPRITE+1
		clc
		adc #$10
		sta PLAYER_SPRITE+5
		rts
		
	@continue:
	
	lda frameCounter
	and #%00000011
	cmp #1
	bcs @no_flop
	cmp #1
	bcs @no_flop
		lda #0
		jmp @after_flop
	@no_flop:
		lsr
		clc
		adc #1
	@after_flop: 
	clc
	adc playerDirection
	sta PLAYER_SPRITE+1
	clc
	adc #$10
	sta PLAYER_SPRITE+5
	
	lda playerDirection
	cmp #PLAYER_DIRECTION_LEFT
	bne @not_left
		lda PLAYER_SPRITE+3
		cmp #MIN_POSITION_LEFT_SCROLL
		bcc @do_scroll_l
		jmp @dont_scroll
	@not_left: 
	lda playerDirection
	cmp #PLAYER_DIRECTION_RIGHT
	bne @dont_scroll
		lda PLAYER_SPRITE+3
		cmp #MIN_POSITION_RIGHT_SCROLL
		bcs @do_scroll_r
		jmp @dont_scroll
		
	@do_scroll_l: 
		lda scrollX
		clc
		adc playerVelocity
		sta scrollX
		
		; If we didn't carry, it's time to swap nametables.
		bcs @dont_swap_nametable
			lda ppuCtrlBuffer
			eor #%00000001
			sta ppuCtrlBuffer
		jmp @dont_swap_nametable

	
	@do_scroll_r: 
		lda scrollX
		clc
		adc playerVelocity
		sta scrollX
		
		; If we carried, it's time to swap nametables.
		bcc @dont_swap_nametable
			lda ppuCtrlBuffer
			eor #%00000001
			sta ppuCtrlBuffer
		@dont_swap_nametable:
		
		; TODO: We're reversing something we did earlier here... there's likely a way to refactor this to not be necessary if we need some cycles back.
		lda PLAYER_SPRITE+3
		sec
		sbc playerVelocity
		sta PLAYER_SPRITE+3
		sta PLAYER_SPRITE+7
	@dont_scroll: 

	rts
	
handle_main_input: 
	lda #0
	sta playerVelocity
	jsr read_controller
	
	lda ctrlButtons
	and #CONTROLLER_LEFT
	beq @done_left
		lda #PLAYER_DIRECTION_LEFT
		sta playerDirection
		
		lda ctrlButtons
		and #CONTROLLER_B
		bne @fast_left
			lda #256-PLAYER_VELOCITY_NORMAL
			jmp @doit_left
		@fast_left: 
			lda #256-PLAYER_VELOCITY_FAST
		@doit_left: 
		sta playerVelocity
	@done_left:
	
	lda ctrlButtons
	and #CONTROLLER_RIGHT
	beq @done_right
		lda #PLAYER_DIRECTION_RIGHT
		sta playerDirection
		
		lda ctrlButtons
		and #CONTROLLER_B
		bne @fast_right
			lda #PLAYER_VELOCITY_NORMAL
			jmp @doit_right
		@fast_right: 
			lda #PLAYER_VELOCITY_FAST
		@doit_right: 
		sta playerVelocity
	@done_right:
		
	rts
	
load_sprite0:
	lda #$ff
	sta SPRITE_ZERO+1
	lda #%00000000
	sta SPRITE_ZERO+2
	lda #$f0
	sta SPRITE_ZERO+3
	; set y last as we test on it.
	lda #SPRITE_ZERO_POSITION
	sta SPRITE_ZERO

	rts
	
main_loop: 
	jsr handle_main_input
	jsr do_player_movement
	jsr vblank_wait
	jmp main_loop
	
show_level: 
	jsr disable_all
	jsr vblank_wait
	jsr load_graphics_data
	jsr load_level
	; FIXME: Kill first 2 rows of input (ish) for this, update views.
	jsr load_nametable
	jsr show_hud
	jsr enable_all
	jsr load_sprite0
	reset_ppu_scrolling
	lda #PLAYER_DIRECTION_RIGHT
	sta playerDirection
	jsr initialize_player_sprite
	jmp main_loop
	
disable_all:
	ldx #$00
	stx ppuMaskBuffer	; disable rendering
	rts
	
disable_all_immediate:
	lda #00
	sta PPU_MASK
	sta ppuMaskBuffer
	rts

enable_all:
	lda	#%00011110	; enable sprites, enable background,
	sta	ppuMaskBuffer	;  no clipping on left
	; If you're running this, we have to assume you are not currently running... so skip the buffer.
	sta PPU_MASK
	rts

vblank_wait: 
	lda frameCounter
	@vblank_loop:
		cmp frameCounter
		beq @vblank_loop
	rts
	
.include "lib/controller.asm"
.include "lib/hud.asm"
	
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
	sta	OAM_ADDR
	
	; Game sprites
	lda	#$02		; set the high byte (02) of the RAM address 
	sta	OAM_DMA		; start the transfer

	
	lda SPRITE_ZERO
	cmp #SPRITE_ZERO_POSITION
	bne @skip_sprite0
	
	; Sprite zero trickery.. set flags so we go right
	lda PPU_STATUS
	lda #$00
	sta PPU_ADDR
	sta PPU_ADDR
	lda #0
	sta PPU_SCROLL
	sta PPU_SCROLL
		
	
	@waitNotSprite0: ; flag off...
		lda $2002
		and #%01000000
		bne @waitNotSprite0
	@waitSprite0: ; flag on...
		lda $2002
		and #%01000000
		beq @waitSprite0
		
	; Ensure we really got to the end of the scanline.
	ldx #$10
	@waitEndOfSprite:
		dex
		bne @waitEndOfSprite
	
	; Your regularly scheduled programming
	@skip_sprite0:
	lda ppuCtrlBuffer
	sta PPU_CTRL
	lda ppuMaskBuffer
	sta PPU_MASK

	lda PPU_STATUS
	store scrollX, PPU_SCROLL
	store scrollY, PPU_SCROLL

	
    pla ; restore regs
    tay
    pla
    tax
    pla
	
	rti
	
	.include "title.asm"
	.include "levels/lvl1.asm"
	
default_chr:
	.incbin "graphics/map_tiles.chr"
	
default_sprite_chr:
	.incbin "graphics/sprites.chr"
	
default_palettes: 
	.byte $31,$06,$16,$1a,$31,$00,$10,$31,$31,$01,$21,$31,$31,$09,$19,$29
	.byte $31,$06,$16,$1a,$31,$00,$10,$31,$31,$01,$21,$31,$31,$09,$19,$29
	
default_sprite_palettes:
	; Palette 1 is turtle
	.byte $30,$05,$09,$19,$30,$00,$10,$30,$30,$01,$21,$31,$30,$06,$16,$26
	.byte $30,$05,$09,$19,$30,$00,$10,$30,$30,$01,$21,$31,$30,$06,$16,$26

	
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