	; Predictable format... start_dimension, 3 emtpy bytes, level data
	.byte DIMENSION_PLAIN, 0, 0, 0
	; compressed ids, compressed level
	.word lvl1_compressed_ids, lvl1_compressed, lvl1_sprites

; 8 bytes in, list of warp points in level. Max #: 248/4 = 62. If we get over that number our level is FAR too complex anyway...
lvl1_warp_points: 
	; Format: x, y, dim1, dim2
	.byte 7, 10, DIMENSION_PLAIN, DIMENSION_AGGRESSIVE
	.byte 127, 10, DIMENSION_AGGRESSIVE, DIMENSION_ICE_AGE
	.byte $ff
