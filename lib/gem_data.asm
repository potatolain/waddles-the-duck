banked_update_gem_count:
	phxy
	lda currentLevel
	asl
	asl
	tay
	lda #0
	sta gemCount
	.repeat 4
		ldx #0
		lda COLLECTIBLE_DATA, y
		: ; No name loop label (No names for labels in this section because we're in a repeat, and we don't want names to collide)
			asl ; (There's likely a smarter way to do this, but this works. If you see this and are facepalming at it, submit a PR to fix it!)
			pha
			lda gemCount
			adc #0 ; We're really just using the value of the carry for each bit. asl drops it in.
			sta gemCount
			and #%00001111
			cmp #$a
			bne :+
				; If we hit 10, bounce up, just like non-hex numbers. Just... drop the hexxy bits.
				lda gemCount
				clc
				adc #6
				sta gemCount
			: ; No name end of section label 
			
			pla

			inx
			cpx #8
			bne :--
		iny
	.endrepeat
	plxy
	rts

; Tricky method to write the gem count in level 8.
banked_override_gem_numbers_in_row:
	lda currentLevel
	cmp #LEVEL_8_ID
	bne @leave
		lda levelPosition
		cmp #16
		bcc @leave
		cmp #20
		bcs @leave
		lda levelPosition
		cmp #16
		bne @not_first
			lda gameGemCountCache+1
			and #%00001111
			clc
			adc #GAME_TILE_0
			sta NEXT_ROW_CACHE+10

			lda gameGemCountCache
			.repeat 4
				lsr
			.endrepeat
			clc
			adc #GAME_TILE_0
			sta NEXT_ROW_CACHE+42
			jmp @leave
		@not_first:
		cmp #17
		bne @not_second
			lda gameGemCountCache
			and #%00001111
			clc
			adc #GAME_TILE_0
			sta NEXT_ROW_CACHE+10

			lda #GAME_TILE_0-2
			sta NEXT_ROW_CACHE+42
			jmp @leave
		@not_second:
		cmp #18
		bne @not_third
			jsr get_game_gem_total
			lda tempd
			and #%00001111
			clc
			adc #GAME_TILE_0
			sta NEXT_ROW_CACHE+10
			lda tempc
			.repeat 4
				lsr 
			.endrepeat
			clc
			adc #GAME_TILE_0
			sta NEXT_ROW_CACHE+42
			jmp @leave
		@not_third:
		cmp #19
		bne @ummm_what
			jsr get_game_gem_total
			lda tempc
			and #%00001111
			clc
			adc #GAME_TILE_0
			sta NEXT_ROW_CACHE+10
			; Second digit isn't used.
		@ummm_what:



	@leave:
	nop
	rts