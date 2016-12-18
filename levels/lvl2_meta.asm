; Predictable format... start_dimension, flag x position, 2 emtpy bytes, level data
	.byte DIMENSION_PLAIN, 131, 0, 0
	; compressed ids, compressed level
	.word lvl2_compressed_ids, lvl2_compressed, lvl2_sprites