// Writes the PNG decoder's fixtures to packages/ent_flutter/test/png/: every color type and bit depth, with
// and without tRNS, plain and Adam7, rows cycling through the five filters, data split over several IDAT chunks.
// Each <name>.png comes with <name>.rgba, the straight RGBA8 bytes a browser hands WebGL: low depths scaled to
// 0..255, 16-bit samples by their high byte, tRNS keys transparent. `node tool/png_fixtures.mjs --chrome` also
// decodes every fixture in the installed headless Chrome (createImageBitmap with premultiplyAlpha and
// colorSpaceConversion 'none', read back through WebGL) and reports any byte that differs.

import { mkdirSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { crc32, deflateSync } from 'node:zlib';

const root = join( dirname( fileURLToPath( import.meta.url ) ), '..' );
const out = join( root, 'packages/ent_flutter/test/png' );
const channels = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 };

// A small LCG, so the fixtures are the same on every run.
function random( seed ) {

	let s = seed;

	return ( n ) => {

		s = ( s * 1103515245 + 12345 ) % 2147483648;
		return Math.floor( s / 2147483648 * n );

	};

}

function chunk( type, data ) {

	const body = Buffer.concat( [ Buffer.from( type, 'ascii' ), data ] );
	const length = Buffer.alloc( 4 );
	const crc = Buffer.alloc( 4 );
	length.writeUInt32BE( data.length );
	crc.writeUInt32BE( crc32( body ) );
	return Buffer.concat( [ length, body, crc ] );

}

// Packs one row of samples at a depth into bytes.
function pack( samples, depth ) {

	const bytes = Buffer.alloc( Math.ceil( samples.length * depth / 8 ) );

	samples.forEach( ( v, i ) => {

		if ( depth === 16 ) {

			bytes.writeUInt16BE( v, i * 2 );

		} else if ( depth === 8 ) {

			bytes[ i ] = v;

		} else {

			bytes[ ( i * depth ) >> 3 ] |= v << ( 8 - depth - ( ( i * depth ) & 7 ) );

		}

	} );

	return bytes;

}

// Filters a row (encoder side) given the unfiltered row above, or zeros.
function filter( type, row, prior, step ) {

	const out = Buffer.alloc( row.length + 1 );
	out[ 0 ] = type;

	for ( let i = 0; i < row.length; i ++ ) {

		const a = i < step ? 0 : row[ i - step ];
		const b = prior[ i ];
		const c = i < step ? 0 : prior[ i - step ];
		const [ pa, pb, pc ] = [ a, b, c ].map( ( v ) => Math.abs( a + b - c - v ) );
		const paeth = pa <= pb && pa <= pc ? a : ( pb <= pc ? b : c );
		const predicted = [ 0, a, b, ( a + b ) >> 1, paeth ][ type ];
		out[ i + 1 ] = ( row[ i ] - predicted ) & 255;

	}

	return out;

}

