# This attempts to build the game for you. 
# Note: This is a pretty poor excuse for a makefile. I'd look elsewhere for better examples. 
# Prequisites:
# - A few fairly standard unix applications available; Gow/Cygwin installed for Windows.
# - ca65 binaries available in system path
# - emulators and misc tools installed in "tools" folder. (If desired)

### USER EDITABLE STUFF STARTS HERE

ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

MAIN_COMPILER=cl65
NODE=node
SPLITTER=tools/readnes3/readnes3
MAIN_EMULATOR=tools/fceux/fceux
DEBUG_EMULATOR=tools/nintendulatordx/nintendulator
SPACE_CHECKER=tools/nessc/nessc
PACKBITS=tools/p8nes/winbinaries/packbits
CONFIG_FILE=$(ROOT_DIR)/ca65-utils/nesgame-chr.cfg
TEXT2DATA=sound/text2data
NSF2DATA=sound/nsf2data
VERSION=1.0-pre   

### USER EDITABLE STUFF ENDS HERE


LEVELS=$(patsubst levels/%, levels/processed/%, $(patsubst %.json, %_tiles.asm, $(wildcard levels/*.json)))
SPRITES=$(patsubst levels/%, levels/processed/%, $(patsubst %.json, %_sprites.asm, $(wildcard levels/*.json)))
GRAPHICS=$(patsubst graphics/%, graphics/processed/%, $(patsubst %.chr, %.chr.pkb, $(wildcard graphics/*.chr)))
NAMETABLES=$(patsubst graphics/%, graphics/processed/%, $(patsubst %.nam, %.nam.pkb, $(wildcard graphics/*.nam)))
BUILD_NUMBER=$(shell cat lib/buildnumber.txt)
BUILD_NUMBER_INCREMENTED=$(shell expr $(BUILD_NUMBER) + 1)
COMMIT_COUNT=$(shell git rev-list --count HEAD)
CODE_LINE_COUNT=$(shell grep -r "^" --include="*.asm" --include="*.js" * | grep -v "levels/processed" | wc -l)
# Old way: Hacky magic to read a random line from our file of splash messages.
# SPLASH_MESSAGE=$(shell awk "NR==$(shell awk "BEGIN{srand();printf(\"%%d\", ($(shell wc -l lib/splash_messages.txt | awk "{print $$1}"))*rand()+1)}") {print;}" lib/splash_messages.txt) 
# New way: Use static text
SPLASH_MESSAGE=Prerelease Build
COPYRIGHT=Copyright 2016-2017 cpprograms

# In theory, most of this makefile (save for the famitone utils, windows only...) should work on Linux/Mac OS. If you find issues, report em!
ifeq ($(OS),Windows_NT)
	BUILD_DATE=$(shell echo %DATE% %TIME:~0,5%)
	UPLOADER=tools\uploader\upload.bat
else
	BUILD_DATE=$(shell date +"%a %m/%d/%Y  %H:%M")
	UPLOADER=tools/uploader/upload.sh
endif

all: generate_constants sound_files convert_levels convert_sprites convert_graphics convert_nametables build 

generate_constants:
	@$(shell echo $(BUILD_NUMBER_INCREMENTED) > lib/buildnumber.txt)
	@echo Defining project constants for $(VERSION) build $(BUILD_NUMBER_INCREMENTED) built on $(BUILD_DATE)
	@echo Random message: $(SPLASH_MESSAGE)
	@echo .define  		BUILD 				$(BUILD_NUMBER) > lib/project_constants.asm
	@echo .define 		VERSION 			"$(VERSION)" >> lib/project_constants.asm
	@echo .define 		BUILD_DATE			"$(BUILD_DATE)" >> lib/project_constants.asm
	@echo .define 		SPLASH_MESSAGE		"$(SPLASH_MESSAGE)" >> lib/project_constants.asm
	@echo .define 		COPYRIGHT			"$(COPYRIGHT)" >> lib/project_constants.asm
	@echo .define 		COMMIT_COUNT		$(COMMIT_COUNT) >> lib/project_constants.asm
	@echo .define 		CODE_LINE_COUNT		$(CODE_LINE_COUNT) >> lib/project_constants.asm
	
sound_files: sound/music.s sound/sfx.s

sound/music.s: sound/music.txt
ifeq ($(OS),Windows_NT)
	$(TEXT2DATA) sound\music.txt -ca65
else
	echo Warning: sound conversion not available on non-windows systems.
endif

sound/sfx.s: sound/sfx.nsf
ifeq ($(OS),Windows_NT)
	$(NSF2DATA) sound\sfx.nsf -ntsc -ca65
else
	echo Warning: sound conversion not available on non-windows systems.
endif


levels/processed/%_tiles.asm: levels/%.json
	$(NODE) ./tools/level-converter $<

levels/processed/%_sprites.asm: levels/%.json
	$(NODE) ./tools/sprite-converter $<

convert_levels: $(LEVELS)
convert_sprites: $(SPRITES)
convert_graphics: $(GRAPHICS)
convert_nametables: $(NAMETABLES)

graphics/processed/%.chr.pkb: graphics/%.chr
	$(PACKBITS) $< $@
graphics/processed/%.nam.pkb: graphics/%.nam
	$(PACKBITS) $< $@

build: 
	cd bin && $(MAIN_COMPILER) --config $(CONFIG_FILE) -t nes -o main.nes -Wa "-D DEBUGGING=1" ../main.asm

build_release:
	cd bin && $(MAIN_COMPILER) --config $(CONFIG_FILE) -t nes -o main.nes -Wa "-D DEBUGGING=0" ../main.asm
	
build_debug:
	cd bin && ca65 -g -o main.o ../main.asm -D DEBUGGING=1
	cd bin && ld65 -o main.nes --config $(CONFIG_FILE) --dbgfile main.nes.dbg main.o

fceux:
	$(MAIN_EMULATOR) bin/main.nes
	
run: fceux

nintendulator:
	$(DEBUG_EMULATOR) bin/main.nes

debug: generate_constants sound_files convert_levels build_debug nintendulator
	
prepare_cart:
	$(SPLITTER) bin/main.nes
ifeq ($(OS),Windows_NT)
	cd bin && copy /b mainProgram.bin + mainProgram.bin cartridge.bin
else
	echo Warning: Catridge converstion not supported on non-windows systems. This should be easy; if you add it, please submit a PR!
endif

space_check:
	$(SPACE_CHECKER) bin/main.nes

release: build_release run uploader

# TODO: Rename this to upload once you get used to not running it directly.
uploader: 
	$(UPLOADER) bin/main.nes

clean: 
	-rm -f bin/*.nes
	-rm -f bin/cartridge.bin
	-rm -f bin/main*.bin
	-rm -f bin/*.dbg
	-rm -f bin/mainDetails.txt
	-rm -f levels/processed/*.asm
	-rm -f graphics/processed/*.pkb