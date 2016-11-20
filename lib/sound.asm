; Wrapper file for all of our music stuff. Mainly handles bankswitching, but should also let us swap libraries more easily.

.macro ft_bank
	pha
	bank_temp #BANK_MUSIC_AND_SOUND
	pla
.endmacro

.macro ft_restore
	pha
	bank_restore
	pla
.endmacro


music_init:
	ft_bank
	jsr FamiToneInit
	ft_restore
	rts


music_play:
	ft_bank
	jsr FamiToneMusicPlay
	ft_restore
	rts

music_pause:
	ft_bank
	jsr FamiToneMusicPause
	ft_restore
	rts


sound_update:
	ft_bank
	jsr FamiToneUpdate
	ft_restore
	rts


sfx_init:
	ft_bank
	jsr FamiToneSfxInit
	ft_restore
	rts

sfx_play:
	ft_bank
	jsr FamiToneSfxPlay
	ft_restore
	rts