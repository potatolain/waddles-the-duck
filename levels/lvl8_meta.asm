; Predictable format... start_dimension, flag x position, 2 emtpy bytes, level data
	.byte DIMENSION_PLAIN, 254, 0, 0
	; compressed ids, compressed level
	.word lvl8_compressed_ids, lvl8_compressed, lvl8_sprites