/**
 * Quick-n-dirty level converter. Takes levels from tiled format (layer 2) and converts them to our sprite format.
 * Expects height to be < 16px, file to have 2 layers, and a length of < 255 columns. 
 * Tile ids must be <= 255.
 * 
 * Very, very specific to this use-case. (I tried to document, but this is really a hacked-together pile of code...)
 * Any levels you have in BASE/levels/*.json will be converted by the makefile. 
 */

var path = require('path'),
	fs = require('fs'),
	packageData = require('./package.json'),

	// Forced height because we're aiming for an engine that expects things to be aligned with a 16 byte border.
	COLUMN_HEIGHT = 16,
	NO_SPRITE = 0, // For now, the first sprite def is a noop/remove me from the screen.
	SPRITE_START_ID = 256,
	NL = "\n",
	
	levelInfo, 
	isVerbose = false,
	lvlName = null,
	file = null,
	outFile = null;

function printUsage() {
	error('Usage: sprite-converter path/to/file.json [path/to/output.asm]');
	error('If an output file is not provided, we will output to a new "processed" directory in the same folder as file.json');
	error('The program assumes there are 256 tiles available, and any sprite id needs 256 removed from its value.');
	error('To change this, use the --start-id parameter with a number');
}

function verbose() {
	if (isVerbose) {
		console.info.apply(this, arguments);
	}
}

function out() {
	console.info.apply(this, arguments);
}

function error() {
	console.error.apply(this, arguments);
}

for (var i = 2; i < process.argv.length; i++) {
	var arg = process.argv[i];
	switch (arg) {
		case '-v':
		case '--verbose':
			isVerbose = true;
			break;
		case '-h':
		case '--help':
			printUsage();
			process.exit(0);
			break; // Well, this is kinda pointless. Shhh >_>
		case '-i':
		case '--start-id':
			if (process.argv.length < i) {
				error('Must provide a value for --start-id');
				printUsage();
				process.exit(1);
			}

			SPRITE_START_ID = parseInt(process.argv[i+1], 10);

			if (isNaN(SPRITE_START_ID)) {
				error('Could not parse start id');
				printUsage();
				process.exit(1);
			}
			break;
		default:
			if (arg[0] == '-') {
				error('Unrecognized option "' + arg + '" ignored.');
			} else if (file !== null) {
				outFile = arg;
			} else {
				file = arg;
				lvlName = path.basename(arg, '.json');
			}
			break;
	}
}

if (file === null) {
	printUsage();
	process.exit(1);
}

// Attempt to guess what file to put out to.
if (outFile === null) {
	var inFile = path.join(process.cwd(), file),
		fileDir = path.join(path.dirname(inFile), 'processed'),
		outFile = path.join(fileDir, path.basename(inFile, '.json') + '_sprites.asm');

	if (!fs.existsSync(fileDir)) {
		verbose('Making directory for output: "' + fileDir + '"');
		fs.mkDir(fileDir);
	}
}

verbose('Processing file "' + file + '". Outputting to: "' + outFile + '"');

try {
	levelInfo = require(path.join(process.cwd(), file));
} catch (e) {
	error('Failed loading level from "' + file + '"', e);
	process.exit(1);
}

var width = levelInfo.width,
	height = levelInfo.height,
	data = levelInfo.layers[1].data,
	originalSize = data.length,
	rawColumns = [],
	columnDefinitions = [],
	spriteDefs = [],
	mapColumns = [],
	fileData = '';

// Tiled seems to like to use 1-based indexes. That ain't gonna fly here.
for (var i = 0; i < data.length; i++) {
	data[i]--;
}

verbose('Map width: ' + width + ' height: ' + height);

for (var y = 0; y < height; y++) {
	for (var x = 0; x < width; x++) {
		if (data[y*width + x] > 0) { // -1 = no tile at all. 1 = no sprites here. (This kind of implies we're doing weird stuff in tiled...')
			spriteDefs.push({x: x, y: y, id: data[y*width + x] - SPRITE_START_ID});
		}
	}
}

verbose('Found ' + spriteDefs.length + ' sprites in stage.');


verbose('Beginning to generate file data.');
fileData = 
	'; Level sprite output for "' + lvlName + '"' + NL +
	'; Generated on ' + (new Date()).toLocaleString() + ' by ' + packageData.name + ' version ' + packageData.version + NL +
	'; ' + NL + 
	NL + 
	NL + 
	lvlName+'_sprites:' + NL;

for (var i = 0; i < spriteDefs.length; i++) {
	fileData += '	.byte ' + spriteDefs[i].x + ', ' + spriteDefs[i].y + ', ' + spriteDefs[i].id + NL;
}

fileData += 
	'	.byte $ff ; End of section.' + NL +
	'; End of "' + lvlName + '" sprite data.' + NL; 

verbose('Computed data for assembly file. Length: ' + fileData.length + ' bytes.');

fs.writeFileSync(outFile, fileData);

out('Successfully wrote ' + lvlName + ' out to "' + outFile + '".');

verbose('Exiting successfully!');
process.exit(0);