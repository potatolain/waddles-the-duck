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
; $600-6ff: Unused.
; $700-7ff: World map data.
	
	
.segment "ZEROPAGE"
	; 6 "scratch" variables for whatever we may be doing at the time. 
	; A little hard to track honestly, but the NES has very limited ram. 
	; Other option is to have multiple names refer to one address, but that actually seems more confusing.
	temp0: 						.res 1
	temp1: 						.res 1
	temp2:						.res 1
	temp3: 						.res 1
	temp4: 						.res 1
	temp5:						.res 1
	tempCollision:				.res 1 ; Yes, this is lame.
	playerPosition:				.res 2
	playerScreenPosition:		.res 1
	tempPlayerPosition:			.res 2
	tempPlayerScreenPosition:	.res 1
	levelPosition:				.res 1
	playerIsInScrollMargin:		.res 1
	levelMemPosR:				.res 1
	frameCounter: 				.res 1
	ppuCtrlBuffer:				.res 1
	ppuMaskBuffer: 				.res 1
	tempAddr: 					.res 2
	levelAddr: 					.res 2
	nametableAddr:				.res 2
	scrollX:					.res 1
	scrollY:					.res 1
	ctrlButtons:				.res 1
	lastCtrlButtons:			.res 1
	playerVelocity:				.res 1
	playerYVelocity:			.res 1
	flightTimer:				.res 1
	playerDirection:			.res 1
	famitoneScratch:			.res 3
	currentDimension:			.res 1
	currentPalette:				.res 1
	warpDimensionA:				.res 1
	warpDimensionB:				.res 1
	warpIntersectY:				.res 1
	tempCollisionTile:			.res 1
	currentLevel:				.res 1
	lvlRowDataAddr:				.res 2
	lvlDataAddr:				.res 2
	warpDataAddr:				.res 2

	CHAR_TABLE_START 		= $e0
	NUM_SYM_TABLE_START	 	= $d0
	CHAR_SPACE				= $ff
	SCREEN_DATA				= $600
	NEXT_ROW_CACHE			= $500
	NEXT_ROW_ATTRS			= $540 ; This could share space with cache if needed.
	LEFT_ATTR_MASK			= %00110011
	RIGHT_ATTR_MASK			= %11001100
	SPRITE_DATA				= $200
	SPRITE_ZERO				= $200
	PLAYER_SPRITE			= $210
	PLAYER_BOTTOM_SPRITE	= PLAYER_SPRITE+12
	
	PLAYER_VELOCITY_NORMAL 		= $01
	PLAYER_VELOCITY_FAST		= $02
	PLAYER_VELOCITY_FALLING		= $02
	PLAYER_VELOCITY_JUMPING		= $ff-$02 ; rotato! (Make it pseudo negative to wrap around.)
	PLAYER_JUMP_TIME_RUN		= $14
	PLAYER_JUMP_TIME			= $10
	PLAYER_DIRECTION_LEFT		= $20
	PLAYER_DIRECTION_RIGHT		= $0
	SPRITE_ZERO_POSITION		= $27
	PLAYER_HEIGHT				= 16
	PLAYER_WIDTH				= 24
	HEADER_PIXEL_OFFSET			= 48

	DIMENSIONAL_SWAP_TIME		= 64

	SWITCHABLE_ROW_POSITION		= $0600; Tile id $60.
	SWITCHABLE_ROW_HEIGHT		= $200

;;;;;;;;;;;;;;;;;;;;;;;
; Dimension definitions
;   Also masks for choosing which palettes to use.

	DIMENSION_MASK				= %11100000
	DIMENSION_PLAIN				= %00000000
	DIMENSION_CALM				= %01000000
	DIMENSION_ICE_AGE			= %11000000
	DIMENSION_AGGRESSIVE		= %00100000
	DIMENSION_AUTUMN			= %01100000
	DIMENSION_END_OF_DAYS		= %11100000 ; NOTE: Same as fade.
	DIMENSION_FADE				= %11100000
	DIMENSION_INVALID			= %00011111

	TILE_ROW_PLAIN				= 6
	TILE_ROW_CALM				= 6
	TILE_ROW_ICE_AGE			= 8
	TILE_ROW_AGGRESSIVE			= $a
	TILE_ROW_AUTUMN				= $a
	TILE_ROW_END_OF_DAYS		= $a


	MIN_POSITION_LEFT_SCROLL		= $40
	MIN_POSITION_RIGHT_SCROLL		= $a0
	MIN_LEFT_LEVEL_POSITION 		= $02
	
	WINDOW_WIDTH			= 32
	WINDOW_WIDTH_TILES		= 16
	BOTTOM_HUD_TILE			= $c0
	
	BANK_SWITCH_ADDR 		= $8000
	BANK_SPRITES_AND_LEVEL	= 0
	
	LAST_WALKABLE_SPRITE	= 0
	FIRST_SOLID_SPRITE		= LAST_WALKABLE_SPRITE+1
	
	SPRITE_OFFSCREEN 		= $ef

	FIRST_VARIABLE_TILE		= 24
	TILE_WATER				= 24
	TILE_WATER_BENEATH		= 25
	TILE_PLANT				= 26
	TILE_ICE_BLOCK			= 27

	TILE_LEVEL_END			= 51


	
