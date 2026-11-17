// Writes the small glTF test assets in fixtures/gltf/, built by hand (no downloads): their JSON and buffers
// are deterministic, so running this again reproduces the same bytes.
//
// Usage: node tool/reference/js/gltf_files.mjs
//
// - scene.gltf: two scenes (the second reuses a node of the first), nested nodes with TRS and matrix transforms,
//   a mesh used by two nodes, a two-primitive mesh, triangle strip and fan primitives, interleaved, sparse and
//   normalized accessors of every component type, MASK, BLEND, double-sided, unlit and emissive-strength
//   materials, vertex colors, perspective and orthographic cameras, punctual lights, duplicate and unsafe node
//   names, extras and an unknown extension. Its buffer is a base64 data URI.
// - scene.glb: the same asset as binary glTF, the buffer in the BIN chunk.
// - external.gltf + external.bin: a small asset whose buffer is an external file, loaded through FileLoader.
// - render.gltf: front-facing quads for the rendering parity scenes (gltf_meshes in the Chrome harness).
// - textured.gltf + textured.glb + checker.png: textures from a buffer view, a data URI and an external file,
//   samplers with each wrap mode and filter, KHR_texture_transform, texCoord 1, every PBR extension plugin, and
//   line, line strip, line loop and point primitives. The PNGs are written here, deterministically.
// - render_textured.gltf: textured and PBR-extension quads, a line strip and points (gltf_textured).
// - skinned.gltf: a two-joint skin with inverse bind matrices, morph targets with names and default weights,
//   node weights, and two animations over translation, rotation, scale and weights with LINEAR, STEP and
//   CUBICSPLINE samplers, one with normalized int16 output (also the gltf_skinned_anim parity scene).

import { mkdirSync, writeFileSync } from 'node:fs';
import { deflateSync } from 'node:zlib';

const out = new URL( '../../../fixtures/gltf/', import.meta.url );
mkdirSync( out, { recursive: true } );

// A growing binary buffer: each view is 4-byte aligned, as glTF requires.
class Builder {

	constructor() {

		this.bytes = [];
		this.views = [];
		this.accessors = [];

	}

	view( array, stride ) {

		while ( this.bytes.length % 4 !== 0 ) {

			this.bytes.push( 0 );

		}

		const offset = this.bytes.length;
		const data = new Uint8Array( array.buffer, array.byteOffset, array.byteLength );

		for ( const b of data ) {

			this.bytes.push( b );

		}

		const view = { buffer: 0, byteOffset: offset, byteLength: data.length };

		if ( stride !== undefined ) {

			view.byteStride = stride;

		}

		this.views.push( view );

		return this.views.length - 1;

	}

	accessor( def ) {

		this.accessors.push( def );

		return this.accessors.length - 1;

	}

	// A tightly packed accessor of its own view; min/max for positions.
	add( array, componentType, type, extra = {} ) {

		const size = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16 }[ type ];
		const def = { bufferView: this.view( array ), componentType, count: array.length / size, type, ...extra };

		if ( extra.bounds ) {

			delete def.bounds;
			def.min = [];
			def.max = [];

			for ( let c = 0; c < size; c ++ ) {

				let min = Infinity, max = - Infinity;

				for ( let i = c; i < array.length; i += size ) {

					min = Math.min( min, array[ i ] );
					max = Math.max( max, array[ i ] );

				}

				def.min.push( min );
				def.max.push( max );

			}

		}

		return this.accessor( def );

	}

	buffer() {

		while ( this.bytes.length % 4 !== 0 ) {

			this.bytes.push( 0 );

		}

		return Buffer.from( this.bytes );

	}

}

const FLOAT = 5126, BYTE = 5120, UBYTE = 5121, SHORT = 5122, USHORT = 5123, UINT = 5125;

// A quad in the z = `z` plane from (x0, y0) to (x1, y1), facing +z.
const quad = ( x0, y0, x1, y1, z = 0 ) => new Float32Array( [ x0, y0, z, x1, y0, z, x1, y1, z, x0, y1, z ] );

