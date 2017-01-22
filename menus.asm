TITLE_CURSOR_X_OFFSET = 32
TITLE_CURSOR_Y_OFFSET = 78

load_menu: 

	; Reset scrolling to 0
	lda #0
	sta scrollX
	sta scrollY
	; Make sure we're not writing every 32nd byte rather than every single one, and force back to nametable 0
	lda ppuCtrlBuffer
	and #%11111000
	sta ppuCtrlBuffer
	jsr vblank_wait

	lda ppuMaskBuffer
	and #%11110111
	sta ppuMaskBuffer ; Stop rendering sprites

	; Hide all sprites
	ldx #0
	lda #SPRITE_OFFSCREEN
	@sprite_loop: 
		sta SPRITE_DATA, x
		.repeat 4
			inx
		.endrepeat
		cpx #0
		bne @sprite_loop

	jsr disable_all
	jsr vblank_wait
	ldy #0
	set_ppu_addr $3f00
	@palette_loop:
		lda menu_palettes, y
		sta PPU_DATA
		iny
		cpy #$20
		bne @palette_loop
	bank #BANK_CHR
	set_ppu_addr $0000
	store #<(menu_chr_data), tempAddr
	store #>(menu_chr_data), tempAddr+1
	jsr PKB_unpackblk

	store #<(default_sprite_chr), tempAddr
	store #>(default_sprite_chr), tempAddr+1
	jsr PKB_unpackblk
	bank #BANK_SPRITES_AND_LEVEL

	; wipe out the nametable so we don't have any leftovers.
	set_ppu_addr $2000
	ldx #0
	ldy #0
	lda #0
	@nametable_loop:
		sta PPU_DATA
		iny
		cpy #$c0
		bne @nametable_loop
		inx
		inc tempAddr+1
		cpx #4
		bne @nametable_loop

	ldy #0
	;set_ppu_addr $23c0
	lda #0
	@clear_attributes:
		sta PPU_DATA
		iny
		cpy #$40
		bne @clear_attributes

	reset_ppu_scrolling
	rts
	
load_title:
	jsr load_menu

	lda #SONG_TITLE
	jsr music_play

	bank_temp #BANK_TEXT_ENGINE
		jsr load_title_text
	bank_restore

	lda GAME_BEATEN_BYTE
	cmp #0
	bne @gems
	jmp load_title_no_gems
	@gems:
		; Show gem count and level select if you've beaten the game once.
		write_string .sprintf("Gems: "), $20e8

		jsr get_game_gem_count
		draw_current_digit
		lda temp1
		draw_current_num

		lda #CHAR_SPACE
		sta PPU_DATA
		lda #NUM_SYM_TABLE_START+$b
		sta PPU_DATA
		lda #CHAR_SPACE
		sta PPU_DATA 


		jsr get_game_gem_total
		draw_current_digit
		lda tempc
		draw_current_num

		; Quick and dirty in-place macro to draw gem count based on the level.
		.macro draw_gem_count I, baseCount
			.local BINARY_COUNT, BINARY_TOTAL
			BINARY_TOTAL = ((I .mod 10) + (I / 10) * 16)

			lda baseCount
			draw_current_num
			lda #CHAR_SPACE
			sta PPU_DATA
			lda #NUM_SYM_TABLE_START+$b
			sta PPU_DATA
			lda #CHAR_SPACE
			sta PPU_DATA
			lda #BINARY_TOTAL
			draw_current_num

		.endmacro

		; NOTE: We're depending on the return value of get_level_gem_count being in temp1 here.
		.repeat NUMBER_OF_REGULAR_LEVELS, I
			.if I = 0 && DEBUGGING = 1
				; Debugging level gets a special case, since we want level numbers to match with/without debugging.
				write_string .sprintf("Level DD  "), $2146+I*$20
				lda #I
				jsr get_level_gem_count
				draw_gem_count LVL_DEBUG_COLLECTIBLE_COUNT, temp1
			.elseif DEBUGGING = 1
				; Unfortunately since we added a special debugging level, we need separate logic for showing level numbers based on that.
				write_string .sprintf("Level %02d  ", I), $2146+I*$20
				lda #I
				jsr get_level_gem_count
				draw_gem_count (.ident(.concat("LVL",.string(I),"_COLLECTIBLE_COUNT"))), temp1
			.else
				write_string .sprintf("Level %02d  ", I+1), $2146+I*$20
				lda #I
				jsr get_level_gem_count
				draw_gem_count (.ident(.concat("LVL",.string(I+1),"_COLLECTIBLE_COUNT"))), temp1
			.endif
		.endrepeat


	load_title_no_gems:
	
	jsr enable_all
	reset_ppu_scrolling
	rts