;;;;;;;;;;;;;;;;;;;;;;;
; Sound Effect ids
	SFX_COIN	= 1
	SFX_FLAP	= 0
	SFX_JUMP	= 2
	SFX_DUCK 	= 3
	SFX_CHIRP 	= 4
	SFX_MENU	= 5
	SFX_WARP	= 7

;;;;;;;;;;;;;;;;;;;;;;;
; Music
	SONG_CRAPPY 		= 0
	SONG_ICE_CRAPPY 	= 1

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

store #0, currentLevel

	
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
		cpy #$10
		bne @palette_loop

	set_ppu_addr $3f10
	ldy #0
	@palette_loop_b:
		lda default_sprite_palettes, y
		sta PPU_DATA
		iny
		cpy #$10
		bne @palette_loop_b

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
	lda #$20
	sta playerPosition
	sta playerScreenPosition
	lda #0
	sta playerPosition+1
	lda #1
	sta playerIsInScrollMargin

	lda #DIMENSION_INVALID
	sta warpDimensionA
	sta warpDimensionB


	; Large amount of weird stuff going on here...
	; First, grab our level id, then look up the address of the various data for the level... 
	lda currentLevel
	asl
	tax
	lda leveldata_table, x
	sta tempAddr
	inx
	lda leveldata_table, x
	sta tempAddr+1

	; Use this to seed the address of the various metadata
	ldy #0
	lda (tempAddr), y
	sta currentDimension

	ldy #4
	lda (tempAddr), y
	sta lvlDataAddr
	iny
	lda (tempAddr), y
	sta lvlDataAddr+1
	iny
	lda (tempAddr), y
	sta lvlRowDataAddr
	iny
	lda (tempAddr), y
	sta lvlRowDataAddr+1

	lda tempAddr
	clc
	adc #8
	sta warpDataAddr
	lda tempAddr+1
	adc #0
	sta warpDataAddr+1


	; Prep nametableAddr with the position we should start on nametable 2
	lda #BOTTOM_HUD_TILE
	sta nametableAddr
	lda #$24
	sta nametableAddr+1
	rts
	
load_nametable:
	
	ldx #1
	stx playerIsInScrollMargin

	ldx #16
	stx levelPosition
	
	@loopdedo: 
		txa
		pha
		jsr load_current_line
		jsr draw_current_nametable_row
		pla
		tax
		inc levelPosition
		inx
		cpx #32
		bne @loopdedo

	; Load the first half second, so we seed SCREEN_DATA with the right stuff, rather than overwriting it. (255 so we get 0 because of overflows... likely could be written more clearly.)
	ldx #255
	stx levelPosition
	
	@loopdedoodle: 
		txa
		pha
		jsr load_current_line
		jsr draw_current_nametable_row
		pla
		tax
		inc levelPosition
		inx
		cpx #17 ; We start the level offset by one to help with scrolling. If we don't do this, we'll skip the first tile of the second screen.
		bne @loopdedoodle

				
	rts
	
initialize_player_sprite: 
	store #$8f, PLAYER_SPRITE
	store #$0, PLAYER_SPRITE+1
	store #$0, PLAYER_SPRITE+2
	store #$20, PLAYER_SPRITE+3
	
	store #$8f, PLAYER_SPRITE+4
	store #$1, PLAYER_SPRITE+5
	store #$0, PLAYER_SPRITE+6
	store #$28, PLAYER_SPRITE+7
	
	store #$8f, PLAYER_SPRITE+8
	store #$2, PLAYER_SPRITE+9
	store #$0, PLAYER_SPRITE+10
	store #$30, PLAYER_SPRITE+11
	
	store #$97, PLAYER_SPRITE+12
	store #$10, PLAYER_SPRITE+13
	store #$0, PLAYER_SPRITE+14
	store #$20, PLAYER_SPRITE+15
	
	store #$97, PLAYER_SPRITE+16
	store #$11, PLAYER_SPRITE+17
	store #$0, PLAYER_SPRITE+18
	store #$28, PLAYER_SPRITE+19
	
	store #$97, PLAYER_SPRITE+20
	store #$12, PLAYER_SPRITE+21 
	store #$0, PLAYER_SPRITE+22
	store #$30, PLAYER_SPRITE+23
	
	
	rts

seed_level_position_l:
	lda tempPlayerPosition
	sec
	sbc tempPlayerScreenPosition
	sta levelPosition
	lda tempPlayerPosition+1
	sbc #0
	sta temp0


	.repeat 4
		lsr temp0
		ror levelPosition
	.endrepeat

	rts