function sceneAsset() {

	const b = new Builder();

	// Mesh 0: a box-like quad with normals and uint16 indices; used by two nodes (instances).
	const boxPos = b.add( quad( - 0.5, - 0.5, 0.5, 0.5 ), FLOAT, 'VEC3', { bounds: true } );
	const boxNrm = b.add( new Float32Array( [ 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1 ] ), FLOAT, 'VEC3' );
	const boxUv = b.add( new Uint16Array( [ 0, 0, 65535, 0, 65535, 65535, 0, 65535 ] ), USHORT, 'VEC2', { normalized: true } );
	const boxIdx = b.add( new Uint16Array( [ 0, 1, 2, 0, 2, 3 ] ), USHORT, 'SCALAR' );

	// Mesh 1: a triangle strip without indices, normalized ubyte RGBA vertex colors, int16 normalized uv1.
	const stripPos = b.add( new Float32Array( [ 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 2, 0 ] ), FLOAT, 'VEC3', { bounds: true } );
	const stripCol = b.add( new Uint8Array( [ 255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 128, 255, 255, 0, 255, 10, 20, 30, 40 ] ), UBYTE, 'VEC4', { normalized: true } );
	const stripUv1 = b.add( new Int16Array( [ 0, 0, 32767, 0, 0, 32767, 32767, 32767, - 32767, 16000 ] ), SHORT, 'VEC2', { normalized: true } );

	// Mesh 2: a triangle fan with ubyte indices, an int8 custom attribute and a uint32-indexed second primitive.
	const fanPos = b.add( new Float32Array( [ 0, 0, 0, 1, 0, 0, 0.7, 0.7, 0, 0, 1, 0, - 0.7, 0.7, 0 ] ), FLOAT, 'VEC3', { bounds: true } );
	const fanIdx = b.add( new Uint8Array( [ 0, 1, 2, 3, 4 ] ), UBYTE, 'SCALAR' );
	const fanCustom = b.add( new Int8Array( [ - 128, - 1, 0, 1, 127 ] ), BYTE, 'SCALAR' );
	const triIdx = b.add( new Uint32Array( [ 0, 2, 4 ] ), UINT, 'SCALAR' );

	// Mesh 3: interleaved position + normal (stride 24) in one view, two accessors into it.
	const inter = new Float32Array( [
		- 1, - 1, 0, 0, 0, 1,
		1, - 1, 0, 0, 0, 1,
		1, 1, 0, 0, 0.6, 0.8,
		- 1, 1, 0, 0, 0.6, 0.8,
	] );
	const interView = b.view( inter, 24 );
	const interPos = b.accessor( { bufferView: interView, byteOffset: 0, componentType: FLOAT, count: 4, type: 'VEC3', min: [ - 1, - 1, 0 ], max: [ 1, 1, 0 ] } );
	const interNrm = b.accessor( { bufferView: interView, byteOffset: 12, componentType: FLOAT, count: 4, type: 'VEC3' } );

	// Mesh 4: sparse accessors: one over a base view (two positions replaced), one without a view (zeros + sparse).
	const sparseBase = b.view( quad( 0, 0, 2, 2 ) );
	const sparseIdx = b.view( new Uint16Array( [ 1, 3 ] ) );
	const sparseVal = b.view( new Float32Array( [ 3, 0, 0.5, 0, 3, - 0.5 ] ) );
	const sparsePos = b.accessor( {
		bufferView: sparseBase, componentType: FLOAT, count: 4, type: 'VEC3', min: [ 0, 0, - 0.5 ], max: [ 3, 3, 0.5 ],
		sparse: { count: 2, indices: { bufferView: sparseIdx, componentType: USHORT }, values: { bufferView: sparseVal } },
	} );
	const sparseIdx2 = b.view( new Uint8Array( [ 0, 0, 0, 2 ] ) );
	const sparseVal2 = b.view( new Float32Array( [ 1, 0.5, 0.25 ] ) );
	const sparseTan = b.accessor( {
		componentType: FLOAT, count: 4, type: 'VEC3',
		sparse: { count: 1, indices: { bufferView: sparseIdx2, byteOffset: 3, componentType: UBYTE }, values: { bufferView: sparseVal2 } },
	} );
	const sparseIdx3 = b.add( new Uint32Array( [ 0, 1, 2, 0, 2, 3 ] ), UINT, 'SCALAR' );

	const json = {
		asset: { version: '2.0', generator: 'ent gltf_files.mjs', copyright: 'CC0', extras: { note: 'test asset' } },
		extensionsUsed: [ 'KHR_lights_punctual', 'KHR_materials_unlit', 'KHR_materials_emissive_strength', 'EXT_unknown_test' ],
		extensions: {
			KHR_lights_punctual: {
				lights: [
					{ type: 'directional', color: [ 1, 0.9, 0.8 ], intensity: 2.5, name: 'Sun' },
					{ type: 'point', intensity: 30, range: 12 },
					{ type: 'spot', color: [ 0.2, 0.4, 1 ], intensity: 50, spot: { innerConeAngle: 0.2, outerConeAngle: 0.6 }, name: 'Spot', extras: { kind: 'spot' } },
				],
			},
		},
		extras: { root: true, n: 3 },
		scene: 0,
		scenes: [
			{ name: 'Main', nodes: [ 0, 9, 10 ], extras: { level: 1 } },
			{ name: 'Second', nodes: [ 11, 3, 10 ] },
		],
		nodes: [
			// 0
			{ name: 'Root', translation: [ 1, 2, 3 ], rotation: [ 0, 0.3826834323650898, 0, 0.9238795325112867 ], scale: [ 2, 2, 2 ], children: [ 1, 2, 4, 5 ], extras: { tag: 'root' } },
			// 1: matrix node with mesh 0
			{ name: 'Child.Box', matrix: [ 1, 0, 0, 0, 0, 0, - 1, 0, 0, 1, 0, 0, 0.5, - 1, 2, 1 ], mesh: 0 },
			// 2: second use of mesh 0, nested under a Dup-named group
			{ name: 'Dup', children: [ 6 ], extensions: { EXT_unknown_test: { value: 42 } } },
			// 3: strip mesh (also in the second scene)
			{ name: 'Strip', mesh: 1, translation: [ - 1, 0, 0 ] },
			// 4: fan + triangle (two primitives -> Group)
			{ name: 'Dup', mesh: 2, rotation: [ 0.1, 0.2, 0.3, 0.9273618495495703 ] },
			// 5: interleaved mesh and a perspective camera -> Group
			{ name: 'a b[c]:d/e', mesh: 3, camera: 0, scale: [ 1, 0.5, 1 ] },
			// 6: second use of mesh 0, unnamed
			{ mesh: 0, translation: [ 0, 0, - 1 ] },
			// 7: orthographic camera, no name
			{ camera: 1, translation: [ 0, 5, 0 ] },
			// 8: lights
			{ name: 'Lights', children: [ 12, 13, 14 ] },
			// 9: sparse mesh
			{ name: 'Sparse', mesh: 4, children: [ 7, 8 ] },
			// 10: empty node with extras of a primitive type
			{ name: 'Empty', extras: 'primitive' },
			// 11: unnamed mesh node in the second scene
			{ mesh: 5 },
			// 12-14
			{ extensions: { KHR_lights_punctual: { light: 0 } }, rotation: [ - 0.3826834323650898, 0, 0, 0.9238795325112867 ] },
			{ name: 'Bulb', extensions: { KHR_lights_punctual: { light: 1 } }, translation: [ 0, 3, 0 ] },
			{ extensions: { KHR_lights_punctual: { light: 2 } }, translation: [ 2, 2, 2 ] },
		],
		cameras: [
			{ type: 'perspective', name: 'Eye', perspective: { yfov: 0.8, aspectRatio: 1.5, znear: 0.05, zfar: 100 }, extras: { cam: 1 } },
			{ type: 'orthographic', orthographic: { xmag: 2, ymag: 1.5, znear: 0.1, zfar: 50 } },
		],
		meshes: [
			{ name: 'Box', primitives: [ { attributes: { POSITION: boxPos, NORMAL: boxNrm, TEXCOORD_0: boxUv }, indices: boxIdx, material: 0 } ], extras: { meshExtra: [ 1, 2 ] } },
			{ primitives: [ { attributes: { POSITION: stripPos, COLOR_0: stripCol, TEXCOORD_1: stripUv1 }, mode: 5, material: 1 } ] },
			{
				name: 'FanAndTri',
				primitives: [
					{ attributes: { POSITION: fanPos, _CUSTOM: fanCustom }, indices: fanIdx, mode: 6, material: 2, extras: { prim: 0 } },
					{ attributes: { POSITION: fanPos }, indices: triIdx, material: 3, extensions: { EXT_unknown_test: { prim: true } } },
				],
			},
			{ name: 'Interleaved', primitives: [ { attributes: { POSITION: interPos, NORMAL: interNrm }, material: 4 } ] },
			{ name: 'Sparse', primitives: [ { attributes: { POSITION: sparsePos, TANGENT: sparseTan }, indices: sparseIdx3, material: 5 } ] },
			{ name: 'Box', primitives: [ { attributes: { POSITION: boxPos, NORMAL: boxNrm, TEXCOORD_0: boxUv }, indices: boxIdx } ] },
		],
		materials: [
			{ name: 'Metal', pbrMetallicRoughness: { baseColorFactor: [ 0.8, 0.2, 0.1, 1 ], metallicFactor: 0.7, roughnessFactor: 0.35 }, emissiveFactor: [ 0.1, 0.05, 0 ], extras: { mat: 'metal' } },
			{ name: 'Masked', pbrMetallicRoughness: { baseColorFactor: [ 1, 1, 1, 0.9 ] }, alphaMode: 'MASK', alphaCutoff: 0.25, doubleSided: true },
			{ name: 'Blend', pbrMetallicRoughness: { baseColorFactor: [ 0.1, 0.5, 0.9, 0.5 ], metallicFactor: 0 }, alphaMode: 'BLEND' },
			{ name: 'Unlit', pbrMetallicRoughness: { baseColorFactor: [ 0.3, 0.6, 0.2, 0.75 ] }, extensions: { KHR_materials_unlit: {} }, alphaMode: 'MASK', emissiveFactor: [ 1, 1, 1 ] },
			{ name: 'Glow', pbrMetallicRoughness: { metallicFactor: 0.1, roughnessFactor: 0.9 }, emissiveFactor: [ 0.5, 1, 0.25 ], extensions: { KHR_materials_emissive_strength: { emissiveStrength: 4 }, EXT_unknown_test: { mat: 1 } } },
			{ name: 'Default-ish', doubleSided: false, alphaMode: 'OPAQUE' },
		],
	};

	return { json: { ...json, accessors: b.accessors, bufferViews: b.views }, bin: b.buffer() };

}

