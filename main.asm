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

; Memory map: 
; $000-0ff: zp values
; $100-1ff: Stack
; $200-2ff: Sprites
; $300-3ff: Famitone (technically, it only uses ~186 bytes... we could probably steal some if needed.)
; $400-4ff: Unused
; $500-55f: Screen buffer
; $520-5ff: Unused.
; $600-7ff: World map data.
	
	
.segment "ZEROPAGE"
	; 6 "scratch" variables for whatever we may be doing at the time. 
	; A little hard to track honestly, but the NES has very limited ram. 
	; Other option is to have multiple names refer to one address, but that actually seems more confusing.
	temp0: 					.res 1
	temp1: 					.res 1
	temp2:					.res 1
	temp3: 					.res 1
	temp4: 					.res 1
	temp5:					.res 1
	levelPosition: 			.res 1
	levelPositionExact:		.res 1
	levelPositionExactP1:	.res 1
	tempLevelPosition:		.res 1
	tempLevelPositionExact:	.res 2
	screenScroll:			.res 1
	playerIsInScrollMargin:	.res 1
	playerXPosOnScreen:		.res 1
	levelMemPosR:			.res 1
	frameCounter: 			.res 1
	ppuCtrlBuffer:			.res 1
	ppuMaskBuffer: 			.res 1
	tempAddr: 				.res 2
	levelAddr: 				.res 2
	nametableAddr:			.res 2
	scrollX:				.res 1
	scrollY:				.res 1
	ctrlButtons:			.res 1
	lastCtrlButtons:		.res 1
	playerVelocity:			.res 1
	playerYVelocity:		.res 1
	flightTimer:			.res 1
	playerDirection:		.res 1
	famitoneScratch:		.res 3
	
	CHAR_TABLE_START 		= $e0
	NUM_SYM_TABLE_START	 	= $d0
	CHAR_SPACE				= $ff
	SCREEN_1_DATA			= $600
	SCREEN_2_DATA			= $700
	NEXT_ROW_CACHE			= $500
	NEXT_ROW_ATTRS			= $540 ; This could share space with cache if needed.
	SPRITE_DATA				= $200
	SPRITE_ZERO				= $200
	PLAYER_SPRITE			= $210
	PLAYER_BOTTOM_SPRITE	= PLAYER_SPRITE+12
	
	PLAYER_VELOCITY_NORMAL 	= $01
	PLAYER_VELOCITY_FAST	= $02
	PLAYER_VELOCITY_FALLING	= $02
	PLAYER_VELOCITY_JUMPING	= $ff-$02 ; rotato! (Make it pseudo negative to wrap around.)
	PLAYER_JUMP_TIME_RUN	= $14
	PLAYER_JUMP_TIME		= $10
	PLAYER_DIRECTION_LEFT	= $3
	PLAYER_DIRECTION_RIGHT	= $0
	SPRITE_ZERO_POSITION	= $27
	PLAYER_HEIGHT			= 24
	
	MIN_POSITION_LEFT_SCROLL		= $40
	MIN_POSITION_RIGHT_SCROLL		= $a0
	MIN_LEFT_LEVEL_POSITION 		= $0f
	
	WINDOW_WIDTH			= 32
	WINDOW_WIDTH_TILES		= 16
	BOTTOM_HUD_TILE			= $c0
	
	BANK_SWITCH_ADDR 		= $8000
	BANK_SPRITES_AND_LEVEL	= 0
	
	LAST_WALKABLE_SPRITE	= 0
	FIRST_SOLID_SPRITE		= LAST_WALKABLE_SPRITE+1
	
	SPRITE_OFFSCREEN 		= $ef
	
	
;;;;;;;;;;;;;;;;;;;;;;;
; Sound Effect ids
	SFX_COIN = 1
	SFX_FLAP = 0
	SFX_JUMP = 2

;;;;;;;;;;;;;;;;;;;;;;;
; Music
	SONG_CRAPPY = 0