seed_level_position_r:
	; Doing a bit of funky science here... subtrating down to the beginning of this screen, 
	; then pushing you an entire screen forward. A little bass-ackwards, but... quick and sane enough.
	lda tempPlayerPosition
	sec
	sbc tempPlayerScreenPosition
	sta levelPosition
	lda tempPlayerPosition+1
	sbc #0
	clc
	adc #1
	sta temp0

	.repeat 4
		lsr temp0
		ror levelPosition
	.endrepeat
	inc levelPosition ; Jump up one row, to keep it off-screen.

	rts



load_current_line:
	lda playerIsInScrollMargin
	cmp #0
	bne @doit
		rts
	@doit: 
	ldy levelPosition

	lda #0
	sta tempAddr+1
	lda (lvlRowDataAddr), y
	.repeat 4
		asl
		rol tempAddr+1
	.endrepeat
	clc
	adc lvlDataAddr
	sta tempAddr
	lda tempAddr+1
	adc lvlDataAddr+1
	sta tempAddr+1
	
	ldy #0
	lda levelPosition
	and #%00001111
	tax ; x is now the position to apply to screen. 0-15, loopinate.
	
	@loop:
	
		lda (tempAddr), y
		sta SCREEN_DATA, x
		jsr draw_to_cache
		iny
		txa
		clc
		adc #16
		tax
		cpy #16
		
		bne @loop
	rts
	
; Draws the tile in a to the next 4 positions in NEXT_ROW_CACHE. 
; Very tightly coupled to load_current_line. Moved to reduce complexity.
draw_to_cache: 
	; strip attrs
	sta temp3
	and #%00111111
	asl
	sta temp1
	sty temp0

	tya
	asl
	tay

	; Bit of madness going on here... basically we need to multiply the upper nybble by 2 in order to get the row number. The lower one is correct.
	lda temp1
	and #%11110000
	asl
	pha
	lda temp1
	and #%00001111
	sta temp1
	pla
	ora temp1
	sta temp1
	
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
	bne @lvl_odd
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
	lda levelPosition
	and #%00001111
	sta temp5
	asl ; x2 because we want nametable addr, not map addr
	clc
	adc #BOTTOM_HUD_TILE
	sta nametableAddr
	
	; TODO: This feels kinda clumsy/inefficient. Is there a smarter way?
	lda levelPosition
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
	cmp #0
	bne @right
		store #LEFT_ATTR_MASK, temp1
		jmp @attrs
	@right: 
		store #RIGHT_ATTR_MASK, temp1
		; fallthru.
		store #RIGHT_ATTR_MASK, temp1
	@attrs: 
		lda PPU_STATUS
		lda nametableAddr+1
		clc 
		adc #3 ; put us at the start of the attr table
		sta PPU_ADDR
		sta tempAddr+1
		lda temp5
		lsr ; Divide by 2 to line up with attrs.
		clc
		adc #$c8 ; start of nametable under status
		sta PPU_ADDR
		sta tempAddr
		ldx #0
		
		.repeat 6
			lda PPU_DATA ; dummy read to get the right value, caching, etc...
			lda temp1
			eor #$ff ; flip all bits
			and PPU_DATA ; Grab data and immediately strip out the new bits. 
			sta temp2
			lda NEXT_ROW_ATTRS, x ; combine with values...
			and temp1
			ora temp2 ; mischief managed.
			sta temp2

			lda tempAddr+1
			sta PPU_ADDR
			lda tempAddr
			sta PPU_ADDR
			lda temp2
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
	@done_attrs: 
		
	reset_ppu_scrolling
	
	rts

do_special_tile_stuff:
	lda tempCollisionTile
	cmp #TILE_LEVEL_END
	bne @not_eol
		; Technically, we're going all abandon ship on our stack here.
		; Trying to accomodate for that by setting the stack pointer back down to $ff, where it starts.
		ldx #$ff
		txs
		inc currentLevel
		jmp show_ready
	@not_eol:
	rts

reset_collision_state:
	store #0, tempCollisionTile
	rts

