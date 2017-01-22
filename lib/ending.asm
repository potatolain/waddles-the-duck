/* 
 * WARNING: This file is the eptimome of deadline-induced bad practice.. while this definitely works, 
 * it is far from elegant code, and is probably hard to read. You're welcome to use it as an example,
 * but I strongly suggest looking elsewhere. You have been warned.
 */

.macro draw_ending_screen num
	set_ppu_addr $2000
	store #<(.ident(.concat("ending_tile_", .string(num)))), tempAddr
	store #>(.ident(.concat("ending_tile_", .string(num)))), tempAddr+1
	jsr PKB_unpackblk

	jsr clear_sprites
	store #<(.ident(.concat("ending_sprites_", .string(num)))), tempAddr
	store #>(.ident(.concat("ending_sprites_", .string(num)))), tempAddr+1
	jsr draw_title_sprites
.endmacro

.macro draw_ending_text_only num
	set_ppu_addr $21c0
	store #<(.ident(.concat("ending_tile_", .string(num)))), tempAddr
	store #>(.ident(.concat("ending_tile_", .string(num)))), tempAddr+1
	jsr PKB_unpackblk

	jsr clear_sprites
	store #<(.ident(.concat("ending_sprites_", .string(num)))), tempAddr
	store #>(.ident(.concat("ending_sprites_", .string(num)))), tempAddr+1
	jsr draw_title_sprites
.endmacro

.macro draw_screen name
	set_ppu_addr $2000
	store #<(name), tempAddr
	store #>(name), tempAddr+1
	jsr PKB_unpackblk
.endmacro



show_good_ending: 
	jmp reset ; Welp, it was nice knowing you...

show_bad_ending:
	lda #SONG_BAD_ENDING
	jsr music_play

	lda #%11001000
	sta ppuCtrlBuffer
	lda #0
	sta scrollX
	sta scrollY
	reset_ppu_scrolling_and_ctrl

	lda #MENU_PALETTE_ID
	sta currentPalette

	lda #$0f
	sta currentBackgroundColorOverride

	lda #0 ; High-resolution timer for events... tempe = lo, tempf = hi
	sta tempe
	sta tempf 

	draw_ending_screen 1

	set_ppu_addr $3f00
	lda #0
	ldx #0
	@loop_pal:
		sta PPU_DATA
		inx
		cpx #32
		bne @loop_pal


	reset_ppu_scrolling_and_ctrl
	jsr vblank_wait

	jsr vblank_wait
	jsr enable_all

	jsr do_menu_fade_in


	@loop:
		jsr sound_update
		jsr read_controller

		inc tempe
		lda #0
		cmp tempe
		bne @no_increment
			inc tempf
		@no_increment:
		
		jsr vblank_wait


		bne16 289, tempe, @not_1st_fadeout
			jsr do_menu_fade_out
		@not_1st_fadeout:
		; Look up where in the cycle we are and if we need to take action.
		bne16 290, tempe, @not_2nd
			jsr disable_all
			jsr vblank_wait
			jsr sound_update
			draw_ending_screen 2
			reset_ppu_scrolling_and_ctrl
			jsr vblank_wait
			jsr sound_update
			jsr enable_all
		@not_2nd:
		bne16 320, tempe, @not_2nd_fadein
			jsr do_menu_fade_in
		@not_2nd_fadein:


		bne16 649, tempe, @not_2nd_fadeout
			jsr do_menu_fade_out
		@not_2nd_fadeout:
		bne16 650, tempe, @not_3rd
			jsr disable_all
			jsr vblank_wait
			jsr sound_update
			draw_ending_screen 3
			reset_ppu_scrolling_and_ctrl
			jsr vblank_wait
			jsr sound_update
			jsr enable_all
		@not_3rd:
		bne16 680, tempe, @not_3rd_fadein
			jsr do_menu_fade_in
		@not_3rd_fadein:


		bne16 1109, tempe, @not_3rd_fadeout
			jsr do_menu_fade_out
		@not_3rd_fadeout:
		bne16 1110, tempe, @not_4th
			jsr disable_all
			jsr vblank_wait
			jsr sound_update
			draw_ending_screen 4
			reset_ppu_scrolling_and_ctrl
			jsr vblank_wait
			jsr sound_update
			jsr enable_all
		@not_4th:
		bne16 1140, tempe, @not_4th_fadein
			jsr do_menu_fade_in
		@not_4th_fadein:


		bne16 1449, tempe, @not_4th_fadeout
			jsr do_menu_fade_out
		@not_4th_fadeout:
		bne16 1450, tempe, @not_5th
			jsr disable_all
			jsr vblank_wait
			jsr sound_update
			draw_ending_screen 5
			reset_ppu_scrolling_and_ctrl
			jsr vblank_wait
			jsr sound_update
			jsr enable_all
		@not_5th:
		bne16 1480, tempe, @not_5th_fadein
			jsr do_menu_fade_in
		@not_5th_fadein:




		bne16 1809, tempe, @not_5th_fadeout
			jsr do_menu_fade_out
		@not_5th_fadeout:
		bne16 1810, tempe, @not_credits_1
			jsr disable_all
			jsr vblank_wait
			jsr sound_update
			draw_screen credits_tile_1
			reset_ppu_scrolling_and_ctrl
			jsr clear_sprites
			jsr vblank_wait
			jsr sound_update
			jsr enable_all
		@not_credits_1:
		bne16 1840, tempe, @not_credits_1_fadein
			jsr do_menu_fade_in
		@not_credits_1_fadein:


		bne16 2169, tempe, @not_credits_1_fadeout
			jsr do_menu_fade_out
		@not_credits_1_fadeout:
		bne16 2170, tempe, @not_credits_2
			jsr disable_all
			jsr vblank_wait
			jsr sound_update
			draw_screen credits_tile_2
			reset_ppu_scrolling_and_ctrl
			jsr vblank_wait
			jsr sound_update
			jsr enable_all
		@not_credits_2:
		bne16 2200, tempe, @not_credits_2_fadein
			jsr do_menu_fade_in
		@not_credits_2_fadein:


		bne16 2529, tempe, @not_credits_2_fadeout
			jsr do_menu_fade_out
		@not_credits_2_fadeout:
		bne16 2530, tempe, @not_the_end
			jsr disable_all
			jsr vblank_wait
			jsr sound_update
			draw_screen the_end_question_tile
			reset_ppu_scrolling_and_ctrl
			jsr vblank_wait
			jsr sound_update
			jsr enable_all
		@not_the_end:
		bne16 2560, tempe, @not_the_end_fade_in
			jsr do_menu_fade_in
		@not_the_end_fade_in:

		bcs16 2260, tempe, @no_music_death
			lda #1
			jsr music_pause
		@no_music_death:

		bcs16 2540, tempe, @no_input
			; Once you get to the end, hit start to continue
			lda ctrlButtons
			and #CONTROLLER_START
			cmp #0
			beq @no_input
				jmp reset ; Welp, it was nice knowing you...
			
		@no_input:
		jmp @loop
		

