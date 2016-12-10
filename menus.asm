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

	store #<(menu_chr_data), tempAddr
	store #>(menu_chr_data), tempAddr+1
	ldx #0
	ldy #0
	set_ppu_addr $0000
	@title_loop:
		lda (tempAddr), y
		sta PPU_DATA
		iny
		cpy #0
		bne @title_loop
		inx
		inc tempAddr+1
		cpx #$10
		bne @title_loop
		
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

	write_string "No Name 2016", $2066
	write_string "NESDev Compo Entry", $20a6
	
	.if SHOW_VERSION_STRING = 1
		set_ppu_addr $2320
		ldx #$80
		lda #$ff
		@loop_clear: 
			sta PPU_DATA
			dex
			cpx #$0
			bne @loop_clear

		write_string .sprintf("Version %04s Build %05d", VERSION, BUILD), $2321
		write_string .sprintf("Built on: %24s", BUILD_DATE), $2341
		write_string SPLASH_MESSAGE, $2361, $1e
	.endif

	.if DEBUGGING = 1
		set_ppu_addr $2300
		ldx #$20
		lda #$ff
		@loop_clear2:
			sta PPU_DATA
			dex
			cpx #0
			bne @loop_clear2
		
		write_string .sprintf("Debug mode enabled"), $2301, 
	.endif
	
	jsr enable_all
	reset_ppu_scrolling
	rts

show_title: 
	jsr load_title
	
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

		jmp @loopa
	@game_time: 
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
	write_string "Making of this NES game", $2382
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