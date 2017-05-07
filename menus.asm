TITLE_CURSOR_X_OFFSET = 42
TITLE_CURSOR_Y_OFFSET = 102

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

	reset_ppu_scrolling_and_ctrl
	rts
	
load_title:
	jsr load_menu

	lda #SONG_TITLE
	jsr music_play
	store #0, titleNoWarpVal

	set_ppu_addr $2000
	store #<(title_screen_base), tempAddr
	store #>(title_screen_base), tempAddr+1
	jsr PKB_unpackblk
	
	.if SHOW_VERSION_STRING = 1
		write_string .sprintf("Version %04s Build %05d", VERSION, BUILD), $2321
		write_string .sprintf("Built on: %24s", BUILD_DATE), $2341
		write_string SPLASH_MESSAGE, $2381, $1e
	.else 
		write_string COPYRIGHT, $2361, $1e
	.endif

	.if DEBUGGING = 1
		write_string .sprintf("Debug enabled"), $2301
	.endif

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
				write_string .sprintf("Level DD  "), $21a7+I*$20
				lda #I
				jsr get_level_gem_count
				draw_gem_count LVL_DEBUG_COLLECTIBLE_COUNT, temp1
			.elseif DEBUGGING = 1
				; Unfortunately since we added a special debugging level, we need separate logic for showing level numbers based on that.
				write_string .sprintf("Level %02d  ", I), $21a7+I*$20
				lda #I
				jsr get_level_gem_count
				draw_gem_count (.ident(.concat("LVL",.string(I),"_COLLECTIBLE_COUNT"))), temp1
			.else
				write_string .sprintf("Level %02d  ", I+1), $21a7+I*$20
				lda #I
				jsr get_level_gem_count
				draw_gem_count (.ident(.concat("LVL",.string(I+1),"_COLLECTIBLE_COUNT"))), temp1
			.endif
			.if ACTION53
				jsr MAIN_draw_menu_extras
			.endif
		.endrepeat
		jmp after_no_gems


	load_title_no_gems:
		.if ACTION53
			jsr MAIN_draw_a53_no_levelsel
		.else
			jsr MAIN_draw_no_levelsel
		.endif
	after_no_gems:
	reset_ppu_scrolling_and_ctrl
	jsr vblank_wait
	jsr enable_all
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

		and #CONTROLLER_START+CONTROLLER_A
		beq @dododo
			jmp @game_time
		@dododo:

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
				.if ACTION53
					cmp #(NUMBER_OF_REGULAR_LEVELS+1)
					bne @no_special
						dec temp5 ; Second dec for action53
					@no_special:
				.endif
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
				.if ACTION53
					cmp #NUMBER_OF_REGULAR_LEVELS-1
					beq @exitopt
					bcs @no_down
					jmp @after_exitopt
					@exitopt:
					inc temp5 ; Extra add for action53 jump
					@after_exitopt:
				.else
					cmp #NUMBER_OF_REGULAR_LEVELS-1
					bcs @no_down
				.endif
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
			jmp @after_level_select
		@no_level_select:
			.if ACTION53
				lda ctrlButtons
				and #CONTROLLER_UP
				beq @no_upb
					lda lastCtrlButtons
					and #CONTROLLER_UP
					bne @no_upb
					lda titleNoWarpVal
					cmp #0
					beq @no_upb
					store #0, titleNoWarpVal
					lda #SFX_MENU
					ldx #FT_SFX_CH0
					jsr sfx_play
				@no_upb:
				lda ctrlButtons
				and #CONTROLLER_DOWN
				beq @no_downb
					lda lastCtrlButtons
					and #CONTROLLER_DOWN
					bne @no_downb
					lda titleNoWarpVal
					cmp #1
					beq @no_downb
					store #1, titleNoWarpVal
					lda #SFX_MENU
					ldx #FT_SFX_CH0
					jsr sfx_play
				@no_downb:
				lda #SPRITE_POINTER
				sta VAR_SPRITE_DATA+1
				lda titleNoWarpVal
				asl
				asl
				asl ; multiply offset by 8
				asl
				adc #TITLE_CURSOR_Y_OFFSET+8
				sta VAR_SPRITE_DATA
				lda #TITLE_CURSOR_X_OFFSET+24
				sta VAR_SPRITE_DATA+3
				lda #0
				sta VAR_SPRITE_DATA+2


			.endif
		@after_level_select:

		jmp @loopa
	@game_time: 
		.if ACTION53
			lda titleNoWarpVal
			cmp #1
			bne @no_exit
				jmp reset_to_action53
		@no_exit:
		.endif

		lda temp5
		.if ACTION53
			cmp #NUMBER_OF_REGULAR_LEVELS+1
			bne @doit
				; If you selected to go back to a53, we'll send ya...
				jmp reset_to_action53
			@doit:
		.endif
		sta currentLevel
		lda #SFX_MENU
		ldx #FT_SFX_CH0
		jsr sfx_play

		jmp show_ready


.if ACTION53 = 1
reset_to_action53:
	; NOTE: Code borrowed/ripped-off from exitpatch.py in the A53 menu tools.
	sei
	ldx #11
	@loop:
		lda @cpsrc,x
		sta $F0,x
		dex
		bpl @loop
		; X = $FF at end
		ldy #$80
		sty $5000
		lda #$00
		iny
		jmp $00F0
	@cpsrc:
		sta $8000
		sty $5000
		stx $8000
		jmp ($FFFC)

.endif

load_ready:
	jsr load_menu

	write_string "Ready!", $218b

	reset_ppu_scrolling_and_ctrl
	jsr vblank_wait
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
		reset_ppu_scrolling_and_ctrl
		jsr vblank_wait
		reset_ppu_scrolling_and_ctrl
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

	lda currentLevel
	cmp #LEVEL_9_ID+1
	bne @bad_ending
		jmp show_good_ending
	@bad_ending:
		jmp show_bad_ending



title_screen_base:
	.incbin "graphics/processed/title_screen.nam.pkb"