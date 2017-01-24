; Predictable format... start_dimension, flag x position, 2 emtpy bytes, level data
	.byte DIMENSION_PLAIN, 242, 0, 0
	; compressed ids, compressed level
	.word lvl9_compressed_ids, lvl9_compressed, lvl9_sprites