// Writes the small MagicaVoxel (.vox) test files in fixtures/vox/, built here byte by byte from the format (no
// downloads, no three.js): the bytes are deterministic, so running this again reproduces them.
//
// Usage: node tool/reference/js/vox_files.mjs
//
// - single.vox (version 150): one 4 × 3 × 2 model in the default palette, a base of one color with one voxel of
//   another and a partial top layer, so greedy meshing merges some faces and splits others.
// - palette.vox (version 150): a 2 × 2 × 2 model with its own RGBA palette, two colors.
// - black.vox (version 150): one voxel whose RGBA palette is all black, so the mesh has no vertex colors.
// - scene.vox (version 200): two models and a scene graph: a root transform without data over a group of a named,
//   translated transform of one shape; a rotated, translated transform of a group (a transform without data over
//   a shape); and a translated transform of a shape with both models; plus a LAYR chunk the loader skips and one
//   RGBA palette after both models, which the loader applies to both.

import { mkdirSync, writeFileSync } from 'node:fs';

const out = new URL( '../../../fixtures/vox/', import.meta.url );
mkdirSync( out, { recursive: true } );

const int32 = ( value ) => {

	const bytes = Buffer.alloc( 4 );
	bytes.writeInt32LE( value );
	return bytes;

};

const string = ( text ) => Buffer.concat( [ int32( text.length ), Buffer.from( text, 'latin1' ) ] );

const dict = ( entries ) => Buffer.concat( [
	int32( Object.keys( entries ).length ),
	...Object.entries( entries ).flatMap( ( [ key, value ] ) => [ string( key ), string( value ) ] )
] );

// A chunk: its id, its content's size, its children's size (always 0 here), its content.
const chunk = ( id, content ) => Buffer.concat( [ Buffer.from( id, 'latin1' ), int32( content.length ), int32( 0 ), content ] );

const size = ( x, y, z ) => chunk( 'SIZE', Buffer.concat( [ int32( x ), int32( y ), int32( z ) ] ) );

const xyzi = ( voxels ) => chunk( 'XYZI', Buffer.concat( [ int32( voxels.length ), Buffer.from( voxels.flat() ) ] ) );

// 256 colors as r, g, b, a bytes; color k is palette index k + 1.
const rgba = ( colors ) => chunk( 'RGBA', Buffer.from( Array.from( { length: 256 }, ( _, k ) => colors[ k ] ?? [ 0, 0, 0, 255 ] ).flat() ) );

const transform = ( id, attributes, child, frame ) =>
	chunk( 'nTRN', Buffer.concat( [ int32( id ), dict( attributes ), int32( child ), int32( - 1 ), int32( 0 ), int32( 1 ), dict( frame ) ] ) );

const group = ( id, children ) => chunk( 'nGRP', Buffer.concat( [ int32( id ), dict( {} ), int32( children.length ), ...children.map( int32 ) ] ) );

const shape = ( id, models ) => chunk( 'nSHP', Buffer.concat( [ int32( id ), dict( {} ), int32( models.length ), ...models.flatMap( ( m ) => [ int32( m ), dict( {} ) ] ) ] ) );

// The file: "VOX ", the version, and a MAIN chunk holding the others.
const file = ( name, version, children ) => {

	const body = Buffer.concat( children );
	const main = Buffer.concat( [ Buffer.from( 'MAIN', 'latin1' ), int32( 0 ), int32( body.length ), body ] );
	writeFileSync( new URL( name, out ), Buffer.concat( [ Buffer.from( 'VOX ', 'latin1' ), int32( version ), main ] ) );

};

const single = [];

for ( let y = 0; y < 3; y ++ ) {

	for ( let x = 0; x < 4; x ++ ) {

		single.push( [ x, y, 0, x === 2 && y === 1 ? 9 : 5 ] );

	}

}

single.push( [ 0, 0, 1, 5 ], [ 1, 0, 1, 5 ], [ 0, 1, 1, 200 ] );
file( 'single.vox', 150, [ size( 4, 3, 2 ), xyzi( single ) ] );

const cube = [];

for ( let i = 0; i < 8; i ++ ) {

	cube.push( [ i & 1, ( i >> 1 ) & 1, i >> 2, i < 4 ? 1 : 2 ] );

}

file( 'palette.vox', 150, [ size( 2, 2, 2 ), xyzi( cube ), rgba( [ [ 200, 40, 60, 255 ], [ 30, 160, 230, 255 ] ] ) ] );

file( 'black.vox', 150, [ size( 1, 1, 1 ), xyzi( [ [ 0, 0, 0, 1 ] ] ), rgba( [] ) ] );

// A rotation byte: the first row's entry in column 1, the second row's in column 0 and negative (a quarter turn).
const turn = String( 1 | ( 0 << 2 ) | ( 1 << 5 ) );

file( 'scene.vox', 200, [
	size( 3, 1, 1 ), xyzi( [ [ 0, 0, 0, 1 ], [ 1, 0, 0, 1 ], [ 2, 0, 0, 1 ] ] ),
	size( 1, 2, 1 ), xyzi( [ [ 0, 0, 0, 2 ], [ 0, 1, 0, 2 ] ] ),
	transform( 0, {}, 1, {} ),
	group( 1, [ 2, 4, 6 ] ),
	transform( 2, { _name: 'left' }, 3, { _t: '5 0 0' } ),
	shape( 3, [ 0 ] ),
	transform( 4, { _name: 'turned' }, 5, { _r: turn, _t: '0 -3 2' } ),
	group( 5, [ 7 ] ),
	transform( 7, {}, 8, {} ),
	shape( 8, [ 1 ] ),
	transform( 6, {}, 9, { _t: '1 2 3' } ),
	shape( 9, [ 0, 1 ] ),
	chunk( 'LAYR', Buffer.concat( [ int32( 0 ), dict( { _name: 'skipped' } ), int32( - 1 ) ] ) ),
	rgba( [ [ 240, 200, 40, 255 ], [ 60, 90, 200, 255 ] ] ),
] );
