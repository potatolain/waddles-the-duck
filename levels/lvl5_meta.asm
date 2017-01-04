; Predictable format... start_dimension, flag x position, 2 emtpy bytes, level data
	.byte DIMENSION_ICE_AGE, 145, 0, 0
	; compressed ids, compressed level
	.word lvl5_compressed_ids, lvl5_compressed, lvl5_sprites