.macro set_ppu_addr addr
	lda PPU_STATUS
	lda #>(addr)
	sta PPU_ADDR
	lda #<(addr)
	sta PPU_ADDR
.endmacro

.macro reset_ppu_scrolling

	lda PPU_STATUS
	store scrollX, PPU_SCROLL
	store scrollY, PPU_SCROLL
.endmacro

.macro reset_ppu_scrolling_and_ctrl
	reset_ppu_scrolling
	lda ppuCtrlBuffer
	sta PPU_CTRL
.endmacro


.macro store_ppu_data aa, bb, cc, dd, ee, ff, gg, hh, ii, jj, kk, ll, mm, nn, oo, pp, qq, rr, ss, tt, uu, vv, ww, xx, yy, zz
	.ifblank aa
		.exitmacro
	.else 
		lda aa
		sta PPU_DATA
	.endif
	store_ppu_data bb, cc, dd, ee, ff, gg, hh, ii, jj, kk, ll, mm, nn, oo, pp, qq, rr, ss, tt, uu, vv, ww, xx, yy, zz
.endmacro

.macro store data, addr
	lda data
	sta addr
.endmacro


; Write a *static* string to the PPU. Will wrap it around if needed. 
.macro write_string text, location, wraplen
	wrap .set $20
	.ifnblank wraplen
		wrap .set wraplen
	.endif
	lda PPU_STATUS
	lda #>(location)
	sta PPU_ADDR
	lda #<(location)
	sta PPU_ADDR
	lastchar .set '|'
	.repeat .strlen(text), I
		; This actually never fires properly. Wrapping needs to be fixed.
		.if ((I .mod wrap) = (wrap))
			lda PPU_STATUS
			lda #>(location+($20 * ((I+1)/wrap)))
			sta PPU_ADDR
			lda #<(location+($20 * ((I+1)/wrap)))
			sta PPU_ADDR
		.endif
		
		char .set .strat(text, I)
		.if (char > $40 .and char < $5b) ; uppercase
			char .set .strat(text, I) - $41 + CHAR_TABLE_START
		.elseif (char >= 'a' .and char <= 'z') ; lowercase
			char .set .strat(text, I) - $61 + CHAR_TABLE_START
		.elseif (char >= '0' .and char <= '9') ; numbers (non-zero)
			char .set .strat(text, I) - $30 + NUM_SYM_TABLE_START
		.elseif (char = '.')
			char .set CHAR_TABLE_START+$1b
		.elseif (char = ':')
			char .set NUM_SYM_TABLE_START + $0a
		.elseif (char = '/')
			char .set NUM_SYM_TABLE_START + $0b
		.elseif (char = '!')
			char .set NUM_SYM_TABLE_START + $0c
		.elseif (char = '=')
			char .set NUM_SYM_TABLE_START + $0d
		.elseif (char = '?')
			char .set NUM_SYM_TABLE_START + $0e
		.elseif (char = '^')
			char .set CHAR_TABLE_START + $1d
		.elseif (char = '_')
			char .set CHAR_TABLE_START + $1e
		.elseif (char = '[' .or char = '(')
			char .set CHAR_TABLE_START+$1a
		.elseif (char = ']' .or char = ')')
			char .set CHAR_TABLE_START+$1c
		.elseif (char = '$')
			char .set NUM_SYM_TABLE_START+$f
		.elseif (char = 34) ; Double quote
			char .set NUM_SYM_TABLE_START+$d
		.elseif (char = '`') ; Heart
			char .set $ce
		.else; (char = $20) ; space
			char .set CHAR_SPACE
		.endif
		
		.if (char <> lastchar)
			lda #char
		.endif
		lastchar .set char
		sta PPU_DATA
	.endrepeat 
.endmacro

.macro phx
	sta macroTmp
	txa
	pha
	lda macroTmp
.endmacro

.macro phy
	sta macroTmp
	tya
	pha
	lda macroTmp
.endmacro

.macro plx
	sta macroTmp
	pla
	tax
	lda macroTmp
.endmacro

