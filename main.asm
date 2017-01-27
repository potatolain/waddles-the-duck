.feature c_comments
.linecont +
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
; $400-41f: Unused
; $420-4ff: Static collectible data
; $500-55f: Screen buffer
; $560-5ff: Unused
; $600-6ff: Animated tile buffer (If we need space, this could shrink to 1x, and reloaded every cycle)
; $700-7bf: Extended sprite data
; $7c0-7ff: Current level collectible data

		
.segment "ZEROPAGE"
	watchme: 						.res 1
	skippedSprites:					.res 1 ; Counter for every time we have a sprite and can't fit it into memory. If this is non-zero, there's a potential problem with the engine and/or level layout.
	; Set of short-lived "scratch" variables for whatever we may be doing at the time. 
	; These should ONLY be used in short code sections, when an extra accumulator might be useful. 
	; All code using them should fit into roughly 10 lines, and should not jsr to other methods 
	; (which could also use them).
	scratch0:						.res 1
	scratch1:						.res 1
	; Similar longer-term scratch variables stemming from a thought that I'd need more ZP variables earlier on.
	; TODO: Start replacing these with sane ZP vars. The engine is nearly complete, and we're using < 1/2 ZP.
	temp0: 							.res 1
	temp1: 							.res 1
	temp2:							.res 1
	temp3: 							.res 1
	temp4: 							.res 1
	temp5:							.res 1
	temp6:							.res 1
	temp7:							.res 1
	temp8:							.res 1
	temp9:							.res 1
	tempa:							.res 1
	tempb:							.res 1
	tempc:							.res 1
	tempd:							.res 1
	tempe:							.res 1
	tempf:							.res 1
	tempCollision:					.res 1 ; Yes, this is lame.
	playerPosition:					.res 2
	playerScreenPosition:			.res 1
	tempPlayerPosition:				.res 2
	tempPlayerScreenPosition:		.res 1
	levelPosition:					.res 1
	playerIsInScrollMargin:			.res 1
	levelMemPosR:					.res 1
	frameCounter: 					.res 1
	ppuCtrlBuffer:					.res 1
	ppuMaskBuffer: 					.res 1
	tempAddr: 						.res 2
	levelAddr: 						.res 2
	nametableAddr:					.res 2
	blockLookupAddr:				.res 2
	scrollX:						.res 1
	scrollY:						.res 1
	ctrlButtons:					.res 1
	lastCtrlButtons:				.res 1
	playerVelocity:					.res 1
	playerYVelocity:				.res 1
	playerYVelocityNext:			.res 1
	lastFramePlayerYVelocity:		.res 1
	playerXVelocityLockTime:		.res 1
	playerYVelocityLockTime:		.res 1
	flightTimer:					.res 1
	playerDirection:				.res 1
	lastPlayerDirection:			.res 1
	playerVisibleDirection:			.res 1
	famitoneScratch:				.res 3
	currentDimension:				.res 1
	currentPalette:					.res 1
	warpDimensionA:					.res 1
	warpDimensionB:					.res 1
	isInWarpZone:					.res 1
	tempCollisionTile:				.res 1
	tempCollisionTilePos:			.res 1
	currentLevel:					.res 1
	currentLevelFlagX:				.res 1
	lvlRowDataAddr:					.res 2
	lvlDataAddr:					.res 2
	lvlSpriteDataAddr:				.res 2
	paletteAddr:					.res 2
	currentSprite:					.res 1
	xScrollChange:					.res 1
	duckPausePosition:				.res 1
	macroTmp:						.res 2 ; MACROS. ONLY. (Do not use in macros that call other macros, as a general rule.)
	gemCount:						.res 1 ; NOTE: This should *not* be used for comparisons; it uses 0-9 to form the counts for the ui.
	totalGemCount:					.res 1 ; So does this.
	currentBank:					.res 1
	arbitraryTileUpdateId:			.res 1
	arbitraryTileUpdatePos:			.res 1
	arbitraryTileNametableOffset:	.res 1
	arbitraryTileAddr:				.res 2
	isOnIce:						.res 1
	pauseOption:					.res 1
	hasStompedSprite:				.res 1
	tempPosition:					.res 1
	extendedSpriteDataX:			.res 1
	varSpriteDataX:					.res 1
	varSpriteDataOffset:			.res 1
	spriteOffsetTmp:				.res 1
	textPage:						.res 1
	hasTalkedToMrDuck:				.res 1
	preTextPpuCtrl:					.res 1
	gameGemCountCache:				.res 2
	currentBackgroundColorOverride:	.res 1
	dimensionSwapTimer:				.res 1
	hasHitLastLevelWarpThing:		.res 1 ; Candidate for best variable name ever... if this is non-zero, we won't flip dimensions in level 9 anymore.


	CHAR_TABLE_START 				= $e1
	NUM_SYM_TABLE_START	 			= $d0
	CHAR_SPACE						= $e0
	COLLECTIBLE_DATA				= $420
	COLLECTIBLE_DATA_LENGTH			= $d9 ; Don't add in magical byte
	MAGICAL_BYTE					= $4ff
	MAGICAL_BYTE_VALUE				= $db
	GAME_BEATEN_BYTE				= $4fe
	NEXT_ROW_CACHE					= $500
	NEXT_ROW_ATTRS					= $540 ; This could share space with cache if needed.
	ANIMATED_TILE_CACHE				= $600
	EXTENDED_SPRITE_DATA			= $700
	LEFT_ATTR_MASK					= %00110011
	RIGHT_ATTR_MASK					= %11001100
	SPRITE_DATA						= $200
	SPRITE_ZERO						= $200
	PLAYER_SPRITE					= $210
	PLAYER_BOTTOM_SPRITE			= PLAYER_SPRITE+12
	HUD_GEM_SPRITE 					= $22c
	PLAYER_SPRITE_ID				= $c6
	FIRST_VAR_SPRITE				= $230
	VAR_SPRITE_DATA					= FIRST_VAR_SPRITE
	LAST_VAR_SPRITE					= $2fc
	NUM_VAR_SPRITES					= 12
	CURRENT_LEVEL_DATA				= $7c0
	CURRENT_LEVEL_DATA_B			= $7e0
	CURRENT_LEVEL_DATA_LENGTH		= $40
	CURRENT_LEVEL_DATA_TILE_LENGTH 	= $20
	
	PLAYER_VELOCITY_NORMAL 		= $01
	PLAYER_VELOCITY_FAST		= $02
	PLAYER_VELOCITY_FALLING		= $02
	PLAYER_VELOCITY_JUMPING		= $100-$02 ; rotato! (Make it pseudo negative to wrap around.)
	PLAYER_JUMP_TIME_RUN		= $1c
	PLAYER_JUMP_TIME			= $18
	HOP_LOCK_TIME				= $6
	RUN_MOVEMENT_LOCK_TIME		= $0a
	ICE_RUN_MOVEMENT_LOCK_TIME	= $1a
	PLAYER_DIRECTION_LEFT		= $20
	PLAYER_DIRECTION_RIGHT		= $0
	PLAYER_DIRECTION_MASK		= %00100000
	SPRITE_ZERO_POSITION		= $17
	SPRITE_ZERO_X				= $80
	PLAYER_HEIGHT				= 16
	PLAYER_WIDTH				= 24
	HEADER_PIXEL_OFFSET			= 48
	SPRITE_HEIGHT_OFFSET		= 8
	SPRITE_VELOCITY_NORMAL		= 1 ; This trips every other frame, so multiply accordinly.
	SPRITE_X_CUTOFF 			= 240

	DIMENSIONAL_SWAP_TIME		= 64

	SWITCHABLE_ROW_POSITION		= $0600; Tile id $60.
	SWITCHABLE_ROW_HEIGHT		= $200

;;;;;;;;;;;;;;;;;;;;;;;
; Dimension definitions
;   Also masks for choosing which palettes to use.
;   NOTE: Must not be %10100000, or SPRITE_ANIMATION_DYING needs a value this won't collide with 
	DIMENSION_MASK				= %11100000
	DIMENSION_PLAIN				= %00000000
	DIMENSION_BARREN			= %00000010
	DIMENSION_ICE_AGE			= %11000000
	DIMENSION_AGGRESSIVE		= %00100000
	DIMENSION_AUTUMN			= %01100000
	DIMENSION_END_OF_DAYS		= %11100000 ; NOTE: Same as fade.
	DIMENSION_FADE				= %11100000
	DIMENSION_INVALID			= %00011111

	TILE_ROW_PLAIN				= $6
	TILE_ROW_BARREN				= $a
	TILE_ROW_ICE_AGE			= $8
	TILE_ROW_AGGRESSIVE			= $4
	TILE_ROW_AUTUMN				= $a
	TILE_ROW_END_OF_DAYS		= $a


	; TODO: The logic around this could probably be axed at this point - we just always scroll if you're not at the start/end of the level.
	MIN_POSITION_LEFT_SCROLL		= $80
	MIN_POSITION_RIGHT_SCROLL		= $80
	MIN_LEFT_LEVEL_POSITION 		= $04

	MIN_SPRITE_GRAVITY_X		= $30
	MAX_SPRITE_GRAVITY_X		= $b0
	
	WINDOW_WIDTH			= 32
	WINDOW_WIDTH_TILES		= 16
	BOTTOM_HUD_TILE			= $c0
	
	BANK_SWITCH_ADDR 		= $8000
	BANK_SPRITES_AND_LEVEL	= 0
	BANK_MUSIC_AND_SOUND	= 1
	BANK_CHR				= 1
	BANK_TEXT_ENGINE		= 2
	BANK_GEM_FUNCTIONS		= 2
	BANK_INTRO				= 2
	
	LAST_WALKABLE_SPRITE	= 0
	FIRST_SOLID_SPRITE		= LAST_WALKABLE_SPRITE+1
	SPRITE_SCREEN_OFFSET	= 16
	MAX_SPRITE_REMOVAL_TIME	= 45
	
	SPRITE_OFFSCREEN 		= $ef

	FIRST_NO_COLLIDE_TILE	= 8
	LAST_NO_COLLIDE_TILE	= 16
	FIRST_VARIABLE_TILE		= 24
	TILE_WATER				= 24
	TILE_WATER_BENEATH		= 25
	TILE_PLANT				= 26
	TILE_ICE_BLOCK			= 27
	TILE_FLOWER				= 29
	TILE_QUESTION_BLOCK		= 2
	TILE_CLOUD				= 28

	TILE_LEVEL_END			= 49

	WATER_TILE_LOCATION		= $0600
	FIRE_TILE_LOCATION		= $0660

	GAME_TILE_A				= $e6
	GAME_TILE_0				= $dc

	SPRITE_DYING			= $0c
	SPRITE_PAUSE_LETTERS	= $e0
	SPRITE_POINTER			= $f3

	; How many frames to show the "ready" screen for.
	READY_TIME				= 48
	END_OF_LEVEL_WAIT_TIME	= 144

	; How many frames the player goes up before going down if dying to an enemy.
	DEATH_HOP_TIME			= 6
	DEATH_SONG_TIME			= 128

	MENU_PALETTE_ID			= 7

	
;;;;;;;;;;;;;;;;;;;;;;;
; Sound Effect ids
	SFX_COIN		= 1
	SFX_FLAP		= 0
	SFX_JUMP		= 2
	SFX_DUCK 		= 3
	SFX_CHIRP 		= 4
	SFX_MENU		= 5
	SFX_WARP		= 7
	SFX_SQUISH		= 9
	SFX_HURT		= 8
	SFX_MENU_DOWN	= 10
	SFX_DEATH		= 11
	SFX_BLOCK_HIT	= 12
	SFX_MENU_TICK	= 13

;;;;;;;;;;;;;;;;;;;;;;;
; Music
	SONG_CRAPPY 		= 5
	SONG_ICE_CRAPPY 	= 11
	SONG_CRAPPY_DESERT	= 4
	SONG_FIRE			= 10
	SONG_EOD			= 12
	SONG_DEATH			= 3
	SONG_LEVEL_END		= 9
	SONG_INTRO			= 13
	SONG_TITLE			= 2
	SONG_BAD_ENDING		= 8
	SONG_GOOD_ENDING	= 14

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
	

/*
;;;;;;;;;;;;;;;;;;;;;
; Sprite Data map

Store all sprite info in a 60 byte table, with 8 bytes per sprite. 
; 0+1: full-blown x position.  SPRITE_DATA+x is abbreviated version
; 2		y position
; 3 	id
; 4 	alive? (binary... could use this for more)
; 5		direction (Also binary) + anim state
; 6		type?
; 7		sprite-specific data
*/
SPRITE_DATA_X 						= 0
SPRITE_DATA_Y 						= 2
SPRITE_DATA_ID						= 3
SPRITE_DATA_DIRECTION 				= 5
SPRITE_DATA_ANIM_STATE				= 5
SPRITE_DATA_ALIVE					= 4
SPRITE_DATA_TEMP_Y					= 4 ; HACK: Shared with alive - this is meaningless for collectible sprites, so we reuse the field.
SPRITE_DATA_TILE_ID					= 6
SPRITE_DATA_LVL_INDEX				= 7
SPRITE_DATA_WIDTH					= 8
SPRITE_DATA_HEIGHT					= 9
SPRITE_DATA_SIZE					= 10
SPRITE_DATA_ANIM_TYPE				= 11
SPRITE_DATA_TYPE					= 12
SPRITE_DATA_PALETTE					= 12 ; HACK: Shared with type 
SPRITE_DATA_LEVEL_DATA_POSITION 	= 13
SPRITE_DATA_SPEED					= 14
SPRITE_DATA_EXTRA					= 15

SPRITE_DATA_DIRECTION_MASK 		= PLAYER_DIRECTION_MASK
SPRITE_DATA_ANIM_STATE_MASK 	= %00001111
SPRITE_DIRECTION_LEFT			= PLAYER_DIRECTION_LEFT
SPRITE_DIRECTION_RIGHT 			= PLAYER_DIRECTION_RIGHT
SPRITE_DATA_TYPE_MASK			= %00111111
SPRITE_DATA_PALETTE_MASK		= %11000000

SPRITE_DATA_EXTRA_IS_HIDDEN			= 255 ; Used for collectibles hidden behind blocks. (Could also use the put-behind-background bit, but, eh..)

;;;;;;;;;;;;;;;;;;;;;;
; Our Sound Settings
	SOUND_CHANNEL_PLAYER = FT_SFX_CH0

;;;;;;;;;;;;;;;;;;;;;;
; Misc	
	SHOW_VERSION_STRING = 1
	BASE_NUMBER_OF_LEVELS = 9
	BASE_NUMBER_OF_REGULAR_LEVELS = 8

; Debugging level has to count if we're debugging, and thus included it.
.if DEBUGGING = 1
	NUMBER_OF_LEVELS = BASE_NUMBER_OF_LEVELS+1
	NUMBER_OF_REGULAR_LEVELS = BASE_NUMBER_OF_REGULAR_LEVELS+1
	LEVEL_8_ID = 8
	LEVEL_9_ID = 9
.else
	NUMBER_OF_LEVELS = BASE_NUMBER_OF_LEVELS
	NUMBER_OF_REGULAR_LEVELS = BASE_NUMBER_OF_REGULAR_LEVELS
	LEVEL_8_ID = 7
	LEVEL_9_ID = 8
.endif
	
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
	; Use a `magical` byte to not reset the $400 memory page on reset, allowing us to keep your gem count through restarts.
	lda MAGICAL_BYTE
	cmp #MAGICAL_BYTE_VALUE
	beq @no_400
		lda #0
		sta	$0400, x
	@no_400:
	lda #0
	sta	$0500, x
	sta	$0600, x
	sta	$0700, x
	txa
	and #%00000011
	beq  @its_y
		lda #0
		jmp @doit
	@its_y: 
		lda #SPRITE_OFFSCREEN
	@doit: 
	sta	$0200, x	; move all sprites off screen
	inx
	bne	clear_memory

	store #MAGICAL_BYTE_VALUE, MAGICAL_BYTE
	
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
bank #BANK_SPRITES_AND_LEVEL

ldx #<(all_music)
ldy #>(all_music)
lda #1 ; play ntsc musics/sound.
jsr music_init
ldx #<(all_sfx)
ldy #>(all_sfx)
jsr sfx_init

store #0, currentLevel

.if DEBUGGING = 1
	store #1, GAME_BEATEN_BYTE
.endif

	
jsr disable_all
lda	#%10001000	; enable NMI, sprites from pattern table 0,
sta	PPU_CTRL	;  background from pattern table 1
sta ppuCtrlBuffer
jsr enable_all

jmp show_title

load_graphics_data: 

	jsr load_sprite_palettes
	bank #BANK_CHR
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

	jsr PKB_unpackblk

	jsr load_palettes_for_dimension

	bank #BANK_SPRITES_AND_LEVEL
		
	rts
	
