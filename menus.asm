load_menu: 
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
		
	ldy #0
	set_ppu_addr $23c0
	lda #0
	@clear_attributes:
		sta PPU_DATA
		iny
		cpy #$40
		bne @clear_attributes
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
	
	jsr enable_all
	reset_ppu_scrolling
	rts

show_title: 
	jsr load_title
	
	@loopa: 
		jsr FamiToneUpdate
		jsr read_controller
		
		; Check for start button...

		; Make sure we don't count keypresses from last cycle.
		lda lastCtrlButtons
		eor #$ff ; flip the bits.
		and ctrlButtons
		
		and #CONTROLLER_START
		bne @game_time
		jsr vblank_wait
		jmp @loopa
	@game_time: 
		lda #SFX_MENU
		ldx #FT_SFX_CH0
		jsr FamiToneSfxPlay
		jmp show_level