; Expectations: 
; - a is set to the tile value to test
; - End result is a is set to 1 if collision, 2 if not.
; - Any side-effects are applied by this process. (Damage, block breakage, etc)
do_collision_test:
	sta tempCollision

	cmp #TILE_LEVEL_END
	beq @special_tile_collision

	cmp #0
	beq @no_collision
	cmp #FIRST_VARIABLE_TILE
	bcc @collision
	cmp #FIRST_VARIABLE_TILE + 8
	bcs @collision

	lda currentDimension
	cmp #DIMENSION_AGGRESSIVE
	beq @fire
	cmp #DIMENSION_AUTUMN
	beq @fire
	cmp #DIMENSION_ICE_AGE
	beq @ice_age
	; By default, fallthrough to @default. Hits calm and normal. (And I guess end of days)


	@default: 
		lda tempCollision
		cmp #TILE_WATER
		beq @no_collision
		cmp #TILE_ICE_BLOCK
		beq @no_collision
		jmp @collision


 	@fire:
		; We're in the fire dimension. Special rules apply.
		lda tempCollision
		cmp #TILE_WATER
		beq @no_collision
		cmp #TILE_PLANT
		beq @no_collision
		cmp #TILE_ICE_BLOCK
		beq @no_collision
		jmp @collision

	@ice_age:
		; Pretty much everything is a collision! Ice is a PITA...
		jmp @collision

	@special_tile_collision:
		store tempCollision, tempCollisionTile
		lda #1
		rts

	@special_tile_no_collision:
		store tempCollision, tempCollisionTile
		lda #0
		rts


	@collision: ; intentional fallthru.
		lda #1
		rts

	@no_collision:
		lda #0
		rts



; WARNING: This method has a number of expectations and is kinda specialized to one use case. 
; [temp2,temp1] should be the position you want to test on the map. (Full)
; temp4 and temp5 will be consumed.
test_vertical_collision:
	.repeat 4
		lsr temp1
		ror temp2
	.endrepeat
	; temp2 is now the x position of the block in test.
	lda #%00001111 ; We only want the position % 16, so we can find our spot.
	and temp2
	sta temp2

	lda playerYVelocity
	cmp #PLAYER_VELOCITY_JUMPING
	beq @going_up 

		lda PLAYER_BOTTOM_SPRITE
		clc
		adc #7
		clc
		adc playerYVelocity
		sec
		sbc #HEADER_PIXEL_OFFSET ; remove header

		and #%11110000 ; Align with 16
		cmp #%11000000 
		sta temp1
		bcs @no_collision ; If the y is greater than 12, you're below the screen. Go away.

		; a is now the y coord of the block. temp2 is now the x. 
		; a is already multipied by 16, so we just need to combine it with temp2.
		; Carry must be clear or we'd hit no collision, so skip clc
		adc temp2
		sta temp2 ; Temp2 is now our index off of the collision table to check.

		tay
		lda SCREEN_DATA, y
		and #%00111111
		jsr do_collision_test
		cmp #0
		beq @no_collision
			store #0, playerYVelocity
			jmp @no_collision

	@going_up:

		lda PLAYER_SPRITE
		sec
		sbc #HEADER_PIXEL_OFFSET ; remove header
		clc
		adc playerYVelocity
		and #%11110000 ; Align with 16
		sta temp1
		; TODO: Header check... and do, something?

		; a is now the y coord of the block. temp2 is now the x.
		; combine away.
		clc
		adc temp2
		sta temp2

		tay
		lda SCREEN_DATA, y
		and #%00111111
		jsr do_collision_test
		cmp #0
		beq @no_collision
			store #0, playerYVelocity
			; jmp @no_collision ; Intentional fallthrough 

	@no_collision:

	; Test warp collision, too. temp1 is our y
	lda temp1
	.repeat 4
		lsr
	.endrepeat
	sta temp1
	ldy #0
	@loop_warp:
		lda (warpDataAddr), y
		cmp #$ff
		beq @done_warp
		iny
		lda (warpDataAddr), y
		cmp temp1
		bne @not_warp
			store #1, warpIntersectY
		@not_warp:
		.repeat 3
			iny
		.endrepeat

	@done_warp:


	rts

; WARNING: This method has a number of expectations and is kinda specialized to one use case. 
; [temp2,temp1] should be the position you want to test on the map. (Full)
; temp4 and temp5 will be consumed.
; temp3=0: top, 1: bottom
test_horizontal_collision:

	.repeat 4
		lsr temp1
		ror temp2
	.endrepeat
	lda temp2
	sta temp1
	lda #%00001111 ; We only want the position % 16 to find our x.
	and temp2
	sta temp2

	; temp1 is the position within the level being tested.
	lda #DIMENSION_INVALID
	sta warpDimensionA
	sta warpDimensionB

	lda warpIntersectY
	cmp #0
	beq @done_warp

	ldy #0
	@loop_warp:
		lda (warpDataAddr), y
		cmp #$ff
		beq @color_warp
		cmp temp1
		beq @do_warp
		lda playerDirection
		cmp #PLAYER_DIRECTION_RIGHT
		bne @left
			lda (warpDataAddr), y
			clc
			adc #1
			cmp temp1
			beq @do_warp
			jmp @after_tests
		@left: 
			lda (warpDataAddr), y
			sec
			sbc #1
			cmp temp1
			beq @do_warp
			; fallthru
		@after_tests:

		.repeat 4 
			iny
		.endrepeat
		jmp @loop_warp

	@do_warp:
		; its a warp, and we already hit y. Let's do it
		iny
		iny
		lda (warpDataAddr), y
		sta warpDimensionA
		iny
		lda (warpDataAddr), y
		sta warpDimensionB

		lda currentDimension
		cmp warpDimensionA
		beq @do_warp_color
		cmp warpDimensionB
		beq @do_warp_color
		jmp @done_warp

		@do_warp_color:

		lda ppuMaskBuffer
		and #DIMENSION_MASK^255
		ora #DIMENSION_FADE
		sta ppuMaskBuffer
		jmp @done_warp


	@color_warp: 
		lda ppuMaskBuffer
		and #DIMENSION_MASK^255
		ora currentDimension
		sta ppuMaskBuffer

	@done_warp:

	lda temp3
	cmp #1
	beq @collide_up
		; collision bottom
		lda PLAYER_BOTTOM_SPRITE
		clc
		adc #7 ; bottom of sprite
		sec
		sbc #HEADER_PIXEL_OFFSET ; remove header
		and #%11110000 ; Align with 16

		clc
		adc temp2
		sta temp2

		tay
		lda SCREEN_DATA, y
		and #%00111111
		jsr do_collision_test
		cmp #0
		beq @no_collision
			store #0, playerVelocity
		

	@collide_up: 
		; collision top
		lda PLAYER_SPRITE ; Grab top of top sprite.
		sec
		sbc #HEADER_PIXEL_OFFSET ; remove header

		and #%11110000 ; align with 16

		clc
		adc temp2
		sta temp2
		
		tay 
		lda SCREEN_DATA, y
		and #%00111111
		jsr do_collision_test
		cmp #0
		beq @no_collision
			store #0, playerVelocity

	@no_collision:

	rts