ending_tile_1:
	.incbin "graphics/processed/bad_ending_0.nam.pkb"
ending_sprites_1:
	.scope ENDING_SPRITE_0
		DX1 = 60
		DY1 = 48
		.byte DY1, $c0, 0, DX1, DY1, $c1, 0, DX1+8, DY1, $c2, 0, DX1+16
		.byte DY1+8, $d0, 0, DX1, DY1+8, $d1, 0, DX1+8, DY1+8, $d2, 0, DX1+16
		
		DX2 = 160
		DY2 = 48
		.byte DY2, $c2, $40, DX2, DY2, $c1, $40, DX2+8, DY2, $c0, $40, DX2+16
		.byte DY2+8, $d2, $40, DX2, DY2+8, $d1, $40, DX2+8, DY2+8, $d0, $40, DX2+16

		DX3 = 190
		DY3 = 68
		.byte DY3, $c8, $40, DX3, DY3, $c7, $40, DX3+8, DY3, $c6, $40, DX3+16
		.byte DY3+8, $d8, $40, DX3, DY3+8, $d7, $40, DX3+8, DY3+8, $d6, $40, DX3+16
		.byte $ff

		.byte $ff
	.endscope

ending_tile_2:
	.incbin "graphics/processed/bad_ending_1.nam.pkb"
ending_sprites_2:
ending_sprites_3:
ending_sprites_4:
	.scope ENDING_SPRITE_1
		DX1 = 60
		DY1 = 48
		.byte DY1, $c0, 0, DX1, DY1, $c1, 0, DX1+8, DY1, $c2, 0, DX1+16
		.byte DY1+8, $d0, 0, DX1, DY1+8, $d1, 0, DX1+8, DY1+8, $d2, 0, DX1+16
		
		DX2 = 90
		DY2 = 38
		.byte DY2, $c2, $40, DX2, DY2, $c1, $40, DX2+8, DY2, $c0, $40, DX2+16
		.byte DY2+8, $d2, $40, DX2, DY2+8, $d1, $40, DX2+8, DY2+8, $d0, $40, DX2+16

		DX3 = 90
		DY3 = 68
		.byte DY3, $c2, $40, DX3, DY3, $c1, $40, DX3+8, DY3, $c0, $40, DX3+16
		.byte DY3+8, $d2, $40, DX3, DY3+8, $d1, $40, DX3+8, DY3+8, $d0, $40, DX3+16
		.byte $ff

	.endscope
ending_sprites_5:
	.scope ENDING_SPRITE_5
		DX1 = 100
		DY1 = 48
		.byte DY1, $c0, 0, DX1, DY1, $c1, 0, DX1+8, DY1, $c2, 0, DX1+16
		.byte DY1+8, $d0, 0, DX1, DY1+8, $d1, 0, DX1+8, DY1+8, $d2, 0, DX1+16
		.byte $ff
	.endscope


ending_tile_3:
	.incbin "graphics/processed/bad_ending_2.nam.pkb"

ending_tile_4:
	.incbin "graphics/processed/bad_ending_3.nam.pkb"

ending_tile_5:
	.incbin "graphics/processed/bad_ending_4.nam.pkb"


credits_tile_1: 
	.incbin "graphics/processed/credits_0.nam.pkb"
credits_tile_2: 
	.incbin "graphics/processed/credits_1.nam.pkb"

the_end_tile:
	.incbin "graphics/processed/the_end.nam.pkb"
the_end_question_tile:
	.incbin "graphics/processed/the_end_question.nam.pkb"