function externalAsset() {

	const b = new Builder();
	const pos = b.add( new Float32Array( [ 0, 0, 0, 1, 0, 0, 0, 1, 0 ] ), FLOAT, 'VEC3', { bounds: true } );
	const idx = b.add( new Uint16Array( [ 0, 1, 2 ] ), USHORT, 'SCALAR' );

	return {
		json: {
			asset: { version: '2.0' },
			scenes: [ { nodes: [ 0 ] } ],
			nodes: [ { name: 'Tri', mesh: 0 } ],
			meshes: [ { primitives: [ { attributes: { POSITION: pos }, indices: idx } ] } ],
			accessors: b.accessors,
			bufferViews: b.views,
		},
		bin: b.buffer(),
	};

}

// Quads in an orthographic view of [-1, 1]²: edges on multiples of 1/64 lie halfway between pixel centres of
// the 128×128 frame (centres at (i + 0.5) / 64 - 1).
function renderAsset() {

	const b = new Builder();
	const n = new Float32Array( [ 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1 ] );
	const idx = b.add( new Uint16Array( [ 0, 1, 2, 0, 2, 3 ] ), USHORT, 'SCALAR' );
	const nrm = b.add( n, FLOAT, 'VEC3' );

	const litPos = b.add( quad( - 0.875, 0.125, - 0.125, 0.875 ), FLOAT, 'VEC3', { bounds: true } );
	const unlitPos = b.add( quad( 0.125, 0.125, 0.875, 0.875 ), FLOAT, 'VEC3', { bounds: true } );

	// A strip quad with vertex colors (lower left).
	const stripPos = b.add( new Float32Array( [ - 0.875, - 0.875, 0, - 0.125, - 0.875, 0, - 0.875, - 0.125, 0, - 0.125, - 0.125, 0 ] ), FLOAT, 'VEC3', { bounds: true } );
	const stripCol = b.add( new Uint8Array( [ 230, 40, 40, 255, 40, 230, 40, 255, 40, 40, 230, 255, 230, 230, 40, 255 ] ), UBYTE, 'VEC4', { normalized: true } );

	// Interleaved quad (lower right), and a blended quad over the lit and unlit ones.
	const inter = new Float32Array( 4 * 6 );
	const ip = quad( 0.125, - 0.875, 0.875, - 0.125 );

	for ( let i = 0; i < 4; i ++ ) {

		inter.set( ip.subarray( i * 3, i * 3 + 3 ), i * 6 );
		inter.set( [ 0, 0, 1 ], i * 6 + 3 );

	}

	const interView = b.view( inter, 24 );
	const interPos = b.accessor( { bufferView: interView, byteOffset: 0, componentType: FLOAT, count: 4, type: 'VEC3', min: [ 0.125, - 0.875, 0 ], max: [ 0.875, - 0.125, 0 ] } );
	const interNrm = b.accessor( { bufferView: interView, byteOffset: 12, componentType: FLOAT, count: 4, type: 'VEC3' } );
	const blendPos = b.add( quad( - 0.5, 0.375, 0.5, 0.625, 0.25 ), FLOAT, 'VEC3', { bounds: true } );

	return {
		json: {
			asset: { version: '2.0' },
			extensionsUsed: [ 'KHR_lights_punctual', 'KHR_materials_unlit', 'KHR_materials_emissive_strength' ],
			extensions: { KHR_lights_punctual: { lights: [ { type: 'directional', color: [ 1, 0.95, 0.9 ], intensity: 2 } ] } },
			scenes: [ { nodes: [ 0, 5 ] } ],
			nodes: [
				{ name: 'Quads', children: [ 1, 2, 3, 4 ], translation: [ 0, 0, - 1 ] },
				{ name: 'Lit', mesh: 0 },
				{ name: 'Unlit', mesh: 1 },
				{ name: 'Strip', mesh: 2 },
				{ name: 'Inter', mesh: 3, children: [ 6 ] },
				{ name: 'Sun', extensions: { KHR_lights_punctual: { light: 0 } }, rotation: [ - 0.25, 0.2, 0, 0.9473309334313418 ] },
				{ name: 'Blend', mesh: 4, matrix: [ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 ] },
			],
			meshes: [
				{ primitives: [ { attributes: { POSITION: litPos, NORMAL: nrm }, indices: idx, material: 0 } ] },
				{ primitives: [ { attributes: { POSITION: unlitPos }, indices: idx, material: 1 } ] },
				{ primitives: [ { attributes: { POSITION: stripPos, NORMAL: nrm, COLOR_0: stripCol }, mode: 5, material: 2 } ] },
				{ primitives: [ { attributes: { POSITION: interPos, NORMAL: interNrm }, indices: idx, material: 3 } ] },
				{ primitives: [ { attributes: { POSITION: blendPos, NORMAL: nrm }, indices: idx, material: 4 } ] },
			],
			materials: [
				{ pbrMetallicRoughness: { baseColorFactor: [ 0.8, 0.3, 0.2, 1 ], metallicFactor: 0.2, roughnessFactor: 0.6 }, emissiveFactor: [ 0.05, 0.05, 0.1 ], extensions: { KHR_materials_emissive_strength: { emissiveStrength: 2 } } },
				{ pbrMetallicRoughness: { baseColorFactor: [ 0.2, 0.7, 0.4, 1 ] }, extensions: { KHR_materials_unlit: {} } },
				{ pbrMetallicRoughness: { metallicFactor: 0, roughnessFactor: 0.7 }, doubleSided: true },
				{ pbrMetallicRoughness: { baseColorFactor: [ 0.6, 0.6, 0.65, 1 ], metallicFactor: 0.5, roughnessFactor: 0.5 } },
				{ pbrMetallicRoughness: { baseColorFactor: [ 0.1, 0.3, 0.9, 0.5 ], metallicFactor: 0, roughnessFactor: 0.8 }, alphaMode: 'BLEND' },
			],
			accessors: b.accessors,
			bufferViews: b.views,
		},
		bin: b.buffer(),
	};

}

