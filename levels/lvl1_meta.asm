	; Predictable format... start_dimension, 3 emtpy bytes, level data
	.byte DIMENSION_PLAIN, 0, 0, 0
	; compressed ids, compressed level
	.word lvl1_compressed_ids, lvl1_compressed, lvl1_sprites