do_player_vertical_movement:
	store playerPosition+1, temp1
	store playerPosition, temp2

	lda playerYVelocity
	cmp #0
	bne @non_zero
		store #PLAYER_VELOCITY_FALLING, playerYVelocity
	@non_zero:

	; Player's position is now in playerPosition[2]. And in temp1/temp2.
	jsr test_vertical_collision

	lda playerPosition
	clc
	adc #PLAYER_WIDTH
	sta temp2
	lda playerPosition+1
	adc #0
	sta temp1

	; We shifted you.. now repeat. 
	jsr test_vertical_collision
	
	
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
			ldx #$ff
			lda #1
			jsr FamiToneMusicPause
			txs ; Another instance where we rewrite the stack pointer to avoid doing bad things.
			jmp show_ready ; FIXME: Probably should have something else happen on death.
		@not_uhoh:
		sta PLAYER_SPRITE
		sta PLAYER_SPRITE+4
		sta PLAYER_SPRITE+8
		
		lda PLAYER_SPRITE+12
		clc
		adc playerYVelocity
		sta PLAYER_SPRITE+12
		sta PLAYER_SPRITE+16
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
		store #0, temp4
		lda playerPosition
		clc
		adc playerVelocity ; Expected rollover
		sta tempPlayerPosition
		
		lda playerPosition+1
		sbc #0 ; Take advantage of the fact we now have carry set, unless we didn't roll over.
		sta tempPlayerPosition+1
		sta temp0

		lda playerScreenPosition
		sta tempPlayerScreenPosition
		clc
		adc playerVelocity
		cmp #MIN_POSITION_LEFT_SCROLL
		bcc @after_move
		beq @after_move ; If we're >= scroll pos, don't update.
		sta tempPlayerScreenPosition 
		jmp @after_move
	@move_right: 
		store #PLAYER_WIDTH, temp4
		lda playerPosition
		clc
		adc playerVelocity
		sta tempPlayerPosition
		
		lda playerPosition+1
		adc #0
		sta tempPlayerPosition+1
		sta temp0

		lda playerScreenPosition
		sta tempPlayerScreenPosition
		clc
		adc playerVelocity
		cmp #MIN_POSITION_RIGHT_SCROLL
		bcs @after_move
		beq @after_move ; Don't store if it we're not scrolling. 
		sta tempPlayerScreenPosition
	@after_move:

	store #0, temp3
	lda playerDirection
	cmp #PLAYER_DIRECTION_LEFT
	beq @collision_left
		; right
		jsr seed_level_position_r
		jmp @after_seed
	@collision_left: 
		; right
		jsr seed_level_position_l
	@after_seed:
		lda tempPlayerPosition 
		clc
		adc temp4
		sta temp2
		lda tempPlayerPosition+1
		adc #0
		sta temp1
		jsr test_horizontal_collision

		store #1, temp3
		lda tempPlayerPosition 
		clc
		adc temp4
		sta temp2
		lda tempPlayerPosition+1
		adc #0
		sta temp1

		jsr test_horizontal_collision

		lda playerVelocity
		cmp #0
		beq @stop

		jmp @dont_stop
	
	@stop: 
		; TODO: Do we need to reverse anything or otherwise make this okay to do? I think we've jmped otherwise? 
		rts
	@dont_stop: 
	
	store tempPlayerPosition, playerPosition
	store tempPlayerPosition+1, playerPosition+1
	store tempPlayerScreenPosition, playerScreenPosition	
	
	lda #0
	sta playerIsInScrollMargin

	; TODO: If I aggressively start and stop running I can likely start skipping blocks. Should we lock you to running/walking for a few frames? (If we do that right it might even feel more natural.)
	lda playerVelocity
	cmp #PLAYER_VELOCITY_FAST
	beq @fast
	cmp #256-PLAYER_VELOCITY_FAST
	beq @fast
		; slow; 1px per scanline
		lda playerPosition
		and #%00001111
		cmp #0
		bne @not_scrollin
		jmp @scrollit
	@fast: 
		; fast; 2px per scanline
		lda playerPosition
		and #%00001110
		cmp #0
		bne @not_scrollin
		; intentional fallthru.

	@scrollit:
	lda playerVelocity
	cmp #0
	beq @not_scrollin
		lda #1
		sta playerIsInScrollMargin
		jsr load_current_line
	@not_scrollin:
		
	lda PLAYER_SPRITE+3
	clc
	adc playerVelocity
	sta PLAYER_SPRITE+3
	sta PLAYER_SPRITE+15

	clc
	adc #8
	sta PLAYER_SPRITE+7
	sta PLAYER_SPRITE+19

	clc
	adc #8
	sta PLAYER_SPRITE+11
	sta PLAYER_SPRITE+23
	
	lda playerVelocity
	cmp #0
	bne @continue
		lda playerDirection
		clc
		sta PLAYER_SPRITE+1
		adc #1
		sta PLAYER_SPRITE+5
		adc #1
		sta PLAYER_SPRITE+9
		adc #$0e ; $10 - the sprites set here.
		sta PLAYER_SPRITE+13
		adc #1
		sta PLAYER_SPRITE+17
		adc #1
		sta PLAYER_SPRITE+21
		rts
		
	@continue:
	
	lda playerVelocity
	cmp #PLAYER_VELOCITY_FAST
	bne @slow
	cmp #256-PLAYER_VELOCITY_FAST
	bne @slow

		lda frameCounter
		and #%000001000
		lsr 
		lsr
		lsr
		jmp @do_anim
	@slow: 
		lda frameCounter
		and #%00000100
		lsr
		lsr

	@do_anim:
	sta temp0
	clc
	; multiply by 3.
	adc temp0
	adc temp0
	adc #3 ; Add 3 to skip the "standing still" tile.

	adc playerDirection
	sta PLAYER_SPRITE+1
	adc #1
	sta PLAYER_SPRITE+5
	adc #1
	sta PLAYER_SPRITE+9
	adc #$0e ; 10 - the three sprites set here.
	sta PLAYER_SPRITE+13
	adc #1
	sta PLAYER_SPRITE+17
	adc #1
	sta PLAYER_SPRITE+21

	lda playerDirection
	cmp #PLAYER_DIRECTION_LEFT
	bne @not_left

		lda PLAYER_SPRITE+3
		cmp #MIN_POSITION_LEFT_SCROLL
		bcc @maybe_do_scroll_l
		jmp @dont_scroll
		@maybe_do_scroll_l:
			lda playerPosition+1
			cmp #0
			bne @do_scroll_l
			lda playerPosition
			cmp #MIN_POSITION_LEFT_SCROLL
			bcs @do_scroll_l
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
		sta PLAYER_SPRITE+15
		clc
		adc #8
		sta PLAYER_SPRITE+7
		sta PLAYER_SPRITE+19
		clc
		adc #8
		sta PLAYER_SPRITE+11
		sta PLAYER_SPRITE+23
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
		lda playerPosition+1
		cmp #0
		bne @continue_left
		lda playerPosition
		cmp #MIN_LEFT_LEVEL_POSITION
		bcc @done_left
		@continue_left:
		
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

	lda ctrlButtons
	and #CONTROLLER_SELECT
	beq @done_sel
		jsr do_dimensional_transfer
	@done_sel:

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
	txa
	pha
	ldx #$10
	@waitEndOfSprite:
		dex
		bne @waitEndOfSprite
	pla
	tax
	lda PPU_STATUS
	lda ppuCtrlBuffer
	sta PPU_CTRL
	@skip_sprite0:
	reset_ppu_scrolling
	rts