// One fixture: `samples[ y ][ x ]` holds a pixel's raw samples; `palette` (RGB triples) and `trns` (raw tRNS bytes)
// as the type needs.
function write( name, { type, depth, width, height, interlace, samples, palette, trns, gama } ) {

	const n = channels[ type ];
	const raw = [];
	let k = 0;

	// Adam7's passes as [ x0, y0, dx, dy ]; a plain image is one pass.
	for ( const [ x0, y0, dx, dy ] of interlace
		? [ [ 0, 0, 8, 8 ], [ 4, 0, 8, 8 ], [ 0, 4, 4, 8 ], [ 2, 0, 4, 4 ], [ 0, 2, 2, 4 ], [ 1, 0, 2, 2 ],
			[ 0, 1, 1, 2 ] ]
		: [ [ 0, 0, 1, 1 ] ] ) {

		const w = Math.ceil( ( width - x0 ) / dx );
		const h = Math.ceil( ( height - y0 ) / dy );

		if ( w <= 0 || h <= 0 ) {

			continue;

		}

		let prior = Buffer.alloc( Math.ceil( w * n * depth / 8 ) );

		for ( let y = 0; y < h; y ++ ) {

			const row = pack(
				Array.from( { length: w }, ( _, x ) => samples[ y0 + y * dy ][ x0 + x * dx ] ).flat(),
				depth,
			);
			raw.push( filter( k ++ % 5, row, prior, Math.ceil( n * depth / 8 ) ) );
			prior = row;

		}

	}

	const header = Buffer.alloc( 13 );
	header.writeUInt32BE( width, 0 );
	header.writeUInt32BE( height, 4 );
	header[ 8 ] = depth;
	header[ 9 ] = type;
	header[ 12 ] = interlace ? 1 : 0;

	const zlib = deflateSync( Buffer.concat( raw ) );
	const parts = [ Buffer.from( [ 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a ] ), chunk( 'IHDR', header ) ];

	if ( gama ) {

		parts.push( chunk( 'gAMA', Buffer.from( [ 0, 0, 0x27, 0x10 ] ) ) );

	}

	if ( palette ) {

		parts.push( chunk( 'PLTE', Buffer.from( palette.flat() ) ) );

	}

	if ( trns ) {

		parts.push( chunk( 'tRNS', Buffer.from( trns ) ) );

	}

	for ( let i = 0; i < zlib.length; i += 50 ) {

		parts.push( chunk( 'IDAT', zlib.subarray( i, i + 50 ) ) );

	}

	parts.push( chunk( 'IEND', Buffer.alloc( 0 ) ) );

	// The expected straight RGBA8 bytes.
	const scale = ( v ) => depth === 16 ? v >> 8 : Math.floor( v * 255 / ( ( 1 << depth ) - 1 ) );
	const key = trns && type !== 3
		? trns.filter( ( _, i ) => i % 2 === 0 ).map( ( v, i ) => v << 8 | trns[ i * 2 + 1 ] )
		: null;
	const rgba = Buffer.alloc( width * height * 4 );

	samples.flat().forEach( ( s, i ) => {

		if ( type === 3 ) {

			rgba.set( [ ...palette[ s[ 0 ] ], trns && s[ 0 ] < trns.length ? trns[ s[ 0 ] ] : 255 ], i * 4 );

		} else {

			// Gray or RGB, then alpha: a sample, or 0 where tRNS's key equals the raw samples.
			rgba.set( [
				...( type === 0 || type === 4 ? [ s[ 0 ], s[ 0 ], s[ 0 ] ] : s.slice( 0, 3 ) ).map( scale ),
				type === 4 || type === 6
					? scale( s[ n - 1 ] )
					: ( key?.length === ( type === 0 ? 1 : 3 ) && key.every( ( v, c ) => v === s[ c ] ) ? 0 : 255 ),
			], i * 4 );

		}

	} );

	const png = Buffer.concat( parts );
	writeFileSync( join( out, name + '.png' ), png );
	writeFileSync( join( out, name + '.rgba' ), rgba );
	return { name, png, rgba };

}

const cases = [];

// Each color type with the bit depths it allows.
for ( const [ type, depths ] of [
	[ 0, [ 1, 2, 4, 8, 16 ] ], [ 2, [ 8, 16 ] ], [ 3, [ 1, 2, 4, 8 ] ], [ 4, [ 8, 16 ] ], [ 6, [ 8, 16 ] ],
] ) {

	for ( const depth of depths ) {

		for ( const keyed of type === 4 || type === 6 ? [ false ] : [ false, true ] ) {

			cases.push( { type, depth, keyed } );

		}

	}

}

mkdirSync( out, { recursive: true } );
const fixtures = [];

for ( const [ index, { type, depth, keyed } ] of cases.entries() ) {

	for ( const interlace of [ false, true ] ) {

		const next = random( index * 2 + ( interlace ? 1 : 0 ) + 1 );
		const max = ( 1 << depth ) - 1;
		const [ width, height ] = [ 13, 11 ];
		const colors = type === 3 ? Math.min( max + 1, 200 ) : 0;
		const list = ( length, f ) => Array.from( { length }, f );
		const samples = list( height, () => list( width, () => list(
			channels[ type ],
			() => next( colors || max + 1 ),
		) ) );
		let trns;

		if ( type === 6 ) {

			// Colored texels of alpha 0, as AlphaBlendModeTest's label has.
			samples[ 0 ][ 0 ][ 3 ] = 0;
			samples[ 1 ][ 2 ][ 3 ] = 0;

		}

		if ( keyed && type === 3 ) {

			trns = Array.from( { length: Math.ceil( colors / 3 ) }, () => next( 256 ) );

		} else if ( keyed ) {

			// The key is the first pixel; every seventh pixel takes it, and for 16 bits the next one differs from it
			// in the low byte only, so it stays opaque.
			const color = samples[ 0 ][ 0 ];
			trns = color.flatMap( ( v ) => [ v >> 8, v & 255 ] );

			samples.flat().forEach( ( s, i ) => {

				if ( i % 7 === 0 ) {

					s.splice( 0, s.length, ...color );

				} else if ( depth === 16 && i % 7 === 1 ) {

					s.splice( 0, s.length, ...color.map( ( v ) => v ^ 1 ) );

				}

			} );

		}

		fixtures.push( write( `t${ type }_d${ depth }${ keyed ? '_trns' : '' }${ interlace ? '_adam7' : '' }`, {
			type, depth, width, height, interlace, samples, trns,
			palette: type === 3 ? list( colors, () => [ next( 256 ), next( 256 ), next( 256 ) ] ) : undefined,
		} ) );

	}

}