load_level: 
	lda #$20
	sta playerPosition
	sta tempPlayerPosition
	sta playerScreenPosition
	sta tempPlayerScreenPosition
	lda #0
	sta playerPosition+1
	sta tempPlayerPosition+1
	sta playerXVelocityLockTime
	sta playerYVelocityLockTime
	sta hasTalkedToMrDuck
	sta frameCounter ; Reset all timers when you start a level. Mainly important so level 9 behaves consistently.
	sta dimensionSwapTimer
	sta hasHitLastLevelWarpThing
	lda #1
	sta playerIsInScrollMargin
	jsr seed_level_position_l

	lda #SPRITE_OFFSCREEN
	ldx #0
	@loop_desprite:
		sta EXTENDED_SPRITE_DATA, x
		sta EXTENDED_SPRITE_DATA+1, x
		txa
		clc
		adc #16
		tax
		cpx #0
		bne @loop_desprite
	; ldx #0 ; Implied.
	lda #0
	@loop_delevel:
		sta CURRENT_LEVEL_DATA, x
		inx
		cpx #CURRENT_LEVEL_DATA_LENGTH
		bne @loop_delevel

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
	jsr seed_palette

	iny
	lda (tempAddr), y
	; The tile editor is off by a tile due to being 1-based. Accounting for that here is easier than remembering to remove 1.
	clc
	adc #1
	sta currentLevelFlagX

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
	iny
	lda (tempAddr), y
	sta lvlSpriteDataAddr
	iny
	lda (tempAddr), y
	sta lvlSpriteDataAddr+1

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

	; Load the first half second, so we draw the screen with the right stuff, rather than overwriting it. (255 so we get 0 because of overflows... likely could be written more clearly.)
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
	store #PLAYER_SPRITE_ID, PLAYER_SPRITE+1
	store #$0, PLAYER_SPRITE+2
	store #$20, PLAYER_SPRITE+3
	
	store #$8f, PLAYER_SPRITE+4
	store #PLAYER_SPRITE_ID+1, PLAYER_SPRITE+5
	store #$0, PLAYER_SPRITE+6
	store #$28, PLAYER_SPRITE+7
	
	store #$8f, PLAYER_SPRITE+8
	store #PLAYER_SPRITE_ID+2, PLAYER_SPRITE+9
	store #$0, PLAYER_SPRITE+10
	store #$30, PLAYER_SPRITE+11
	
	store #$97, PLAYER_SPRITE+12
	store #PLAYER_SPRITE_ID+$10, PLAYER_SPRITE+13
	store #$0, PLAYER_SPRITE+14
	store #$20, PLAYER_SPRITE+15
	
	store #$97, PLAYER_SPRITE+16
	store #PLAYER_SPRITE_ID+$11, PLAYER_SPRITE+17
	store #$0, PLAYER_SPRITE+18
	store #$28, PLAYER_SPRITE+19
	
	store #$97, PLAYER_SPRITE+20
	store #PLAYER_SPRITE_ID+$12, PLAYER_SPRITE+21 
	store #$0, PLAYER_SPRITE+22
	store #$30, PLAYER_SPRITE+23
	
	
	rts

; Seeds levelPosition, same as the others, but uses the player's 
; exact current position, rather than projected w/ movement. Also does not attempt to place you before the screen
seed_level_position_l_current:
	lda playerPosition
	sec
	sbc playerScreenPosition
	sta levelPosition
	lda playerPosition+1
	sbc #0
	sta temp0


	.repeat 4
		lsr temp0
		ror levelPosition
	.endrepeat
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
	dec levelPosition ; Jump back one row, once again to keep it offscreen.
	
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

; Kind of an intense method... expects: tempe: coarse x, tempf: coarse y (Should be tile numbers, not full coords)
; Looks up the exact tile id from lvlData&lvlDataAddr, and puts it in a.
get_tile_at_position:
	phxy


	lda #0
	ldy tempe
	sta blockLookupAddr+1
	lda (lvlRowDataAddr), y
	.repeat 4
		asl
		rol blockLookupAddr+1
	.endrepeat
	clc
	adc lvlDataAddr
	sta blockLookupAddr
	lda blockLookupAddr+1
	adc lvlDataAddr+1
	sta blockLookupAddr+1

	ldy tempf
	lda (blockLookupAddr), y


	plxy
	rts

; Tricky method to write the gem count in level 8.
override_gem_numbers_in_row:
	bank_temp #BANK_GEM_FUNCTIONS
		jsr banked_override_gem_numbers_in_row
	bank_restore
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
		jsr draw_to_cache
		iny
		cpy #16
		
		bne @loop

	jsr override_gem_numbers_in_row

	; The row **also** has sprites! Maybe!
	ldx levelPosition
	stx tempa
	lda playerDirection
	cmp #PLAYER_DIRECTION_LEFT
	bne @carry_on_going_right
		store levelPosition, tempa
	@carry_on_going_right:
	ldy #0
	ldx #0
	@loop_sprites:
		store #0, tempd ; offset to sprite y.
		lda (lvlSpriteDataAddr), y
		cmp #$ff
		bne @not_done_sprites
			jmp @done_sprites
		@not_done_sprites:
		cmp tempa
		beq @dont_move_on
			jmp @move_on
		@dont_move_on:
			store #0, temp1 ; Position of the byte
			store #255, currentSprite
			stx temp3 ; Store the original number for later use, before we consume it.
			txa
			pha 
			lda #%00000001
			@loop_for_mask:
				asl
				bcc @not_relooping
					inc temp1
					lda #%00000001
				@not_relooping:
				dex
				cpx #255 ; Make sure we actually calculate the 0 run.
				bne @loop_for_mask
				; Okay, temp1 is now the index off of CURRENT_LEVEL_DATA, and a is the mask. Sooo...
				ldx temp1
				sta tempc
				iny
				iny
				lda (lvlSpriteDataAddr), y
				sta tempb
				dey
				dey

				lda tempb
				cmp #SPRITE_TYPE_COLLECTIBLE
				bne @not_collectible_grabbable
					; It's a collectible... lets see if its been hit before.
					lda tempc
					and CURRENT_LEVEL_DATA_B, x
					cmp #0
					beq @not_collectible_grabbable
						; If it's found in here, someone hit it before. Elevate it up.
						lda #16
						sta tempd
						; we know that the data in the buffer is wrong, too... so let's correct it
						phx
							iny
							lda (lvlSpriteDataAddr), y
							dey
							asl ; Tiles are 2x tall...
							tax
							lda #(TILE_QUESTION_BLOCK+1<<2)
							sta NEXT_ROW_CACHE, x
							lda #(TILE_QUESTION_BLOCK+1<<2)+$10 ; This goes down in a column, so... tile id goes up to next row.
							inx
							sta NEXT_ROW_CACHE, x
							; Next col too
							txa
							clc
							adc #$1f
							tax
							lda #(TILE_QUESTION_BLOCK+1<<2)+$1
							sta NEXT_ROW_CACHE, x
							lda #(TILE_QUESTION_BLOCK+1<<2)+$11 ; This goes down in a column, so... tile id goes up to next row.
							inx
							sta NEXT_ROW_CACHE, x

						plx
				@not_collectible_grabbable:

				lda tempc
				and CURRENT_LEVEL_DATA, x
				cmp #0
				beq @dun_move_on
					; Bit of a hack... if we detect this is a gem, show it anyway (so we can detect which question blocks are in which state efficiently)
					lda tempb
					cmp #SPRITE_TYPE_COLLECTIBLE
					bne @really_move_on
						jmp @dun_move_on
					@really_move_on:
					jmp @move_on_plx
				@dun_move_on:


			phx
			; Make sure it's not a dupe... last check, honest
			ldx #0
			@loop_dedupe: 
				; what the heck is efficiency? TODO: This could be better in many ways.
				phx
				txa
				asl
				asl
				asl
				asl
				tax
				lda EXTENDED_SPRITE_DATA+SPRITE_DATA_LEVEL_DATA_POSITION, x
				sta scratch0
				cmp #0
				bne @must_test
					; okay, so either you're sprite 0 in the level, or you're gone. If you're sprite zero, you should still have a non-zero y coordinate.
					lda EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
					cmp #0 
					beq @not_covered_and_empty
				
				@must_test: 
				cpy scratch0
				bne @not_covered
					; Okay, if you were a gem we have a little more work for you...
					lda EXTENDED_SPRITE_DATA+SPRITE_DATA_TYPE, x
					and #SPRITE_DATA_TYPE_MASK
					cmp #SPRITE_TYPE_COLLECTIBLE
					bne @not_gem
						jsr remove_existing_gems_and_boxes
					@not_gem:
					plx
					plx
					; Escape. Escape.
					jmp @move_on_plx
				@not_covered_and_empty:
					; Before we do the not covered stuff, here's a good spot for a new sprite. Well, maybe...
					lda EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
					cmp #0
					bne @not_covered ; Bah, you're still around... we can't repurpose you. So close.
					; Okay, you're here, and you're not in use.
					stx currentSprite
					; Now, onto your regularly scheduled programming...
				@not_covered:
				plx
				inx
				cpx #NUM_VAR_SPRITES
				bne @loop_dedupe
			plx


			lda currentSprite
			cmp #255
			bne @not_terrible_day
				; Bah, okay, You've got a sprite, and we don't have space for it anywhere. Keep track and move on.
				inc skippedSprites
				jmp @move_on_plx
			@not_terrible_day: 

			ldx currentSprite
			sty temp7

			iny
			lda (lvlSpriteDataAddr), y ; Y Position of the sprite
			clc
			adc #3 ; Add three because header...
			.repeat 4
				asl
			.endrepeat
			sec
			sbc tempd
			sta EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
			iny
			lda (lvlSpriteDataAddr), y ; sprite id.
			sta EXTENDED_SPRITE_DATA+SPRITE_DATA_ID, x
			iny
			lda #0
			sta tempAddr+1
			lda tempa
			sta tempAddr
			.repeat 4 ; get levelPosition to a full-length position...
				asl tempAddr
				rol tempAddr+1
			.endrepeat
			lda tempAddr
			sta EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x
			lda tempAddr+1
			sta EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x
			
			lda #0
			sta EXTENDED_SPRITE_DATA+SPRITE_DATA_ALIVE, x
			
			lda #SPRITE_DIRECTION_LEFT
			sta EXTENDED_SPRITE_DATA+SPRITE_DATA_DIRECTION, x

			lda temp7
			sta EXTENDED_SPRITE_DATA+SPRITE_DATA_LEVEL_DATA_POSITION, x


			; Get our real type... have to get it off sprite_definitions, which is "fun"
			lda EXTENDED_SPRITE_DATA+SPRITE_DATA_ID, x
			.repeat 3
				asl
			.endrepeat
			tax
			stx temp6 ; index off of sprite_data
			lda sprite_definitions+5, x
			sta temp7
			ldx currentSprite
			sta EXTENDED_SPRITE_DATA+SPRITE_DATA_TILE_ID, x
						
			ldx currentSprite
			lda temp3
			sta EXTENDED_SPRITE_DATA+SPRITE_DATA_LVL_INDEX, x

			ldx temp6
			lda sprite_definitions+1, x
			sta temp7
			ldx currentSprite
			sta EXTENDED_SPRITE_DATA+SPRITE_DATA_WIDTH, x 

			ldx temp6
			lda sprite_definitions+2, x
			sta temp7
			ldx currentSprite
			sta EXTENDED_SPRITE_DATA+SPRITE_DATA_HEIGHT, x 

			ldx temp6
			lda sprite_definitions+3, x
			sta temp7
			ldx currentSprite
			sta EXTENDED_SPRITE_DATA+SPRITE_DATA_SIZE, x

			ldx temp6
			lda sprite_definitions+4, x
			sta temp7
			ldx currentSprite
			sta EXTENDED_SPRITE_DATA+SPRITE_DATA_ANIM_TYPE, x 

			ldx temp6
			lda sprite_definitions+7, x
			sta temp7
			ldx currentSprite
			sta EXTENDED_SPRITE_DATA+SPRITE_DATA_SPEED, x

			ldx temp6
			lda sprite_definitions+6, x ; Get palette
			ror
			ror
			ror
			and #SPRITE_DATA_PALETTE_MASK
			ora sprite_definitions+0, x ; Merge with type, so we can store both.
			sta temp7
			ldx currentSprite
			sta EXTENDED_SPRITE_DATA+SPRITE_DATA_TYPE, x


			cmp #SPRITE_TYPE_COLLECTIBLE
			bne @not_collectible

			; TODO: It's painfully inefficient to do this here... we could stop building this up before we even started
			; Also, I lied, that wasn't the last check. ;)
			jsr remove_existing_gems_and_boxes

						
			@not_collectible:

			lda EXTENDED_SPRITE_DATA+SPRITE_DATA_TYPE, x
			and #SPRITE_DATA_TYPE_MASK
			cmp #SPRITE_TYPE_FIREBALL
			beq @fireball_extra
			cmp #SPRITE_TYPE_SHARK
			beq @shark_extra

			lda tempd
			cmp #0
			beq @normal_extra
				; If tempd is set, that means a linked gem box has been hit. Ignore extra data
				lda #0
				sta EXTENDED_SPRITE_DATA+SPRITE_DATA_EXTRA, x
				jmp @after_extra
			@fireball_extra:
				lda EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
				sta EXTENDED_SPRITE_DATA+SPRITE_DATA_EXTRA, x
				jmp @after_extra
			@shark_extra:
				lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x
				sta temp8
				lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x
				.repeat 4
					lsr temp8
					ror
				.endrepeat
				sta EXTENDED_SPRITE_DATA+SPRITE_DATA_EXTRA, x
				; That stored the original x position... we'll have to undo the math we just did to unpack it into two bytes... 
				; We want it to rotate over a 9 block area, so... let's subtract two now to make that math easier
				.repeat 4
					dec EXTENDED_SPRITE_DATA+SPRITE_DATA_EXTRA, x
				.endrepeat
				; While we're here, let's bump this sprite up a bit, since sharks are short and water is less short
				lda EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
				sec
				sbc #3
				sta EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
				jmp @after_extra
			@normal_extra:
				lda (lvlSpriteDataAddr), y ; Extra data
				sta EXTENDED_SPRITE_DATA+SPRITE_DATA_EXTRA, x
				jmp @after_extra
			@after_extra:



			; Skip @move_on because we increased y ourselves. Do it one more time to finish up.
			iny
			pla
			tax
			inx
			jmp @loop_sprites 
		@move_on_plx:
			pla
			tax
		@move_on:
		.repeat 4
			iny
		.endrepeat
		inx
		jmp @loop_sprites
	@done_sprites:
	ldx temp5 ; put that thing back where it came from, or so help me. (Carryover from nametable row fn)

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

; Will remove any existing gem boxes. tempb is the offset of the sprite (since gems pop up on hit)
remove_existing_gems_and_boxes:
	phxy

	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_LEVEL_DATA_POSITION, x
	jsr get_bit_values_for_collectible
	; Okay, we have the bit address... y is the offset to the addr, a is the bit mask.
	and COLLECTIBLE_DATA, y
	; Even if we take this out entirely, they reset on scroll off/on
	cmp #0
	beq @dont_kill_the_sprite
		plxy

		phy
		jsr remove_sprite
		; Build an address to update our cache
		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_TEMP_Y, x
		sec
		sbc #HEADER_PIXEL_OFFSET
		sta tempf
		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x
		sta tempe
		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x
		.repeat 4
			lsr
			ror tempe
		.endrepeat
		.repeat 4
			lsr tempf
		.endrepeat
		jsr get_tile_at_position
		and #%00111111
		cmp #TILE_QUESTION_BLOCK
		beq @found_it
			; Didn't find it... okay, we might be one tile off on the y axis because the sprite moved. Reload and try again.
			inc tempf
			jsr get_tile_at_position
			and #%00111111
			cmp #TILE_QUESTION_BLOCK
			bne @do_nothing
			; Else fallthrough

		@found_it:

		; Lastly, update next_row_cache. Thankfully we stored the Y pos in tempf, which is all we need for the cache
		ldy tempf
		lda #TILE_QUESTION_BLOCK+1
		jsr draw_to_cache
		@do_nothing:

		ply
		jmp @go_away
	
	@dont_kill_the_sprite:
	plxy
	@go_away:

	rts

; Given a is a tile id, seed the 'nametableAddr' variable
seed_nametable_addr:
	sta temp1
	and #%00001111
	sta temp5
	asl ; x2 because we want nametable addr, not map addr
	clc
	adc #BOTTOM_HUD_TILE
	sta nametableAddr
	
	; TODO: This feels kinda clumsy/inefficient. Is there a smarter way?
	lda temp1
	and #%00010000
	lsr
	lsr
	sta temp1
	lda nametableAddr+1
	and #%11111011
	clc
	adc temp1
	sta nametableAddr+1
	rts
	
draw_current_nametable_row:
	lda levelPosition
	jsr seed_nametable_addr

	
	lda PPU_STATUS
	store nametableAddr+1, PPU_ADDR
	store nametableAddr, PPU_ADDR


	.repeat 24, I ; Use an unrolled loop to do things a bit faster, at a cost of rom space.
		lda NEXT_ROW_CACHE+I
		sta PPU_DATA
	.endrepeat
		

	; nmi methods should be extremely lightweight when possible... so, we know we're on the first row and have no overflow - 
	; we can skip doing a proper 16 bit add.
	lda nametableAddr+1
	sta PPU_ADDR
	inc nametableAddr
	lda nametableAddr
	sta PPU_ADDR
	
	.repeat 24, I ; ditto
		lda NEXT_ROW_CACHE+I+32
		sta PPU_DATA
	.endrepeat

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
		
		.repeat 6, I
			lda PPU_DATA ; dummy read to get the right value, caching, etc...
			lda temp1
			eor #$ff ; flip all bits
			and PPU_DATA ; Grab data and immediately strip out the new bits. 
			sta temp2
			lda NEXT_ROW_ATTRS+I ; combine with values...
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
			
		.endrepeat
		; Write one last time w/o the memory stuffs.
		lda PPU_DATA ; dummy read to get the right value, caching, etc...
		lda temp1
		eor #$ff ; flip all bits
		and PPU_DATA ; Grab data and immediately strip out the new bits. 
		sta temp2
		lda NEXT_ROW_ATTRS+6 ; combine with values...
		and temp1
		ora temp2 ; mischief managed.
		sta temp2

		lda tempAddr+1
		sta PPU_ADDR
		lda tempAddr
		sta PPU_ADDR
		lda temp2
		sta PPU_DATA	
	@done_attrs: 
		
	reset_ppu_scrolling
	
	rts