play_music_for_dimension: 
	lda currentDimension
	cmp #DIMENSION_PLAIN
	bne @not_plain
		lda #SONG_CRAPPY
		jsr FamiToneMusicPlay
		rts
	@not_plain: 
	cmp #DIMENSION_ICE_AGE
	bne @not_ice_age
		lda #SONG_ICE_CRAPPY 
		jsr FamiToneMusicPlay
		rts
	@not_ice_age:
	; Fall back to default track for consistency's sake.
	lda #SONG_CRAPPY
	jsr FamiToneMusicPlay 
	rts

; Child of do_dimensional_transfer - does the actual fading to decrease code dupe.
do_fade_anim: 
	lda currentPalette
	asl
	asl ; multiply by 16 to get position off original number.
	asl
	asl
	tax ; x is now the index of the palette-y thing

	jsr vblank_wait
	lda PPU_STATUS
	set_ppu_addr $3f00

	ldy #16
	@inner_loop:
		lda default_palettes, x
		sec
		sbc temp0
		bcs :+
			lda #$0f ; if you went over carry, fade to black early.
		: ; No-name skip label because if we put a named label in a loop, it'll freak!
		sta PPU_DATA
		dey
		inx

		cpy #0
		bne @inner_loop
	
	; ppu addr is correct from above; no need to reset.
	ldy #16
	txa
	sec
	sbc #16
	tax
	@inner_loop_sprites:
		lda default_sprite_palettes, x
		sec
		sbc temp0
		bcs :+
			lda #$0f ; if you went over carry, fade to black early.
		: ; No-name skip label because if we put a named label in a loop, it'll freak!
		sta PPU_DATA
		dey
		inx

		cpy #0
		bne @inner_loop_sprites
	rts

