; Predictable format... start_dimension, flag x position, 2 emtpy bytes, level data
	.byte DIMENSION_PLAIN, 135, 0, 0
	; compressed ids, compressed level
	.word lvl1_compressed_ids, lvl1_compressed, lvl1_sprites