.macro ply
	sta macroTmp
	pla
	tay
	lda macroTmp
.endmacro

.macro phxy
	sta macroTmp
	txa
	pha
	tya
	pha
	lda macroTmp
.endmacro

.macro plxy
	sta macroTmp
	pla
	tay
	pla
	tax
	lda macroTmp
.endmacro

.macro bank_temp banknum
	tya
	pha
	
	lda banknum
	clc
	adc #<(BANK_SWITCH_ADDR)
	sta macroTmp
	lda #>(BANK_SWITCH_ADDR)
	sta macroTmp+1

	lda banknum
	ldy #0
	sta (macroTmp), y

	pla
	tay
.endmacro

.macro bank banknum
	pha
	lda banknum
	sta currentBank
	pla
	bank_temp banknum
.endmacro

.macro bank_restore
	bank_temp currentBank
.endmacro

; UxROM has a weird restriction where the value of the byte you write to must match the value of the byte itself.
; As a result, we need to stick this in all banks slated for $8000
.macro banktable
  .byte $00, $01, $02, $03, $04, $05, $06
.endmacro

.macro draw_current_digit
	and #%00001111
	clc
	adc #NUM_SYM_TABLE_START
	sta PPU_DATA
.endmacro

.macro draw_current_num
	sta macroTmp
	.repeat 4
		lsr
	.endrepeat
	clc
	adc #NUM_SYM_TABLE_START
	sta PPU_DATA
	lda macroTmp
	and #%00001111
	clc
	adc #NUM_SYM_TABLE_START
	sta PPU_DATA

.endmacro

.macro write_ppu_text text ; Using the text on a regular screen, draw the given text to PPU_DATA character by character

	; With how frequently we use this, it seems to confuse ca65 with the number of named local labels. 
	; As a result, we use unnamed labels.
	jmp :++
	:
	.repeat .strlen(text), I
		char .set .strat(text, I)
		.if (char > $40 .and char < $5b) ; uppercase
			char .set .strat(text, I) - $41 + GAME_TILE_A
		.elseif (char >= 'a' .and char <= 'z') ; lowercase
			char .set .strat(text, I) - $61 + GAME_TILE_A
		.elseif (char >= '0' .and char <= '9') ; numbers (non-zero)
			char .set .strat(text, I) - $30 + GAME_TILE_0
		.elseif (char = '.')
			char .set GAME_TILE_0 - 1
		.elseif (char = ',')
			char .set GAME_TILE_0 - 20 ; Comma's in a bit of weird spot...
		.elseif (char = ':')
			char .set GAME_TILE_0 - 3
		.elseif (char = '/')
			char .set GAME_TILE_0 - 2
		.elseif (char = '!')
			char .set GAME_TILE_0 - 21
		.elseif (char = '?')
			char .set GAME_TILE_0 - 5
		.elseif (char = '-')
			char .set GAME_TILE_0 - 18
		.elseif (char = $27)
			char .set GAME_TILE_0 - 6
		.else; (char = $20) ; space
			char .set GAME_TILE_0-13
		.endif
		
		.byte char
	.endrepeat

	:
	phx
	ldx #0
	:
		lda :---, x
		sta PPU_DATA
		inx
		cpx #.strlen(text)
		bne :-
	plx

.endmacro


.macro beq16 num, var, location
	lda #<(num)
	cmp var
	beq location
	lda #>(num)
	cmp var+1
	beq location
.endmacro

.macro bne16 num, var, location
	lda #<(num)
	cmp var
	bne location
	lda #>(num)
	cmp var+1
	bne location
.endmacro

.macro bcc16 num, var, location
	.local @bigger
	lda #>(num)
	cmp var+1
	bcc location
	bcs @bigger
	lda #<(num)
	cmp var
	bcc location
	@bigger:
.endmacro

.macro bcs16 num, var, location
	.local @smaller
	lda #>(num)
	cmp var+1
	bcs location
	bcc @smaller
	lda #<(num)
	cmp var
	bcs location
	@smaller:
.endmacro