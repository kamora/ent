// Renders the audio scenarios of fixtures/audio/<file>.json with Web Audio's OfflineAudioContext in the installed
// headless Chrome (puppeteer-core from tool/) and writes, per scenario, fixtures/audio/<file>/<name>.f32: the
// rendered channels one after another, as little-endian 32-bit floats. <file>/meta.json records the browser, which
// sources fired `onended`, the parameter values the scenario read and the bin counts of its analyses, whose
// results are in <name>.u8 (getByteFrequencyData) and <name>.db.f32 (getFloatFrequencyData), one after another.
//
// Usage: node tool/reference/audio/render.mjs <file> (for example: sources)
// Chrome: $CHROME, or /Applications/Google Chrome.app.
//
// A scenario has its length in frames, its buffers (filled with `fill`, or by `signal` or `triangle` below, which
// ent_audio's tests repeat) and its operations: [ 'source', name, buffer ], [ 'gain', name ], [ 'panner', name ], [ 'analyser',
// name ], [ 'set', name, attribute, frames ], [ 'attr', name, attribute, value ], [ 'param', name, param, value ],
// [ 'ramp', name, param, value, end ], [ 'target', name, param, value, start, constant ], [ 'read', name, param ],
// [ 'analyse', name ], [ 'connect', name, destination? ], [ 'start', name, when?, offset?, duration? ], [ 'stop',
// name, when ], and [ 'at', frame ], after which the operations run when rendering reaches that frame, a multiple of
// 128. Times are in frames of the context rate; the node named 'listener' is the context's listener.

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

	// Sample i of channel c of a buffer: a fixed pattern in [-1, 1) that needs no transcendental function, or with a
	// `wave` period, a triangle wave of that period.
	const signal = ( c, i ) => ( ( i * 7919 + c * 104729 ) % 2003 ) / 1001.5 - 1;
	const triangle = ( period, i ) => Math.abs( ( i % period ) / period * 4 - 2 ) - 1;
	const time = ( frames ) => frames / doc.rate;
	const context = new OfflineAudioContext( doc.channels, scenario.frames, doc.rate );
	const buffers = {};
	const nodes = { listener: context.listener };
	const ended = [];
	const values = [];
	const bytes = [];
	const decibels = [];
	const bins = [];

	for ( const [ name, b ] of Object.entries( scenario.buffers ) ) {

		const buffer = context.createBuffer( b.channels, b.length, b.rate );

		for ( let c = 0; c < b.channels; c ++ ) {

			const data = buffer.getChannelData( c );

			for ( let i = 0; i < b.length; i ++ ) {

				data[ i ] = b.fill ?? ( b.wave ? triangle( b.wave, i ) : signal( c, i ) );

			}

		}

		buffers[ name ] = buffer;

	}

	const run = ( [ op, name, ...args ] ) => {

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

			case 'gain':
				nodes[ name ] = context.createGain();
				break;
			case 'panner':
				nodes[ name ] = context.createPanner();
				break;
			case 'analyser':
				nodes[ name ] = context.createAnalyser();
				break;
			case 'analyse': {

				const b = new Uint8Array( node.frequencyBinCount );
				const d = new Float32Array( node.frequencyBinCount );

				node.getByteFrequencyData( b );
				node.getFloatFrequencyData( d );
				bytes.push( ...b );

				// As bit patterns: the page's results come back as JSON, which has no -Infinity.
				decibels.push( ...new Uint32Array( d.buffer ) );
				bins.push( node.frequencyBinCount );
				break;

			}

			case 'attr':
				node[ args[ 0 ] ] = args[ 1 ];
				break;

			case 'set':
				node[ args[ 0 ] ] = typeof args[ 1 ] === 'number' ? time( args[ 1 ] ) : args[ 1 ];
				break;
			case 'param':
				node[ args[ 0 ] ].value = args[ 1 ];
				break;
			case 'ramp':
				node[ args[ 0 ] ].linearRampToValueAtTime( args[ 1 ], time( args[ 2 ] ) );
				break;
			case 'target':
				node[ args[ 0 ] ].setTargetAtTime( args[ 1 ], time( args[ 2 ] ), time( args[ 3 ] ) );
				break;
			case 'read':
				values.push( node[ args[ 0 ] ].value );
				break;
			case 'connect':
				node.connect( args.length > 0 ? nodes[ args[ 0 ] ] : context.destination );
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

	};

	// The operations before the first 'at' run now; each later group runs while rendering is suspended at its frame.
	let group = [];
	const groups = [ { frame: 0, ops: group } ];

	for ( const op of scenario.ops ) {

		if ( op[ 0 ] === 'at' ) {

			group = [];
			groups.push( { frame: op[ 1 ], ops: group } );

		} else {

			group.push( op );

		}

	}

	groups[ 0 ].ops.forEach( run );

	for ( const { frame, ops } of groups.slice( 1 ) ) {

		context.suspend( time( frame ) ).then( () => {

			ops.forEach( run );
			context.resume();

		} );

	}

	const result = await context.startRendering();

	await new Promise( ( resolve ) => setTimeout( resolve, 50 ) );

	return {
		channels: Array.from( { length: result.numberOfChannels }, ( _, c ) => Array.from( result.getChannelData( c ) ) ),
		ended,
		values,
		bytes,
		decibels,
		bins,
	};

}

try {

	const page = await browser.newPage();
	const meta = { browser: await browser.version(), ended: {}, values: {}, bins: {} };

	mkdirSync( out, { recursive: true } );

	for ( const [ name, scenario ] of Object.entries( doc.scenarios ) ) {

		const { channels, ended, values, bytes, decibels, bins } = await page.evaluate( render, doc, scenario );

		writeFileSync( join( out, name + '.f32' ), Buffer.from( Float32Array.from( channels.flat() ).buffer ) );
		meta.ended[ name ] = ended;
		meta.values[ name ] = values;

		if ( bins.length > 0 ) {

			writeFileSync( join( out, name + '.u8' ), Uint8Array.from( bytes ) );
			writeFileSync( join( out, name + '.db.f32' ), Buffer.from( Uint32Array.from( decibels ).buffer ) );
			meta.bins[ name ] = bins;

		}

	}

	writeFileSync( join( out, 'meta.json' ), JSON.stringify( meta, null, '\t' ) + '\n' );

} finally {

	await browser.close();

}