// A minimal RGBA PNG (color type 6, filter 0 on every row), deflated by zlib: deterministic bytes.
const crcTable = Array.from( { length: 256 }, ( _, n ) => {

	let c = n;

	for ( let k = 0; k < 8; k ++ ) {

		c = c & 1 ? 0xEDB88320 ^ ( c >>> 1 ) : c >>> 1;

	}

	return c >>> 0;

} );

function crc32( data ) {

	let c = 0xFFFFFFFF;

	for ( const b of data ) {

		c = crcTable[ ( c ^ b ) & 0xFF ] ^ ( c >>> 8 );

	}

	return ( c ^ 0xFFFFFFFF ) >>> 0;

}

function png( width, height, pixel ) {

	const raw = Buffer.alloc( height * ( 1 + width * 4 ) );

	for ( let y = 0; y < height; y ++ ) {

		for ( let x = 0; x < width; x ++ ) {

			raw.set( pixel( x, y ), y * ( 1 + width * 4 ) + 1 + x * 4 );

		}

	}

	const chunk = ( type, data ) => {

		const length = Buffer.alloc( 4 );
		length.writeUInt32BE( data.length );
		const body = Buffer.concat( [ Buffer.from( type ), data ] );
		const crc = Buffer.alloc( 4 );
		crc.writeUInt32BE( crc32( body ) );
		return Buffer.concat( [ length, body, crc ] );

	};

	const header = Buffer.alloc( 13 );
	header.writeUInt32BE( width, 0 );
	header.writeUInt32BE( height, 4 );
	header.set( [ 8, 6, 0, 0, 0 ], 8 );

	return Buffer.concat( [
		Buffer.from( [ 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A ] ),
		chunk( 'IHDR', header ),
		chunk( 'IDAT', deflateSync( raw, { level: 9 } ) ),
		chunk( 'IEND', Buffer.alloc( 0 ) ),
	] );

}

const checker = ( n, a, b ) => png( n, n, ( x, y ) => ( x + y ) % 2 === 0 ? a : b );
const dataUri = ( bytes ) => 'data:image/png;base64,' + bytes.toString( 'base64' );

// A buffer view of raw bytes (an image), 4-byte aligned.
const bytesView = ( b, bytes ) => b.view( new Uint8Array( bytes.buffer, bytes.byteOffset, bytes.byteLength ) );

