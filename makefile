# This attempts to build the game for you. 
# Note: This is a pretty poor excuse for a makefile. I'd look elsewhere for better examples. 
# Prequisites:
# - A few fairly standard unix applications available; Gow/Cygwin installed for Windows.
# - ca65 binaries available in system path
# - emulators and misc tools installed in "tools" folder. (If desired)

### USER EDITABLE STUFF STARTS HERE

ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

MAIN_COMPILER=cl65
SPLITTER=tools/readnes3/readnes3
MAIN_EMULATOR=tools/fceux/fceux
DEBUG_EMULATOR=tools/nintendulatordx/nintendulator
SPACE_CHECKER=tools/nessc/nessc
CONFIG_FILE=$(ROOT_DIR)/ca65-utils/nesgame-chr.cfg
VERSION=0.1a

### USER EDITABLE STUFF ENDS HERE


BUILD_NUMBER=$(shell cat lib/buildnumber.txt)
BUILD_NUMBER_INCREMENTED=$(shell expr $(BUILD_NUMBER) + 1)
# Hacky magic to read a random line from our file of splash messages.
SPLASH_MESSAGE=$(shell awk "NR==$(shell awk "BEGIN{srand();printf(\"%%d\", ($(shell wc -l lib/splash_messages.txt | awk "{print $$1}"))*rand()+1)}") {print;}" lib/splash_messages.txt)

# In theory, every part of this makefile should work on Linux/Mac OS. If you find issues, report em!
ifeq ($(OS),Windows_NT)
	BUILD_DATE=$(shell echo %DATE% %TIME:~0,5%)
	UPLOADER=tools\uploader\upload.bat
else
	BUILD_DATE=$(shell date +"%a %m/%d/%Y  %H:%M")
	UPLOADER=tools/uploader/upload.sh
endif

all: generate_constants build 

generate_constants:
	@$(shell echo $(BUILD_NUMBER_INCREMENTED) > lib/buildnumber.txt)
	@echo Defining project constants for $(VERSION) build $(BUILD_NUMBER_INCREMENTED) built on $(BUILD_DATE)
	@echo Random message: $(SPLASH_MESSAGE)
	@echo .define  		BUILD 			$(BUILD_NUMBER) > lib/project_constants.asm
	@echo .define 		VERSION 		"$(VERSION)" >> lib/project_constants.asm
	@echo .define 		BUILD_DATE		"$(BUILD_DATE)" >> lib/project_constants.asm
	@echo .define 		SPLASH_MESSAGE 	"$(SPLASH_MESSAGE)" >> lib/project_constants.asm
	
build: 
	cd bin && $(MAIN_COMPILER) --config $(CONFIG_FILE) -t nes -o main.nes ../main.asm
	
build_debug:
	cd bin && ca65 -g -o main.o ../main.asm
	cd bin && ld65 -o main.nes --config $(CONFIG_FILE) --dbgfile main.nes.dbg main.o

fceux:
	$(MAIN_EMULATOR) bin/main.nes
	
run: fceux

nintendulator:
	$(DEBUG_EMULATOR) bin/main.nes

debug: generate_constants build_debug nintendulator
	
prepare_cart:
	$(SPLITTER) bin/main.nes

space_check:
	$(SPACE_CHECKER) bin/main.nes

upload: 
	$(UPLOADER) bin/main.nes