; Figure out whether a question block has already been hit and used by finding its gem. 
; If it's not available, a will be 0.
; If it is, a will be 1.
; Y will be the index off of sprite_data 
determine_if_question_block_taken:
		ldy #0
		@loop_sprites: 
			lda (lvlSpriteDataAddr), y
			cmp #$ff
			beq @break_loop
			iny
			iny
			iny
			lda (lvlSpriteDataAddr), y
			cmp #SPRITE_DATA_EXTRA_IS_HIDDEN
			bne @definitely_not_it
				; Okay, we know this is marked as hidden. But, is it "our" sprite? Need to calculate position for comparison.
				dey
				dey
				lda (lvlSpriteDataAddr), y
				; Y position of the sprite... asl this 4 times to get part of tile def
				.repeat 4
					asl
				.endrepeat
				sta temp9
				dey
				lda (lvlSpriteDataAddr), y ; X position of our sprite - includes bytes for which "screen" its on, so and em out
				and #%00001111
				ora temp9
				cmp tempCollisionTilePos
					beq @break_sprite_loop_success ; we found it!!
				; eh, not so much.. go back to the state we were in
				iny
				iny
				iny

			@definitely_not_it:
			iny
			cpy #0
			bne @loop_sprites
	@break_loop:
		lda #0
		rts

	@break_sprite_loop_success: 

		; y is now equal to the sprite's LEVEL_DATA_POSITION. Time for... ANOTHER LOOP to find it.
		sty temp9

		ldy #0
		@loop_extra_sprites:
			lda EXTENDED_SPRITE_DATA+SPRITE_DATA_LEVEL_DATA_POSITION, y
			cmp temp9
			beq @break_extended_loop_success
			tya
			clc
			adc #16
			tay
			cpy #0
			bne @loop_extra_sprites
		; If you get here, well, darn. No sprite for you.
		lda #0
		rts

	@break_extended_loop_success:
		lda #1
		rts
	rts

do_special_tile_stuff:
	lda tempCollisionTile
	cmp #TILE_QUESTION_BLOCK
	beq @skip_question_block_slingshot
		jmp @not_question_block
	@skip_question_block_slingshot:
		; only when going up...
		lda lastFramePlayerYVelocity
		cmp #PLAYER_VELOCITY_JUMPING
		beq @were_in_this
			jmp @not_question_block
		@were_in_this:
		; TODO: Test to make sure you're not coming at this from the side somehow. 
		
		; Calculate our expected location
		phy

		jsr determine_if_question_block_taken
		cmp #0
		beq @its_gone
			; We actually found it. Set the extra byte to show it, and also update the tile to show it has been hit.
			lda EXTENDED_SPRITE_DATA+SPRITE_DATA_EXTRA, y
			cmp #SPRITE_DATA_EXTRA_IS_HIDDEN
			bne @its_gone ; Jumping up a bit... basically, your gem was already gotten, so get outta here.
			lda #0
			sta EXTENDED_SPRITE_DATA+SPRITE_DATA_EXTRA, y

			; Bump it up 1 tile so we can actually grab it.
			lda EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, y
			sec
			sbc #16
			sta EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, y

			stx tempc
			sty tempd

			ldx tempd
			jsr get_gem_update_data

			; Store that you hit this gem box in the secondary set of level data.
			ldy temp8
			ora CURRENT_LEVEL_DATA_B, y
			sta CURRENT_LEVEL_DATA_B, y
			ldx tempc
			ldy tempd

			store tempCollisionTilePos,	 arbitraryTileUpdatePos
			store #TILE_QUESTION_BLOCK+1, arbitraryTileUpdateId
			store #0, arbitraryTileNametableOffset
			lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, y
			and #%00000001
			cmp #0
			beq @do_nothing
				store #4, arbitraryTileNametableOffset
			@do_nothing:
			jsr precalculate_arbitrary_tile

			phx
			ldx #FT_SFX_CH0
			lda #SFX_BLOCK_HIT
			jsr sfx_play
			plx

		@its_gone:

		; Okay, we're done.. put it all back
		ply
		; Intentional fallthrough

	@not_question_block:
	lda tempCollisionTile
	cmp #TILE_WATER
	beq @water
	cmp #TILE_WATER_BENEATH
	beq @water
	cmp #TILE_ICE_BLOCK ; Ice = fire. Icey fwoots!
	beq @fire
	rts

	@water:
		lda currentDimension
		cmp #DIMENSION_AGGRESSIVE
		bne @done_water
		; Welp, time to die.
		jmp do_player_death
	@done_water:

	@fire:
		lda currentDimension
		cmp #DIMENSION_AGGRESSIVE
		beq @fired
		cmp #DIMENSION_END_OF_DAYS
		beq @fired
		jmp @done_fire
		@fired:
		; Again, you die here
		jmp do_player_death
	@done_fire:
	rts

reset_collision_state:
	store #0, tempCollisionTile
	rts

precalculate_arbitrary_tile:
	; Get the real id for it...
	lda arbitraryTileUpdateId
	asl
	sta arbitraryTileUpdateId

	lda #0
	sta arbitraryTileAddr+1

	lda arbitraryTileUpdatePos
	and #%11110000
	asl
	rol arbitraryTileAddr+1
	asl
	rol arbitraryTileAddr+1
	clc
	adc #BOTTOM_HUD_TILE
	sta arbitraryTileAddr
	lda arbitraryTileAddr+1
	adc #0
	sta arbitraryTileAddr+1 ; Deal with carry
	
	lda arbitraryTileUpdatePos
	and #%00001111
	asl
	ora arbitraryTileAddr
	sta arbitraryTileAddr
	
	lda arbitraryTileAddr+1
	clc
	adc #$20 ; We want an offset on $20 for our nametable. (Or 24... but we'll get there; give it a moment)
	adc arbitraryTileNametableOffset
	sta arbitraryTileAddr+1


	rts

; Expectations: 
; - a is set to the tile value to test
; - End result is a is set to 1 if collision, 2 if not.
; - Any side-effects are applied by this process. (Damage, block breakage, etc)
do_collision_test:
	sta tempCollision

	cmp #TILE_LEVEL_END
	beq @no_collision
	cmp #TILE_LEVEL_END+1
	beq @no_collision
	cmp #TILE_QUESTION_BLOCK
	beq @special_tile_collision

	cmp #0
	beq @no_collision

	cmp #FIRST_NO_COLLIDE_TILE
	bcc @not_nocollide
	cmp #LAST_NO_COLLIDE_TILE
	bcs @not_nocollide
		jmp @no_collision
	@not_nocollide:

	cmp #FIRST_VARIABLE_TILE
	bcc @collision
	cmp #FIRST_VARIABLE_TILE + 8
	bcs @collision

	lda currentDimension
	cmp #DIMENSION_BARREN
	beq @barren
	cmp #DIMENSION_AGGRESSIVE
	beq @fire
	cmp #DIMENSION_AUTUMN
	beq @fire
	cmp #DIMENSION_ICE_AGE
	beq @ice_age
	cmp #DIMENSION_END_OF_DAYS
	beq @end_of_days
	; By default, fallthrough to @default. Hits barren and normal. (And I guess end of days)


	@default: 
		lda tempCollision
		cmp #TILE_WATER
		beq @no_collision
		cmp #TILE_ICE_BLOCK
		beq @no_collision
		cmp #TILE_FLOWER
		beq @no_collision
		jmp @collision

	@special_tile_collision:
		store tempCollision, tempCollisionTile
		sty tempCollisionTilePos

			lda #1
		rts

	@special_tile_no_collision:
		sty tempCollisionTilePos

			store tempCollision, tempCollisionTile
		lda #0
		rts


 	@fire:
		; We're in the fire dimension. Special rules apply.
		lda tempCollision

		cmp #TILE_WATER
		beq @special_tile_collision
		cmp #TILE_WATER_BENEATH
		beq @special_tile_collision
		cmp #TILE_ICE_BLOCK
		beq @special_tile_collision
		cmp #TILE_PLANT
		beq @no_collision
		cmp #TILE_ICE_BLOCK
		beq @no_collision
		cmp #TILE_FLOWER
		beq @no_collision
		cmp #TILE_CLOUD
		beq @no_collision
		jmp @collision

	; Yes, it's kind of weird to throw this in here. That said, we drop a few instructions by doing it, since everything
	; Both below and above can access it. (And the rest of the code looks cleaner.) In short, deal with it.
	@collision:
		lda #1
		rts

	@no_collision:
		lda #0
		rts


	@ice_age:
		; Pretty much everything is a collision! Ice is a PITA...
		lda tempCollision
		cmp #TILE_FLOWER
		beq @no_collision
		cmp #TILE_WATER
		beq @collision_ice
		cmp #TILE_ICE_BLOCK
		beq @collision_ice
		cmp #TILE_PLANT
		beq @collision_ice
		jmp @collision

	@barren:
		lda tempCollision
		cmp #TILE_CLOUD
		beq @no_collision
		jmp @default ;

	@collision_ice:
		lda #1
		sta isOnIce
		rts

	@end_of_days:
		lda tempCollision
		cmp #TILE_CLOUD
		beq @no_collision
		cmp #TILE_WATER_BENEATH
		beq @special_tile_collision

		jmp @default ;




; WARNING: This method has a number of expectations and is kinda specialized to one use case. 
; [temp2,temp1] should be the position you want to test on the map. (Full)
; temp4 and temp5 will be consumed.
test_vertical_collision:
	.repeat 4
		lsr temp1
		ror temp2
	.endrepeat
	lda temp2
	sta tempe
	; temp2 is now the x position of the block in test.
	lda #%00001111 ; We only want the position % 16, so we can find our spot.
	and temp2
	sta temp2

	lda playerYVelocity
	cmp #PLAYER_VELOCITY_JUMPING
	beq @going_up 

		lda PLAYER_BOTTOM_SPRITE
		clc
		adc #7 ; sprite width
		clc
		adc playerYVelocity
		sec
		sbc #HEADER_PIXEL_OFFSET ; remove header
		sta tempf

		and #%11110000 ; Align with 16
		cmp #%11000000 
		sta temp1
		bcs @no_collision ; If the y is greater than 12, you're below the screen. Go away.

		; a is now the y coord of the block. temp2 is now the x. 
		; a is already multipied by 16, so we just need to combine it with temp2.
		; Carry must be clear or we'd hit no collision, so skip clc
		adc temp2
		sta temp2 ; Temp2 is now our index off of the current screen - used for question block lookups
		tay

		.repeat 4
			lsr tempf
		.endrepeat
		jsr get_tile_at_position
		and #%00111111
		jsr do_collision_test
		cmp #0
		beq @no_collision
			store #0, playerYVelocityNext
			jmp @no_collision

	@going_up:

		lda PLAYER_SPRITE
		sec
		sbc #HEADER_PIXEL_OFFSET ; remove header
		clc
		adc playerYVelocity
		sta tempf
		and #%11110000 ; Align with 16
		sta temp1

		; a is now the y coord of the block. temp2 is now the x.
		; combine away.
		clc
		adc temp2 ; Temp2 is now our index off of the current screen - used for question block lookups
		sta temp2
		tay

		.repeat 4
			lsr tempf
		.endrepeat
		jsr get_tile_at_position
		and #%00111111
		jsr do_collision_test
		cmp #0
		beq @no_collision
			store #0, playerYVelocityNext
			; jmp @no_collision ; Intentional fallthrough 

	@no_collision:


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
	sta tempe
	lda #%00001111 ; We only want the position % 16 to find our x.
	and temp2
	sta temp2

	; temp1 is the position within the level being tested.

	lda temp3
	cmp #1
	beq @collide_up
		; collision bottom
		lda PLAYER_BOTTOM_SPRITE
		clc
		adc #7 ; bottom of sprite
		sec
		sbc #HEADER_PIXEL_OFFSET ; remove header
		sta tempf
		and #%11110000 ; Align with 16

		clc
		adc temp2
		sta temp2 ; Temp2 is now our index off of the current screen - used for question block lookups

		tay

		.repeat 4
			lsr tempf
		.endrepeat
		jsr get_tile_at_position

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
		clc
		adc #2 ; Little bit of buffer so that the player can fit under sprites, despite being 16 px tall.
		sta tempf

		and #%11110000 ; align with 16

		clc
		adc temp2
		sta temp2 ; Temp2 is now our index off of the current screen - used for question block lookups
		
		tay
		.repeat 4
			lsr tempf
		.endrepeat
		jsr get_tile_at_position
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
	store #0, xScrollChange

	lda playerYVelocity
	sta lastFramePlayerYVelocity
	sta playerYVelocityNext
	cmp #0
	bne @non_zero
		store #PLAYER_VELOCITY_FALLING, playerYVelocity
		sta playerYVelocityNext
	@non_zero:

	; Test 3 positions... left, middle, right. Middle because we're fatter than a single tile, and you could otherwise land right between two tiles.
	; Player's position is now in playerPosition[2]. And in temp1/temp2.

	; left
	jsr test_vertical_collision

	; middle
	lda playerPosition
	clc
	adc #PLAYER_WIDTH/2
	sta temp2
	lda playerPosition+1
	adc #0
	sta temp1

	; We shifted you.. now repeat. 
	jsr test_vertical_collision

	lda tempCollisionTile
	pha
	lda tempCollisionTilePos
	pha

	; right
	lda playerPosition
	clc
	adc #PLAYER_WIDTH
	sta temp2
	lda playerPosition+1
	adc #0
	sta temp1

	; We shifted you.. now repeat. 
	jsr test_vertical_collision

	; If the middle hit counted, use it instead of anything we just found.
	pla 
	cmp #0
	beq @do_nothing
		; You had a value before... bring it back
		sta tempCollisionTilePos
		pla
		sta tempCollisionTile
		jmp @after_doing_nothing
	@do_nothing: 
	pla
	@after_doing_nothing:

	
	lda playerYVelocityNext
	sta playerYVelocity
	cmp #0
	bne @carry_on
		rts
	@carry_on:
		lda PLAYER_SPRITE
		clc
		adc playerYVelocity
		cmp #$fd
		bcs @dont_do_it_at_all
		cmp #SPRITE_OFFSCREEN
		bcc @not_uhoh
			jsr do_player_death
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
		@dont_do_it_at_all:
		
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

		lda PLAYER_SPRITE+3
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

		lda PLAYER_SPRITE+3
		sta tempPlayerScreenPosition
		clc
		adc playerVelocity
		cmp #MIN_POSITION_RIGHT_SCROLL
		bcs @after_move
		beq @after_move ; Don't store if it we're not scrolling. 
		sta tempPlayerScreenPosition
	@after_move:

	lda #0
	sta temp3
	lda playerDirection
	cmp #PLAYER_DIRECTION_LEFT
	beq @collision_left
		; right
		jsr seed_level_position_r
		jmp @after_seed
	@collision_left:
		jsr seed_level_position_l
	@after_seed:
		lda tempPlayerPosition 
		clc
		adc temp4
		sta temp2
		sta tempb
		lda tempPlayerPosition+1
		adc #0
		sta temp1
		sta tempa
		jsr test_horizontal_collision

		; See if we're at the flag point.
		.repeat 4
			lsr tempa
			ror tempb
		.endrepeat
		lda tempb
		cmp currentLevelFlagX
		bcc @not_end_level
			; Technically, we're going all abandon ship on our stack here.
			; Trying to accomodate for that by setting the stack pointer back down to $ff, where it starts.
			jsr do_end_of_level_anim
			ldx #$ff
			txs
			jsr do_next_level
			jmp show_ready
		@not_end_level:

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
		adc #PLAYER_SPRITE_ID
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
	
	jsr do_player_anim
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
		lda #0
		sec
		sbc playerVelocity
		sta xScrollChange

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
		lda #0
		sec
		sbc playerVelocity
		sta xScrollChange

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

do_player_anim:
	lda playerVelocity
	cmp #PLAYER_VELOCITY_FAST
	beq @fast
	cmp #256-PLAYER_VELOCITY_FAST
	beq @fast

		lda frameCounter
		and #%000001000
		lsr 
		lsr
		lsr
		jmp @do_anim
	@fast: 
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

	adc #PLAYER_SPRITE_ID
	adc playerVisibleDirection
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

	rts

blow_away_current_sprite: 
	lda #0
	.repeat 16, I
		sta EXTENDED_SPRITE_DATA+I, x
	.endrepeat
	rts