function texturedAsset() {

	const b = new Builder();

	const attributes = {
		POSITION: b.add( quad( - 0.5, - 0.5, 0.5, 0.5 ), FLOAT, 'VEC3', { bounds: true } ),
		NORMAL: b.add( new Float32Array( [ 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1 ] ), FLOAT, 'VEC3' ),
		TEXCOORD_0: b.add( new Float32Array( [ 0, 1, 1, 1, 1, 0, 0, 0 ] ), FLOAT, 'VEC2' ),
		TEXCOORD_1: b.add( new Float32Array( [ 0, 0, 2, 0, 2, 2, 0, 2 ] ), FLOAT, 'VEC2' ),
	};
	const tangents = { ...attributes, TANGENT: b.add( new Float32Array( [ 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1 ] ), FLOAT, 'VEC4' ) };
	const idx = b.add( new Uint16Array( [ 0, 1, 2, 0, 2, 3 ] ), USHORT, 'SCALAR' );
	const linePos = b.add( new Float32Array( [ 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0 ] ), FLOAT, 'VEC3', { bounds: true } );
	const lineCol = b.add( new Float32Array( [ 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0 ] ), FLOAT, 'VEC3' );
	const tex = ( index, extra = {} ) => ( { index, ...extra } );
	const transform = ( t ) => ( { extensions: { KHR_texture_transform: t } } );

	const materials = [
		{
			name: 'PBR',
			pbrMetallicRoughness: {
				baseColorFactor: [ 1, 0.9, 0.8, 1 ],
				baseColorTexture: tex( 0, transform( { offset: [ 0.25, - 0.5 ], rotation: 0.4, scale: [ 2, 3 ] } ) ),
				metallicRoughnessTexture: tex( 1 ),
				metallicFactor: 0.6,
				roughnessFactor: 0.4,
			},
			normalTexture: tex( 2, { scale: 0.8 } ),
			occlusionTexture: tex( 3, { strength: 0.6, texCoord: 1 } ),
			emissiveTexture: tex( 4, transform( { texCoord: 1 } ) ),
			emissiveFactor: [ 1, 0.5, 0.25 ],
		},
		{
			name: 'Clearcoat',
			extensions: {
				KHR_materials_clearcoat: {
					clearcoatFactor: 0.9,
					clearcoatTexture: tex( 1 ),
					clearcoatRoughnessFactor: 0.2,
					clearcoatRoughnessTexture: tex( 3 ),
					clearcoatNormalTexture: tex( 2, { scale: 0.5 } ),
				},
			},
		},
		{
			name: 'Sheen',
			extensions: { KHR_materials_sheen: { sheenColorFactor: [ 0.9, 0.3, 0.6 ], sheenRoughnessFactor: 0.45, sheenColorTexture: tex( 0 ), sheenRoughnessTexture: tex( 1 ) } },
		},
		{
			name: 'Glass',
			extensions: {
				KHR_materials_transmission: { transmissionFactor: 0.8, transmissionTexture: tex( 1 ) },
				KHR_materials_volume: { thicknessFactor: 0.3, thicknessTexture: tex( 3 ), attenuationDistance: 2.5, attenuationColor: [ 0.9, 0.8, 0.7 ] },
				KHR_materials_ior: { ior: 1.33 },
			},
		},
		{
			name: 'Specular',
			extensions: { KHR_materials_specular: { specularFactor: 0.7, specularTexture: tex( 1 ), specularColorFactor: [ 0.8, 1, 0.9 ], specularColorTexture: tex( 0 ) } },
		},
		{
			name: 'Iridescence',
			extensions: {
				KHR_materials_iridescence: {
					iridescenceFactor: 0.75,
					iridescenceTexture: tex( 1 ),
					iridescenceIor: 1.6,
					iridescenceThicknessMinimum: 150,
					iridescenceThicknessMaximum: 500,
					iridescenceThicknessTexture: tex( 3 ),
				},
			},
		},
		{
			name: 'Anisotropy',
			extensions: { KHR_materials_anisotropy: { anisotropyStrength: 0.6, anisotropyRotation: 1.2, anisotropyTexture: tex( 2 ) } },
		},
		{
			name: 'Defaults',
			extensions: {
				KHR_materials_dispersion: {},
				KHR_materials_ior: { ior: 0 },
				KHR_materials_volume: {},
				KHR_materials_specular: {},
				KHR_materials_sheen: {},
				KHR_materials_diffuse_roughness: { diffuseRoughnessFactor: 0.3, diffuseRoughnessTexture: tex( 1 ) },
				EXT_materials_bump: { bumpFactor: 0.25, bumpTexture: tex( 1 ) },
			},
		},
		{
			name: 'UnlitTextured',
			pbrMetallicRoughness: { baseColorFactor: [ 0.5, 1, 1, 0.8 ], baseColorTexture: tex( 2, { texCoord: 1 } ) },
			extensions: { KHR_materials_unlit: {} },
		},
		{ name: 'Wire', pbrMetallicRoughness: { baseColorFactor: [ 0.2, 0.8, 0.4, 0.5 ], baseColorTexture: tex( 0 ) }, alphaMode: 'BLEND', doubleSided: true },
	];

	const meshes = materials.map( ( m, i ) => ( {
		name: m.name,
		primitives: [ { attributes: i === 1 ? tangents : attributes, indices: idx, material: i } ],
	} ) );

	meshes.push( {
		name: 'LinesAndPoints',
		primitives: [
			{ attributes: { POSITION: linePos }, mode: 1, material: 9 },
			{ attributes: { POSITION: linePos, COLOR_0: lineCol }, mode: 3, material: 9 },
			{ attributes: { POSITION: linePos }, mode: 2, material: 0 },
			{ attributes: { POSITION: linePos, COLOR_0: lineCol }, mode: 0, material: 9 },
			{ attributes: { POSITION: linePos }, mode: 0 },
		],
	} );

	const json = {
		asset: { version: '2.0' },
		extensionsUsed: [
			'KHR_texture_transform', 'KHR_materials_unlit', 'KHR_materials_clearcoat', 'KHR_materials_sheen', 'KHR_materials_transmission',
			'KHR_materials_volume', 'KHR_materials_ior', 'KHR_materials_specular', 'KHR_materials_iridescence', 'KHR_materials_anisotropy',
			'KHR_materials_dispersion', 'KHR_materials_diffuse_roughness', 'EXT_materials_bump',
		],
		scenes: [ { nodes: meshes.map( ( _, i ) => i ) } ],
		nodes: meshes.map( ( m, i ) => ( { name: m.name, mesh: i, translation: [ i % 4, Math.floor( i / 4 ), 0 ] } ) ),
		meshes,
		materials,
		images: [
			{ bufferView: bytesView( b, checker( 4, [ 230, 60, 40, 255 ], [ 40, 90, 220, 255 ] ) ), mimeType: 'image/png', name: 'CheckerImage', extras: { kind: 'checker' } },
			{ uri: dataUri( png( 8, 2, ( x, y ) => [ x * 32, y * 255, 128, 255 ] ) ) },
			{ uri: 'checker.png' },
		],
		samplers: [
			{ magFilter: 9728, minFilter: 9728, wrapS: 33071, wrapT: 33648 },
			{ magFilter: 9729, minFilter: 9985, wrapS: 10497, wrapT: 33071 },
			{},
			{ minFilter: 9729, wrapS: 33648 },
			{ minFilter: 9984 },
		],
		textures: [
			{ source: 0, sampler: 0, name: 'Checker' },
			{ source: 1, sampler: 1 },
			{ source: 2 },
			{ source: 0, sampler: 3 },
			{ source: 1, sampler: 4 },
		],
	};

	return { json: { ...json, accessors: b.accessors, bufferViews: b.views }, bin: b.buffer() };

}