// Small interlaced images, where some of Adam7's passes are empty, and a gAMA chunk that must be ignored.
fixtures.push(
	write( 'tiny_1x1_adam7', {
		type: 6, depth: 8, width: 1, height: 1, interlace: true, samples: [ [ [ 10, 20, 30, 0 ] ] ],
	} ),
	write( 'tiny_3x2_adam7', {
		type: 0, depth: 1, width: 3, height: 2, interlace: true,
		samples: [ [ [ 1 ], [ 0 ], [ 1 ] ], [ [ 0 ], [ 1 ], [ 1 ] ] ],
	} ),
	write( 'gama', {
		type: 2, depth: 8, width: 2, height: 1, gama: true, samples: [ [ [ 100, 150, 200 ], [ 3, 128, 250 ] ] ],
	} ),
);
console.log( `${ fixtures.length } fixtures in ${ out }` );

if ( process.argv.includes( '--chrome' ) ) {

	const puppeteer = ( await import(
		pathToFileURL( createRequire( join( root, 'tool/package.json' ) ).resolve( 'puppeteer-core' ) )
	) ).default;
	const browser = await puppeteer.launch( {
		executablePath: process.env.CHROME ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
		headless: true,
		args: [ '--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist' ],
	} );

	try {

		const page = await browser.newPage();
		let failures = 0;

		for ( const { name, png, rgba } of fixtures ) {

			const wrong = ( await page.evaluate( async ( data ) => {

				const bitmap = await createImageBitmap(
					new Blob( [ Uint8Array.from( atob( data ), ( c ) => c.charCodeAt( 0 ) ) ], { type: 'image/png' } ),
					{ premultiplyAlpha: 'none', colorSpaceConversion: 'none' },
				);
				const gl = new OffscreenCanvas( 1, 1 ).getContext( 'webgl2' );
				gl.pixelStorei( gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false );
				gl.pixelStorei( gl.UNPACK_COLORSPACE_CONVERSION_WEBGL, gl.NONE );
				const texture = gl.createTexture();
				gl.bindTexture( gl.TEXTURE_2D, texture );
				gl.texImage2D( gl.TEXTURE_2D, 0, gl.RGBA8, gl.RGBA, gl.UNSIGNED_BYTE, bitmap );
				gl.bindFramebuffer( gl.FRAMEBUFFER, gl.createFramebuffer() );
				gl.framebufferTexture2D( gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture, 0 );
				const read = new Uint8Array( bitmap.width * bitmap.height * 4 );
				gl.readPixels( 0, 0, bitmap.width, bitmap.height, gl.RGBA, gl.UNSIGNED_BYTE, read );
				return Array.from( read );

			}, png.toString( 'base64' ) ) ).map( ( v, i ) => [ i, v, rgba[ i ] ] ).filter( ( [ , v, e ] ) => v !== e );

			if ( wrong.length > 0 ) {

				failures ++;
				console.log( `${ name }: ${ wrong.length } bytes differ, e.g. ` + wrong.slice( 0, 4 )
					.map( ( [ i, v, e ] ) => `[${ i }] chrome ${ v } expected ${ e }` ).join( ', ' ) );

			}

		}

		console.log( `Chrome: ${ fixtures.length - failures } of ${ fixtures.length } fixtures match` );

	} finally {

		await browser.close();

	}

}
