; Predictable format... start_dimension, flag x position, 2 emtpy bytes, level data
	.byte DIMENSION_PLAIN, 140, 0, 0
	; compressed ids, compressed level
	.word lvl4_compressed_ids, lvl4_compressed, lvl4_sprites