// Textured quads for the rendering parity scene gltf_textured, in the layout of renderAsset(): a checker with a
// texture transform (upper left), normal + occlusion/roughness/metalness + emissive maps (upper right),
// clearcoat and sheen (lower left), transmission over an opaque bar (lower right); a line strip and points.
function renderTexturedAsset() {

	const b = new Builder();

	const idx = b.add( new Uint16Array( [ 0, 1, 2, 0, 2, 3 ] ), USHORT, 'SCALAR' );
	const nrm = b.add( new Float32Array( [ 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1 ] ), FLOAT, 'VEC3' );
	const uv = b.add( new Float32Array( [ 0, 1, 1, 1, 1, 0, 0, 0 ] ), FLOAT, 'VEC2' );
	const at = ( x0, y0, x1, y1, z ) => b.add( quad( x0, y0, x1, y1, z ), FLOAT, 'VEC3', { bounds: true } );
	const prim = ( position, material ) => ( { primitives: [ { attributes: { POSITION: position, NORMAL: nrm, TEXCOORD_0: uv }, indices: idx, material } ] } );

	// Rows and columns through pixel centres ((i + 0.5) / 64 - 1).
	const c = ( i ) => ( i + 0.5 ) / 64 - 1;
	const nearest = 0, linear = 1;

	return {
		json: {
			asset: { version: '2.0' },
			extensionsUsed: [ 'KHR_texture_transform', 'KHR_lights_punctual', 'KHR_materials_clearcoat', 'KHR_materials_sheen', 'KHR_materials_transmission', 'KHR_materials_ior' ],
			extensions: { KHR_lights_punctual: { lights: [ { type: 'directional', color: [ 1, 0.95, 0.9 ], intensity: 2 } ] } },
			scenes: [ { nodes: [ 0, 7 ] } ],
			nodes: [
				{ name: 'Quads', children: [ 1, 2, 3, 4, 5, 6 ], translation: [ 0, 0, - 1 ] },
				{ name: 'Checker', mesh: 0 },
				{ name: 'Maps', mesh: 1 },
				{ name: 'Coat', mesh: 2 },
				{ name: 'Bar', mesh: 3 },
				{ name: 'Glass', mesh: 4 },
				{ name: 'LinesAndPoints', mesh: 5 },
				{ name: 'Sun', extensions: { KHR_lights_punctual: { light: 0 } }, rotation: [ - 0.25, 0.2, 0, 0.9473309334313418 ] },
			],
			meshes: [
				prim( at( - 0.875, 0.125, - 0.125, 0.875, 0 ), 0 ),
				prim( at( 0.125, 0.125, 0.875, 0.875, 0 ), 1 ),
				prim( at( - 0.875, - 0.875, - 0.125, - 0.125, 0 ), 2 ),
				prim( at( 0.375, - 0.875, 0.625, - 0.125, - 0.5 ), 3 ),
				prim( at( 0.125, - 0.75, 0.875, - 0.25, 0 ), 4 ),
				{
					primitives: [
						{ attributes: { POSITION: b.add( new Float32Array( [ c( 8 ), c( 3 ), 0, c( 60 ), c( 3 ), 0, c( 60 ), c( 5 ), 0 ] ), FLOAT, 'VEC3', { bounds: true } ) }, mode: 3, material: 3 },
						{
							attributes: {
								POSITION: b.add( new Float32Array( [ c( 10 ), c( 64 ), 0, c( 20 ), c( 64 ), 0, c( 30 ), c( 63 ), 0 ] ), FLOAT, 'VEC3', { bounds: true } ),
								COLOR_0: b.add( new Float32Array( [ 1, 0, 0, 0, 1, 0, 0, 0.5, 1 ] ), FLOAT, 'VEC3' ),
							},
							mode: 0,
						},
					],
				},
			],
			materials: [
				{
					pbrMetallicRoughness: { baseColorTexture: { index: 0, extensions: { KHR_texture_transform: { offset: [ 0.25, 0 ], rotation: 0.5, scale: [ 1.5, 1.5 ] } } }, metallicFactor: 0, roughnessFactor: 0.8 },
				},
				{
					pbrMetallicRoughness: { baseColorFactor: [ 0.7, 0.7, 0.75, 1 ], metallicRoughnessTexture: { index: 2 } },
					normalTexture: { index: 1, scale: 0.9 },
					occlusionTexture: { index: 2, strength: 0.7 },
					emissiveTexture: { index: 3 },
					emissiveFactor: [ 1, 1, 1 ],
				},
				{
					pbrMetallicRoughness: { baseColorFactor: [ 0.3, 0.4, 0.8, 1 ], metallicFactor: 0.1, roughnessFactor: 0.6 },
					extensions: {
						KHR_materials_clearcoat: { clearcoatFactor: 1, clearcoatRoughnessFactor: 0.15 },
						KHR_materials_sheen: { sheenColorFactor: [ 0.9, 0.6, 0.2 ], sheenRoughnessFactor: 0.5 },
					},
				},
				{ pbrMetallicRoughness: { baseColorFactor: [ 0.9, 0.7, 0.1, 1 ], metallicFactor: 0, roughnessFactor: 0.5 } },
				{
					pbrMetallicRoughness: { baseColorFactor: [ 0.9, 0.95, 1, 1 ], metallicFactor: 0, roughnessFactor: 0.1 },
					extensions: { KHR_materials_transmission: { transmissionFactor: 0.9 }, KHR_materials_ior: { ior: 1.4 } },
				},
			],
			images: [
				{ bufferView: bytesView( b, checker( 8, [ 230, 60, 40, 255 ], [ 40, 90, 220, 255 ] ) ), mimeType: 'image/png' },
				{ uri: dataUri( png( 4, 4, ( x, y ) => [ 128 + ( x - 1.5 ) * 30, 128 + ( y - 1.5 ) * 30, 230, 255 ] ) ) },
				{ uri: dataUri( png( 4, 4, ( x, y ) => [ 255 - x * 40, 60 + y * 50, x * 80, 255 ] ) ) },
				{ uri: dataUri( png( 2, 2, ( x, y ) => ( x + y ) % 2 === 0 ? [ 60, 20, 0, 255 ] : [ 0, 0, 0, 255 ] ) ) },
			],
			samplers: [
				{ magFilter: 9728, minFilter: 9728 },
				{ magFilter: 9729, minFilter: 9729 },
			],
			textures: [
				{ source: 0, sampler: nearest },
				{ source: 1, sampler: linear },
				{ source: 2, sampler: linear },
				{ source: 3, sampler: nearest },
			],
			accessors: b.accessors,
			bufferViews: b.views,
		},
		bin: b.buffer(),
	};

}

