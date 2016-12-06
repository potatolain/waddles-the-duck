; Predictable format... start_dimension, 3 emtpy bytes, level data
.byte DIMENSION_PLAIN, 0, 0, 0
; compressed ids, compressed level
.word lvl_debug_compressed_ids, lvl_debug_compressed, lvl_debug_sprites