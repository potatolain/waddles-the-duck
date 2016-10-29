	; Predictable format... start_dimension, 3 emtpy bytes, level data
	.byte DIMENSION_ICE_AGE, 0, 0, 0
	; compressed ids, compressed level
	.word lvl2_compressed_ids, lvl2_compressed, lvl2_sprites

; 8 bytes in, list of warp points in level. Max #: 248/4 = 62. If we get over that number our level is FAR too complex anyway...
lvl2_warp_points: 
	; Format: x, y, dim1, dim2
	.byte 33, 8, DIMENSION_PLAIN, DIMENSION_ICE_AGE
	.byte $ff