; Quick method to convert accumulator as a dimension id into a row number to start drawing files into the variable tile row.
get_row_from_a:
	cmp #DIMENSION_PLAIN
	beq @plain
	cmp #DIMENSION_CALM
	beq @plain
	cmp #DIMENSION_ICE_AGE
	beq @ice_age
	; Fallthru... just use a default to save some instructions.
	; cmp #DIMENSION_AGGRESSIVE
	; beq @aggressive
	; cmp #DIMENSION_AUTUMN
	; beq @aggressive
	; cmp #DIMENSION_END_OF_DAYS
	; beq @aggressive
	@aggressive:
	 	lda #TILE_ROW_AGGRESSIVE
		rts

	@plain: 
		lda #TILE_ROW_PLAIN
		rts

	@ice_age: 
		lda #TILE_ROW_ICE_AGE
		rts

draw_switchable_tiles: 

	; Okay, we've gotta swap tiles. Which ones do we want?
	lda currentDimension
	jsr get_row_from_a
	sta temp2

	store #0, tempAddr
	store temp2, tempAddr+1 ; Row id is an actual row id, so just stick it into the address to start.

	; Now add in the actual position of the nametable. (default_chr may not be 0 aligned, so we gotta do both.)
	lda tempAddr
	clc
	adc #<(default_chr)
	sta tempAddr
	lda tempAddr+1
	adc #>(default_chr)
	sta tempAddr+1

	; Okay, time to loop over everything.
	set_ppu_addr SWITCHABLE_ROW_POSITION
	
	store #1, temp2
	ldy #0
	@loop_tiles:
		; Should be exactly 512 bytes per row, so loop 2x
		lda (tempAddr), y
		sta PPU_DATA
		iny
		cpy #0
		bne @loop_tiles
		inc tempAddr+1
		dec temp2
		cpy temp2 ; Since y is definitely 0, and that's what we wanna count down to.
		beq @loop_tiles
	rts

