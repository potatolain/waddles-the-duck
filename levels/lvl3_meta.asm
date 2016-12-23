; Predictable format... start_dimension, flag x position, 2 emtpy bytes, level data
	.byte DIMENSION_PLAIN, 76, 0, 0
	; compressed ids, compressed level
	.word lvl3_compressed_ids, lvl3_compressed, lvl3_sprites