;;;;;;;;;;;;;;;;;;;;;;;
; Famitone Settings

	FT_BASE_ADR			= $0300				;page in the RAM used for FT2 variables, should be $xx00
	FT_TEMP				= famitoneScratch	;3 bytes in zeropage used by the library as a scratchpad
	FT_DPCM_OFF			= $c000	;$c000..$ffc0, 64-byte steps
	FT_SFX_STREAMS		= 4		;number of sound effects played at once, 1..4

	FT_DPCM_ENABLE		= 0		;undefine to exclude all DMC code
	FT_SFX_ENABLE		= 1		;undefine to exclude all sound effects code
	FT_THREAD			= 1		;undefine if you are calling sound effects from the same thread as the sound update call

	FT_PAL_SUPPORT		= 0		;undefine to exclude PAL support
	FT_NTSC_SUPPORT		= 1		;undefine to exclude NTSC support
	 
	; HAAAAAX (Overrides something needed in famitone that isn't properly defined for ca65)
	FT_PITCH_FIX = 0
	
;;;;;;;;;;;;;;;;;;;;;;
; Our Sound Settings
	SOUND_CHANNEL_PLAYER = FT_SFX_CH0

;;;;;;;;;;;;;;;;;;;;;;
; Misc	
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
	
; Use first bank.
lda BANK_SPRITES_AND_LEVEL
sta BANK_SWITCH_ADDR
	
ldx #<(all_music)
ldy #>(all_music)
lda #1 ; play ntsc musics/sound.
jsr FamiToneInit
ldx #<(all_sfx)
ldy #>(all_sfx)
jsr FamiToneSfxInit

	
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
	lda #$0f
	sta levelPosition
	lda #0
	sta levelPositionExact+1
	lda #0
	sta temp1
	lda #$fe ; The position we want to scroll from is at the very edge of 1 screen of content... 16*16. I'm actually unsure why I added the 2 pixels of wiggle room here...
	sta levelPositionExact
	lda #0 
	sta playerIsInScrollMargin

	lda #2
	sta screenScroll

	; We start you at $20, so your position should represent that.
	lda #$20
	sta playerXPosOnScreen

	
	; Prep nametableAddr with the position we should start on nametable 2
	lda #BOTTOM_HUD_TILE
	sta nametableAddr
	lda #$24
	sta nametableAddr+1
	rts
	
load_nametable:
	
	ldx #1
	stx playerIsInScrollMargin

	ldx #0
	stx levelPosition
	ldx #255
	stx screenScroll
	ldx #0
	
	@loopdedo: 
		txa
		pha
		jsr load_current_line
		jsr draw_current_nametable_row
		pla
		tax
		inc levelPosition
		inc screenScroll
		inx
		cpx #16
		bne @loopdedo
				
	store #0, playerIsInScrollMargin
	rts
	
initialize_player_sprite: 
	store #$a7, PLAYER_SPRITE
	store #$0, PLAYER_SPRITE+1
	store #$0, PLAYER_SPRITE+2
	store #$20, PLAYER_SPRITE+3
	
	store #$af, PLAYER_SPRITE+4
	store #$10, PLAYER_SPRITE+5
	store #$0, PLAYER_SPRITE+6
	store #$20, PLAYER_SPRITE+7
	
	store #$b7, PLAYER_SPRITE+8
	store #$20, PLAYER_SPRITE+9
	store #$0, PLAYER_SPRITE+10
	store #$20, PLAYER_SPRITE+11
	
	store #$a7, PLAYER_SPRITE+12
	store #$01, PLAYER_SPRITE+13
	store #$0, PLAYER_SPRITE+14
	store #$28, PLAYER_SPRITE+15
	
	store #$af, PLAYER_SPRITE+16
	store #$11, PLAYER_SPRITE+17
	store #$0, PLAYER_SPRITE+18
	store #$28, PLAYER_SPRITE+19
	
	store #$b7, PLAYER_SPRITE+20
	store #$21, PLAYER_SPRITE+21 
	store #$0, PLAYER_SPRITE+22
	store #$28, PLAYER_SPRITE+23
	
	
	rts

load_current_line:
	lda playerIsInScrollMargin
	cmp #0
	bne @doit
		rts
	@doit: 
	lda playerDirection
	cmp #PLAYER_DIRECTION_LEFT
	bne @right
		lda levelPosition
		sec
		sbc #WINDOW_WIDTH_TILES+3
		tay
		lda screenScroll
		clc
		adc #16
		sta temp4
		cmp #32
		bcs @go
		sec
		sbc #32
		sta temp4
		jmp @go
	@right: 
		ldy levelPosition
		lda screenScroll 
		sta temp4
	@go:
	
	lda #0
	sta tempAddr+1
	lda lvl1_compressed, y
	.repeat 4
		asl
		rol tempAddr+1
	.endrepeat
	clc
	adc #<(lvl1_compressed_ids)
	sta tempAddr
	lda tempAddr+1
	adc #>(lvl1_compressed_ids)
	sta tempAddr+1
	
	ldy #0
	ldx temp4
	cpx #16
	bcc @loop_l
	
	txa
	sec
	sbc #16
	tax
	
	@loop_r:
	
		lda (tempAddr), y
		sta SCREEN_2_DATA, x
		jsr draw_to_cache
		iny
		txa
		clc
		adc #16
		tax
		cpy #16
		
		bne @loop_r
	rts
	
	@loop_l:
		lda (tempAddr), y
		sta SCREEN_1_DATA, x
		jsr draw_to_cache
		iny
		txa
		clc
		adc #16
		tax
		cpy #16
		bne @loop_l

	rts
	
; Draws the tile in a to the next 4 positions in NEXT_ROW_CACHE. 
; Very tightly coupled to load_current_line. Moved to reduce complexity.
draw_to_cache: 
	; strip attrs
	sta temp3
	and #%00111111
	pha
	sty temp0
	tya
	asl
	tay
	pla
	asl
	sta NEXT_ROW_CACHE, y
	clc
	adc #$10
	iny 
	sta NEXT_ROW_CACHE, y
	pha
	tya
	clc
	adc #$1f
	tay
	pla
	sec
	sbc #$0f
	sta NEXT_ROW_CACHE, y
	iny
	clc
	adc #$10
	sta NEXT_ROW_CACHE, y
	
	lda temp0
	clc
	adc #1 ; Increment by 1, as we want to start on the second row, since our status bar is 6 tiles high. We need to start on those last 2.
	sta temp1
	lsr
	tay ; Index to fetch/put data.
	
	lda temp3
	and #%11000000
	sta temp3
	
	lda levelPosition
	and #%00000001
	cmp #0
	beq @lvl_odd
		; Level is even. We want left of the bytes
		lda temp1
		and #%00000001
		cmp #0
		bne @tilenum_odd
			; Tile number is even. We want bit 0
			asl temp3
			rol temp3
			rol temp3
			
			lda NEXT_ROW_ATTRS, y
			and #%11111100
			clc
			adc temp3
			sta NEXT_ROW_ATTRS, y

			jmp @go
		@tilenum_odd: 
			; Tile number is odd. We want bit 4
			lsr temp3
			lsr temp3
			
			lda NEXT_ROW_ATTRS, y
			and #%11001111
			clc
			adc temp3
			sta NEXT_ROW_ATTRS, y

			jmp @go
	@lvl_odd: 
		; Level is odd. We want the right of the bytes.
		lda temp1
		and #%00000001
		cmp #0
		bne @tilenum2_odd
			; Tilenum is even. We want bit 2
			.repeat 4
				lsr temp3
			.endrepeat
			
			lda NEXT_ROW_ATTRS, y
			and #%11110011
			clc
			adc temp3
			sta NEXT_ROW_ATTRS, y
			jmp @go
		@tilenum2_odd: 
			; Tilenum is odd. We want bit 6
			lda NEXT_ROW_ATTRS, y
			and #%00111111
			clc
			adc temp3
			sta NEXT_ROW_ATTRS, y

	@go: 
	ldy temp0
	
	rts
	
draw_current_nametable_row:
	
	lda playerDirection
	cmp #PLAYER_DIRECTION_LEFT
	bne @right
		; left
		lda levelPosition
		sec
		sbc #WINDOW_WIDTH_TILES+3
		sta temp5
		jmp @go
	@right: 
		lda levelPosition
		sta temp5
		jmp @go
	
	@go:
	lda temp5
	and #%00001111
	sta temp1
	asl ; x2 because we want nametable addr, not map addr
	clc
	adc #BOTTOM_HUD_TILE
	sta nametableAddr
	
	; TODO: This feels kinda clumsy/inefficient. Is there a smarter way?
	lda temp5
	and #%00010000
	lsr
	lsr
	sta temp1
	lda nametableAddr+1
	and #%11111011
	clc
	adc temp1
	sta nametableAddr+1

	
	lda PPU_STATUS
	store nametableAddr+1, PPU_ADDR
	store nametableAddr, PPU_ADDR


	ldx #0
	@looper: 
		lda NEXT_ROW_CACHE, x
		sta PPU_DATA
		inx
		cpx #24 ; 32 - 8 rows for sprite 0 header stuff
		bne @looper
		
	lda PPU_STATUS
	lda nametableAddr
	clc
	adc #$1
	sta nametableAddr
	lda nametableAddr+1
	adc #0
	sta nametableAddr+1
	sta PPU_ADDR
	lda nametableAddr
	sta PPU_ADDR
	
	ldx #32
	@looper2: 
		lda NEXT_ROW_CACHE, x
		sta PPU_DATA
		inx
		cpx #56 ; 64 - 8 rows for sprite 0 header stuff
		bne @looper2

	lda levelPosition
	and #%00000001
	bne @attrs
	jmp @no_attrs
		
	@attrs: 
		lda PPU_STATUS
		lda nametableAddr+1
		clc 
		adc #3 ; put us at the start of the attr table
		sta PPU_ADDR
		sta tempAddr+1
		lda temp5
		and #%00001111 ; get our offset from the screen % 16
		lsr ; Divide by 2 to line up with attrs.
		clc
		adc #$c8 ; start of nametable under status
		sta PPU_ADDR
		sta tempAddr
		ldx #0
		
		.repeat 6
			lda NEXT_ROW_ATTRS, x
			sta PPU_DATA
			
			lda tempAddr+1
			sta PPU_ADDR
			lda tempAddr
			adc #8 ; next ro
			sta tempAddr
			sta PPU_ADDR
			
			inx
		.endrepeat
		; Write one last time w/o the memory stuffs.
		lda NEXT_ROW_ATTRS, x
		sta PPU_DATA
	@no_attrs: 
		
	reset_ppu_scrolling
	
	rts

	
do_player_vertical_movement:
	; FIXME: This is definitely off by a few tiles. What do we do?
	
	; Subtract screenScroll down to where the player actually is... we want distance from right, so subtract from 256=0
	lda #0
	sec 
	sbc playerXPosOnScreen
	;lda playerXPosOnScreen
	;clc
	;adc #8 ; force ourselves to round up.
	.repeat 4
		lsr ; Divide down to x16
	.endrepeat
	sta temp5
	lda screenScroll
	sec
	sbc temp5 
	and #%00011111 ; %32 effectively. Should wrap us.
	sta temp5 ; temp5 is now the scroll pos of the target row.



	lda playerYVelocity
	cmp #PLAYER_VELOCITY_JUMPING ; FIXME: What about jumping collisions?
	beq @collide_up 
	cmp #0
	bne @collide_down
		store #PLAYER_VELOCITY_FALLING, playerYVelocity ; If you're not moving, assume falling until you are proven to be standing on something.
	@collide_down:
	
		lda PLAYER_BOTTOM_SPRITE ; +0 for y.
		clc
		adc #8 ; Get to bottom of sprite.
		and #%11110000 ; Drop all digits < 16.. align with 16 (imagine / 16 (* 16))
		sec
		sbc #%00100000 ; Subtract 2 to make us below the header.
		cmp #%11000000 
		bcs @no_collision ; If the y is greater than 12, you're below the screen. Go away.
		jmp @collision_prep

	@collide_up: 
		lda PLAYER_BOTTOM_SPRITE
		sec
		sbc #PLAYER_HEIGHT-8 ; Lose the height of the sprite itself from the total player height. Other option is to add 8 to the position to find the bottom first. (That = silly)
		and #%11110000 ; Drop all digits < 16 to align with 16
		sec
		sbc #%00100000 ; Lose two because of the header
		cmp #%00000000 ; If you're in the header, go away. Kick your direction down.
		bcs @collision_prep
			store #0, playerYVelocity
			jmp @no_collision
	
	@collision_prep:
	
	; We have the y position in the accumulator in either case.. add the scroll position in and move on.
	clc
	adc temp5
	sta tempAddr ; Low byte of the address.

	lda temp5 ; Add in the position in scroll to figure out which nametable and add x coord
	cmp #16
	bcc @left
		lda tempAddr
		sec
		sbc #16 ; Get ourselves onto the same wavelength - > 16 just tells us which nametable/mem area we want.
		sta tempAddr
		; Left, so hi byte of memory address is...
		store #>(SCREEN_2_DATA), tempAddr+1
		jmp @ready_for_collision
	@left: 
		store #>(SCREEN_1_DATA), tempAddr+1
		jmp @ready_for_collision

	@ready_for_collision:
	ldy #0
	lda (tempAddr), y
	and #%01111111 ; Hi bit is used to switch colors, so exclude it.
	cmp #63 ; FIXME: This is really, really stupid.
	beq @no_collision
		store #0, playerYVelocity ; Collided. Stop movin.
	@no_collision:
	
	; FIXME: Need to test both left and right.
	
	lda levelPosition ; x
	lda playerYVelocity
	cmp #0
	bne @carry_on
		rts
	@carry_on:
		lda PLAYER_SPRITE
		clc
		adc playerYVelocity
		cmp #SPRITE_OFFSCREEN
		bcc @not_uhoh
			jmp reset ; FIXME: Probably should have something else happen on death.
		@not_uhoh:
		sta PLAYER_SPRITE
		sta PLAYER_SPRITE+12
		
		lda PLAYER_SPRITE+4
		clc
		adc playerYVelocity
		sta PLAYER_SPRITE+4
		sta PLAYER_SPRITE+16
		
		lda PLAYER_SPRITE+8
		clc
		adc playerYVelocity
		sta PLAYER_SPRITE+8
		sta PLAYER_SPRITE+20
	rts
	
do_player_movement: 
	lda playerVelocity
	cmp #0
	bne @carry_on
		rts
	@carry_on:
	lda playerDirection
	cmp #PLAYER_DIRECTION_LEFT
	bne @move_right
		lda playerVelocity
		and #%00000011 ; get it down to a real speed; get rid of potential negation.
		sta temp0
		lda levelPositionExact
		sec
		sbc temp0
		sta tempLevelPositionExact
		sta tempLevelPosition
		
		lda levelPositionExact+1
		sbc #0
		sta tempLevelPositionExact+1
		sta temp0

		lda playerXPosOnScreen
		sec
		sbc temp0
		sta playerXPosOnScreen 
		jmp @after_move
	@move_right: 
		lda levelPositionExact
		clc
		adc playerVelocity
		sta tempLevelPositionExact
		sta tempLevelPosition
		
		lda levelPositionExact+1
		adc #0
		sta tempLevelPositionExact+1
		sta temp0

		lda playerXPosOnScreen
		clc
		adc temp0
		sta playerXPosOnScreen
	@after_move:
	
	
	.repeat 4
		lsr temp0
		ror tempLevelPosition
	.endrepeat

						
	; Test collision here.
	lda playerDirection
	cmp #PLAYER_DIRECTION_LEFT
	bne @collision_right
		; left
		jmp @dont_stop
	@collision_right: 
		; right
		
		jmp @dont_stop
	
	@stop: 
		lda #0
		sta playerVelocity
		; TODO: Do we need to reverse anything or otherwise make this okay to do? I think we've jmped otherwise? 
		rts
	@dont_stop: 
	
	store tempLevelPosition, levelPosition
	store tempLevelPositionExact, levelPositionExact
	store tempLevelPositionExact+1, levelPositionExact+1
	
	
	lda #0
	sta playerIsInScrollMargin
	lda levelPositionExact
	and #%00001110
	cmp #0
	bne @not_scrollin
	lda playerVelocity
	cmp #0
	beq @not_scrollin
		lda #1
		sta playerIsInScrollMargin
		lda playerDirection
		cmp #PLAYER_DIRECTION_LEFT
		bne @right
			dec screenScroll
			lda screenScroll
			cmp #255
			bne @nada
				lda #31
				sta screenScroll
			@nada:

			jmp @do_scrollin
		@right: 
			inc screenScroll
			lda screenScroll
			cmp #32
			bne @nadab
				lda #0
				sta screenScroll
			@nadab:
		@do_scrollin:
		jsr load_current_line
	@not_scrollin:
		
	lda PLAYER_SPRITE+3
	clc
	adc playerVelocity
	sta PLAYER_SPRITE+3
	sta PLAYER_SPRITE+7
	sta PLAYER_SPRITE+11

	clc
	adc #8
	sta PLAYER_SPRITE+15
	sta PLAYER_SPRITE+19
	sta PLAYER_SPRITE+23
	
	lda playerVelocity
	cmp #0
	bne @continue
		lda playerDirection
		asl
		sta PLAYER_SPRITE+1
		clc
		adc #$10
		sta PLAYER_SPRITE+5
		clc 
		adc #$10
		sta PLAYER_SPRITE+9
		clc
		adc #1
		sta PLAYER_SPRITE+21
		sec
		sbc #$10
		sta PLAYER_SPRITE+17
		sec
		sbc #$10
		sta PLAYER_SPRITE+13
		rts
		
	@continue:
	
	lda frameCounter
	and #%00000011
	cmp #1
	bcs @no_flop
		lda #0
		jmp @after_flop
	@no_flop:
		lsr
		clc
		adc #1
	@after_flop: 
	asl
	clc
	adc playerDirection
	adc playerDirection ; Sprites are two wide, so double it.
	sta PLAYER_SPRITE+1
	clc
	adc #$10
	sta PLAYER_SPRITE+5
	clc
	adc #$10
	sta PLAYER_SPRITE+9
	clc
	adc #1
	sta PLAYER_SPRITE+21
	sec
	sbc #$10
	sta PLAYER_SPRITE+17
	sec
	sbc #$10
	sta PLAYER_SPRITE+13

	lda playerDirection
	cmp #PLAYER_DIRECTION_LEFT
	bne @not_left
		lda PLAYER_SPRITE+3
		cmp #MIN_POSITION_LEFT_SCROLL
		bcs @dont_scroll
		lda levelPosition
		cmp #WINDOW_WIDTH_TILES+2 ; 1 to stretch PAST the window width, and 1 more to deal with bcc, rather than having a beq too.
		bcc @dont_scroll
		jmp @do_scroll_l
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
		bcs @dont_swap_nametable_l
			lda ppuCtrlBuffer
			eor #%00000001
			sta ppuCtrlBuffer
		@dont_swap_nametable_l:
	
		jmp @done_scroll
		
	
	@do_scroll_r: 
		lda scrollX
		clc
		adc playerVelocity
		sta scrollX
		
		; If we carried, it's time to swap nametables.
		bcc @dont_swap_nametable_r
			lda ppuCtrlBuffer
			eor #%00000001
			sta ppuCtrlBuffer
		@dont_swap_nametable_r:
		

		
		@done_scroll:
		
		; TODO: We're reversing something we did earlier here... there's likely a way to refactor this to not be necessary if we need some cycles back.
		lda PLAYER_SPRITE+3
		sec
		sbc playerVelocity
		sta PLAYER_SPRITE+3
		sta PLAYER_SPRITE+7
		sta PLAYER_SPRITE+11
		clc
		adc #8
		sta PLAYER_SPRITE+15
		sta PLAYER_SPRITE+19
		sta PLAYER_SPRITE+23
		lda playerXPosOnScreen
		sec 
		sbc playerVelocity ; Undo the move of our position on the screen... put us back where we belong.
		sta playerXPosOnScreen
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
		
		; If you're at the start of the level, go away. Don't run past the end.
		lda levelPosition
		cmp #MIN_LEFT_LEVEL_POSITION
		bcc @done_left
		
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
	
	lda ctrlButtons
	and #CONTROLLER_A
	beq @done_a
		lda lastCtrlButtons
		and #CONTROLLER_A
		bne @done_a ; Don't jump if you already used this A press to jump.
		lda playerYVelocity
		cmp #0
		bne @done_a
		lda flightTimer
		cmp #0
		bne @done_a
		
		lda #PLAYER_VELOCITY_JUMPING
		sta playerYVelocity
		lda playerVelocity
		cmp #PLAYER_VELOCITY_FAST
		beq @fast
		cmp #256-PLAYER_VELOCITY_FAST
		beq @fast
			lda #PLAYER_JUMP_TIME
			jmp @do_jump
		@fast: 
			lda #PLAYER_JUMP_TIME_RUN
		@do_jump:
		sta flightTimer
		
		lda #SFX_JUMP
		ldx #SOUND_CHANNEL_PLAYER
		jsr FamiToneSfxPlay

	@done_a:
	
	; Extra jump logic...
	lda flightTimer
	cmp #0
	beq @no_yvelocity
		cmp #1
		bne @not_switch
			store #PLAYER_VELOCITY_FALLING, playerYVelocity
		@not_switch:
		lda ctrlButtons
		and #CONTROLLER_A
		bne @dont_start_fallin
			store #PLAYER_VELOCITY_FALLING, playerYVelocity
			store #1, flightTimer ; So we can leverage that dec flightTimer below instead of jumping around!
		@dont_start_fallin: 
		dec flightTimer
	
	@no_yvelocity:
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
	
do_sprite0:
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
	lda PPU_STATUS
	lda ppuCtrlBuffer
	sta PPU_CTRL
	@skip_sprite0:
	reset_ppu_scrolling
	rts
	
main_loop: 

	jsr handle_main_input
	jsr do_player_vertical_movement
	jsr do_player_movement
	jsr FamiToneUpdate

	jsr vblank_wait
	
	; Not ideal to do this inside vblank...
	lda #%00001110
	and levelPositionExact
	cmp #0
	bne @go_on
		jsr draw_current_nametable_row
	@go_on:
	jsr do_sprite0
	
	jmp main_loop
	
show_level: 
	jsr disable_all
	jsr vblank_wait
	
	; Turn off 32 bit adding for addresses initially.
	lda ppuCtrlBuffer
	and #%11111011
	sta PPU_CTRL
	sta ppuCtrlBuffer
	
	jsr load_graphics_data
	jsr load_level

	; Turn on 32 bit adding for addresses to load rows.
	lda ppuCtrlBuffer
	ora #%00000100
	sta PPU_CTRL
	sta ppuCtrlBuffer

	jsr load_nametable

	; Turn it back off for the hud

	lda ppuCtrlBuffer
	and #%11111011
	sta PPU_CTRL
	sta ppuCtrlBuffer

	jsr show_hud
	jsr enable_all
	jsr load_sprite0
	reset_ppu_scrolling
	lda #PLAYER_DIRECTION_RIGHT
	sta playerDirection
	jsr initialize_player_sprite
	
	; Turn on 32 bit adding for addresses to load rows, instead of columns.
	lda ppuCtrlBuffer
	ora #%00000100
	sta ppuCtrlBuffer

	lda #0
	jsr FamiToneMusicPlay
	
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

	; Your regularly scheduled programming
	lda PPU_STATUS

	@skip_sprite0:
	lda ppuCtrlBuffer
	sta PPU_CTRL
	lda ppuMaskBuffer
	sta PPU_MASK

	store scrollX, PPU_SCROLL
	store scrollY, PPU_SCROLL

	
    pla ; restore regs
    tay
    pla
    tax
    pla
	
	rti
	
	.include "title.asm"
	
.segment "BANK0"
	.include "sound/famitone2.s"

all_music: 
	.include "sound/music.s"

all_sfx: 
	.include "sound/sfx.s"
	
	
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