// A z rotation quaternion.
const turnZ = ( a ) => [ 0, 0, Math.sin( a / 2 ), Math.cos( a / 2 ) ];

function skinnedAsset() {

	const b = new Builder();

	// Mesh 0: a column of three quads from y = -0.9 to 0.6, skinned to Root (at -0.9) and Tip (0.75 above it),
	// with two morph targets: `bulge` (POSITION + NORMAL, the top rows outwards) and `widen` (POSITION only,
	// the middle rows), default weights [ 0.25, 0 ].
	const rows = [ - 0.9, - 0.4, 0.1, 0.6 ];
	const pos = new Float32Array( rows.flatMap( ( y ) => [ - 0.2, y, 0, 0.2, y, 0 ] ) );
	const nrm = new Float32Array( rows.flatMap( () => [ 0, 0, 1, 0, 0, 1 ] ) );
	const joints = new Uint8Array( rows.flatMap( () => [ 0, 1, 0, 0, 0, 1, 0, 0 ] ) );
	const weights = new Float32Array( [ [ 1, 0 ], [ 0.7, 0.3 ], [ 0.2, 0.8 ], [ 0, 1 ] ].flatMap( ( [ a, c ] ) => [ a, c, 0, 0, a, c, 0, 0 ] ) );
	const idx = new Uint16Array( [ 0, 1, 3, 0, 3, 2, 2, 3, 5, 2, 5, 4, 4, 5, 7, 4, 7, 6 ] );
	const bulge = new Float32Array( [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, - 0.15, 0, 0, 0.15, 0, 0, - 0.3, 0.1, 0, 0.3, 0.1, 0 ] );
	const bulgeNrm = new Float32Array( [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, - 0.2, 0, - 0.1, 0.2, 0, - 0.1, - 0.3, 0, - 0.2, 0.3, 0, - 0.2 ] );
	const widen = new Float32Array( [ 0, 0, 0, 0, 0, 0, - 0.12, 0, 0, 0.12, 0, 0, - 0.08, 0, 0, 0.08, 0, 0, 0, 0, 0, 0, 0, 0 ] );

	const columnPos = b.add( pos, FLOAT, 'VEC3', { bounds: true } );
	const columnNrm = b.add( nrm, FLOAT, 'VEC3' );
	const columnJoints = b.add( joints, UBYTE, 'VEC4' );
	const columnWeights = b.add( weights, FLOAT, 'VEC4' );
	const columnIdx = b.add( idx, USHORT, 'SCALAR' );
	const bulgePos = b.add( bulge, FLOAT, 'VEC3', { bounds: true } );
	const bulgeNormal = b.add( bulgeNrm, FLOAT, 'VEC3' );
	const widenPos = b.add( widen, FLOAT, 'VEC3', { bounds: true } );

	// Inverse bind matrices (column-major): Root's world is a translation by -0.9, Tip's by -0.15.
	const translation = ( y ) => [ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, y, 0, 1 ];
	const ibm = b.add( new Float32Array( [ ...translation( 0.9 ), ...translation( 0.15 ) ] ), FLOAT, 'MAT4' );

	// Mesh 1: a quad (not skinned) with two position targets, weights driven by a CUBICSPLINE channel.
	const blobPos = b.add( quad( - 0.15, - 0.15, 0.15, 0.15 ), FLOAT, 'VEC3', { bounds: true } );
	const blobIdx = b.add( new Uint16Array( [ 0, 1, 2, 0, 2, 3 ] ), USHORT, 'SCALAR' );
	const blobUp = b.add( new Float32Array( [ 0, 0, 0, 0, 0, 0, 0, 0.2, 0, 0, 0.2, 0 ] ), FLOAT, 'VEC3', { bounds: true } );
	const blobRight = b.add( new Float32Array( [ 0, 0, 0, 0.2, 0, 0, 0.2, 0, 0, 0, 0, 0 ] ), FLOAT, 'VEC3', { bounds: true } );

	// Animation 0 `wave` (times 0, 0.5, 1): Root translation and Tip rotation CUBICSPLINE (in-tangent, value,
	// out-tangent per key), Tip scale STEP, the column's weights and Root's rotation LINEAR, Blob's weights
	// CUBICSPLINE.
	const t3 = b.add( new Float32Array( [ 0, 0.5, 1 ] ), FLOAT, 'SCALAR', { bounds: true } );
	const t2 = b.add( new Float32Array( [ 0, 1 ] ), FLOAT, 'SCALAR', { bounds: true } );
	const rootMove = b.add( new Float32Array( [
		0, 0, 0, 0, - 0.9, 0, 0.4, 0, 0,
		0.2, 0.1, 0, 0.2, - 0.85, 0, - 0.3, 0.1, 0,
		0, - 0.2, 0, 0, - 0.8, 0, 0, 0, 0,
	] ), FLOAT, 'VEC3' );
	const tipTurn = b.add( new Float32Array( [
		0, 0, 0, 0, ...turnZ( 0 ), 0, 0, 0.6, 0,
		0, 0, 0.3, - 0.1, ...turnZ( 0.6 ), 0, 0, - 0.4, 0,
		0, 0, - 0.2, 0, ...turnZ( - 0.3 ), 0, 0, 0, 0,
	] ), FLOAT, 'VEC4' );
	const tipScale = b.add( new Float32Array( [ 1, 1, 1, 1.3, 1.2, 1, 0.8, 0.9, 1 ] ), FLOAT, 'VEC3' );
	const columnMorph = b.add( new Float32Array( [ 0, 0, 1, 0.6 ] ), FLOAT, 'SCALAR' );
	const rootTurn = b.add( new Float32Array( [ ...turnZ( 0 ), ...turnZ( 0.25 ) ] ), FLOAT, 'VEC4' );
	const blobMorph = b.add( new Float32Array( [
		0, 0, 0, 0, 2, 0.5,
		- 1, 0.5, 0.8, 0.3, 0, 0,
		0, 0, 0.2, 1, 0, 0,
	] ), FLOAT, 'SCALAR' );

	// Animation 1 (no name): Blob's rotation STEP from normalized int16 values.
	const q16 = ( q ) => q.map( ( v ) => Math.round( v * 32767 ) );
	const blobTurn = b.add( new Int16Array( [ ...q16( turnZ( 0 ) ), ...q16( turnZ( 0.5 ) ) ] ), SHORT, 'VEC4', { normalized: true } );

	return {
		json: {
			asset: { version: '2.0' },
			scene: 0,
			scenes: [ { nodes: [ 0 ] } ],
			nodes: [
				{ name: 'Armature', children: [ 1, 2, 4 ] },
				{ name: 'Column', mesh: 0, skin: 0 },
				{ name: 'Root', translation: [ 0, - 0.9, 0 ], children: [ 3 ] },
				{ name: 'Tip', translation: [ 0, 0.75, 0 ] },
				{ name: 'Blob', mesh: 1, translation: [ 0.6, 0.2, 0 ], weights: [ 0.5, 0 ] },
			],
			skins: [ { name: 'Rig', joints: [ 2, 3 ], inverseBindMatrices: ibm, skeleton: 2 } ],
			meshes: [
				{
					name: 'Column',
					primitives: [ {
						attributes: { POSITION: columnPos, NORMAL: columnNrm, JOINTS_0: columnJoints, WEIGHTS_0: columnWeights },
						indices: columnIdx,
						material: 0,
						targets: [ { POSITION: bulgePos, NORMAL: bulgeNormal }, { POSITION: widenPos } ],
					} ],
					weights: [ 0.25, 0 ],
					extras: { targetNames: [ 'bulge', 'widen' ] },
				},
				{
					name: 'Blob',
					primitives: [ {
						attributes: { POSITION: blobPos },
						indices: blobIdx,
						material: 1,
						targets: [ { POSITION: blobUp }, { POSITION: blobRight } ],
					} ],
				},
			],
			materials: [
				{ pbrMetallicRoughness: { baseColorFactor: [ 0.9, 0.5, 0.2, 1 ], metallicFactor: 0, roughnessFactor: 1 } },
				{ pbrMetallicRoughness: { baseColorFactor: [ 0.3, 0.7, 0.9, 1 ] }, extensions: { KHR_materials_unlit: {} } },
			],
			extensionsUsed: [ 'KHR_materials_unlit' ],
			animations: [
				{
					name: 'wave',
					samplers: [
						{ input: t3, output: rootMove, interpolation: 'CUBICSPLINE' },
						{ input: t3, output: tipTurn, interpolation: 'CUBICSPLINE' },
						{ input: t3, output: tipScale, interpolation: 'STEP' },
						{ input: t2, output: columnMorph },
						{ input: t2, output: rootTurn, interpolation: 'LINEAR' },
						{ input: t3, output: blobMorph, interpolation: 'CUBICSPLINE' },
					],
					channels: [
						{ sampler: 0, target: { node: 2, path: 'translation' } },
						{ sampler: 1, target: { node: 3, path: 'rotation' } },
						{ sampler: 2, target: { node: 3, path: 'scale' } },
						{ sampler: 3, target: { node: 1, path: 'weights' } },
						{ sampler: 4, target: { node: 2, path: 'rotation' } },
						{ sampler: 5, target: { node: 4, path: 'weights' } },
					],
					extras: { loop: true },
				},
				{
					samplers: [ { input: t2, output: blobTurn, interpolation: 'STEP' } ],
					channels: [ { sampler: 0, target: { node: 4, path: 'rotation' } } ],
				},
			],
			accessors: b.accessors,
			bufferViews: b.views,
		},
		bin: b.buffer(),
	};

}

