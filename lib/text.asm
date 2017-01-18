show_professor_text:

	set_ppu_addr $2300
	
	store #TILE_BORDER_TL, PPU_DATA
	lda #TILE_BORDER_B
	.repeat $1e
		sta PPU_DATA
	.endrepeat
	store #TILE_BORDER_TR, PPU_DATA


	.repeat 5
		lda #TILE_HUD_BLANK
		.repeat $20
			sta PPU_DATA
		.endrepeat
	.endrepeat

	set_ppu_addr $23f0
	lda #%01010101
	.repeat $10
		sta PPU_DATA
	.endrepeat

    ; Force the screen to scroll position 0. 
    lda scrollX
    pha
    lda #0
    sta scrollX
    sta textPage

    jsr show_updated_text
    jsr enable_all


	ldx #(VAR_SPRITE_DATA-SPRITE_DATA) ; Skip player, since relocating the player will likely result in death.
	@loop_sprites:
		lda SPRITE_DATA, x
		cmp #192 
		bcc @do_nothing
			; If it's in the last 1/4 of the screen, hide it.
			lda #SPRITE_OFFSCREEN
			sta SPRITE_DATA, x
		@do_nothing:
		.repeat 4 
			inx
		.endrepeat
		cpx #0
		bne @loop_sprites

	@loop:
		jsr vblank_wait
		jsr sound_update
		jsr read_controller
		lda ctrlButtons
		and #CONTROLLER_A
		beq @loop
		lda lastCtrlButtons
		and #CONTROLLER_A
		bne @loop
        ; Okay, you pressed something, update the text and do things accordingly
        jsr disable_all
        jsr vblank_wait
        jsr show_updated_text
        jsr enable_all
        lda textPage
        cmp #255
        bne @loop

    pla
    sta scrollX


	jsr disable_all
	jsr vblank_wait
	set_ppu_addr $2300
	ldx #0
	@loop_restore_original:
		lda ANIMATED_TILE_CACHE, x
		sta PPU_DATA
		inx
		cpx #0
		bne @loop_restore_original
    rts


show_updated_text: 
	lda currentDimension
	cmp #DIMENSION_END_OF_DAYS
	beq @end_of_days


    lda textPage
    inc textPage
    .repeat 7, I
		cmp #I
		bne :+ 
		jmp .ident(.concat("professor_text_", .string(I)))
		:
	.endrepeat
    jmp professor_text_final

	@end_of_days:
	    lda textPage
    inc textPage
    .repeat 13, I
		cmp #I
		bne :+ 
		jmp .ident(.concat("professor_eod_text_", .string(I)))
		:
	.endrepeat
	jmp professor_text_final

    professor_text_0:
	    set_ppu_addr $2301
        write_ppu_text " Prof "

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text "Waddles, you've made it!        "
        write_ppu_text "This teleporter can send you    "
        write_ppu_text "back in time.                   "
        rts
    
    professor_text_1:
        ;set_ppu_addr $2301
        ;write_ppu_text "Prof"

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text "It isn't the most precise,      "
        write_ppu_text "but it will get you close to    "
        write_ppu_text "your own time.                  "
		rts

	professor_text_2:
        set_ppu_addr $2301
        write_ppu_text " Waddles "

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text "Close to my own time?           "
        write_ppu_text "                                "
        write_ppu_text "                                "
		rts

    professor_text_3:
        set_ppu_addr $2301
        write_ppu_text " Prof -----"

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text "Yes. It should have a margin    "
        write_ppu_text "of error around... 50 years.    "
        write_ppu_text "                                "
		rts

    professor_text_4:
        set_ppu_addr $2301
        write_ppu_text " Waddles "

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text "Is that as close as you can     "
        write_ppu_text "get?                            "
        write_ppu_text "                                "
		rts

    professor_text_5:
        set_ppu_addr $2301
        write_ppu_text " Prof -----"

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text "With more time and gems,        "
        write_ppu_text "maybe I could get closer, but   "
        write_ppu_text "it would take years.            "
		rts

    professor_text_6:
        ;set_ppu_addr $2301
        ;write_ppu_text "Prof    "

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text "Are you ready?                  "
        write_ppu_text "                                "
        write_ppu_text "                                "
		rts

	professor_text_final:
		lda #255
		sta textPage
    	rts

        
    professor_eod_text_0:
	    set_ppu_addr $2301
        write_ppu_text " Prof "

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text "Waddles, you've made it!        "
        write_ppu_text "                                "
        write_ppu_text "                                "
        rts
    
    professor_eod_text_1:
        ;set_ppu_addr $2301
        ;write_ppu_text "Prof"

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text "The panel upstairs can take     "
        write_ppu_text "you to the exact date and time  "
        write_ppu_text "you were taken from.            "
		rts

	professor_eod_text_2:
        set_ppu_addr $2301
        write_ppu_text " Waddles "

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text "That's amazing!                 "
        write_ppu_text "                                "
        write_ppu_text "                                "
		rts

    professor_eod_text_3:
        set_ppu_addr $2301
        write_ppu_text " Prof -----"

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text "There is a catch, however...    "
        write_ppu_text "                                "
        write_ppu_text "                                "
		rts

    professor_eod_text_4:
        set_ppu_addr $2301
        write_ppu_text " Prof -----"

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text "When you go through, you will   "
        write_ppu_text "lose your ability to travel     "
        write_ppu_text "through dimensions.             "
		rts

    professor_eod_text_5:
        set_ppu_addr $2301
        write_ppu_text " Prof -----"

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text "The world around you may go a   "
        write_ppu_text "bit crazy.                      "
        write_ppu_text "                                "
		rts

    professor_eod_text_6:
        set_ppu_addr $2301
        write_ppu_text " Prof -----"

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text "Try to get back to the place    "
        write_ppu_text "in time you came from, even     "
        write_ppu_text "if the path is unfamiliar.      "
		rts

    professor_eod_text_7:
        set_ppu_addr $2301
        write_ppu_text " Prof -----"

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text "When you find it, you will be   "
        write_ppu_text "teleported back to your own     "
        write_ppu_text "timeline.                       "
		rts

    professor_eod_text_8:
        set_ppu_addr $2301
        write_ppu_text " Waddles "

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text "So I can see my family again?   "
        write_ppu_text "                                "
        write_ppu_text "                                "
		rts

    professor_eod_text_9:
        set_ppu_addr $2301
        write_ppu_text " Prof -----"

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text "Luck willing, yes.              "
        write_ppu_text "                                "
        write_ppu_text "                                "
		rts

    professor_eod_text_10:
        set_ppu_addr $2301
        write_ppu_text " Waddles "

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text "That is all I need to hear.     "
        write_ppu_text "                                "
        write_ppu_text "                                "
		rts

    professor_eod_text_11:
        set_ppu_addr $2301
        write_ppu_text " Waddles "

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text "I am ready.	                    "
        write_ppu_text "                                "
        write_ppu_text "                                "
		rts

	professor_eod_text_12:
        set_ppu_addr $2301
        write_ppu_text " Prof -----"

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text "Good luck, Waddles.             "
        write_ppu_text "                                "
        write_ppu_text "                                "
		rts

