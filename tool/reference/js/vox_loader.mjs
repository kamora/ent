// Parses the MagicaVoxel test files of fixtures/vox/ (written by vox_files.mjs) with the pinned three.js r187
// VOXLoader in Node and writes what it returns to fixtures/values/vox_loader.json: each chunk's size, palette and
// voxel data; the scene graph (names, kinds, positions, quaternions, scales, children); the mesh buildMesh makes of
// each chunk (positions, normals, indices, colors, vertexColors); and the texture buildData3DTexture makes of it.
// packages/ent/test/loaders/vox_loader_test.dart parses the same files with the Dart port and compares.
//
// Usage: node tool/reference/js/vox_loader.mjs

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

const { VOXLoader, buildMesh, buildData3DTexture } = await import( '../../../third_party/three.js/examples/jsm/loaders/VOXLoader.js' );

const mesh = ( m ) => ( {
	position: Array.from( m.geometry.getAttribute( 'position' ).array ),
	normal: Array.from( m.geometry.getAttribute( 'normal' ).array ),
	index: Array.from( m.geometry.index.array ),
	color: m.geometry.getAttribute( 'color' ) ? Array.from( m.geometry.getAttribute( 'color' ).array ) : null,
	vertexColors: m.material.vertexColors,
	material: m.material.type,
} );

const node = ( object ) => ( {
	type: object.type,
	name: object.name,
	position: object.position.toArray(),
	quaternion: object.quaternion.toArray(),
	scale: object.scale.toArray(),
	children: object.children.map( node ),
	...( object.isMesh ? { vertices: object.geometry.getAttribute( 'position' ).count } : {} ),
} );

const files = {};

for ( const file of [ 'single.vox', 'palette.vox', 'black.vox', 'scene.vox' ] ) {

	const bytes = readFileSync( new URL( '../../../fixtures/vox/' + file, here ) );
	const result = new VOXLoader().parse( bytes.buffer.slice( bytes.byteOffset, bytes.byteOffset + bytes.byteLength ) );

	files[ file ] = {
		chunks: result.chunks.map( ( chunk ) => ( {
			size: [ chunk.size.x, chunk.size.y, chunk.size.z ],
			palette: chunk.palette,
			data: Array.from( chunk.data ),
			mesh: mesh( buildMesh( chunk ) ),
			texture: ( ( texture ) => ( {
				size: [ texture.image.width, texture.image.height, texture.image.depth ],
				data: Array.from( texture.image.data ),
				format: texture.format,
				minFilter: texture.minFilter,
				magFilter: texture.magFilter,
				unpackAlignment: texture.unpackAlignment,
			} ) )( buildData3DTexture( chunk ) ),
		} ) ),
		scene: result.scene ? node( result.scene ) : null,
	};

}

writeFileSync(
	new URL( '../../../fixtures/values/vox_loader.json', here ),
	JSON.stringify( { three: pin, files }, null, '\t' ) + '\n'
);