// JSON with tabs (canon 004); the buffer is a data URI or an external file.
function gltf( json, bin, uri ) {

	json.buffers = [ { byteLength: bin.length, uri: uri ?? 'data:application/octet-stream;base64,' + bin.toString( 'base64' ) } ];

	return JSON.stringify( json, null, '\t' ) + '\n';

}

function glb( json, bin ) {

	const copy = structuredClone( json );
	copy.buffers = [ { byteLength: bin.length } ];

	let text = Buffer.from( JSON.stringify( copy ) );
	text = Buffer.concat( [ text, Buffer.alloc( ( 4 - text.length % 4 ) % 4, 0x20 ) ] );

	const header = Buffer.alloc( 12 );
	const total = 12 + 8 + text.length + 8 + bin.length;
	header.write( 'glTF', 0 );
	header.writeUInt32LE( 2, 4 );
	header.writeUInt32LE( total, 8 );

	const chunk = ( type, data ) => {

		const h = Buffer.alloc( 8 );
		h.writeUInt32LE( data.length, 0 );
		h.writeUInt32LE( type, 4 );

		return Buffer.concat( [ h, data ] );

	};

	return Buffer.concat( [ header, chunk( 0x4E4F534A, text ), chunk( 0x004E4942, bin ) ] );

}

const scene = sceneAsset();
writeFileSync( new URL( 'scene.gltf', out ), gltf( structuredClone( scene.json ), scene.bin ) );
writeFileSync( new URL( 'scene.glb', out ), glb( scene.json, scene.bin ) );

const external = externalAsset();
writeFileSync( new URL( 'external.gltf', out ), gltf( external.json, external.bin, 'external.bin' ) );
writeFileSync( new URL( 'external.bin', out ), external.bin );

const render = renderAsset();
writeFileSync( new URL( 'render.gltf', out ), gltf( render.json, render.bin ) );

const textured = texturedAsset();
writeFileSync( new URL( 'textured.gltf', out ), gltf( structuredClone( textured.json ), textured.bin ) );
writeFileSync( new URL( 'textured.glb', out ), glb( textured.json, textured.bin ) );
writeFileSync( new URL( 'checker.png', out ), checker( 2, [ 250, 250, 250, 255 ], [ 20, 20, 20, 255 ] ) );

const renderTextured = renderTexturedAsset();
writeFileSync( new URL( 'render_textured.gltf', out ), gltf( renderTextured.json, renderTextured.bin ) );

const skinned = skinnedAsset();
writeFileSync( new URL( 'skinned.gltf', out ), gltf( skinned.json, skinned.bin ) );

console.log( 'wrote', [ 'scene.gltf', 'scene.glb', 'external.gltf', 'external.bin', 'render.gltf', 'textured.gltf', 'textured.glb', 'checker.png', 'render_textured.gltf', 'skinned.gltf' ].map( ( f ) => 'fixtures/gltf/' + f ).join( ', ' ) );