do_sprite_movement:
	lda levelPosition
	pha
	jsr seed_level_position_l_current
	lda levelPosition
	sta tempAddr
	lda #0
	sta tempAddr+1
	.repeat 4
		asl tempAddr
		rol tempAddr+1
	.endrepeat

	lda scrollX
	and #%00001111
	sta temp2

	ldx #0
	; little hack to deal with the extreme length of this method. Nothing to see here, just start the loop...
	jmp @loop

	@go_away_forever:
		jsr blow_away_current_sprite
		jmp @remove


	@loop:
		stx tempa
		txa
		pha
		.repeat 4
			asl
		.endrepeat
		tax

			
			; Start of left/right logic
			lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x
			sta temp8
			lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x
			sta temp7
			.repeat 4
				lsr temp7
				ror temp8
			.endrepeat
			
			; Get levelPosition to be a 16-bit offset like the sprite offset is. This way, the top half is a screen id, and the bottom half is position within the screen.
			; (Well, sorta... this lets us easily know if a sprite is more than 1 screen away)
			lda #0
			sta tempc
			lda levelPosition
			sta tempd
			.repeat 4
				asl tempd
				rol tempc
			.endrepeat
			sec
			lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x
			sbc tempd
			sta tempe
			lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x
			sbc tempc
			sta tempf

			; Our scrolling logic makes this stuff behave pretty weird on the first panel of the map.
			; So... heck with it, rather than do complex calculations to remove things on this screen, just... don't. 
			; Once we get past the first screen everything will naturally fall off.
			lda levelPosition
			cmp #16
			bcc @okay
			cmp #255
			beq @okay

			; tempe is the low byte, tempf is the high... so, if the high byte is non-zero, you're useless to us. Go the heck away.
			lda tempf
			cmp #0
			beq @okay 
			cmp #1
			beq @okay ; TODO: This and the one below it really depend on your direction. Should we consider direction
			cmp #255
			beq @okay
			jmp @go_away_forever
			@okay:



			; After we've done removal, if you're something that doesn't move, go away.
			lda EXTENDED_SPRITE_DATA+SPRITE_DATA_TYPE, x
			and #SPRITE_DATA_TYPE_MASK
			cmp #SPRITE_TYPE_COLLECTIBLE
			beq @go_no_motion
			cmp #SPRITE_TYPE_DIMENSIONER
			beq @go_no_motion
			cmp #SPRITE_TYPE_TELEPORT
			beq @go_no_motion
			cmp #SPRITE_TYPE_FIREBALL
			bne @no_fireball
				jsr do_fireball_movement
				jmp @no_motion
			@no_fireball:
			cmp #SPRITE_TYPE_SHARK
			bne @no_shark
				jsr do_shark_movement
				jmp @no_motion
			@no_shark:

			; Don't bother calculating gravity if the sprite isn't visible.
			lda EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
			cmp #0
			beq @go_no_motion

			; TODO: This is kind of a mess... 
			jmp @skip_inline_method
			@go_no_motion: 
				jmp @no_motion
			@skip_inline_method:


			
			jsr get_current_sprite_y
			clc
			adc EXTENDED_SPRITE_DATA+SPRITE_DATA_HEIGHT, x
			bcs @go_remove
			sec
			sbc #HEADER_PIXEL_OFFSET
			clc
			adc #PLAYER_VELOCITY_FALLING
			sta tempf
			and #%11110000
			cmp #0
			bne @not_dead
				@go_remove:
				; The sprite has died. Uh oh.
				jmp @remove
			@not_dead:

			.repeat 4
				lsr tempf
			.endrepeat

			lda temp8 ; Kind of weird... stems from poor variable usage. TODO: Make this less silly
			sta tempe
			jsr get_tile_at_position
			and #%00111111
			jsr do_collision_test
			cmp #0
			bne @hit
			
			; Recalculate for sprite+width
			lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x
			clc
			adc EXTENDED_SPRITE_DATA+SPRITE_DATA_WIDTH, x
			sta tempe
			lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x
			adc #0
			sta temp7
			.repeat 4
				lsr temp7
				ror tempe
			.endrepeat
			jsr get_tile_at_position
			and #%00111111
			jsr do_collision_test
			cmp #0
			bne @hit
				; Okay, we tested both sides... you didn't hit. GOING DOWN.
				lda EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
				clc
				adc #PLAYER_VELOCITY_FALLING
				sta EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
				jmp @skip_horizontal_movement ; If this sprite was affected by gravity, don't move left/right at all.
			@hit:

			; Before we do left/right, make sure we aren't dead. Dead things shant move.
			lda EXTENDED_SPRITE_DATA+SPRITE_DATA_ANIM_TYPE, x
			cmp #SPRITE_ANIMATION_DYING
			bne @not_dying_yet
				jmp @skip_horizontal_movement
			@not_dying_yet:

			; Do sprite left/right calculations every other frame to slow them down a little and give us more control over speed.
			lda frameCounter
			and #%00000010
			cmp #0
			beq @keep_going_horizontally
				jmp @skip_horizontal_movement
			@keep_going_horizontally:

			; Okay, time to start that whole mess again for whatever direction you're facing...
			lda EXTENDED_SPRITE_DATA+SPRITE_DATA_DIRECTION, x
			and #SPRITE_DATA_DIRECTION_MASK
			cmp #SPRITE_DIRECTION_RIGHT
			bne @not_right
				jmp @right
			@not_right: 
				; We're goin left!
				; Start of left/right logic
				lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x
				sec
				sbc #SPRITE_VELOCITY_NORMAL
				sta tempe
				lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x
				sbc #0
				sta temp7
				.repeat 4
					lsr temp7
					ror tempe
				.endrepeat

				
				jsr get_current_sprite_y
				sec
				sbc #HEADER_PIXEL_OFFSET
				sec
				sbc #SPRITE_HEIGHT_OFFSET ; Shift the position on the sprite up a little bit, since we let them sink into the ground for appearance purposes.
				sta tempf
				
				.repeat 4
					lsr tempf
				.endrepeat

				jsr get_tile_at_position

				and #%00111111
				jsr do_collision_test
				cmp #0
				bne @hit_l
				
				; Recalculate for sprite bottom
				jsr get_current_sprite_y
				sec
				sbc #HEADER_PIXEL_OFFSET+2 ; Little extra buffer to make sure we stay on the same tile. Don't want us stuck in the ground!
				clc
				adc EXTENDED_SPRITE_DATA+SPRITE_DATA_HEIGHT, x
				sta tempf

				.repeat 4
					lsr tempf
				.endrepeat

				jsr get_tile_at_position

				and #%00111111
				jsr do_collision_test
				cmp #0
				bne @hit_l
					; Okay, we tested both sides... you didn't hit. MOVE OUT!
					lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x
					sec
					sbc EXTENDED_SPRITE_DATA+SPRITE_DATA_SPEED, x
					sta EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x
					lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x
					sbc #0
					sta EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x
					jmp @skip_horizontal_movement ; If this sprite was affected by gravity, don't move left/right at all.
				@hit_l:
					lda EXTENDED_SPRITE_DATA+SPRITE_DATA_DIRECTION, x
					and #(SPRITE_DATA_DIRECTION_MASK ^ %11111111)
					ora #SPRITE_DIRECTION_RIGHT
					sta EXTENDED_SPRITE_DATA+SPRITE_DATA_DIRECTION, x

				jmp @skip_horizontal_movement
			@right:
				; We're goin right!
				; Start of left/right logic
				lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x
				clc
				adc EXTENDED_SPRITE_DATA+SPRITE_DATA_WIDTH, x
				sta tempe
				lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x
				adc #0
				sta temp7
				lda tempe
				clc
				adc #SPRITE_VELOCITY_NORMAL
				sta tempe
				lda temp7
				adc #0
				sta temp7

				.repeat 4
					lsr temp7
					ror tempe
				.endrepeat

				
				jsr get_current_sprite_y
				sec
				sbc #HEADER_PIXEL_OFFSET
				sbc #SPRITE_HEIGHT_OFFSET ; Shift the position on the sprite up a little bit, since we let them sink into the ground for appearance purposes.
				sta tempf

				.repeat 4
					lsr tempf
				.endrepeat

				jsr get_tile_at_position

				and #%00111111
				jsr do_collision_test
				cmp #0
				bne @hit_r
				
				; Recalculate for sprite bottom
				jsr get_current_sprite_y
				sec
				sbc #HEADER_PIXEL_OFFSET+2 ; Little extra buffer to make sure we stay on the same tile. Don't want us stuck in the ground!
				clc
				adc EXTENDED_SPRITE_DATA+SPRITE_DATA_HEIGHT, x
				sta tempf

				.repeat 4
					lsr tempf
				.endrepeat

				jsr get_tile_at_position

				and #%00111111
				jsr do_collision_test
				cmp #0
				bne @hit_r
					; Okay, we tested both sides... you didn't hit. MOVE OUT!
					lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x
					clc
					adc EXTENDED_SPRITE_DATA+SPRITE_DATA_SPEED, x
					sta EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x
					lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x
					adc #0
					sta EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x
					jmp @skip_horizontal_movement ; If this sprite was affected by gravity, don't move left/right at all.
				@hit_r:
					lda EXTENDED_SPRITE_DATA+SPRITE_DATA_DIRECTION, x
					and #(SPRITE_DATA_DIRECTION_MASK ^ %11111111)
					ora #SPRITE_DIRECTION_LEFT
					sta EXTENDED_SPRITE_DATA+SPRITE_DATA_DIRECTION, x

				jmp @skip_horizontal_movement

			@skip_horizontal_movement:
		@no_motion:


		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x
		sec
		sbc tempAddr
		sta temp9
		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x
		sbc #0
		sta tempa
		
		lda temp9
		sta temp1

		lda tempa
		sbc tempAddr+1
		; This is a partial workaround for a really obscure problem where when the player turns left in the first 1/4 of the first screen on a level, our sprites disappear. For some reason,
		; the sprites are off by a factor of $10 in this one case. (And they don't appear to be set to SPRITE_OFFsCREEN. It likely relates to something strange with levelPosition
		; when set by seed_level_position_l[_current] is run at this point, but I can't pinpoint the issue, and nothing else seems affected.
		; TODO: Investigate this and find a real fix to the problem.
		cmp #$ef
		beq @edge_case
		
		cmp #0
		beq @dont_remove
			jmp @remove
		@dont_remove:
		jmp @past_edge_case
		@edge_case:
			lda temp1
			sec
			sbc #16
			sta temp1
		@past_edge_case:


			lda EXTENDED_SPRITE_DATA+SPRITE_DATA_TYPE, x
			cmp #SPRITE_TYPE_DIMENSIONER
			beq @goto_after_anim

			lda EXTENDED_SPRITE_DATA+SPRITE_DATA_ANIM_TYPE, x
			cmp #SPRITE_ANIMATION_NONE
			bne @not_no_anim
				@goto_after_anim:
				lda #0
				sta temp6
				sta temp7
				jmp @after_anim
			@not_no_anim:
			cmp #SPRITE_ANIMATION_DYING
			bne @not_dying
				inc EXTENDED_SPRITE_DATA+SPRITE_DATA_ALIVE, x
				lda EXTENDED_SPRITE_DATA+SPRITE_DATA_ALIVE, x
				cmp #MAX_SPRITE_REMOVAL_TIME
				bne @not_dead_yet
					jsr remove_sprite
					jmp @remove
				@not_dead_yet:
				lda #0
				sta temp6
				sta temp7
				jmp @after_anim
			@not_dying:
			cmp #SPRITE_ANIMATION_NORMAL
			bne @not_normal
				lda frameCounter
				and #%00001000
				lsr
				lsr
				lsr
				sta temp6
				lda EXTENDED_SPRITE_DATA+SPRITE_DATA_DIRECTION, x
				and #SPRITE_DATA_DIRECTION_MASK
				; 0010,0000
				.repeat 5
					lsr ; make it a multiple of 8
				.endrepeat
				sta temp7
				jmp @after_anim
			@not_normal:
			cmp #SPRITE_ANIMATION_FAST
			bne @not_fast
				lda frameCounter
				and #%00000100
				lsr
				lsr
				sta temp6
				lda EXTENDED_SPRITE_DATA+SPRITE_DATA_DIRECTION, x
				and #SPRITE_DATA_DIRECTION_MASK
				; 0010,0000
				.repeat 5
					lsr ; make it a multiple of 8
				.endrepeat
				sta temp7
				jmp @after_anim
			@not_fast:

			cmp #SPRITE_ANIMATION_BINARY
			bne @not_binary
				lda frameCounter
				and #%00001000
				lsr
				lsr
				lsr
				sta temp6
				lda #0
				sta temp7
			@not_binary:
			cmp #SPRITE_ANIMATION_LR
			bne @not_lr
				lda #0
				sta temp6
				lda EXTENDED_SPRITE_DATA+SPRITE_DATA_DIRECTION, x
				and #SPRITE_DATA_DIRECTION_MASK
				.repeat 5
					lsr
				.endrepeat
				sta temp7
			@not_lr:
			@after_anim:

			lda EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
			cmp #0 ; Last chance, GET OUT
			beq @remove

			lda EXTENDED_SPRITE_DATA+SPRITE_DATA_SIZE, x
			cmp #SPRITE_SIZE_DEFAULT
			bne @not_default
				jsr draw_default_sprite_size
				jmp @continue
			@not_default:
			cmp #SPRITE_SIZE_2X1
			bne @not_2x1
				jsr draw_2x1_sprite_size
				jmp @continue
			@not_2x1:
			cmp #SPRITE_SIZE_3X1
			bne @not_3x1
				jsr draw_3x1_sprite_size
				jmp @continue
			@not_3x1:
			cmp #SPRITE_SIZE_TELEPORTER
			bne @not_tele
				jsr draw_teleporter_sprite_size
				jmp @continue
			@not_tele:
			cmp #SPRITE_SIZE_TINY
			bne @not_tiny
				jsr draw_tiny_sprite_size
				jmp @continue
			@not_tiny:
			cmp #SPRITE_SIZE_TINY_NORMAL_ALIGNMENT
			bne @not_tiny_ish
				jsr draw_tiny_aligned_sprite_size
				jmp @continue
			@not_tiny_ish:
				jsr draw_default_sprite_size
				jmp @continue

		@remove: 
			phx
			jsr get_var_sprite_data_offset
			lda #SPRITE_OFFSCREEN
			.repeat 4, I
				sta VAR_SPRITE_DATA+(I*4), x
			.endrepeat
			plx
			; fallthru to continue
		@continue:
		jsr remove_offscreened_sprites
		pla
		tax
		inx
		cpx #NUM_VAR_SPRITES
		beq @done
		jmp @loop

	@done:
	pla
	sta levelPosition
	rts

; Fireballs are a real far-cry from everything else, so let's give them their own separate method for movement.
do_fireball_movement:
	lda currentDimension
	cmp #DIMENSION_AGGRESSIVE
	beq @okay_doit
	cmp #DIMENSION_END_OF_DAYS
	beq @okay_doit
		@make_sprite_goner:
		; Oh? Well, ummm... this is awkward. I'll just go away then
		lda #0
		sta EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
		rts
	@okay_doit:

	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_DIRECTION, x
	and #(SPRITE_DATA_DIRECTION_MASK ^ $ff)
	ora #SPRITE_DIRECTION_RIGHT
	sta EXTENDED_SPRITE_DATA+SPRITE_DATA_DIRECTION, x

	lda frameCounter
	sec
	sbc EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x
	and #%01000000
	bne @make_sprite_goner ; Only show this thing every other cycle

	lda frameCounter
	sec
	sbc EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x ; Add an element of "randomness" to when they jump.
	and #%00111111
	sta tempe
	clc
	adc tempe
	lsr tempe
	adc tempe
	sta tempe
	cmp #128
	bcs @make_sprite_goner ; The speed we use causes us to go a bit over 128; use for extra pause time.
	cmp #64
	bcc @no_flip
		sta tempe
		lda #128
		sec
		sbc tempe
		sta tempe
		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_DIRECTION, x
		and #(SPRITE_DATA_DIRECTION_MASK ^ $ff)
		ora #SPRITE_DIRECTION_LEFT
		sta EXTENDED_SPRITE_DATA+SPRITE_DATA_DIRECTION, x

	@no_flip:
	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_EXTRA, x
	sec
	sbc tempe
	sta EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
	rts

do_shark_movement:
	lda currentDimension
	cmp #DIMENSION_BARREN
	beq @okay_doit
	cmp #DIMENSION_END_OF_DAYS
	beq @okay_doit
		@make_sprite_goner:
		; Oh? Well, ummm... this is awkward. I'll just go away then
		lda #255
		sta EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x
		rts
	@okay_doit:

	lda #0
	sta EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x
	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_EXTRA, x
	.repeat 4
		asl
		rol EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x
	.endrepeat
	sta EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x

	lda frameCounter
	and #%10000000
	cmp #0
	beq @subtract
		lda frameCounter
		and #%01111111
		clc
		adc EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x
		sta EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x

		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x
		adc #0
		sta EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x

		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_DIRECTION, x
		and #SPRITE_DATA_DIRECTION_MASK^$ff
		ora #SPRITE_DIRECTION_RIGHT
		sta EXTENDED_SPRITE_DATA+SPRITE_DATA_DIRECTION, x

		rts
	@subtract:
		lda frameCounter
		and #%01111111
		sta tempe
		lda #128
		sec
		sbc tempe
		sta tempe

		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x
		clc
		adc tempe
		sta EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x

		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x
		adc #0
		sta EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x

		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_DIRECTION, x
		and #SPRITE_DATA_DIRECTION_MASK^$ff
		ora #SPRITE_DIRECTION_LEFT
		sta EXTENDED_SPRITE_DATA+SPRITE_DATA_DIRECTION, x


		rts


; Little bit of context... sprites are hard, and our logic is... pretty complicated. 
; In an ideal world this wouldn't exist, and when we put individual sprites into VAR_SPRITE_DATA, we'd check if they are offscreen,
; then if this part of the metasprite is off-screen don't copy it.
; Reality is, this logic would take a very long time to untangle, and likely break a few things on the way. With a deadline approaching, doing
; that work doesn't make much sense. SO...
;
; This method takes the top-left sprite in your metasprite (4 tiles) and makes sure all other pieces are within 64px of it. If not, it is assumed to be on the wrong 
; screen and removed. 
remove_offscreened_sprites:
	lda VAR_SPRITE_DATA, x
	cmp #SPRITE_OFFSCREEN
	bne @no_escape
		rts
	@no_escape:
	lda VAR_SPRITE_DATA+12, x
	cmp #SPRITE_OFFSCREEN
	beq @no_4th
		lda VAR_SPRITE_DATA+15, x
		sec
		sbc VAR_SPRITE_DATA+3,x 
		cmp #64
		bcc @no_action_4
			lda #SPRITE_OFFSCREEN
			sta VAR_SPRITE_DATA+12, x
		@no_action_4:
	@no_4th:

	lda VAR_SPRITE_DATA+8, x
	cmp #SPRITE_OFFSCREEN
	beq @no_3rd
		lda VAR_SPRITE_DATA+11, x
		sec
		sbc VAR_SPRITE_DATA+3,x 
		cmp #64
		bcc @no_action_3
			lda #SPRITE_OFFSCREEN
			sta VAR_SPRITE_DATA+8, x
		@no_action_3:
	@no_3rd:

	lda VAR_SPRITE_DATA+4, x
	cmp #SPRITE_OFFSCREEN
	beq @no_2nd
		lda VAR_SPRITE_DATA+7, x
		sec
		sbc VAR_SPRITE_DATA+3,x 
		cmp #64
		bcc @no_action_2
			lda #SPRITE_OFFSCREEN
			sta VAR_SPRITE_DATA+4, x
		@no_action_2:
	@no_2nd:
	rts

test_sprite_collision:
	lda #0
	sta hasStompedSprite
	lda PLAYER_SPRITE
	clc
	adc #PLAYER_HEIGHT
	sta temp1 ; player y2

	lda playerPosition
	clc
	adc #PLAYER_WIDTH
	sta temp2 ; player x2
	lda playerPosition+1
	adc #0
	sta tempe

	ldx #0
	@loop:

		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_ANIM_TYPE, x
		cmp #SPRITE_ANIMATION_DYING
		beq @continue ; No collisions for the dying...

		; Logic derived from some code posted by Celius, here: http://forums.nesdev.com/viewtopic.php?t=3743
		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x
		cmp tempe
		bcc @safe_1
		bne @continue

		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x ; enemyLeftEdge
		cmp temp2 ; playerRightEdge
		bcs @continue

		@safe_1:

		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x
		clc
		adc EXTENDED_SPRITE_DATA+SPRITE_DATA_WIDTH, x ; enemyRightEdge
		sta tempf

		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X+1, x
		adc #0
		cmp playerPosition+1
		bcc @continue
		bne @safe_2
		lda tempf
		cmp playerPosition ; playerLeftEdge
		bcc @continue

		@safe_2:

		jsr get_current_sprite_y ; enemyTopEdge
		cmp temp1 ; playerBottomEdge
		bcs @continue

		jsr get_current_sprite_y
		clc
		adc EXTENDED_SPRITE_DATA+SPRITE_DATA_HEIGHT, x ; enemyBottomEdge
		cmp PLAYER_SPRITE ; playerTopEdge
		bcc @continue

		; Is this sprite dead? Don't do things with dead sprites. It's just wrong.
		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
		cmp #0
		beq @continue

		jsr do_sprite_collision

		@continue:
		txa
		clc
		adc #16
		; Something, somewhere, somehow is adding 1 to x. I'm not sure where it is; may be carry, but this will fix it for now.
		; TODO: Figure out why this was needed; ideally remove it.
		and #%11110000
		tax
		cpx #(NUM_VAR_SPRITES*16)
		bne @loop

	; Did you stomp anything? If so, we should do a little updating...
	lda hasStompedSprite
	cmp #1
	bne @no_stompy

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

		lda #HOP_LOCK_TIME
		sta playerYVelocityLockTime

	@no_stompy:
	rts

; x must be a sprite id, temp6 is animation, temp7 is direction
draw_2x1_sprite_size: 
	phy
	jsr get_var_sprite_data_offset_y
	
	lda temp1
	sec
	sbc temp2
	cmp #SPRITE_X_CUTOFF
	bcc @dont_kill_the_sprite
		lda #SPRITE_OFFSCREEN
		sta VAR_SPRITE_DATA, y
		sta VAR_SPRITE_DATA+4, y
		sta VAR_SPRITE_DATA+8, y
		sta VAR_SPRITE_DATA+12, y
		ply
		rts
	@dont_kill_the_sprite:
	sta VAR_SPRITE_DATA+3, y
	clc
	adc #8
	sta VAR_SPRITE_DATA+7, y

	lda #0
	sta tempf
	
	lda temp6
	.repeat 4
		asl
	.endrepeat
	sta temp6
	lda temp7
	asl
	clc
	adc temp6
	sta temp6
	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
	clc
	adc #8 ; You're half height; get on the floor; everybody do the dinosaur
	sta VAR_SPRITE_DATA, y
	sta VAR_SPRITE_DATA+4, y

	lda #SPRITE_OFFSCREEN
	sta VAR_SPRITE_DATA+8, y
	sta VAR_SPRITE_DATA+12, y
	
	; Put sharks behind the background.
	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_TYPE, x
	and #SPRITE_DATA_TYPE_MASK
	cmp #SPRITE_TYPE_SHARK
	bne @not_shark
		lda #%00100000
		sta tempf
	@not_shark:

	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_PALETTE, x
	and #SPRITE_DATA_PALETTE_MASK
	rol
	rol
	rol
	and #%00000011
	ora tempf
	sta VAR_SPRITE_DATA+2, y
	sta VAR_SPRITE_DATA+6, y
	sta VAR_SPRITE_DATA+10, y
	sta VAR_SPRITE_DATA+14, y

	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_TILE_ID, x
	clc
	adc temp6
	sta VAR_SPRITE_DATA+1, y
	clc
	adc #1
	sta VAR_SPRITE_DATA+5, y

	ply
	rts
	
; x must be a sprite id, temp6 is animation, temp7 is direction
draw_tiny_sprite_size: 
	phy
	jsr get_var_sprite_data_offset_y

	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_EXTRA, x
	cmp #SPRITE_DATA_EXTRA_IS_HIDDEN
	bne @not_hidden
		; Oh, you're hidden? Okay we can deal with you.
		lda #SPRITE_OFFSCREEN
		sta VAR_SPRITE_DATA, y
		sta VAR_SPRITE_DATA+4, y
		sta VAR_SPRITE_DATA+8, y
		sta VAR_SPRITE_DATA+12, y
		ply
		rts
	@not_hidden:
	
	; Without a doubt, this is imperfect. It hides sprites that would wrap and show on the right of the screen instead of disappearing.
	; TODO: Figure out what's wrong with the math here, and make sprites appear at the same time terrain does.
	lda temp1
	sec
	sbc temp2
	clc
	adc #4 ; Half width too? Get over there.
	cmp #SPRITE_X_CUTOFF
	bcc @dont_kill_the_sprite
		lda #SPRITE_OFFSCREEN
		sta VAR_SPRITE_DATA, y
		sta VAR_SPRITE_DATA+4, y
		sta VAR_SPRITE_DATA+8, y
		sta VAR_SPRITE_DATA+12, y
		ply
		rts
	@dont_kill_the_sprite:
	sta VAR_SPRITE_DATA+3, y


	lda temp6
	.repeat 4
		asl
	.endrepeat
	sta temp6
	lda temp7
	asl
	clc
	adc temp6
	sta temp6
	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
	clc
	adc #4 ; You're half height; get on the floor; everybody do the dinosaur
	sta VAR_SPRITE_DATA, y

	lda #SPRITE_OFFSCREEN
	sta VAR_SPRITE_DATA+4, y
	sta VAR_SPRITE_DATA+8, y
	sta VAR_SPRITE_DATA+12, y	

	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_PALETTE, x
	and #SPRITE_DATA_PALETTE_MASK
	rol
	rol
	rol
	and #%00000011
	sta VAR_SPRITE_DATA+2, y
	sta VAR_SPRITE_DATA+6, y
	sta VAR_SPRITE_DATA+10, y
	sta VAR_SPRITE_DATA+14, y
	
	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_TILE_ID, x
	clc
	adc temp6
	sta VAR_SPRITE_DATA+1, y

	ply
	rts

; x must be a sprite id, temp6 is animation, temp7 is direction
draw_tiny_aligned_sprite_size: 
	phy
	jsr get_var_sprite_data_offset_y

	lda temp6
	.repeat 4
		asl
	.endrepeat
	sta temp6
	lda temp7
	asl
	clc
	adc temp6
	sta temp6
	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
	sta VAR_SPRITE_DATA, y

	lda #SPRITE_OFFSCREEN
	sta VAR_SPRITE_DATA+4, y
	sta VAR_SPRITE_DATA+8, y
	sta VAR_SPRITE_DATA+12, y
	
	lda temp1
	sec
	sbc temp2
	sta VAR_SPRITE_DATA+3, y

	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_PALETTE, x
	and #SPRITE_DATA_PALETTE_MASK
	rol
	rol
	rol
	and #%00000011
	sta VAR_SPRITE_DATA+2, y
	sta VAR_SPRITE_DATA+6, y
	sta VAR_SPRITE_DATA+10, y
	sta VAR_SPRITE_DATA+14, y

	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_TILE_ID, x
	clc
	adc temp6
	sta VAR_SPRITE_DATA+1, y

	ply
	rts


; x must be a sprite id, temp6 is animation, temp7 is direction
draw_3x1_sprite_size: 
	phy
	jsr get_var_sprite_data_offset_y

	
	lda temp1
	sec
	sbc temp2
	cmp #SPRITE_X_CUTOFF
	bcc @dont_kill_the_sprite
		lda #SPRITE_OFFSCREEN
		sta VAR_SPRITE_DATA, y
		sta VAR_SPRITE_DATA+4, y
		sta VAR_SPRITE_DATA+8, y
		sta VAR_SPRITE_DATA+12, y
		ply
		rts
	@dont_kill_the_sprite:
	sta VAR_SPRITE_DATA+3, y
	clc
	adc #8
	sta VAR_SPRITE_DATA+7, y
	clc
	adc #8
	sta VAR_SPRITE_DATA+11, y

	
	lda temp6
	.repeat 4
		asl
	.endrepeat
	sta temp6
	lda temp7
	clc
	adc temp7 
	adc temp7 ; Multiply by 3.
	
	adc temp6
	sta temp6
	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
	clc
	adc #8 ; You're half height; get on the floor; everybody do the dinosaur
	sta VAR_SPRITE_DATA, y
	sta VAR_SPRITE_DATA+4, y
	sta VAR_SPRITE_DATA+8, y

	lda #SPRITE_OFFSCREEN
	sta VAR_SPRITE_DATA+12, y
	
	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_PALETTE, x
	and #SPRITE_DATA_PALETTE_MASK
	rol
	rol
	rol
	and #%00000011
	sta VAR_SPRITE_DATA+2, y
	sta VAR_SPRITE_DATA+6, y
	sta VAR_SPRITE_DATA+10, y
	sta VAR_SPRITE_DATA+14, y

	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_TILE_ID, x
	clc
	adc temp6
	sta VAR_SPRITE_DATA+1, y
	clc
	adc #1
	sta VAR_SPRITE_DATA+5, y
	clc
	adc #1
	sta VAR_SPRITE_DATA+9, y

	ply
	rts

; x must be a sprite id, temp6 is animation, temp7 is direction
; Teleporter gets its own 'size' due to its unique requirements around sprite show/hide
draw_teleporter_sprite_size: 
	phy
	jsr get_var_sprite_data_offset_y

	
	lda temp1
	sec
	sbc temp2
	cmp #SPRITE_X_CUTOFF
	bcc @dont_kill_the_sprite
		@kill_the_sprite:
		lda #SPRITE_OFFSCREEN
		sta VAR_SPRITE_DATA, y
		sta VAR_SPRITE_DATA+4, y
		sta VAR_SPRITE_DATA+8, y
		sta VAR_SPRITE_DATA+12, y
		ply
		rts
	@dont_kill_the_sprite:

	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_TYPE, x
	and #SPRITE_DATA_TYPE_MASK
	cmp #SPRITE_TYPE_TELEPORT
	bne @eod_teleporter
		; We're in plain. Are you?
		lda currentDimension
		cmp #DIMENSION_PLAIN
		bne @kill_the_sprite
		jmp @well_just_keep_it
	@eod_teleporter:
		lda currentDimension
		cmp #DIMENSION_END_OF_DAYS
		bne @kill_the_sprite
		;jmp @well_just_keep_it  ; intentional fallthrough

	@well_just_keep_it:

	lda temp1
	sec
	sbc temp2

	sta VAR_SPRITE_DATA+3, y
	clc
	adc #8
	sta VAR_SPRITE_DATA+7, y
	clc
	adc #8
	sta VAR_SPRITE_DATA+11, y

	
	lda temp6
	.repeat 4
		asl
	.endrepeat
	sta temp6
	lda temp7
	clc
	adc temp7 
	adc temp7 ; Multiply by 3.
	
	adc temp6
	sta temp6
	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
	clc
	adc #8 ; You're half height; get on the floor; everybody do the dinosaur
	sta VAR_SPRITE_DATA, y
	sta VAR_SPRITE_DATA+4, y
	sta VAR_SPRITE_DATA+8, y

	lda #SPRITE_OFFSCREEN
	sta VAR_SPRITE_DATA+12, y
	
	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_PALETTE, x
	and #SPRITE_DATA_PALETTE_MASK
	rol
	rol
	rol
	and #%00000011
	sta VAR_SPRITE_DATA+2, y
	sta VAR_SPRITE_DATA+6, y
	sta VAR_SPRITE_DATA+10, y
	sta VAR_SPRITE_DATA+14, y

	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_TILE_ID, x
	clc
	adc temp6
	sta VAR_SPRITE_DATA+1, y
	clc
	adc #1
	sta VAR_SPRITE_DATA+5, y
	clc
	adc #1
	sta VAR_SPRITE_DATA+9, y

	ply
	rts


draw_default_sprite_size:
	phy
	jsr get_var_sprite_data_offset_y

	lda #0
	sta scratch1
	lda temp1
	sec
	sbc temp2

	cmp #SPRITE_X_CUTOFF
	bcc @dont_kill_the_sprite
		@kill_the_sprite:
		lda #SPRITE_OFFSCREEN
		sta VAR_SPRITE_DATA, y
		sta VAR_SPRITE_DATA+4, y
		sta VAR_SPRITE_DATA+8, y
		sta VAR_SPRITE_DATA+12, y
		ply
		rts
	@dont_kill_the_sprite:
	pha
	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_TYPE, x
	and #SPRITE_DATA_TYPE_MASK
	cmp #SPRITE_TYPE_GRABBER
	bne @not_grabber
		; Grabbers don't show up unless you're in DIM_END_OF_DAYS
		lda currentDimension
		cmp #DIMENSION_END_OF_DAYS
		beq @oh_yeah_its_a_grabber ; you are allowed
		; Okay its a grabber... clean up our mess...
		pla
		jmp @kill_the_sprite ; and go away
		@oh_yeah_its_a_grabber:
		; It *is* a grabber... these need to float a little bit, so let's add to their y position.
		lda #6
		sta scratch1
	@not_grabber:
	pla
	sta VAR_SPRITE_DATA+3, y
	sta VAR_SPRITE_DATA+11, y
	clc
	adc #8
	sta VAR_SPRITE_DATA+7, y
	sta VAR_SPRITE_DATA+15, y


	lda temp6
	.repeat 5
		asl
	.endrepeat
	sta temp6
	lda temp7
	asl
	clc
	adc temp6
	sta temp6

	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
	sec
	sbc scratch1
	sta VAR_SPRITE_DATA, y
	sta VAR_SPRITE_DATA+4, y
	clc
	adc #8
	sta VAR_SPRITE_DATA+8, y
	sta VAR_SPRITE_DATA+12, y

	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_PALETTE, x
	and #SPRITE_DATA_PALETTE_MASK
	rol
	rol
	rol
	and #%00000011
	sta VAR_SPRITE_DATA+2, y
	sta VAR_SPRITE_DATA+6, y
	sta VAR_SPRITE_DATA+10, y
	sta VAR_SPRITE_DATA+14, y

	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_TILE_ID, x
	clc
	adc temp6
	sta VAR_SPRITE_DATA+1, y
	clc
	adc #1
	sta VAR_SPRITE_DATA+5, y
	clc
	adc #$f
	sta VAR_SPRITE_DATA+9, y
	adc #1
	sta VAR_SPRITE_DATA+13, y

	ply
	rts

; Due to some poor decisions in design, the stored Y for sprites isn't actually their real position; it is their position if they were 16px tall.
; Unfortunately, refactoring to fix this would take time I don't have before the end of the contest, so... going to just make this as clear as I can.
; Given a sprite index in x, places the y position of the sprite into a.
get_current_sprite_y:
	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_SIZE, x
	cmp #SPRITE_SIZE_DEFAULT
	beq @default
	cmp #SPRITE_SIZE_2X1
	beq @half
	cmp #SPRITE_SIZE_3X1
	beq @half
	cmp #SPRITE_SIZE_TELEPORTER
	beq @half
	cmp #SPRITE_SIZE_TINY
	beq @quarter
	cmp #SPRITE_SIZE_TINY_NORMAL_ALIGNMENT
	beq @quarter
	jmp @default


	@default: 
		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
		rts

	@half:
		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
		clc
		adc #8
		rts
	
	@quarter: 
		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
		clc
		adc #4
		rts
	

; Similar explanation... there are a few things that really work best using collisions between on-screen sprites. But, we want rotating sprites to 
; allow flickering when > 8 sprites on a line. So... try to avoid doing it, but if you have to, use this.
; Will seed x with the value of the offset to VAR_SPRITE_DATA to use. Note: this obviously destroys x, so put it somewhere first.
get_var_sprite_data_offset:
	lda varSpriteDataOffset
	and #%00000001
	cmp #0
	beq @do_nothing
		stx spriteOffsetTmp
		lda #$b0
		sec
		sbc spriteOffsetTmp

		tax
		rts
	@do_nothing:

	rts

; Same as above, but this puts it into y
get_var_sprite_data_offset_y:
	lda varSpriteDataOffset
	and #%00000001
	cmp #0
	beq @do_nothing
		stx spriteOffsetTmp
		lda #$b0
		sec
		sbc spriteOffsetTmp

		tay
		rts
	@do_nothing:
	txa
	tay
	rts


; You hit. What're we gonna do to you?
do_sprite_collision: 
	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_ID, x
	.repeat 3
		asl
	.endrepeat
	tay
	lda sprite_definitions, y
	cmp #SPRITE_TYPE_COLLECTIBLE
	bne @not_collectible

		phxy

		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_LEVEL_DATA_POSITION, x
		stx tempa
		jsr get_bit_values_for_collectible
		; Okay, we have the bit address... y is the offset to the addr, a is the bit mask.
		ora COLLECTIBLE_DATA, y
		sta COLLECTIBLE_DATA, y ; IT. IS. DONE.
		
		jsr update_gem_count
		ldx tempa
		jsr remove_sprite		


		; Ding dong?
		lda #SFX_COIN
		ldx #FT_SFX_CH0
		jsr sfx_play
		
		plxy
		rts
	@not_collectible:
	cmp #SPRITE_TYPE_JUMPABLE_ENEMY
	bne @not_jumpable
		lda PLAYER_SPRITE
		sec
		sbc playerYVelocity ; put you back where you were last frame for comparison.
		clc
		adc #PLAYER_HEIGHT
		sta temp6
		jsr get_current_sprite_y
		cmp temp6
		bcs @above
			jmp do_player_death						
		@above:
			jsr squish_sprite

		store #1, hasStompedSprite
		
		rts
	@not_jumpable:
	cmp #SPRITE_TYPE_INVULN_ENEMY
	bne @not_invuln
		jmp do_player_death
	@not_invuln:
	cmp #SPRITE_TYPE_GRABBER
	bne @not_grabber
		lda currentDimension
		cmp #DIMENSION_END_OF_DAYS
		bne @not_grabber
		jmp do_player_death
	@not_grabber:
	cmp #SPRITE_TYPE_FIREBALL
	bne @not_fireball
		jmp do_player_death
	@not_fireball:
	cmp #SPRITE_TYPE_SHARK
	bne @not_shark
		jmp do_player_death
	@not_shark:
	cmp #SPRITE_TYPE_TELEPORT
	bne @not_tele
		lda currentDimension
		cmp #DIMENSION_PLAIN
		bne @not_tele
		jsr do_teleporter_collision
	@not_tele:
	cmp #SPRITE_TYPE_TELEPORT_2
	bne @not_tele_2
		lda currentDimension
		cmp #DIMENSION_END_OF_DAYS
		bne @not_tele_2
		jsr do_teleporter_collision
	@not_tele_2:
	cmp #SPRITE_TYPE_DIMENSIONER
	bne @not_dimensioner
		; This thing transports us between dimensions... mark it up.
		store #1, isInWarpZone
		; Little bit of funky, dirty code here. We store dimension A in the anim type, and b in the speed. 
		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_ANIM_TYPE, x
		sta warpDimensionA
		lda EXTENDED_SPRITE_DATA+SPRITE_DATA_SPEED, x
		sta warpDimensionB
	@not_dimensioner:
	cmp #SPRITE_TYPE_PROFESSOR
	bne @not_professor
		lda hasTalkedToMrDuck
		cmp #1
		beq @not_professor
		lda #1
		sta hasTalkedToMrDuck
		jsr show_bottom_hud
	@not_professor:

	rts

do_teleporter_collision:
	; Technically, we're going all abandon ship on our stack here.
	; Trying to accomodate for that by setting the stack pointer back down to $ff, where it starts.
	jsr do_end_of_level_teleporter_anim
	ldx #$ff
	txs
	jsr do_next_level ; TODO: This needs to be smarter-er about whether to show the bad end, or good end.
	jmp show_ready
	rts

; Gets the position of a collectible. Give it: 
; a - the position of the sprite in the level.
; all registers will be destroyed. Push em if you need em.
get_bit_values_for_collectible:
	sta temp7
	ldy #2
	ldx #0
	@find_it: 
		lda (lvlSpriteDataAddr), y
		cmp #COLLECTIBLE_SPRITE_ID
		bne @not_collectibleb
			inx
		@not_collectibleb:
		dey
		dey
		cpy temp7
		bne @go_find_it
			jmp @found_it
		@go_find_it:
		iny
		iny
		
		iny
		iny
		iny
		iny
		jmp @find_it
	@found_it:
		
	stx temp7 
	; Okay, we now know what collectible  id this is... now we need to get it to a bit id

	lda currentLevel
	asl
	asl ; Each level gets 4 bytes = 32 total coins. 1 bit per.
	tay
	
	ldx #0
	lda #1
	@convert_it:
		cpx temp7
		beq @done_convert
		
		asl
		bcc @no_carry
			lda #1
			iny
		@no_carry: 

		inx
		jmp @convert_it

	@done_convert:
	rts

do_player_death:
	txa
	pha
	lda #SFX_DEATH
	ldx #FT_SFX_CH1
	jsr sfx_play
	lda #SONG_DEATH
	jsr music_play
	pla
	tax

	lda PLAYER_SPRITE+12
	clc
	adc #PLAYER_VELOCITY_FALLING
	adc #10
	bcs @dead

	ldx #0 ; bounce up a wee bit before falling to your doom...
	@fallup:
		lda PLAYER_SPRITE+12
		sec
		sbc #PLAYER_VELOCITY_FALLING
		sta PLAYER_SPRITE+12
		sta PLAYER_SPRITE+16
		sta PLAYER_SPRITE+20
		sec
		sbc #8
		sta PLAYER_SPRITE
		sta PLAYER_SPRITE+4
		sta PLAYER_SPRITE+8

		txa
		pha
		jsr vblank_wait
		jsr do_sprite0
		jsr sound_update
		pla
		tax
		inx
		cpx #DEATH_HOP_TIME
		bne @fallup


	@falldown_goboom:
		lda PLAYER_SPRITE+12
		clc
		adc #PLAYER_VELOCITY_FALLING
		bcc @not_dead_yet
			jmp @dead
		@not_dead_yet:
		sta PLAYER_SPRITE+12
		sta PLAYER_SPRITE+16
		sta PLAYER_SPRITE+20
		sec
		sbc #8
		sta PLAYER_SPRITE
		sta PLAYER_SPRITE+4
		sta PLAYER_SPRITE+8

		jsr vblank_wait
		jsr do_sprite0
		jsr sound_update
		jmp @falldown_goboom
	@dead:
	ldx #00
	@loop_snd:
		txa
		pha
		jsr vblank_wait
		jsr do_sprite0
		jsr sound_update
		pla
		tax
		inx
		cpx #DEATH_SONG_TIME
		bne @loop_snd
	ldx #$ff
	txs ; Another instance where we rewrite the stack pointer to avoid doing bad things.
	jmp show_ready

; Start squish animation for a sprite at position x
squish_sprite:
	tya
	pha
	lda #SPRITE_ANIMATION_DYING
	sta EXTENDED_SPRITE_DATA+SPRITE_DATA_ANIM_TYPE, x

	lda #SPRITE_DYING
	sta EXTENDED_SPRITE_DATA+SPRITE_DATA_TILE_ID, x

	txa
	pha
	lda #SFX_SQUISH
	ldx #FT_SFX_CH1
	jsr sfx_play
	pla
	tax

	pla
	tay
	rts

; Remove a sprite at position x (16-based) entirely from existance.
remove_sprite:
	; If you get here, we have collided.
	tya
	pha
	; Back up your original y, in case we need it (mainly used for gem boxes)
	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
	cmp #0
	beq @already_gone
		; HACKY HJACKY HACKY HACKY HAAACK
		sta EXTENDED_SPRITE_DATA+SPRITE_DATA_TEMP_Y, x
	@already_gone:

	lda #0
	sta EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
	

	; Also update level data...
	jsr get_gem_update_data

	; Okay, temp0 is now the index off CURRENT_LEVEL_DATA, and a is the mask...
	ldy temp8
	ora CURRENT_LEVEL_DATA, y
	sta CURRENT_LEVEL_DATA, y

	lda #0
	sta EXTENDED_SPRITE_DATA+SPRITE_DATA_LEVEL_DATA_POSITION, x

	pla
	tay
	rts

; Bit of a weird method... expects to have a 2 bit value to apply in tempc, and x as a sprite offset.
; Returns byte offset in temp8, and bit mask in a
get_gem_update_data:
	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_LVL_INDEX, x
	tay
	store #0, temp8
	lda #%00000001
	@loop_indexer:
		asl
		bcc @no_reloop
			inc temp8
			lda #%00000001
		@no_reloop:
		dey
		cpy #255 ; Make sure we actually calculate the 0 run.
		bne @loop_indexer
	rts

update_gem_count:
	bank_temp #BANK_GEM_FUNCTIONS
	jsr banked_update_gem_count
	bank_restore
	rts

; Not moved to separate bank because it uses data in another bank.
update_total_gem_count:
	store #0, totalGemCount
	
	ldy #0
	@level_data_loop:
		lda (lvlSpriteDataAddr), y
		cmp #$ff
		beq @done_level_data_loop
		iny
		iny
		lda (lvlSpriteDataAddr), y
		cmp #SPRITE_TYPE_COLLECTIBLE
		bne @not_collectible
			inc totalGemCount
			lda totalGemCount
			and #%00001111
			cmp #$a
			bne @not_inc_it
				lda totalGemCount
				clc
				adc #6
				sta totalGemCount
			@not_inc_it:
		@not_collectible:
		iny
		iny
		jmp @level_data_loop
	@done_level_data_loop:
	rts

get_game_gem_count:
	lda #0
	sta temp1
	sta temp2
	ldx #0
	@loop:
		ldy #0
		lda COLLECTIBLE_DATA, x
		@inner_loop:
			clc
			asl
			pha
			bcc @no_add
				inc temp1
				lda temp1
				and #%00001111
				cmp #10
				bne @no_bump
					lda temp1
					clc
					adc #6 ; bump to next level
					sta temp1

					cmp #$a0
					bcc @no_3rd_digit
					inc temp2
					sec
					sbc #$a0
					sta temp1
					@no_3rd_digit:

				@no_bump:
			@no_add:
			pla
			iny
			cpy #8
			bne @inner_loop
		inx
		cpx #COLLECTIBLE_DATA_LENGTH
		bne @loop
		lda temp2

	rts

get_level_gem_count:
	asl
	asl ; Each level gets 4 bytes = 32 total coins. 1 bit per.
	tax
	ldy #0
	sty temp1
	@loop:
		phy
		ldy #0
		lda COLLECTIBLE_DATA, x
		@inner_loop: 
			clc
			asl
			pha
			bcc @no_add
				inc temp1
				lda temp1
				and #%00001111
				cmp #10
				bne @no_bump	
					lda temp1
					clc
					adc #6 ; bump to next level
					sta temp1
				@no_bump:
			@no_add:
			pla
			iny
			cpy #8
			bne @inner_loop

		ply
		iny
		inx
		cpy #4
		bne @loop
		lda temp1
		rts

get_game_gem_total:
	; This looks really gross... all it's doing is taking our total count, and converting it to BCD... each hex digit is now a decimal digit.
	lda #((GAME_GEM_TOTAL .MOD 10) + ((GAME_GEM_TOTAL / 10) .MOD 10 * 16))
	sta tempc
	lda #((GAME_GEM_TOTAL / 100)) .MOD 10
	sta tempd
	rts
	
.macro do_x_velocity_lock DIRECTION, MAX_DIST, VEL_FAST, VEL_NORMAL
	.local @we_are_ok, @skip_inc, @done_macro, @okay, @normal

	lda ctrlButtons
	and DIRECTION
	beq @skip_inc

		inc playerXVelocityLockTime
		lda playerXVelocityLockTime
		cmp MAX_DIST
		bcc @we_are_ok
			lda MAX_DIST
			sta playerXVelocityLockTime
		@we_are_ok:
		lda VEL_FAST
		jmp @done_macro
	@skip_inc:
		dec playerXVelocityLockTime
		lda playerXVelocityLockTime
		cmp #255
		bne @okay
			store #0, playerXVelocityLockTime
		@okay: 
		lda ctrlButtons
		and #(CONTROLLER_LEFT + CONTROLLER_RIGHT)
		cmp #0
		beq @normal
		cmp #CONTROLLER_B
		bne @normal
			; Gotta go fast!
			lda VEL_FAST
			jmp @done_macro
		@normal: 
		lda VEL_NORMAL

	@done_macro:
.endmacro

handle_main_input: 
	lda playerYVelocityLockTime
	cmp #0
	beq @not_locked
		dec playerYVelocityLockTime
		jsr read_controller
		jmp @locked_allowed_buttons
	@not_locked:
	jsr read_controller

	lda playerDirection
	sta lastPlayerDirection
	store #0, playerVelocity

	; No matter what, show the sprite facing the same direction you pressed.
	lda ctrlButtons
	and #CONTROLLER_LEFT
	beq @not_left_vis
		store #PLAYER_DIRECTION_LEFT, playerVisibleDirection
	@not_left_vis:
	lda ctrlButtons
	and #CONTROLLER_RIGHT
	beq @not_right_vis
		store #PLAYER_DIRECTION_RIGHT, playerVisibleDirection
	@not_right_vis:

	lda playerXVelocityLockTime
	cmp #0
	beq @no_x_lock
		; Okay, you're locked... so, if you're going in the same direction, cool. If not, well, actually, yes you are!
		lda lastPlayerDirection
		cmp #PLAYER_DIRECTION_LEFT
		bne @not_left_lock
			jmp @do_left
		@not_left_lock:
			jmp @do_right

	@no_x_lock: 
	
	lda ctrlButtons
	and #CONTROLLER_LEFT
	bne @do_left
		jmp @done_left
	@do_left:
		lda #PLAYER_DIRECTION_LEFT
		sta playerDirection
		
		; If you're at the start of the level, go away. Don't run past the end.
		lda playerPosition+1
		cmp #0
		bne @continue_left
		lda playerPosition
		cmp #MIN_LEFT_LEVEL_POSITION
		bcs @continue_left
			; No Messing around, STOP.
			lda #0
			sta playerXVelocityLockTime
			sta playerVelocity
			jmp @done_left
		@continue_left:
		
		lda ctrlButtons
		and #CONTROLLER_B
		bne @fast_left
			; Slow left.
			do_x_velocity_lock ctrlButtons, #0, #256-PLAYER_VELOCITY_NORMAL, #256-PLAYER_VELOCITY_NORMAL
			jmp @doit_left
		@fast_left:
			lda isOnIce
			cmp #1
			beq @icy2
				lda #RUN_MOVEMENT_LOCK_TIME
				jmp @go_velocitize2
			@icy2:
				lda #ICE_RUN_MOVEMENT_LOCK_TIME
			@go_velocitize2:
			sta tempa
			do_x_velocity_lock #CONTROLLER_LEFT, tempa, #256-PLAYER_VELOCITY_FAST, #256-PLAYER_VELOCITY_NORMAL
			
		@doit_left: 
		sta playerVelocity
	@done_left:

	; Special case for if you're holding right, but locked to left. Don't pass go, don't collect $200
	lda playerXVelocityLockTime
	cmp #0
	beq @your_good
		lda playerDirection
		cmp #PLAYER_DIRECTION_RIGHT
		beq @your_good
		jmp @done_right ; get outta here, ya sneak.
	@your_good:
	
	lda ctrlButtons
	and #CONTROLLER_RIGHT
	bne @do_right
		jmp @done_right
	@do_right:
		lda #PLAYER_DIRECTION_RIGHT
		sta playerDirection
		
		lda ctrlButtons
		and #CONTROLLER_B
		bne @fast_right
			do_x_velocity_lock ctrlButtons, #0, #PLAYER_VELOCITY_NORMAL, #PLAYER_VELOCITY_NORMAL
			jmp @doit_right
		@fast_right: 
			lda isOnIce
			cmp #1
			beq @icy
				lda #RUN_MOVEMENT_LOCK_TIME
				jmp @go_velocitize
			@icy:
				lda #ICE_RUN_MOVEMENT_LOCK_TIME
			@go_velocitize:
			sta tempa
			do_x_velocity_lock #CONTROLLER_RIGHT, tempa, #PLAYER_VELOCITY_FAST, #PLAYER_VELOCITY_NORMAL
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
		jsr sfx_play

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

	@locked_allowed_buttons:
	lda ctrlButtons
	and #CONTROLLER_START
	beq @done_start
		lda lastCtrlButtons
		and #CONTROLLER_START
		bne @done_start
		.if DEBUGGING = 1
			lda ctrlButtons
			and #CONTROLLER_SELECT
			beq @no_hax
				; If you hit both start and select in debug mode, you finish the level!
				jsr do_next_level
				jmp show_ready
			@no_hax:
			lda ctrlButtons
			and #CONTROLLER_A
			beq @no_hax2
				jsr HACK_GIMME_ALL_GEMS
			@no_hax2:
		.endif
		jsr do_pause_screen
	@done_start:

	lda ctrlButtons
	and #CONTROLLER_SELECT
	beq @done_sel
		lda lastCtrlButtons
		and #CONTROLLER_SELECT
		bne @done_sel
		lda currentLevel
		cmp #LEVEL_9_ID
		beq @not_allowed
			jsr do_dimensional_transfer
		@not_allowed:
	@done_sel:

	rts
	
load_sprite0:
	lda #$ff
	sta SPRITE_ZERO+1
	lda #%00000000
	sta SPRITE_ZERO+2
	lda #SPRITE_ZERO_X
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

seed_palette:
	lda #$ff
	sta currentBackgroundColorOverride
	lda currentDimension
	cmp #DIMENSION_AGGRESSIVE
	beq @aggressive
	cmp #DIMENSION_ICE_AGE
	beq @ice
	cmp #DIMENSION_END_OF_DAYS
	beq @eod
	cmp #DIMENSION_BARREN
	beq @barren

	@default: 
		store #0, currentPalette
		rts

	@ice:
		store #2, currentPalette
		rts

	@eod:
		store #3, currentPalette
		rts

	@barren: 
		store #4, currentPalette
		rts

	@aggressive:
		store #1, currentPalette
		rts

load_palettes_for_dimension:
	txa
	pha
	tya
	pha

	lda currentPalette
	.repeat 4
		asl
	.endrepeat
	tax

	set_ppu_addr $3f00
	ldy #0
	@loop:
		
		lda default_palettes, x
		sta PPU_DATA
		iny
		inx
		cpy #16
		bne @loop
	pla
	tay
	pla
	tax	 
	rts

load_palettes_for_pause:
	ldx #0
	set_ppu_addr $3f00
	lda #$0f
	@loop:
		sta PPU_DATA
		inx
		cpx #16 ; get the sprite palettes too; except the last one.
		bne @loop
		.repeat 4
			lda #$0f
			sta PPU_DATA
			lda #$00
			sta PPU_DATA
			lda #$38
			sta PPU_DATA
			lda #$0f
			sta PPU_DATA
		.endrepeat 

	rts

load_sprite_palettes:
	set_ppu_addr $3f10

	lda currentDimension
	cmp #DIMENSION_END_OF_DAYS
	bne @normal
		ldx #0
		@loop_dark:
			lda dark_sprite_palettes, x
			sta PPU_DATA
			inx
			cpx #16
			bne @loop_dark

	@normal:
	ldx #0
	@loop:
		lda default_sprite_palettes, x
		sta PPU_DATA
		inx
		cpx #16
		bne @loop

	rts

hide_duck: 
	lda PLAYER_SPRITE
	sta duckPausePosition
	lda #SPRITE_OFFSCREEN
	.repeat 6, I
		sta PLAYER_SPRITE+(I*4)
	.endrepeat
	rts

restore_duck:
	lda duckPausePosition
	sta PLAYER_SPRITE
	sta PLAYER_SPRITE+4
	sta PLAYER_SPRITE+8
	lda duckPausePosition
	clc
	adc #$8
	sta PLAYER_SPRITE+12
	sta PLAYER_SPRITE+16
	sta PLAYER_SPRITE+20
	rts

		

play_music_for_dimension: 
	lda currentDimension
	cmp #DIMENSION_PLAIN
	bne @not_plain
		lda #SONG_CRAPPY
		jsr music_play
		rts
	@not_plain: 
	cmp #DIMENSION_ICE_AGE
	bne @not_ice_age
		lda #SONG_ICE_CRAPPY 
		jsr music_play
		rts
	@not_ice_age:
	cmp #DIMENSION_BARREN
	bne @not_barren
		lda #SONG_CRAPPY_DESERT
		jsr music_play
		rts
	@not_barren:
	cmp #DIMENSION_AGGRESSIVE
	bne @not_aggressive
		lda #SONG_FIRE
		jsr music_play
		rts
	@not_aggressive:
	cmp #DIMENSION_END_OF_DAYS
	bne @not_eod
		lda #SONG_EOD
		jsr music_play
		rts
	@not_eod:
	; Fall back to default track for consistency's sake.
	lda #SONG_CRAPPY
	jsr music_play
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
	ldx #0 ; only one palette for sprites for now.
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

	lda currentBackgroundColorOverride
	cmp #$ff
	beq @no_override
		lda currentBackgroundColorOverride
		sta PPU_DATA
	@no_override:
	rts

; Quick method to convert accumulator as a dimension id into a row number to start drawing files into the variable tile row.
get_row_from_a:
	cmp #DIMENSION_PLAIN
	beq @plain
	cmp #DIMENSION_BARREN
	beq @barren
	cmp #DIMENSION_ICE_AGE
	beq @ice_age
	cmp #DIMENSION_AGGRESSIVE
	beq @aggressive
	cmp #DIMENSION_END_OF_DAYS
	beq @end_of_days
	@aggressive:
	 	lda #TILE_ROW_AGGRESSIVE
		rts

	@barren: 
		lda #TILE_ROW_BARREN
		rts

	@end_of_days:
		lda #TILE_ROW_END_OF_DAYS
		rts

	@plain: 
		lda #TILE_ROW_PLAIN
		rts

	@ice_age: 
		lda #TILE_ROW_ICE_AGE
		rts

draw_switchable_tiles: 

	bank #BANK_CHR

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

	; Okay, almost done... now we need to separate out the animated tiles, and draw those into the next row.
	; These will then get copied into their places every cycle (well, realistically more like  1x every 4 or so)
	phx

	ldy #0
	ldx #0
	dec tempAddr+1
	dec tempAddr+1 ; Put us back where we started last time.
	@loop_animated_tiles_1: 
		lda (tempAddr), y
		sta ANIMATED_TILE_CACHE, x

		iny
		inx
		cpy #32
		bne @loop_animated_tiles_1
	
	ldy #192
	@loop_animated_tiles_2: 
		lda (tempAddr), y
		sta ANIMATED_TILE_CACHE, x

		iny
		inx
		cpy #224
		bne @loop_animated_tiles_2


	; Now get the bottom tiles.
	ldy #0
	inc tempAddr+1 ; Next row please.
	@loop_animated_tiles_3: 
		lda (tempAddr), y
		sta ANIMATED_TILE_CACHE, x

		iny
		inx
		cpy #32
		bne @loop_animated_tiles_3
	
	ldy #192
	@loop_animated_tiles_4: 
		lda (tempAddr), y
		sta ANIMATED_TILE_CACHE, x

		iny
		inx
		cpy #224
		bne @loop_animated_tiles_4


	; Fire too
	dec tempAddr+1
	ldy #96
	@loop_animated_tiles_5: 
		lda (tempAddr), y
		sta ANIMATED_TILE_CACHE, x

		iny
		inx
		cpy #128
		bne @loop_animated_tiles_5
	
	ldy #224
	@loop_animated_tiles_6: 
		lda (tempAddr), y
		sta ANIMATED_TILE_CACHE, x

		iny
		inx
		cpy #0
		bne @loop_animated_tiles_6


	; Now get the bottom tiles.
	ldy #96
	inc tempAddr+1 ; Next row please.
	@loop_animated_tiles_7: 
		lda (tempAddr), y
		sta ANIMATED_TILE_CACHE, x

		iny
		inx
		cpy #128
		bne @loop_animated_tiles_7
	
	ldy #224
	@loop_animated_tiles_8: 
		lda (tempAddr), y
		sta ANIMATED_TILE_CACHE, x

		iny
		inx
		cpy #0
		bne @loop_animated_tiles_8



	plx
	bank #BANK_SPRITES_AND_LEVEL
	rts

; Try to create a "Smooth" (well, for NES) fade in/out. Buys us time to swap out tiles, etc.
do_dimensional_transfer:
	lda isInWarpZone
	cmp #0
	bne @maybe_doit
		rts
	@maybe_doit:

	lda warpDimensionA
	cmp currentDimension
	beq @doit
	lda warpDimensionB
	cmp currentDimension
	beq @doit
	rts
	@doit:

	; Special case for end-of-days... 
	lda warpDimensionB
	cmp #DIMENSION_END_OF_DAYS
	bne @normal
		; It is 1) a one-way trip
		lda currentDimension
		cmp #DIMENSION_PLAIN
		beq @continue_ending_days
			@nope_you_fail:
			rts 
		@continue_ending_days:
		; 2) Only available if you have all gems in the game.
		jsr get_game_gem_total
		lda gameGemCountCache
		cmp tempc
		bne @nope_you_fail
		lda gameGemCountCache+1
		cmp tempd
		bne @nope_you_fail

	@normal:
	; Fallthrough - this entrypoint allows us to skip all of the checks above, and just force a dimension change. Used in level 9