; Try to create a "Smooth" (well, for NES) fade in/out. Buys us time to swap out tiles, etc.
do_dimensional_transfer:

	lda warpDimensionA
	cmp currentDimension
	beq @doit
	lda warpDimensionB
	cmp currentDimension
	beq @doit
	rts
	@doit:

	lda #SFX_WARP
	ldx #SOUND_CHANNEL_PLAYER
	jsr FamiToneSfxPlay
	jsr FamiToneMusicPause ; A should be non-zero here, causing a pause.


	lda ppuCtrlBuffer
	sta temp4
	and #%11111011
	sta ppuCtrlBuffer ; Reset to going sequentially rather than incrementing by 32
	jsr vblank_wait

	
	; TODO: Lots of hard coded numbers here... numbers are kinda necessary but I'm wondering if there's math I could pull off.
	; For now, assumes 0 < x <=64
	ldx #0

	@loopah: 
		cpx #16
		bcs @increase_maybe
			; decreasing palette.
			txa
			pha ; Shove it into the stack so we can get it back.
			lsr
			lsr ; Now between 0-3 decreasing
			asl
			asl
			asl
			asl ; Now a multiple of 16
			sta temp0
			
			jsr do_fade_anim
			jsr do_sprite0

			pla
			tax ; x is back.

			jmp @end_loop
			


		@increase_maybe:
		cpx #17 ; at 17, wipe everything out, since our fade method is kind of flawed/imperfect and doesn't always 0 everything out.
		bne @increase_maybe2
			jsr vblank_wait
			lda PPU_STATUS
			set_ppu_addr $3f00

			ldy #32
			@wiper_loop_decrease:
				lda #$0f
				sta PPU_DATA
				dey

				cpy #0
				bne @wiper_loop_decrease
				jsr do_sprite0
			jmp @end_loop
		@increase_maybe2:
		cpx #33
		bne @increase

			; This is where we turn things off and do our tile swaps, switch to a different palette, change the dimension, etc. The world is your lobster. (yes, lobster)
			; TODO: Probably need this passed in. temp5 is unused, or we could define one just for this. 
			jsr vblank_wait
			jsr do_sprite0
			jsr FamiToneUpdate
			jsr disable_all
			jsr vblank_wait
			jsr FamiToneUpdate

			lda currentDimension
			cmp warpDimensionA
			bne @not_a
				; it's a; go to b.
				lda warpDimensionB
				jmp @after_swap
			@not_a:
				lda warpDimensionA
			@after_swap:
			sta currentDimension


			jsr draw_switchable_tiles					

			jsr enable_all ; Will put mask data back for us too. 
			; The 48 is just a guess at how long this bit should take... skip the actual "frames"
			jmp @end_loop

		@increase:

			; decreasing palette.
			txa
			pha ; Shove it into the stack so we can get it back.
			sec
			sbc #48 ; Get it down to 0-15
			sta temp0
			lda #16
			sbc temp0 ; and now it's inverted.
			lsr
			lsr ; Now between 0-3 decreasing
			asl
			asl
			asl
			asl ; Now a multiple of 16
			sta temp0
			jsr do_fade_anim
			jsr do_sprite0

			pla
			tax ; x is back.

		@end_loop:
			txa
			pha
			reset_ppu_scrolling
			jsr FamiToneUpdate; We're our own little thing.. need to trigger famitone.
			pla
			tax 
			inx
			cpx #DIMENSIONAL_SWAP_TIME
			beq @done_d
				jmp @loopah; You will stay here FOR-EV-ER!!
			@done_d:
	@done:
	jsr vblank_wait
	jsr do_sprite0
	lda temp4
	sta ppuCtrlBuffer
	jsr play_music_for_dimension
	lda #0 ; 0 = play.
	jsr FamiToneMusicPause
	rts
	
main_loop: 

	jsr handle_main_input
	store #0, warpIntersectY ; reset warp intersection data. (TODO: This isn't the clearest thing ever written...)
	jsr reset_collision_state
	jsr do_player_vertical_movement
	jsr do_player_movement
	jsr do_special_tile_stuff
	jsr FamiToneUpdate

	jsr vblank_wait
	
	; Not ideal to do this inside vblank...
	; TODO: Factor in player speed -- 0 v 2 (Probably drawing stuff twice)
	lda #%00001110
	and playerPosition
	cmp #0
	bne @go_on
	lda playerVelocity
	cmp #0
	beq @go_on
		lda playerDirection
		cmp #PLAYER_DIRECTION_LEFT
		bne @right
			jsr seed_level_position_l
			jmp @do_draw
		@right: 
			jsr seed_level_position_r
		@do_draw:
		jsr draw_current_nametable_row
	@go_on:
	jsr do_sprite0
	
	jmp main_loop
	
show_level: 
	jsr disable_all
	jsr vblank_wait

	; Turn off 32 bit adding for addresses initially.
	lda ppuCtrlBuffer
	and #%11111000 ; set to nametable 0
	sta PPU_CTRL
	sta ppuCtrlBuffer
	
	jsr load_graphics_data
	jsr load_level
	jsr draw_switchable_tiles


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

	jsr play_music_for_dimension
	
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
	ora currentDimension
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
	
	.include "menus.asm"
	
.segment "BANK0"
	.include "sound/famitone2.s"

all_music: 
	.include "sound/music.s"

all_sfx: 
	.include "sound/sfx.s"
	
lvl1:
	.include "levels/lvl1_meta.asm"
	.include "levels/processed/lvl1.asm"

lvl2:
	.include "levels/lvl2_meta.asm"
	.include "levels/processed/lvl2.asm"

leveldata_table: 
	.word lvl1, lvl2


default_chr:
	.incbin "graphics/map_tiles.chr"
	
default_sprite_chr:
	.incbin "graphics/sprites.chr"

menu_chr_data: 
	.incbin "graphics/title_tiles.chr"

	
default_palettes: 
	; Normal (and probably ice)
	.byte $31,$06,$16,$1a,$31,$11,$21,$06,$31,$06,$19,$28,$31,$09,$19,$29
	; fire-ized
	.byte $31,$06,$17,$0a,$31,$06,$17,$2D,$31,$06,$19,$28,$31,$09,$19,$29
default_sprite_palettes: ; Drawn at same time as above.
	; 0) duck. 1) turtle
	.byte $31,$27,$38,$0f,$31,$00,$10,$31,$31,$01,$21,$31,$31,$09,$19,$29

menu_palettes: 
	.byte $0f,$00,$10,$30,$0f,$01,$21,$31,$0f,$06,$16,$26,$0f,$09,$19,$29
	.byte $0f,$00,$10,$30,$0f,$01,$21,$31,$0f,$06,$16,$26,$0f,$09,$19,$29

	
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