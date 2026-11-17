// Parses the RGBE test images of fixtures/hdr/ (written by hdr_files.mjs) with the pinned three.js r187
// HDRLoader in Node, as HalfFloatType and as FloatType, and writes what parse() returns to
// fixtures/values/hdr_loader.json: size, header, gamma, exposure, type, color space, filters, mipmaps, flipY and the
// data (half floats as their 16-bit integers, floats as numbers). packages/ent/test/loaders/hdr_loader_test.dart
// parses the same files with the Dart port and compares.
//
// Usage: node tool/reference/js/hdr_loader.mjs

import { readFileSync, writeFileSync } from 'node:fs';
import { execSync } from 'node:child_process';
import { register } from 'node:module';

const here = new URL( '.', import.meta.url );
const core = new URL( '../../../third_party/three.js/src/Three.Core.js', here ).href;
const git = ( args ) => execSync( 'git ' + args, { cwd: new URL( '../../../third_party/three.js/', here ) } ).toString().trim();
const pin = { tag: git( 'describe --tags --exact-match' ), commit: git( 'rev-parse HEAD' ) };

if ( pin.tag !== 'r187' ) {

	throw new Error( 'three.js checkout is ' + pin.tag + ', fixtures require r187' );

}

// The addons import the bare specifier 'three'; resolve it to the core build of the pinned source.
const hook = `export async function resolve( specifier, context, next ) {
	if ( specifier === 'three' ) {
		return { url: ${JSON.stringify( core )}, shortCircuit: true };
	}
	return next( specifier, context );
}`;
register( 'data:text/javascript,' + encodeURIComponent( hook ) );

const THREE = await import( core );
const { HDRLoader } = await import( '../../../third_party/three.js/examples/jsm/loaders/HDRLoader.js' );

const files = {};

for ( const file of [ 'sky.hdr', 'flat.hdr' ] ) {

	const bytes = readFileSync( new URL( '../../../fixtures/hdr/' + file, here ) );
	files[ file ] = {};

	for ( const [ name, type ] of [ [ 'half', THREE.HalfFloatType ], [ 'float', THREE.FloatType ] ] ) {

		const result = new HDRLoader().setDataType( type ).parse( bytes.buffer.slice( bytes.byteOffset, bytes.byteOffset + bytes.byteLength ) );
		files[ file ][ name ] = { ...result, data: Array.from( result.data ) };

	}

}

writeFileSync( new URL( '../../../fixtures/values/hdr_loader.json', here ), JSON.stringify( { three: pin, files }, null, '\t' ) + '\n' );