do_dimensional_transfer_unsafe:

	lda #SFX_WARP
	ldx #SOUND_CHANNEL_PLAYER
	jsr sfx_play
	jsr music_pause ; A should be non-zero here, causing a pause.


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
			jsr sound_update
			jsr disable_all
			jsr vblank_wait
			jsr sound_update

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
			jsr seed_palette

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
			jsr sound_update; We're our own little thing.. need to trigger famitone.
			pla
			tax 
			inx
			cpx #DIMENSIONAL_SWAP_TIME
			beq @done_d
				jmp @loopah; You will stay here FOR-EV-ER!!
			@done_d:
	@done:
	jsr vblank_wait
	jsr load_sprite_palettes
	jsr load_palettes_for_dimension ; Reload palettes - our fade stuff is imperfect, and this works around that.
	reset_ppu_scrolling
	jsr do_sprite0
	lda temp4
	sta ppuCtrlBuffer
	jsr play_music_for_dimension
	lda #0 ; 0 = play.
	jsr music_pause
	rts
	
main_loop: 
	lda frameCounter
	sta varSpriteDataOffset

	jsr handle_main_input
	lda #0
	sta isInWarpZone
	sta isOnIce
	sta warpDimensionA
	sta warpDimensionB
	jsr reset_collision_state
	jsr do_player_vertical_movement
	jsr do_player_movement
	jsr do_special_tile_stuff
	jsr do_sprite_movement
	jsr test_sprite_collision
	jsr update_buffer_for_warp_zone
	jsr sound_update
	jsr level_9_dimension_transfer

	lda #0
	sta tempf ; Keep track of what to skip....
	jsr vblank_wait
	
	; Not ideal to do this inside vblank...
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
		store #1, tempf
	@go_on:

	; Turn off 32 bit adding to do arbitrary graphical updates
	lda ppuCtrlBuffer
	and #%00001000
	sta PPU_CTRL

	; Alternate between updating the hud and animating tiles on even/odd cycles
	lda arbitraryTileUpdatePos
	cmp #0
	beq @no_arbitrary_tile
		jsr update_arbitrary_tile
		jmp @after_switchables
	@no_arbitrary_tile:

	; Skip animation if we've updated the next row this time around... we don't have enough cycles left!
	lda tempf
	cmp #0
	bne @after_switchables

	lda frameCounter
	and #%00000001
	cmp #0
	beq @do_animation
		jsr update_hud_gem_count
		jmp @after_switchables
	@do_animation:
		jsr animate_tiles
	@after_switchables: 

	; Turn 32 bit adding back on.
	lda ppuCtrlBuffer
	sta PPU_CTRL

	jsr do_sprite0


	jmp main_loop

