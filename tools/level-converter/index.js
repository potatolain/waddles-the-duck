/**
 * Quick-n-dirty level converter. Takes levels from tiled format and converts them to our level format.
 * Expects height to be < 16px, file to have 2 layers, and a length of < 255 columns. 
 * Tile ids must be <= 255; 0-63 unique tiles, then top 2 bits handle palette.
 * 
 * Very, very specific to this use-case. (I tried to document, but this is really a hacked-together pile of code...)
 * Any levels you have in BASE/levels/*.json will be converted by the makefile. 
 */

var path = require('path'),
	fs = require('fs'),
	packageData = require('./package.json'),

	// Forced height because we're aiming for an engine that expects things to be aligned with a 16 byte border.
	COLUMN_HEIGHT = 16,
	PAD_VALUE = 0,
	NL = "\n",
	
	levelInfo, 
	isVerbose = false,
	lvlName = null,
	file = null,
	outFile = null;

function printUsage() {
	error('Usage: level-converter path/to/file.json [path/to/output.asm]');
	error('If an output file is not provided, we will output to a new "processed" directory in the same folder as file.json');
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

function findColumnDefinitionId(columnDef) {
	// Have to loop through all column defs and check manually, as js doesn't have built-in array comparison.
	for (var i = 0; i < columnDefinitions.length; i++) {
		// Go through all ids
		var isMatch = true;
		for (var j = 0; j < columnDefinitions[i].length; j++) {
			
			// If a single id does not match, go to next row.
			if (columnDefinitions[i][j] !== columnDef[j]) {
				isMatch = false;
				break;
			}
		}
		if (isMatch) {
			return i;
		}

	}
	return -1;
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
		outFile = path.join(fileDir, path.basename(inFile, '.json') + '_tiles.asm');

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
	data = levelInfo.layers[0].data,
	originalSize = data.length,
	rawColumns = [],
	columnDefinitions = [],
	mapColumns = [],
	fileData = '';

// Tiled seems to like to use 1-based indexes. That ain't gonna fly here.
for (var i = 0; i < data.length; i++) {
	data[i]--;
}

verbose('Map width: ' + width + ' height: ' + height + ' uncompressed length: ' + (width * height) + ' bytes.');

for (var w = 0; w < width; w++) {
	var thisColumn = [];
	for (var h = 0; h < height; h++) {
		// Get everything in this column.
		thisColumn.push(data[width*h + w]);
	}

	// We have a column. Put it into the column lists.
	rawColumns.push(thisColumn);
	columnDefinitions.push(thisColumn);
}

// Deduplicate the rows to find how many we really need to track. Must be < 255.
columnDefinitions = columnDefinitions.filter(function(elem, pos) {
	// If this is the first instance, keep it. Else, escapeh.
	return findColumnDefinitionId(elem) === pos;
});

for (var w = 0; w < rawColumns.length; w++) {
	mapColumns.push(findColumnDefinitionId(rawColumns[w]));
}

verbose('Processed ' + width + ' columns and found ' + columnDefinitions.length + ' unique columns.');

// Now that we've mapped everything to values, let's pad the column defs to the correct length.
for (var i = 0; i < columnDefinitions.length; i++) {
	for (var j = columnDefinitions[i].length; j < COLUMN_HEIGHT; j++) {
		columnDefinitions[i].push(PAD_VALUE);
	}
}

var compressedSize = ((columnDefinitions.length * COLUMN_HEIGHT) + mapColumns.length),
	compressionRatio = originalSize / compressedSize,
	spaceSavings = 1 - (compressedSize / originalSize);

verbose('Finished processing. Total compressed size: ' + compressedSize + ' bytes. Compression ratio: ' + (compressionRatio * 100).toFixed(2) + '% Space Savings: ' + (spaceSavings * 100).toFixed(2) + '%');



verbose('Beginning to generate file data.');
fileData = 
	'; Level output for "' + lvlName + '"' + NL +
	'; Generated on ' + (new Date()).toLocaleString() + ' by ' + packageData.name + ' version ' + packageData.version + NL +
	'; ' + NL + 
	'; Original length: ' + originalSize + ' bytes. ' + NL +
	'; Compressed length: ' + compressedSize + ' bytes' + NL +
	NL + 
	NL + 
	lvlName+'_compressed_ids:' + NL;

for (var i = 0; i < columnDefinitions.length; i++) {
	fileData += '	.byte ' + columnDefinitions[i].join(', ') + NL;
}

fileData += 
	'	.byte $ff ; end of section.' + NL +
	NL + 
	NL + lvlName + '_compressed:' + NL;

// Ugly? Yes. But sometimes the simplest thing you could possibly do will just suffice.
// The end result is just a list of bytes in a NES file, whether we chunk it into 16 byte chunks, 
// or lazily output them one at at time.
for (var i = 0; i < mapColumns.length; i++) {
	fileData += '	.byte ' + mapColumns[i] + NL;
}

fileData += 
	'	.byte $ff ; End of section.' + NL +
	'; End of "' + lvlName + '" level data.' + NL; 

verbose('Computed data for assembly file. Length: ' + fileData.length + ' bytes.');

fs.writeFileSync(outFile, fileData);

out('Successfully wrote ' + lvlName + ' out to "' + outFile + '".');
out('    Original length: ' + originalSize + ' bytes. ');
out('    Compressed length: ' + compressedSize + ' bytes');
out('    Compression ratio: ' + (compressionRatio * 100).toFixed(2) + '%');
out('    Space Savings: ' + (spaceSavings * 100).toFixed(2) + '%');


verbose('Exiting successfully!');
process.exit(0);