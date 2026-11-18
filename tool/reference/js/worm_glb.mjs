// Writes examples/worm/assets/worm.glb, the model of the example viewer (lib/main.dart), built by hand (no
// downloads): a striped, skinned tube with a looping `wiggle` animation. Deterministic, so running this again
// reproduces the same bytes.
//
// Usage: node tool/reference/js/worm_glb.mjs
//
// - Body: an open tube of radius 0.22 from y = 0 to 2 (24 sides, 32 rings) with a top cap, UVs, normals, and
//   joints/weights blending linearly between the two nearest of 5 bones.
// - Bone0..Bone4: a chain 0.5 apart, Bone0 at the foot; inverse bind matrices are the bind translations negated.
// - wiggle: 2 s, 17 LINEAR keys per bone 1..4, a travelling wave about z (0.32 rad) and x (0.18 rad); the first
//   and last keys are equal, so it loops seamlessly.
// - Material: metallic 0, roughness 0.55, a 64 x 64 PNG base color of rings and a dorsal stripe.

import { mkdirSync, writeFileSync } from 'node:fs';
import { deflateSync } from 'node:zlib';

const out = new URL( '../../../examples/worm/assets/', import.meta.url );
mkdirSync( out, { recursive: true } );

const FLOAT = 5126, UBYTE = 5121, USHORT = 5123;

// A growing binary buffer of tightly packed, 4-byte aligned views, one per accessor.
class Builder {

	constructor() {

		this.bytes = [];
		this.views = [];
		this.accessors = [];

	}

	view( array ) {

		while ( this.bytes.length % 4 !== 0 ) {

			this.bytes.push( 0 );

		}

		const offset = this.bytes.length;

		for ( const b of new Uint8Array( array.buffer, array.byteOffset, array.byteLength ) ) {

			this.bytes.push( b );

		}

		this.views.push( { buffer: 0, byteOffset: offset, byteLength: array.byteLength } );

		return this.views.length - 1;

	}

	// An accessor of its own view; min/max with `bounds` (positions and animation inputs need them).
	add( array, componentType, type, bounds = false ) {

		const size = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16 }[ type ];
		const def = { bufferView: this.view( array ), componentType, count: array.length / size, type };

		if ( bounds ) {

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

		this.accessors.push( def );

		return this.accessors.length - 1;

	}

	buffer() {

		while ( this.bytes.length % 4 !== 0 ) {

			this.bytes.push( 0 );

		}

		return Buffer.from( this.bytes );

	}

}

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

function glb( json, bin ) {

	json.buffers = [ { byteLength: bin.length } ];

	let text = Buffer.from( JSON.stringify( json ) );
	text = Buffer.concat( [ text, Buffer.alloc( ( 4 - text.length % 4 ) % 4, 0x20 ) ] );

	const header = Buffer.alloc( 12 );
	header.write( 'glTF', 0 );
	header.writeUInt32LE( 2, 4 );
	header.writeUInt32LE( 12 + 8 + text.length + 8 + bin.length, 8 );

	const chunk = ( type, data ) => {

		const h = Buffer.alloc( 8 );
		h.writeUInt32LE( data.length, 0 );
		h.writeUInt32LE( type, 4 );

		return Buffer.concat( [ h, data ] );

	};

	return Buffer.concat( [ header, chunk( 0x4E4F534A, text ), chunk( 0x004E4942, bin ) ] );

}

// The quaternion of Euler angles (x, 0, z) in XYZ order: qx * qz.
function turn( x, z ) {

	const [ sx, cx, sz, cz ] = [ Math.sin( x / 2 ), Math.cos( x / 2 ), Math.sin( z / 2 ), Math.cos( z / 2 ) ];

	return [ sx * cz, - sx * sz, cx * sz, cx * cz ];

}

const radius = 0.22, height = 2, sides = 24, rings = 32, bones = 5, gap = 0.5;
const b = new Builder();
const pos = [], nrm = [], uv = [], joints = [], weights = [], idx = [];

// Skin weights of a point at height y: linear between the two nearest bones.
function skin( y ) {

	const s = Math.min( y / gap, bones - 1 - 1e-6 );
	const i = Math.floor( s );

	joints.push( i, i + 1, 0, 0 );
	weights.push( 1 - ( s - i ), s - i, 0, 0 );

}

for ( let r = 0; r <= rings; r ++ ) {

	const y = height * r / rings;

	// The tube narrows a little towards its tip.
	const w = radius * ( 1 - 0.35 * ( r / rings ) ** 2 );

	for ( let s = 0; s <= sides; s ++ ) {

		const a = 2 * Math.PI * s / sides;

		pos.push( w * Math.sin( a ), y, w * Math.cos( a ) );
		nrm.push( Math.sin( a ), 0, Math.cos( a ) );
		uv.push( s / sides, r / rings );
		skin( y );

	}

}