update_buffer_for_warp_zone:
	lda isInWarpZone
	cmp #0
	beq @restore_original_colors
		; It's a warp! but is it ours?
		lda currentDimension
		cmp warpDimensionA
		beq @its_probably_a_warp
		cmp warpDimensionB
		beq @its_probably_a_warp
		jmp @restore_original_colors

	@its_probably_a_warp:
		; Little extra check to eliminate the end of days warps unless you meet the criteria
		lda warpDimensionB
		cmp #DIMENSION_END_OF_DAYS
		bne @its_definitely_a_warp
		lda currentDimension
		cmp #DIMENSION_END_OF_DAYS
		beq @restore_original_colors

		cmp #DIMENSION_PLAIN
		bne @its_probably_a_warp
		; Okay... you're in plain, this thing goes to end of days... do you meet the criteria?
		jsr get_game_gem_total
		lda gameGemCountCache
		cmp tempc
		bne @restore_original_colors
		lda gameGemCountCache+1
		cmp tempd
		bne @restore_original_colors
		jmp @its_definitely_a_warp
		

	@its_definitely_a_warp: 
		; party time
		lda ppuMaskBuffer
		and #DIMENSION_MASK^255
		ora #DIMENSION_FADE
		sta ppuMaskBuffer
		rts

	@restore_original_colors:
		; Not a warp :(
		lda ppuMaskBuffer
		and #DIMENSION_MASK^255
		ora currentDimension
		sta ppuMaskBuffer
		rts

update_arbitrary_tile:

	lda PPU_STATUS
	store arbitraryTileAddr+1, PPU_ADDR
	store arbitraryTileAddr, PPU_ADDR
	lda arbitraryTileUpdateId
	sta PPU_DATA
	clc
	adc #1
	sta PPU_DATA

	; Now jump two lines and do it again.
	lda PPU_STATUS
	lda arbitraryTileAddr
	clc
	adc #$20
	sta arbitraryTileAddr
	lda arbitraryTileAddr+1
	adc #0
	sta arbitraryTileAddr+1
	sta PPU_ADDR
	store arbitraryTileAddr, PPU_ADDR

	lda arbitraryTileUpdateId
	clc
	adc #$10
	sta PPU_DATA
	adc #1
	sta PPU_DATA


	lda #0
	sta arbitraryTileUpdatePos

	rts

animate_tiles:
	lda frameCounter
	and #%00000010
	beq animate_water_tiles
	jmp animate_fire_tiles

animate_water_tiles: 
	lda frameCounter
	and #%00010000
	asl ; Get the var we got from frameCounter to be either 32 or 0, allowing us to select data from one of our two tiles.
	tax

	set_ppu_addr WATER_TILE_LOCATION
	.repeat 32, I
		lda ANIMATED_TILE_CACHE+I, x
		sta PPU_DATA
	.endrepeat

	set_ppu_addr WATER_TILE_LOCATION+$100 ; second tile row
	.repeat 32, I
		lda ANIMATED_TILE_CACHE+64+I, x
		sta PPU_DATA
	.endrepeat
	rts

animate_fire_tiles: 
	lda frameCounter
	and #%00010000
	asl ; Get the var we got from frameCounter to be either 32 or 0, allowing us to select data from one of our two tiles.
	tax

	set_ppu_addr FIRE_TILE_LOCATION
	.repeat 32, I
		lda ANIMATED_TILE_CACHE+128+I, x
		sta PPU_DATA
	.endrepeat

	set_ppu_addr FIRE_TILE_LOCATION+$100 ; second tile row
	.repeat 32, I
		lda ANIMATED_TILE_CACHE+192+I, x
		sta PPU_DATA
	.endrepeat
	rts

clear_sprites:
	ldx #0
	@loop:
		lda #SPRITE_OFFSCREEN
		sta SPRITE_DATA, x
		lda #0
		sta SPRITE_DATA+1, x
		sta SPRITE_DATA+2, x
		sta SPRITE_DATA+3, x
		inx
		inx
		inx
		inx
		cpx #0
		bne @loop

	; WARNING: This clears everything in the page sprite data is in. This may have side effects!
	ldx #0
	lda #0
	@loop_data:
		sta EXTENDED_SPRITE_DATA, x
		inx
		cpx #0
		bne @loop_data
	rts

clear_var_sprites:
	lda #SPRITE_OFFSCREEN
	.repeat NUM_VAR_SPRITES*4, I
		sta VAR_SPRITE_DATA+(I*4)
	.endrepeat
	rts
	
show_level: 
	jsr vblank_wait
	jsr disable_all
	jsr vblank_wait
	jsr update_gem_count
	jsr get_game_gem_count
	lda temp1
	sta gameGemCountCache
	lda temp2
	sta gameGemCountCache+1

	; Turn off 32 bit adding for addresses initially.
	lda ppuCtrlBuffer
	and #%11111000 ; set to nametable 0
	sta PPU_CTRL
	sta ppuCtrlBuffer
	jsr vblank_wait

	jsr load_level
	jsr clear_sprites
	jsr load_graphics_data
	jsr draw_switchable_tiles
	jsr load_palettes_for_dimension
	jsr update_total_gem_count



	; Turn on 32 bit adding for addresses to load rows.
	lda ppuCtrlBuffer
	ora #%00000100
	sta PPU_CTRL
	sta ppuCtrlBuffer
	jsr vblank_wait

	jsr load_nametable

	; Turn it back off for the hud

	lda ppuCtrlBuffer
	and #%11111011
	sta PPU_CTRL
	sta ppuCtrlBuffer
	jsr vblank_wait

	jsr show_hud

	; Turn on 32 bit adding for addresses to load rows, instead of columns.
	lda ppuCtrlBuffer
	ora #%00000100
	sta ppuCtrlBuffer

	reset_ppu_scrolling_and_ctrl
	jsr vblank_wait
	jsr enable_all
	jsr load_sprite0
	;reset_ppu_scrolling
	lda #PLAYER_DIRECTION_RIGHT
	sta playerDirection
	jsr initialize_player_sprite
	
	jsr play_music_for_dimension
	
	jsr vblank_wait
	jmp main_loop


do_pause_screen:
	lda ppuCtrlBuffer
	and #%11111011
	sta ppuCtrlBuffer

	jsr disable_all
	jsr vblank_wait
	jsr load_palettes_for_pause
	jsr clear_var_sprites
	jsr hide_duck
	lda #SPRITE_OFFSCREEN
	sta HUD_GEM_SPRITE
	jsr enable_all

	store #SPRITE_PAUSE_LETTERS, VAR_SPRITE_DATA+1
	store #SPRITE_PAUSE_LETTERS+1, VAR_SPRITE_DATA+5
	store #SPRITE_PAUSE_LETTERS+$10, VAR_SPRITE_DATA+9
	store #SPRITE_PAUSE_LETTERS+$11, VAR_SPRITE_DATA+13
	store #SPRITE_PAUSE_LETTERS+2, VAR_SPRITE_DATA+17
	store #SPRITE_PAUSE_LETTERS+3, VAR_SPRITE_DATA+21

	lda #SPRITE_PAUSE_LETTERS+$12
	sta VAR_SPRITE_DATA+25
	sta VAR_SPRITE_DATA+29

	store #SPRITE_PAUSE_LETTERS+4, VAR_SPRITE_DATA+33
	store #SPRITE_PAUSE_LETTERS+2, VAR_SPRITE_DATA+37
	store #SPRITE_PAUSE_LETTERS+$11, VAR_SPRITE_DATA+41
	store #SPRITE_PAUSE_LETTERS+$14, VAR_SPRITE_DATA+45
	store #SPRITE_PAUSE_LETTERS+$15, VAR_SPRITE_DATA+49
	store #SPRITE_PAUSE_LETTERS+2, VAR_SPRITE_DATA+53

	store #SPRITE_PAUSE_LETTERS+4, VAR_SPRITE_DATA+57
	store #SPRITE_PAUSE_LETTERS+2, VAR_SPRITE_DATA+61
	store #SPRITE_PAUSE_LETTERS+$11, VAR_SPRITE_DATA+65
	store #SPRITE_PAUSE_LETTERS+5, VAR_SPRITE_DATA+69
	store #SPRITE_PAUSE_LETTERS+1, VAR_SPRITE_DATA+73
	store #SPRITE_PAUSE_LETTERS+4, VAR_SPRITE_DATA+77
	store #SPRITE_PAUSE_LETTERS+5, VAR_SPRITE_DATA+81
	store #SPRITE_POINTER, VAR_SPRITE_DATA+85

	; Don't touch palettes here - most sprites should have a non-duck color, meaning we can rely on them.

	lda #$60 ; paused text
	.repeat 8, I
		sta VAR_SPRITE_DATA+(I*4)
	.endrepeat

	lda #$a0 ; Resume
	.repeat 8, I
		sta VAR_SPRITE_DATA+(32+(I*4))
	.endrepeat

	lda #$a8 ; restart
	.repeat 8, I
		sta VAR_SPRITE_DATA+(56+(I*4))
	.endrepeat

	lda #$60
	.repeat 6, I
		sta VAR_SPRITE_DATA+(I*4)+3
		adc #8
	.endrepeat
	adc #8
	sta VAR_SPRITE_DATA+31
	lda #$50
	sta VAR_SPRITE_DATA+27

	lda #$60 ; Resume
	.repeat 6, I
		sta VAR_SPRITE_DATA + 32 + (I*4) + 3
		adc #8
	.endrepeat

	lda #$60 ; Restart
	.repeat 7, I
		sta VAR_SPRITE_DATA + 56 + (I * 4) + 3
		adc #8
	.endrepeat

	lda #$50
	sta VAR_SPRITE_DATA+87

	lda #1
	jsr music_pause

	store #0, pauseOption

	lda #SFX_MENU
	ldx #FT_SFX_CH0
	jsr sfx_play

	@loop_pause_screen:
		lda pauseOption
		asl
		asl
		asl
		clc
		adc #$a0
		sta VAR_SPRITE_DATA+84
		
		jsr read_controller
		
		lda ctrlButtons
		and #CONTROLLER_START|CONTROLLER_A
		beq @done_start
			lda lastCtrlButtons
			and #CONTROLLER_START|CONTROLLER_A
			bne @done_start
			lda pauseOption
			cmp #0
			beq @escape_pause
			jmp @escape_pause_harder
		@done_start:

		lda ctrlButtons
		and #CONTROLLER_UP
		beq @done_up
			lda pauseOption
			cmp #0
			beq @done_up
			store #0, pauseOption
			lda #SFX_MENU_TICK
			ldx #FT_SFX_CH0
			jsr sfx_play
		@done_up:
		lda ctrlButtons
		and #CONTROLLER_DOWN
		beq @done_down
			lda pauseOption
			cmp #1
			beq @done_down
			store #1, pauseOption
			lda #SFX_MENU_TICK
			ldx #FT_SFX_CH0
			jsr sfx_play
		@done_down:


		jsr sound_update
		jsr vblank_wait
		jsr do_sprite0

	jmp @loop_pause_screen

	@escape_pause_harder: ; If you were really done, restart the level for you.
		ldx #$ff
		txs ; Another instance where we rewrite the stack pointer to avoid doing bad things.
		jmp show_ready

	@escape_pause:
		; Turn off 32 bit adding
		lda ppuCtrlBuffer
		and #%11111011
		sta ppuCtrlBuffer

		jsr disable_all
		jsr vblank_wait
		jsr load_sprite_palettes
		jsr load_palettes_for_dimension

		jsr restore_duck
		jsr draw_hud_gem
		reset_ppu_scrolling
		lda #0
		jsr music_pause
		lda #SFX_MENU_DOWN
		ldx #FT_SFX_CH0
		jsr sfx_play

		jsr vblank_wait
		
		; Turn 32 bit adding back on.
		lda ppuCtrlBuffer
		ora #%00000100
		sta ppuCtrlBuffer
		jsr enable_all
		rts
do_next_level:
	inc currentLevel
	lda currentLevel
	cmp #NUMBER_OF_REGULAR_LEVELS
	bne @just_go
		store #1, GAME_BEATEN_BYTE

		lda currentDimension
		cmp #DIMENSION_END_OF_DAYS
		beq @carry_on_my_wayward_son
			; Oh, so... you hit level 9, but you're in the normal dimension. Well... sadly, that means you're
			; gonna get a bad ending. 
			jsr game_end
		@carry_on_my_wayward_son:
		; oh, you were in EOD? Guess you've got one more level to play. Carry on.

	@just_go:
	lda currentLevel
	cmp #LEVEL_9_ID+1
	bne @seriously_just_go
		; Ah, you beat 9. Fine, have your lame "credits", and your silly "happy ending". I won't stop you.
		; - flowey
		jsr game_end
	@seriously_just_go:
	rts

do_end_of_level_anim:
	lda #SONG_LEVEL_END
	jsr music_play
	lda #PLAYER_VELOCITY_FALLING
	sta playerYVelocity
	lda #PLAYER_VELOCITY_NORMAL*2
	sta playerVelocity

	; Force us back to 1 bit adding instead of 32
	lda ppuCtrlBuffer
	and #%11111011
	sta ppuCtrlBuffer

	ldx #0

	@loop:
		stx tempf
		phx
		lda PLAYER_SPRITE
		cmp #SPRITE_OFFSCREEN ; If you get yanked offscreen you'll probably get killed... let's avoid that.
		beq @no_gravity
			jsr do_player_vertical_movement
		@no_gravity: 
		lda PLAYER_SPRITE+3
		clc
		adc #1
		bcc @dont_hide_1 ; Flipped over the other side? Time to continue on...
			ldy #SPRITE_OFFSCREEN
			sty PLAYER_SPRITE
			sty PLAYER_SPRITE+12
		@dont_hide_1:
		sta PLAYER_SPRITE+3
		sta PLAYER_SPRITE+15
		clc
		adc #8
		bcc @dont_hide_2
			ldy #SPRITE_OFFSCREEN
			sty PLAYER_SPRITE+4
			sty PLAYER_SPRITE+16
		@dont_hide_2:
		sta PLAYER_SPRITE+7
		sta PLAYER_SPRITE+19
		clc
		adc #8
		bcc @dont_hide_3
			ldy #SPRITE_OFFSCREEN
			sty PLAYER_SPRITE+8
			sty PLAYER_SPRITE+20
		@dont_hide_3:
		sta PLAYER_SPRITE+11
		sta PLAYER_SPRITE+23

		jsr sound_update
		jsr vblank_wait
		jsr do_sprite0
		jsr do_player_anim

		lda tempf
		cmp #END_OF_LEVEL_WAIT_TIME-$12
		bcc @no_anim
			sec
			sbc #END_OF_LEVEL_WAIT_TIME-$12
			and #%11111100
			asl
			asl
			sta temp0
			jsr do_fade_anim
			jsr do_sprite0
			reset_ppu_scrolling_and_ctrl
			jmp @first_round_only
		@no_anim:
		
		; Do it twice, animating every other tile, to make timing code simpler.
		jsr sound_update
		jsr vblank_wait
		jsr do_sprite0
		@first_round_only:

		plx
		inx
		cpx #END_OF_LEVEL_WAIT_TIME
		beq @unloop
			jmp @loop
		@unloop:

	rts

do_end_of_level_teleporter_anim:
	
	lda #SONG_LEVEL_END
	phx
	jsr music_play
	plx
	lda #0
	sta playerYVelocity
	sta playerVelocity

	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_Y, x
	sec 
	sbc #4 ; We wanna be on the thing, not overlapping it
	sta PLAYER_SPRITE
	sta PLAYER_SPRITE+4
	sta PLAYER_SPRITE+8
	clc
	adc #8
	sta PLAYER_SPRITE+12
	sta PLAYER_SPRITE+16
	sta PLAYER_SPRITE+20

	lda EXTENDED_SPRITE_DATA+SPRITE_DATA_X, x
	sec
	sbc scrollX
	clc
	adc #4
	and #%11110000
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

	lda #PLAYER_SPRITE_ID
	sta PLAYER_SPRITE+1
	clc 
	adc #1
	sta PLAYER_SPRITE+5
	adc #1
	sta PLAYER_SPRITE+9

	lda #PLAYER_SPRITE_ID+$10
	sta PLAYER_SPRITE+13
	adc #1
	sta PLAYER_SPRITE+17
	adc #1
	sta PLAYER_SPRITE+21

	ldx #0

	@loop:
		stx temp0
		phx

		jsr sound_update

		lda #END_OF_LEVEL_WAIT_TIME
		sec
		sbc temp0
		bcc @no_decrease
		sta temp0
		cmp #144
		bcs @no_decrease
		cmp #113
		bcc @black
			lda #144
			sec
			sbc temp0
			lsr
			lsr
			lsr
			and #%00000011
			asl
			asl
			asl
			asl
			sta temp0
			; Force 1-byte increment, instead of 32
			lda ppuCtrlBuffer
			and #%11111011
			sta ppuCtrlBuffer
			jsr do_fade_anim
			; Restore
			lda ppuCtrlBuffer
			ora #%00000100
			sta ppuCtrlBuffer
			reset_ppu_scrolling
			jmp @after_vbl
		@black: 
			phx
			ldx #0
			; Force 1-byte increment, instead of 32
			lda ppuCtrlBuffer
			and #%11111011
			sta ppuCtrlBuffer

			jsr vblank_wait

			set_ppu_addr $3f00
			lda #$0f
			@loop_black_pal:
				sta PPU_DATA
				inx
				cpx #32
				bne @loop_black_pal
			
			; Restore
			lda ppuCtrlBuffer
			ora #%00000100
			sta ppuCtrlBuffer
			reset_ppu_scrolling

			plx
			jmp @after_vbl
		@no_decrease:
		jsr vblank_wait
		@after_vbl:

		jsr do_sprite0

		; Do it twice, animating every other tile, to make timing code simpler.
		jsr sound_update
		jsr vblank_wait
		jsr do_sprite0

		plx
		inx
		cpx #END_OF_LEVEL_WAIT_TIME
		beq @get_out
			jmp @loop
		@get_out:

	rts

level_9_dimension_transfer:
	lda currentLevel
	cmp #LEVEL_9_ID
	beq @doit
		@escape:
		rts
	@doit:


	lda levelPosition
	cmp #250
	bcs @below_all ; There's a bug where we have negative level positions... work around that.
	cmp #193
	bcc @below_all
	lda #1
	sta hasHitLastLevelWarpThing
	lda levelPosition
	cmp #234
	bcs @go_to_normal
		; Welp, time for you to go to the dark, dark dimension...
		lda currentDimension
		cmp #DIMENSION_END_OF_DAYS
		beq @escape
		sta warpDimensionA
		lda #DIMENSION_END_OF_DAYS
		sta warpDimensionB
		jsr do_dimensional_transfer_unsafe
		lda #DIMENSION_INVALID
		sta warpDimensionA
		sta warpDimensionB
		jmp @escape

	@go_to_normal:
		lda currentDimension
		cmp #DIMENSION_PLAIN
		beq @escape
		sta warpDimensionA
		lda #DIMENSION_PLAIN
		sta warpDimensionB
		jsr do_dimensional_transfer_unsafe
		lda #DIMENSION_INVALID
		sta warpDimensionA
		sta warpDimensionB
		jmp @escape

	@below_all:

	lda hasHitLastLevelWarpThing
	cmp #0
	bne @escape

	lda frameCounter
	cmp #0
	beq @its_time_i_think
		rts
	@its_time_i_think:
	inc dimensionSwapTimer
	lda dimensionSwapTimer
	and #%00000001
	cmp #1
	beq @it_is_time
		rts
	@it_is_time:

	; Alright, time to swap dimensions on you manually...
	lda currentDimension
	cmp #DIMENSION_PLAIN
	bne @not_plain
		lda #DIMENSION_ICE_AGE
		jmp @dimension_found
	@not_plain:
	cmp #DIMENSION_ICE_AGE
	bne @not_ice
		lda #DIMENSION_BARREN
		jmp @dimension_found
	@not_ice:
	cmp #DIMENSION_BARREN
	bne @not_barren
		lda #DIMENSION_AGGRESSIVE
		jmp @dimension_found
	@not_barren:
	cmp #DIMENSION_AGGRESSIVE
	bne @not_aggressive
		lda #DIMENSION_END_OF_DAYS
		jmp @dimension_found
	@not_aggressive:
	cmp #DIMENSION_END_OF_DAYS
	bne @confused
		lda #DIMENSION_PLAIN
		jmp @dimension_found
	@confused:

	@dimension_found:
		sta warpDimensionB
		lda currentDimension
		sta warpDimensionA
		jsr do_dimensional_transfer_unsafe
		lda #DIMENSION_INVALID
		sta warpDimensionA
		sta warpDimensionB
	rts
	
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

; Little hack method you can throw somewhere to get your gem count up to the total in the game.
; WARNING: This doesn't really do it legitimately - gems will still be in some later levels, and if you
; grab them, you'll break stuff. Generally, don't use this. 
; TODO: Remove this before shipping. Please?
HACK_GIMME_ALL_GEMS:
	lda #255
	.repeat 20, I
		sta COLLECTIBLE_DATA+I
	.endrepeat
	lda #1
	sta COLLECTIBLE_DATA+21
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
	
	; Reminder: NO shared variables here. If you share them, make sure you save them before, and pop em after!
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
	.include "lib/sprites.asm"
	.include "lib/sound.asm"

	.include "lib/unpkb.asm"
	
; Putting palettes in bank 0 because we access this from a few other banks.

default_palettes: 
	; Normal
	.incbin "graphics/default.pal"
	; fire-ized
fire_palettes:
	.incbin "graphics/fire.pal"
ice_palettes:
	.incbin "graphics/ice.pal"
dark_palettes:
	.incbin "graphics/dark.pal"
desert_palettes:
	.incbin "graphics/desert.pal"


default_sprite_palettes: ; Drawn at same time as above.
	; 0) duck. 1) turtle
	.incbin "graphics/default_sprite.pal"
