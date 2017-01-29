show_professor_text:

	jsr do_sprite0
	jsr vblank_wait
	set_ppu_addr $2300
	
	store #TILE_BORDER_TL, PPU_DATA
	lda #TILE_BORDER_B
	.repeat $1e
		sta PPU_DATA
	.endrepeat
	store #TILE_BORDER_TR, PPU_DATA
	jsr do_sprite0
	lda #0
    sta textPage

	reset_ppu_scrolling_and_ctrl
	jsr sound_update
	jsr vblank_wait


	.repeat 5, I
		set_ppu_addr $2320+($20*I)
		lda #TILE_HUD_BLANK
		.repeat $20
			sta PPU_DATA
		.endrepeat
		reset_ppu_scrolling_and_ctrl
		jsr sound_update
		jsr vblank_wait
	.endrepeat

	set_ppu_addr $23f0
	lda #%01010101
	.repeat $10
		sta PPU_DATA
	.endrepeat
	reset_ppu_scrolling_and_ctrl

	jsr sound_update
	jsr vblank_wait


    jsr show_updated_text
	reset_ppu_scrolling_and_ctrl
	jsr sound_update


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
		reset_ppu_scrolling_and_ctrl
		jsr sound_update
		jsr read_controller
		lda ctrlButtons
		and #CONTROLLER_A
		beq @loop
		lda lastCtrlButtons
		and #CONTROLLER_A
		bne @loop
        ; Okay, you pressed something, update the text and do things accordingly
		reset_ppu_scrolling_and_ctrl

        jsr vblank_wait
        jsr show_updated_text
		reset_ppu_scrolling_and_ctrl
		jsr sound_update
		jsr vblank_wait

		jsr sound_update
        lda textPage
        cmp #255
        bne @loop


	.repeat 4, I
		jsr vblank_wait
		set_ppu_addr $2300+(I*$40)
		ldx #0
		:
			lda HUD_TEXT_BACKUP+(I*$40), x
			sta PPU_DATA
			inx
			cpx #$40
			bne :-
		reset_ppu_scrolling_and_ctrl
		jsr do_sprite0
		jsr sound_update
	.endrepeat
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
		reset_ppu_scrolling_and_ctrl
		jsr sound_update
		jsr vblank_wait

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text .concat( \
			"Waddles, you've made it!        ", \
        	"This teleporter can send you    ", \
        	"back in time.                   "  \
		)
        rts
    
    professor_text_1:
        ;set_ppu_addr $2301
        ;write_ppu_text "Prof"

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text .concat( \
			"It isn't the most precise,      ", \
        	"but it will get you close to    ", \
        	"your own time.                  "  \
		)
		rts

	professor_text_2:
        set_ppu_addr $2301
        write_ppu_text " Waddles "
		reset_ppu_scrolling_and_ctrl
		jsr sound_update
		jsr vblank_wait

        set_ppu_addr $2342 ; Second row, second char
		write_ppu_text .concat( \
        	"Close to my own time?           ", \
        	"                                ", \
        	"                                "  \
		)
		rts

    professor_text_3:
        set_ppu_addr $2301
        write_ppu_text " Prof -----"
		reset_ppu_scrolling_and_ctrl
		jsr sound_update
		jsr vblank_wait

        set_ppu_addr $2342 ; Second row, second char
		write_ppu_text .concat( \
        	"Yes. It should have a margin    ", \
        	"of error around... 50 years.    ", \
        	"                                "  \
		)
		rts

    professor_text_4:
        set_ppu_addr $2301
        write_ppu_text " Waddles "
		reset_ppu_scrolling_and_ctrl
		jsr sound_update
		jsr vblank_wait

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text .concat( \
			"Is that as close as you can     ", \
        	"get?                            ", \
        	"                                "  \
		)
		rts

    professor_text_5:
        set_ppu_addr $2301
        write_ppu_text " Prof ---"
		reset_ppu_scrolling_and_ctrl
		jsr sound_update
		jsr vblank_wait

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text .concat( \ 
			"With more time and gems,        ", \
			"I could get closer, but         ", \
			"it would take years.            "  \
		)
		rts

    professor_text_6:
        ;set_ppu_addr $2301
        ;write_ppu_text "Prof    "

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text .concat( \
			"Are you ready?                  ", \
        	"                                ", \
        	"                                " \
		)
		rts

	professor_text_final:
		lda #255
		sta textPage
    	rts

        
    professor_eod_text_0:
	    set_ppu_addr $2301
        write_ppu_text " Prof "
		reset_ppu_scrolling_and_ctrl
		jsr sound_update
		jsr vblank_wait

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text .concat( \
			"Waddles, you've made it!        ", \
        	"                                ", \
        	"                                "  \
		)
        rts
    
    professor_eod_text_1:
        ;set_ppu_addr $2301
        ;write_ppu_text "Prof"

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text .concat( \
			"The panel upstairs can take     ", \
        	"you to the exact date and time  ", \
        	"you were taken from.            "  \
		)
		rts

	professor_eod_text_2:
        set_ppu_addr $2301
        write_ppu_text " Waddles "
		reset_ppu_scrolling_and_ctrl
		jsr sound_update
		jsr vblank_wait

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text .concat( \
			"That's amazing!                 ", \
        	"                                ", \
        	"                                "  \
		)
		rts

    professor_eod_text_3:
        set_ppu_addr $2301
        write_ppu_text " Prof ---"
		reset_ppu_scrolling_and_ctrl
		jsr sound_update
		jsr vblank_wait

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text .concat( \
			"There is a catch, however...    ", \
        	"                                ", \
        	"                                "  \
		)
		rts

    professor_eod_text_4:
        set_ppu_addr $2301
        write_ppu_text " Prof ---"
		reset_ppu_scrolling_and_ctrl
		jsr sound_update
		jsr vblank_wait

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text .concat( \
			"When you go through, you will   ", \
        	"lose your ability to travel     ", \
        	"through dimensions.             "  \
		)
		rts

    professor_eod_text_5:
        set_ppu_addr $2301
        write_ppu_text " Prof ---"
		reset_ppu_scrolling_and_ctrl
		jsr sound_update
		jsr vblank_wait

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text .concat( \
			"The world around you may go a   ", \
        	"bit crazy.                      ", \
        	"                                "  \
		)
		rts

    professor_eod_text_6:
        set_ppu_addr $2301
        write_ppu_text " Prof ---"
		reset_ppu_scrolling_and_ctrl
		jsr sound_update
		jsr vblank_wait

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text .concat( \
			"Try to get back to the place    ", \
        	"in time you came from, even     ", \
        	"if the path is unfamiliar.      "  \
		)
		rts

    professor_eod_text_7:
        set_ppu_addr $2301
        write_ppu_text " Prof ---"
		reset_ppu_scrolling_and_ctrl
		jsr sound_update
		jsr vblank_wait

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text .concat( \
			"When you find it, you will be   ", \
        	"teleported back to your own     ", \
        	"timeline.                       "  \
		)
		rts

    professor_eod_text_8:
        set_ppu_addr $2301
        write_ppu_text " Waddles "
		reset_ppu_scrolling_and_ctrl
		jsr sound_update
		jsr vblank_wait

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text .concat( \
			"So I can see my family again?   ", \
        	"                                ", \
        	"                                "  \
		)
		rts

    professor_eod_text_9:
        set_ppu_addr $2301
        write_ppu_text " Prof ---"
		reset_ppu_scrolling_and_ctrl
		jsr sound_update
		jsr vblank_wait

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text .concat( \
			"Luck willing, yes.              ", \
        	"                                ", \
        	"                                "  \
		)
		rts

    professor_eod_text_10:
        set_ppu_addr $2301
        write_ppu_text " Waddles "
		reset_ppu_scrolling_and_ctrl
		jsr sound_update
		jsr vblank_wait

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text .concat( \
			"That is all I need to hear.     ", \
        	"                                ", \
        	"                                "  \
		)
		rts

    professor_eod_text_11:
        set_ppu_addr $2301
        write_ppu_text " Waddles "
		reset_ppu_scrolling_and_ctrl
		jsr sound_update
		jsr vblank_wait

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text .concat( \
			"I am ready.	                 ", \
        	"                                ", \
        	"                                "  \
		)
		rts

	professor_eod_text_12:
        set_ppu_addr $2301
        write_ppu_text " Prof ---"
		reset_ppu_scrolling_and_ctrl
		jsr sound_update
		jsr vblank_wait

        set_ppu_addr $2342 ; Second row, second char
        write_ppu_text .concat( \
			"Good luck, Waddles.             ", \
        	"                                ", \
        	"                                "  \
		)
		rts
