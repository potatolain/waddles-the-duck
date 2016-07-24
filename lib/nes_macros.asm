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

	lda #1
	sta graphicsState
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
		.elseif (char >= '1' .and char <= '9') ; numbers (non-zero)
			char .set .strat(text, I) - $31 + NUM_SYM_TABLE_START
		.elseif (char = '0') ; zero (same as letter O to save space)
			char .set CHAR_TABLE_START + $0e
		.elseif (char = '.')
			char .set CHAR_TABLE_START+$1b
		.elseif (char = ':')
			char .set NUM_SYM_TABLE_START + $09
		.elseif (char = '/')
			char .set NUM_SYM_TABLE_START + $0a
		.elseif (char = '!')
			char .set NUM_SYM_TABLE_START + $0b
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
		.else; (char = $20) ; space
			char .set CHAR_SPACE
		.endif
		
		lda #char
		sta PPU_DATA
	.endrepeat 
.endmacro