show_title: 
	jsr load_menu
	bank #BANK_INTRO
		jsr show_intro
	bank #BANK_SPRITES_AND_LEVEL

	jsr load_title
	lda #0
	sta temp5 ; Cursor offset if you have level select enabled.
	
	@loopa: 
		jsr sound_update
		jsr read_controller
		
		jsr vblank_wait
		
		; Check for start button...

		; Make sure we don't count keypresses from last cycle.
		lda lastCtrlButtons
		eor #$ff ; flip the bits.
		and ctrlButtons
		
		and #CONTROLLER_START
		bne @game_time

		lda GAME_BEATEN_BYTE
		cmp #0
		beq @no_level_select

			lda ctrlButtons
			and #CONTROLLER_UP
			beq @no_up
				lda lastCtrlButtons
				and #CONTROLLER_UP
				bne @no_up
				lda temp5
				cmp #0
				beq @no_up
				dec temp5
				lda #SFX_MENU
				ldx #FT_SFX_CH0
				jsr sfx_play
			@no_up:
			lda ctrlButtons
			and #CONTROLLER_DOWN
			beq @no_down
				lda lastCtrlButtons
				and #CONTROLLER_DOWN
				bne @no_down
				lda temp5
				cmp #NUMBER_OF_REGULAR_LEVELS-1
				bcs @no_down
				inc temp5
				lda #SFX_MENU
				ldx #FT_SFX_CH0
				jsr sfx_play

			@no_down:

			lda #SPRITE_POINTER
			sta VAR_SPRITE_DATA+1
			lda temp5
			asl
			asl
			asl ; multiply offset by 8
			adc #TITLE_CURSOR_Y_OFFSET
			sta VAR_SPRITE_DATA
			lda #TITLE_CURSOR_X_OFFSET
			sta VAR_SPRITE_DATA+3
			lda #0
			sta VAR_SPRITE_DATA+2
		@no_level_select:

		jmp @loopa
	@game_time: 
		lda temp5
		sta currentLevel
		lda #SFX_MENU
		ldx #FT_SFX_CH0
		jsr sfx_play

		jmp show_ready


load_ready:
	jsr load_menu

	write_string "Ready!", $218b

	reset_ppu_scrolling
	jsr enable_all
	rts

show_ready:
	lda #1
	jsr music_pause
	jsr load_ready

	lda #0
	sta scrollX
	sta scrollY
	ldx #0
	@loopa: 
		txa
		pha
		; Not really doing anything... just makes it look less like we're locked for frames. Could easily be ditched.
		jsr read_controller
		jsr sound_update
		reset_ppu_scrolling
		jsr vblank_wait
		reset_ppu_scrolling
		pla
		tax
		inx
		cpx #READY_TIME
		bne @loopa

	game_time: 
		jmp show_level



game_end:
	
	; Clear out buttons in case you already hit start for some screwy reason.
	lda #0
	sta ctrlButtons
	sta lastCtrlButtons
	sta scrollX
	sta scrollY
	jsr load_menu

	bank #BANK_INTRO

	lda currentDimension
	cmp #DIMENSION_END_OF_DAYS
	bne @bad_ending
		jmp show_good_ending
	@bad_ending:
		jmp show_bad_ending

/*
	; Alignment test... quotes contain 30 spaces (assuming a 1 tile border)
	; __________ "                              "
	write_string "Congratulations!", $2047
	write_string "You have completed Waddles the", $20a1
	write_string "Duck. You must be awesome!", $20c1
	write_string "Created as part of", $2121
	write_string "The 2016 NESDEV Compo", $2141
	write_string "code/art/music by: cppchriscpp", $21a1
	write_string "Inspired by Eversion", $2201
	write_string "Thanks for playing!", $22a6
	write_string "No ducks were harmed in the", $2362
	write_string "Making of this game", $2382
	jsr enable_all
	jsr vblank_wait

	; TODO: I need some ducks man (Add some sprites, or otherwise pretty this up. Make the thank you look nicer, if nothing else!)
	; TODO: Ending theme
	; TODO: Colorize?
	@loop:
		jsr read_controller
		jsr sound_update
		reset_ppu_scrolling
		jsr vblank_wait
		reset_ppu_scrolling

		; Make sure we don't count keypresses from last cycle.
		lda lastCtrlButtons
		eor #$ff ; flip the bits.
		and ctrlButtons
		
		and #CONTROLLER_START
		bne @go_reset
		jmp @loop


	@go_reset:
		jmp reset ; Welp, it was nice knowing you...
		*/