dark_sprite_palettes:
	.incbin "graphics/dark_sprite.pal"

menu_palettes: 
	.incbin "graphics/menu.pal" ; Chr
	.incbin "graphics/menu.pal" ; Sprite


.segment "BANK0"
banktable

.if DEBUGGING = 1
	lvldebug:
		.include "levels/lvl_debug_meta.asm"
		.include "levels/processed/lvl_debug_tiles.asm"
		.include "levels/processed/lvl_debug_sprites.asm"
.else
	LVL_DEBUG_COLLECTIBLE_COUNT = 0
.endif

lvl1:
	.include "levels/lvl1_meta.asm"
	.include "levels/processed/lvl1_tiles.asm"
	.include "levels/processed/lvl1_sprites.asm"

lvl2:
	.include "levels/lvl2_meta.asm"
	.include "levels/processed/lvl2_tiles.asm"
	.include "levels/processed/lvl2_sprites.asm"
lvl3:
	.include "levels/lvl3_meta.asm"
	.include "levels/processed/lvl3_tiles.asm"
	.include "levels/processed/lvl3_sprites.asm"
lvl4:
	.include "levels/lvl4_meta.asm"
	.include "levels/processed/lvl4_tiles.asm"
	.include "levels/processed/lvl4_sprites.asm"
