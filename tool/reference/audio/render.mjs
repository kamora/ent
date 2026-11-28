// Renders the audio scenarios of fixtures/audio/<file>.json with Web Audio's OfflineAudioContext in the installed
// headless Chrome (puppeteer-core from tool/) and writes, per scenario, fixtures/audio/<file>/<name>.f32: the
// rendered channels one after another, as little-endian 32-bit floats. <file>/meta.json records the browser and
// which sources fired `onended`.
//
// Usage: node tool/reference/audio/render.mjs <file> (for example: sources)
// Chrome: $CHROME, or /Applications/Google Chrome.app.
//
// A scenario has its length in frames, its buffers (filled by `signal` below, which ent_audio's tests repeat) and
// its operations: [ 'source', name, buffer ], [ 'set', name, attribute, value ], [ 'param', name, param, value ],
// [ 'connect', name ], [ 'start', name, when?, offset?, duration? ], [ 'stop', name, when ]. Times are in frames of
// the context rate.

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = fileURLToPath( new URL( '../../../', import.meta.url ) );
const file = process.argv[ 2 ];
const doc = JSON.parse( readFileSync( join( root, 'fixtures/audio', file + '.json' ), 'utf8' ) );
const out = join( root, 'fixtures/audio', file );
const puppeteer = ( await import( pathToFileURL( createRequire( join( root, 'tool/package.json' ) ).resolve( 'puppeteer-core' ) ) ) ).default;
const browser = await puppeteer.launch( {
	executablePath: process.env.CHROME ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
	headless: true,
} );

// Runs in the page: renders one scenario and returns its channels and the sources that ended.
async function render( doc, scenario ) {

	// Sample i of channel c of a buffer: a fixed pattern in [-1, 1) that needs no transcendental function.
	const signal = ( c, i ) => ( ( i * 7919 + c * 104729 ) % 2003 ) / 1001.5 - 1;
	const time = ( frames ) => frames / doc.rate;
	const context = new OfflineAudioContext( doc.channels, scenario.frames, doc.rate );
	const buffers = {};
	const nodes = {};
	const ended = [];

	for ( const [ name, b ] of Object.entries( scenario.buffers ) ) {

		const buffer = context.createBuffer( b.channels, b.length, b.rate );

		for ( let c = 0; c < b.channels; c ++ ) {

			const data = buffer.getChannelData( c );

			for ( let i = 0; i < b.length; i ++ ) {

				data[ i ] = signal( c, i );

			}

		}

		buffers[ name ] = buffer;

	}

	for ( const [ op, name, ...args ] of scenario.ops ) {

		const node = nodes[ name ];

		switch ( op ) {

			case 'source': {

				const source = context.createBufferSource();

				if ( args[ 0 ] !== null ) {

					source.buffer = buffers[ args[ 0 ] ];

				}

				source.onended = () => ended.push( name );
				nodes[ name ] = source;
				break;

			}

			case 'set':
				node[ args[ 0 ] ] = typeof args[ 1 ] === 'number' ? time( args[ 1 ] ) : args[ 1 ];
				break;
			case 'param':
				node[ args[ 0 ] ].value = args[ 1 ];
				break;
			case 'connect':
				node.connect( context.destination );
				break;
			case 'start':
				node.start( ...args.map( time ) );
				break;
			case 'stop':
				node.stop( time( args[ 0 ] ) );
				break;
			default:
				throw new Error( 'unknown operation ' + op );

		}

	}

	const result = await context.startRendering();

	await new Promise( ( resolve ) => setTimeout( resolve, 50 ) );

	return {
		channels: Array.from( { length: result.numberOfChannels }, ( _, c ) => Array.from( result.getChannelData( c ) ) ),
		ended,
	};

}

try {

	const page = await browser.newPage();
	const meta = { browser: await browser.version(), ended: {} };

	mkdirSync( out, { recursive: true } );

	for ( const [ name, scenario ] of Object.entries( doc.scenarios ) ) {

		const { channels, ended } = await page.evaluate( render, doc, scenario );

		writeFileSync( join( out, name + '.f32' ), Buffer.from( Float32Array.from( channels.flat() ).buffer ) );
		meta.ended[ name ] = ended;

	}

	writeFileSync( join( out, 'meta.json' ), JSON.stringify( meta, null, '\t' ) + '\n' );

} finally {

	await browser.close();

}
