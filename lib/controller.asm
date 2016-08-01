; Reads controller.
; Reliable even if DMC is playing.
; Time: ~660 clocks
; hat tip: http://forums.nesdev.com/viewtopic.php?f=2&t=4124&start=15 (Thank you blargg!!)
read_controller:
	; Preserve the old stuff.
	lda ctrlButtons
	sta lastCtrlButtons
	
	jsr read_controller_internal
	sta <temp3
	jsr read_controller_internal
	pha
	jsr read_controller_internal
	sta <temp2
	jsr read_controller_internal
	
	; All combinations of one controller
	; change and one DMC DMA corruption
	; leave at least two matching readings,
	; and never just the first and last
	; matching. No more than one DMC DMA
	; corruption can occur.
	
			; X--X can't occur
	pla
	cmp <temp3
	beq @done       ; XX--
	cmp <temp1
	beq @done       ; -X-X
	
	lda <temp2      ; X-X-
			; -XX-
			; --XX
	@done: 
		cmp #0
		sta ctrlButtons
	rts
	
read_controller_internal:
	; Strobe controller
	lda #1          ; 2
	sta $4016       ; 4
	lda #0          ; 2
	sta $4016       ; 4
	
	; Read 8 bits
	lda #$80        ; 2
	sta <temp1      ; 3
	@load_byte:
		lda $4016   ; *4
	
	; Merge bits 0 and 1 into carry. Normal
	; controllers use bit 0, and Famicom
	; external controllers use bit 1.
	and #$03        ; *2
	cmp #$01        ; *2
	
	ror <temp1      ; *5
	bcc @load_byte  ; *3
			; -1
	lda <temp1      ; 3
	rts             ; 6