// Writes the small RGBE (.hdr) test images in fixtures/hdr/, computed here (no downloads, no three.js): the
// bytes are deterministic, so running this again reproduces them.
//
// Usage: node tool/reference/js/hdr_files.mjs
//
// - sky.hdr: a 64 × 32 run-length encoded equirectangular sky in linear light (dark ground to a blue zenith,
//   warmer toward +x) with a soft sun up to about 4.6, for the hdr_environment parity scenes; its constant
//   ground rows give encoded runs, the rest literal runs.
// - flat.hdr: a 4 × 2 flat (not run-length encoded) image with comment, GAMMA and EXPOSURE header lines, a black
//   texel and one above half float's 65504.

import { mkdirSync, writeFileSync } from 'node:fs';

const out = new URL( '../../../fixtures/hdr/', import.meta.url );
mkdirSync( out, { recursive: true } );

// Ward's float2rgbe: the largest channel's binary exponent, the mantissas scaled to 0..255.
function rgbe( [ r, g, b ] ) {

	const max = Math.max( r, g, b );

	if ( max < 1e-32 ) {

		return [ 0, 0, 0, 0 ];

	}

	let e = Math.floor( Math.log2( max ) ) + 1;

	// frexp: max = m * 2^e with m in [0.5, 1).
	while ( max / 2 ** e >= 1 ) {

		e ++;

	}

	while ( max / 2 ** e < 0.5 ) {

		e --;

	}

	const v = 256 / 2 ** e;
	return [ Math.floor( r * v ), Math.floor( g * v ), Math.floor( b * v ), e + 128 ];

}

function header( width, height, lines = [] ) {

	return Buffer.from( [ '#?RADIANCE', ...lines, 'FORMAT=32-bit_rle_rgbe', '', `-Y ${height} +X ${width}`, '' ].join( '\n' ), 'latin1' );

}

// One channel of a scanline: runs of 3 or more equal bytes as (128 + count, value), the rest as literal runs of
// up to 128 bytes.
function channel( bytes ) {

	const out = [];
	let literal = [];

	const flush = () => {

		for ( let i = 0; i < literal.length; i += 128 ) {

			const part = literal.slice( i, i + 128 );
			out.push( part.length, ...part );

		}

		literal = [];

	};

	for ( let i = 0; i < bytes.length; ) {

		let run = 1;

		while ( i + run < bytes.length && run < 127 && bytes[ i + run ] === bytes[ i ] ) {

			run ++;

		}

		if ( run >= 3 ) {

			flush();
			out.push( 128 + run, bytes[ i ] );
			i += run;

		} else {

			literal.push( bytes[ i ] );
			i ++;

		}

	}

	flush();
	return out;

}

function sky() {

	const width = 64, height = 32;
	const toward = [ 0.6, 0.55, 0.58 ];
	const bytes = [];

	// Rows top first (-Y): the zenith row comes first.
	for ( let y = 0; y < height; y ++ ) {

		const texels = [];

		for ( let x = 0; x < width; x ++ ) {

			const phi = ( ( x + 0.5 ) / width - 0.5 ) * 2 * Math.PI;
			const theta = ( 0.5 - ( y + 0.5 ) / height ) * Math.PI;
			const d = [ Math.cos( phi ) * Math.cos( theta ), Math.sin( theta ), Math.sin( phi ) * Math.cos( theta ) ];
			const t = Math.min( Math.max( ( d[ 1 ] + 0.3 ) / 1, 0 ), 1 );
			const up = t * t * ( 3 - 2 * t );
			const warm = 0.5 + 0.5 * d[ 0 ];
			const glow = 4 * Math.exp( - 6 * ( 1 - ( d[ 0 ] * toward[ 0 ] + d[ 1 ] * toward[ 1 ] + d[ 2 ] * toward[ 2 ] ) / Math.hypot( ...toward ) ) );

			// The ground below -30° is one constant color.
			texels.push( rgbe( d[ 1 ] < - 0.5 ? [ 0.1, 0.08, 0.06 ] : [
				0.12 + 0.25 * up + 0.3 * warm * ( 1 - up ) + glow,
				0.1 + 0.4 * up + 0.12 * warm + glow * 0.9,
				0.08 + 0.75 * up + glow * 0.7,
			] ) );

		}

		bytes.push( 2, 2, width >> 8, width & 255 );

		for ( let c = 0; c < 4; c ++ ) {

			bytes.push( ...channel( texels.map( ( texel ) => texel[ c ] ) ) );

		}

	}

	return Buffer.concat( [ header( width, height, [ '# sky for the ent parity scenes' ] ), Buffer.from( bytes ) ] );

}

function flat() {

	return Buffer.concat( [
		header( 4, 2, [ '# flat', 'GAMMA=2.2', 'EXPOSURE=0.5' ] ),
		Buffer.from( [ [ 0, 0, 0 ], [ 0.5, 0.25, 0.125 ], [ 3.7, 1.2, 0.01 ], [ 1, 1, 1 ], [ 70000, 30, 2 ], [ 0.001, 0.002, 0.003 ], [ 12, 6, 3 ], [ 0.2, 0.9, 0.4 ] ].flatMap( rgbe ) ),
	] );

}

writeFileSync( new URL( 'sky.hdr', out ), sky() );
writeFileSync( new URL( 'flat.hdr', out ), flat() );