for ( let r = 0; r < rings; r ++ ) {

	for ( let s = 0; s < sides; s ++ ) {

		const a = r * ( sides + 1 ) + s, c = a + sides + 1;

		idx.push( a, a + 1, c, a + 1, c + 1, c );

	}

}

// The cap: a fan around a centre slightly above the top ring.
const tip = pos.length / 3;
pos.push( 0, height + 0.06, 0 );
nrm.push( 0, 1, 0 );
uv.push( 0.5, 1 );
skin( height );

for ( let s = 0; s < sides; s ++ ) {

	const a = rings * ( sides + 1 ) + s;

	idx.push( a, a + 1, tip );

}

const texture = png( 64, 64, ( x, y ) => {

	// Rings along v (y), a darker dorsal stripe around u = 0.5 (x), a little deterministic speckle.
	const ring = Math.floor( y / 4 ) % 2 === 0;
	const stripe = Math.abs( x - 32 ) < 5;
	const speckle = ( ( x * 7 + y * 13 ) % 11 ) * 2;
	const base = ring ? [ 214, 112, 92 ] : [ 176, 74, 70 ];
	const k = stripe ? 0.6 : 1;

	return [ ...base.map( ( c ) => Math.min( 255, Math.round( c * k ) + speckle ) ), 255 ];

} );

const accessors = {
	pos: b.add( new Float32Array( pos ), FLOAT, 'VEC3', true ),
	nrm: b.add( new Float32Array( nrm ), FLOAT, 'VEC3' ),
	uv: b.add( new Float32Array( uv ), FLOAT, 'VEC2' ),
	joints: b.add( new Uint8Array( joints ), UBYTE, 'VEC4' ),
	weights: b.add( new Float32Array( weights ), FLOAT, 'VEC4' ),
	idx: b.add( new Uint16Array( idx ), USHORT, 'SCALAR' ),
	ibm: b.add( new Float32Array( Array.from( { length: bones }, ( _, i ) => [ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, - i * gap, 0, 1 ] ).flat() ), FLOAT, 'MAT4' ),
};

const image = b.view( new Uint8Array( texture.buffer, texture.byteOffset, texture.byteLength ) );

// The wiggle: bone i (1..4) turns by a wave with phase i * 0.9 over the 2 s loop.
const keys = 17, period = 2;
const times = b.add( new Float32Array( Array.from( { length: keys }, ( _, k ) => period * k / ( keys - 1 ) ) ), FLOAT, 'SCALAR', true );
const samplers = [], channels = [];

for ( let i = 1; i < bones; i ++ ) {

	const values = Array.from( { length: keys }, ( _, k ) => {

		const p = 2 * Math.PI * k / ( keys - 1 ) - i * 0.9;

		return turn( 0.18 * Math.sin( p + 1.3 ), 0.32 * Math.sin( p ) );

	} ).flat();

	samplers.push( { input: times, output: b.add( new Float32Array( values ), FLOAT, 'VEC4' ), interpolation: 'LINEAR' } );
	channels.push( { sampler: i - 1, target: { node: 2 + i, path: 'rotation' } } );

}

const json = {
	asset: { version: '2.0', generator: 'ent worm_glb.mjs' },
	scene: 0,
	scenes: [ { nodes: [ 0 ] } ],
	nodes: [
		{ name: 'Worm', children: [ 1, 2 ] },
		{ name: 'Body', mesh: 0, skin: 0 },
		{ name: 'Bone0', children: [ 3 ] },
		...Array.from( { length: bones - 1 }, ( _, i ) => ( { name: 'Bone' + ( i + 1 ), translation: [ 0, gap, 0 ], ...( i < bones - 2 ? { children: [ 4 + i ] } : {} ) } ) ),
	],
	skins: [ { name: 'Spine', joints: Array.from( { length: bones }, ( _, i ) => 2 + i ), inverseBindMatrices: accessors.ibm, skeleton: 2 } ],
	meshes: [ {
		name: 'Body',
		primitives: [ {
			attributes: { POSITION: accessors.pos, NORMAL: accessors.nrm, TEXCOORD_0: accessors.uv, JOINTS_0: accessors.joints, WEIGHTS_0: accessors.weights },
			indices: accessors.idx,
			material: 0,
		} ],
	} ],
	materials: [ {
		name: 'Skin',
		pbrMetallicRoughness: { baseColorTexture: { index: 0 }, metallicFactor: 0, roughnessFactor: 0.55 },
	} ],
	textures: [ { sampler: 0, source: 0 } ],
	samplers: [ { magFilter: 9729, minFilter: 9987, wrapS: 10497, wrapT: 10497 } ],
	images: [ { bufferView: image, mimeType: 'image/png', name: 'Rings' } ],
	animations: [ { name: 'wiggle', samplers, channels } ],
	accessors: b.accessors,
	bufferViews: b.views,
};

const bytes = glb( json, b.buffer() );
writeFileSync( new URL( 'worm.glb', out ), bytes );
console.log( 'wrote examples/worm/assets/worm.glb,', bytes.length, 'bytes' );
