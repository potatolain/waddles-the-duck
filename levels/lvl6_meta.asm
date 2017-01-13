; Predictable format... start_dimension, flag x position, 2 emtpy bytes, level data
	.byte DIMENSION_PLAIN, 171, 0, 0
	; compressed ids, compressed level
	.word lvl6_compressed_ids, lvl6_compressed, lvl6_sprites