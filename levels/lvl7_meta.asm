; Predictable format... start_dimension, flag x position, 2 emtpy bytes, level data
	.byte DIMENSION_PLAIN, 171, 0, 0
	; compressed ids, compressed level
	.word lvl7_compressed_ids, lvl7_compressed, lvl7_sprites