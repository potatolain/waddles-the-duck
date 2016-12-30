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
	
	rts

update_hud_gem_count: 

	set_ppu_addr $2041
	lda #GAME_TILE_A+6 ; G
	sta PPU_DATA
	lda #GAME_TILE_A+4 ; E
	sta PPU_DATA
	lda #GAME_TILE_A+12 ; M
	sta PPU_DATA
	lda #GAME_TILE_A+18 ; S
	sta PPU_DATA
	lda #GAME_TILE_0-3
	STA PPU_DATA
	lda #0
	sta PPU_DATA
	
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