lvl5:
	.include "levels/lvl5_meta.asm"
	.include "levels/processed/lvl5_tiles.asm"
	.include "levels/processed/lvl5_sprites.asm"
lvl6:
	.include "levels/lvl6_meta.asm"
	.include "levels/processed/lvl6_tiles.asm"
	.include "levels/processed/lvl6_sprites.asm"
lvl7:
	.include "levels/lvl7_meta.asm"
	.include "levels/processed/lvl7_tiles.asm"
	.include "levels/processed/lvl7_sprites.asm"
lvl8:
	.include "levels/lvl8_meta.asm"
	.include "levels/processed/lvl8_tiles.asm"
	.include "levels/processed/lvl8_sprites.asm"
lvl9:
	.include "levels/lvl9_meta.asm"
	.include "levels/processed/lvl9_tiles.asm"
	.include "levels/processed/lvl9_sprites.asm"



leveldata_table:
	.if DEBUGGING = 1 
		.word lvldebug
	.endif
	.word lvl1, lvl2, lvl3, lvl4, lvl5, lvl6, lvl7, lvl8, lvl9

GAME_GEM_TOTAL = LVL_DEBUG_COLLECTIBLE_COUNT + LVL1_COLLECTIBLE_COUNT + LVL2_COLLECTIBLE_COUNT + LVL3_COLLECTIBLE_COUNT + LVL4_COLLECTIBLE_COUNT + LVL5_COLLECTIBLE_COUNT + LVL6_COLLECTIBLE_COUNT + LVL7_COLLECTIBLE_COUNT + LVL8_COLLECTIBLE_COUNT + LVL9_COLLECTIBLE_COUNT



	
	
.segment "CHUNK"
	; Nothing here. Just reserving it...
	.byte $ff

.segment "BANK1"
banktable

.include "sound/famitone2.s"

all_music: 
	.include "sound/music.s"

all_sfx: 
	.include "sound/sfx.s"

default_chr:
	.incbin "graphics/map_tiles.chr"
	
default_sprite_chr:
	.incbin "graphics/processed/sprites.chr.pkb"

menu_chr_data: 
	.incbin "graphics/processed/title_tiles.chr.pkb"


.segment "BANK2"
banktable

.include "lib/text.asm"
.include "lib/title.asm"
.include "lib/ending.asm"


; Okay, this is messy. Plain and simple. Running up against the deadline, and I hit the limitation on the size of my kernel bank.
; So... to avoid having to refactor, well, everything, I'm sticking a few things that are easily separated into bank 3.
.include "lib/gem_data.asm"



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