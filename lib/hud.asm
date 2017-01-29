show_hud: 
	; This could be cleaner with loops... but it's not that many instructions so this might be ok too.
	set_ppu_addr $2000
	
	.repeat 3
		lda #TILE_HUD_BLANK
		.repeat $20
			sta PPU_DATA
		.endrepeat
	.endrepeat

	store #TILE_BORDER_BL, PPU_DATA
	lda #TILE_BORDER_B
	.repeat $1e
		sta PPU_DATA
	.endrepeat
	store #TILE_BORDER_BR, PPU_DATA

	set_ppu_addr $23c0
	lda #%01010101
	.repeat $8
		sta PPU_DATA
	.endrepeat
	reset_ppu_scrolling
	
	rts

hide_hud_gem_count:
	
	set_ppu_addr $2059
	lda #TILE_HUD_BLANK
	.repeat 6
		sta PPU_DATA
	.endrepeat

	lda #SPRITE_OFFSCREEN
	sta HUD_GEM_SPRITE
	rts

update_hud_gem_count: 
	
	lda currentLevel
	cmp #LEVEL_9_ID
	beq hide_hud_gem_count ; uhoh! We shouldn't do this... go do your thing.
	lda currentDimension
	cmp #DIMENSION_END_OF_DAYS
	beq hide_hud_gem_count

	set_ppu_addr $2059

	lda #GAME_TILE_0-22
	sta PPU_DATA

	jsr draw_hud_gem

	lda gemCount ; left digit
	.repeat 4
		lsr
	.endrepeat
	clc
	adc #GAME_TILE_0
	sta PPU_DATA

	lda gemCount ; right digit
	and #%00001111
	clc
	adc #GAME_TILE_0
	sta PPU_DATA 

	lda #GAME_TILE_0-2
	sta PPU_DATA

	lda totalGemCount
	.repeat 4
		lsr
	.endrepeat
	clc
	adc #GAME_TILE_0
	sta PPU_DATA

	lda totalGemCount
	and #%00001111
	clc
	adc #GAME_TILE_0
	sta PPU_DATA

	rts

; NOTE: This is used very rarely, so we cheat and put this all on one nametable. 
; Any instance of chatter must be aligned with $2000 as a result.
show_bottom_hud:
	; Force the screen to scroll position 0. 
    lda scrollX
    pha
    lda #0
    sta scrollX

	lda ppuCtrlBuffer
	pha
	; Force vram increment to 0, nametable to 0
	and #%11111000
	;ora #%00000000
	sta ppuCtrlBuffer


	.repeat 4, I
		jsr vblank_wait
		set_ppu_addr $2300+(I*$40)
		lda PPU_DATA ; 1 read to flush the data that's already in...
		ldx #0
		:
			lda PPU_DATA
			sta HUD_TEXT_BACKUP+(I*$40), x
			inx
			cpx #$40
			bne :-
		reset_ppu_scrolling_and_ctrl
		jsr do_sprite0
		jsr sound_update
	.endrepeat
	jsr vblank_wait
	
	bank #BANK_TEXT_ENGINE
		jsr show_professor_text
	bank #BANK_SPRITES_AND_LEVEL
	
	pla
	sta ppuCtrlBuffer
	pla
	sta scrollX

	rts

draw_hud_gem:
	lda #194
	sta HUD_GEM_SPRITE+3
	lda #15
	sta HUD_GEM_SPRITE
	lda #0
	sta HUD_GEM_SPRITE+2
	lda #2
	sta HUD_GEM_SPRITE+1
	rts