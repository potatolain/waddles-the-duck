show_hud: 
	; This could be cleaner with loops... but it's not that many instructions so this might be ok too.
	set_ppu_addr $2000
	lda #TILE_HUD_BLANK
	.repeat $20
		sta PPU_DATA
	.endrepeat
	
	store #TILE_BORDER_TL, PPU_DATA
	lda #TILE_BORDER_T
	.repeat $1e
		sta PPU_DATA
	.endrepeat
	store #TILE_BORDER_TR, PPU_DATA
	.repeat 3
		store #TILE_BORDER_L, PPU_DATA
		lda #TILE_HUD_BLANK
		.repeat $1e
			sta PPU_DATA
		.endrepeat
		store #TILE_BORDER_R, PPU_DATA
	.endrepeat

	store #TILE_BORDER_BL, PPU_DATA
	lda #TILE_BORDER_B
	.repeat $1e
		sta PPU_DATA
	.endrepeat
	store #TILE_BORDER_BR, PPU_DATA
	
	rts