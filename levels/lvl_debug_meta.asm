; Predictable format... start_dimension, 3 emtpy bytes, level data
.byte DIMENSION_PLAIN, 0, 0, 0
; compressed ids, compressed level
.word lvl_debug_compressed_ids, lvl_debug_compressed, lvl_debug_sprites

; 8 bytes in, list of warp points in level. Max #: 248/4 = 62. If we get over that number our level is FAR too complex anyway...
lvl_debug_warp_points: 
	; Format: x, y, dim1, dim2
	.byte 7, 10, DIMENSION_PLAIN, DIMENSION_AGGRESSIVE
	.byte 3, 10, DIMENSION_PLAIN, DIMENSION_ICE_AGE
	.byte 5, 10, DIMENSION_PLAIN, DIMENSION_CALM
	.byte 9, 10, DIMENSION_PLAIN, DIMENSION_AUTUMN
	.byte 11, 10, DIMENSION_PLAIN, DIMENSION_END_OF_DAYS
	.byte $ff
