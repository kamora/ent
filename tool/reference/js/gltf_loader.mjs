// Loads the glTF test assets of fixtures/gltf/ (written by gltf_files.mjs) with the pinned three.js r187
// GLTFLoader in Node and writes what it built to fixtures/values/gltf_loader.json: per file, the scenes' object trees
// (names, types, local matrices, user data, cameras, lights), geometries (attributes with their typed arrays,
// interleaving, index, groups, bounds) and materials (type and the properties glTF sets), shared ones numbered
// by first appearance, plus the root's asset, user data, cameras and the parser's associations; morph attributes
// and influences, skins (bind matrices, bones, inverses) and animation clips (tracks with their typed arrays,
// interpolation and values sampled through each track's interpolant).
// packages/ent/test/loaders/gltf_loader_test.dart loads the same files with the Dart port and compares.
//
// Usage: node tool/reference/js/gltf_loader.mjs
//
// There is no DOM and no network: GLTFLoader.parse() gets the file's bytes, data URIs go through Node's fetch
// and file: URLs (the external buffer) through a fetch that reads the file.
//
// Node has no createImageBitmap, so the parser takes the TextureLoader, and no image decoder: a stand-in
// `document.createElementNS()` image reads its src (a data URI, a file: URL or the object URL of a buffer view's
// Blob), takes its size from the PNG header and a 32-bit FNV-1a hash of the encoded bytes as its identity, and
// fires 'load'. The Dart test's image does the same, so textures compare by image size and source bytes.

import { readFileSync, writeFileSync } from 'node:fs';
import { resolveObjectURL } from 'node:buffer';
import { execSync } from 'node:child_process';
import { register } from 'node:module';
import { fileURLToPath } from 'node:url';

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

const { GLTFLoader } = await import( '../../../third_party/three.js/examples/jsm/loaders/GLTFLoader.js' );

// FileLoader reports progress with the DOM's ProgressEvent while it reads a body.
globalThis.ProgressEvent = class ProgressEvent extends Event {

	constructor( type, init = {} ) {

		super( type );
		Object.assign( this, init );

	}

};

const nodeFetch = globalThis.fetch;

globalThis.fetch = async ( request ) => {

	const url = typeof request === 'string' ? request : request.url;

	if ( url.startsWith( 'file:' ) ) {

		return new Response( readFileSync( fileURLToPath( url ) ), { status: 200 } );

	}

	return nodeFetch( request );

};

// GLTFLoader reads `self.URL` for object URLs.
globalThis.self = globalThis;

function fnv1a( bytes ) {

	let h = 0x811C9DC5;

	for ( const b of bytes ) {

		h = Math.imul( h ^ b, 0x01000193 ) >>> 0;

	}

	return h;

}

class Image extends EventTarget {

	width = 0;
	height = 0;
	hash = 0;
	#src = '';

	get src() {

		return this.#src;

	}

	set src( url ) {

		this.#src = url;

		const read = url.startsWith( 'blob:' )
			? resolveObjectURL( url ).arrayBuffer()
			: globalThis.fetch( url ).then( ( r ) => r.arrayBuffer() );

		read.then( ( buffer ) => {

			const bytes = new Uint8Array( buffer );
			const view = new DataView( buffer );
			this.width = view.getUint32( 16 );
			this.height = view.getUint32( 20 );
			this.hash = fnv1a( bytes );
			this.dispatchEvent( new Event( 'load' ) );

		}, () => this.dispatchEvent( new Event( 'error' ) ) );

	}

}

globalThis.document = { createElementNS: () => new Image() };

const dir = new URL( '../../../fixtures/gltf/', here );
const files = [ 'scene.gltf', 'scene.glb', 'external.gltf', 'render.gltf', 'textured.gltf', 'textured.glb', 'skinned.gltf' ];

// The times at which each animation track's interpolant is sampled, in order through one interpolant.
const samples = [ 0, 0.1, 0.25, 0.5, 0.7, 0.95, 1, 1.3 ];

// The texture slots and the extension properties of the materials glTF makes.
const maps = [
	'map', 'metalnessMap', 'roughnessMap', 'normalMap', 'aoMap', 'emissiveMap', 'clearcoatMap', 'clearcoatRoughnessMap',
	'clearcoatNormalMap', 'sheenColorMap', 'sheenRoughnessMap', 'transmissionMap', 'thicknessMap', 'specularIntensityMap',
	'specularColorMap', 'iridescenceMap', 'iridescenceThicknessMap', 'anisotropyMap', 'diffuseRoughnessMap', 'bumpMap',
];
const properties = [
	'aoMapIntensity', 'clearcoat', 'clearcoatRoughness', 'clearcoatNormalScale', 'sheen', 'sheenColor', 'sheenRoughness',
	'transmission', 'thickness', 'attenuationDistance', 'attenuationColor', 'ior', 'specularIntensity', 'specularColor',
	'iridescence', 'iridescenceIOR', 'iridescenceThicknessMinimum', 'iridescenceThicknessMaximum', 'anisotropy',
	'anisotropyRotation', 'dispersion', 'diffuseRoughness', 'bumpScale', 'size', 'sizeAttenuation',
];

function attribute( a ) {

	if ( a === null || a === undefined ) {

		return null;

	}

	const data = a.isInterleavedBufferAttribute ? a.data : a;

	return {
		itemSize: a.itemSize,
		count: a.count,
		normalized: a.normalized,
		interleaved: a.isInterleavedBufferAttribute === true,
		stride: a.isInterleavedBufferAttribute ? a.data.stride : undefined,
		offset: a.isInterleavedBufferAttribute ? a.offset : undefined,
		arrayType: data.array.constructor.name,
		array: Array.from( data.array ),
	};

}

function dump( gltf ) {

	const geometries = [];
	const materials = [];
	const textures = [];
	const objects = [];

	const value = ( v ) => v === undefined ? null : ( v !== null && v.toArray ? v.toArray() : v );

	const texture = ( t ) => {

		if ( ! t ) {

			return null;

		}

		let i = textures.findIndex( ( e ) => e.ref === t );

		if ( i < 0 ) {

			textures.push( {
				ref: t,
				name: t.name,
				type: t.type,
				image: [ t.image.width, t.image.height, t.image.hash ],
				wrapS: t.wrapS,
				wrapT: t.wrapT,
				magFilter: t.magFilter,
				minFilter: t.minFilter,
				generateMipmaps: t.generateMipmaps,
				flipY: t.flipY,
				colorSpace: t.colorSpace,
				channel: t.channel,
				offset: t.offset.toArray(),
				repeat: t.repeat.toArray(),
				rotation: t.rotation,
				center: t.center.toArray(),
				matrixAutoUpdate: t.matrixAutoUpdate,
				matrix: t.matrix.toArray(),
				userData: t.userData,
				association: gltf.parser.associations.get( t ) ?? null,
			} );
			i = textures.length - 1;

		}

		return i;

	};

	const box = ( b ) => b ? [ ...b.min.toArray(), ...b.max.toArray() ] : null;

	const geometry = ( g ) => {

		let i = geometries.findIndex( ( e ) => e.ref === g );

		if ( i < 0 ) {

			geometries.push( {
				ref: g,
				attributes: Object.fromEntries( Object.keys( g.attributes ).sort().map( ( k ) => [ k, attribute( g.attributes[ k ] ) ] ) ),
				index: attribute( g.index ),
				groups: g.groups.map( ( r ) => [ r.start, r.count, r.materialIndex ?? 0 ] ),
				drawRange: [ g.drawRange.start, g.drawRange.count ],
				boundingBox: box( g.boundingBox ),
				boundingSphere: g.boundingSphere ? [ ...g.boundingSphere.center.toArray(), g.boundingSphere.radius ] : null,
				userData: g.userData,
				morphAttributes: Object.fromEntries( Object.keys( g.morphAttributes ).sort().map( ( k ) => [ k, g.morphAttributes[ k ].map( attribute ) ] ) ),
				morphTargetsRelative: g.morphTargetsRelative,
			} );
			i = geometries.length - 1;

		}

		return i;

	};

	const material = ( m ) => {

		let i = materials.findIndex( ( e ) => e.ref === m );

		if ( i < 0 ) {

			materials.push( {
				ref: m,
				type: m.type,
				name: m.name,
				color: m.color ? m.color.toArray() : null,
				emissive: m.emissive ? m.emissive.toArray() : null,
				emissiveIntensity: m.emissiveIntensity ?? null,
				metalness: m.metalness ?? null,
				roughness: m.roughness ?? null,
				opacity: m.opacity,
				transparent: m.transparent,
				depthWrite: m.depthWrite,
				depthTest: m.depthTest,
				alphaTest: m.alphaTest,
				side: m.side,
				vertexColors: m.vertexColors,
				flatShading: m.isMeshStandardMaterial ? m.flatShading : null,
				normalScale: m.normalScale ? m.normalScale.toArray() : null,
				userData: m.userData,
				association: gltf.parser.associations.get( m ) ?? null,
				maps: Object.fromEntries( maps.map( ( k ) => [ k, texture( m[ k ] ) ] ) ),
				properties: Object.fromEntries( properties.map( ( k ) => [ k, value( m[ k ] ) ] ) ),
			} );
			i = materials.length - 1;

		}

		return i;

	};

	const object = ( o ) => {

		const d = {
			name: o.name,
			type: o.type,
			matrix: o.matrix.toArray(),
			userData: o.userData,
			association: gltf.parser.associations.get( o ) ?? null,
			pivot: o.pivot ? o.pivot.toArray() : null,
		};

		if ( o.isMesh || o.isLine || o.isPoints ) {

			d.geometry = geometry( o.geometry );
			d.material = material( o.material );

		}

		if ( o.morphTargetInfluences ) {

			d.morph = { influences: [ ...o.morphTargetInfluences ], dictionary: o.morphTargetDictionary ?? null };

		}

		if ( o.isSkinnedMesh ) {

			d.skin = {
				bindMode: o.bindMode,
				bindMatrix: o.bindMatrix.toArray(),
				bindMatrixInverse: o.bindMatrixInverse.toArray(),
				bones: o.skeleton.bones.map( ( b ) => [ b.name, b.type, gltf.scenes.some( ( s ) => s.getObjectById( b.id ) === b ) ] ),
				boneInverses: o.skeleton.boneInverses.map( ( m ) => m.toArray() ),
			};

		}

		if ( o.isPerspectiveCamera ) {

			d.camera = [ o.fov, o.aspect, o.near, o.far ];

		} else if ( o.isOrthographicCamera ) {

			d.camera = [ o.left, o.right, o.top, o.bottom, o.near, o.far ];

		}

		if ( o.isLight ) {

			d.light = { color: o.color.toArray(), intensity: o.intensity, distance: o.distance ?? null, angle: o.angle ?? null, penumbra: o.penumbra ?? null, decay: o.decay ?? null };

		}

		d.children = o.children.map( object );
		objects.push( o );

		return d;

	};

	const scenes = gltf.scenes.map( object );

	return {
		scene: gltf.scenes.indexOf( gltf.scene ),
		scenes,
		cameras: gltf.cameras.map( ( c ) => [ c.name, c.type ] ),
		asset: gltf.asset,
		userData: gltf.userData,
		animations: gltf.animations.map( ( clip ) => ( {
			name: clip.name,
			duration: clip.duration,
			blendMode: clip.blendMode,
			userData: clip.userData,
			tracks: clip.tracks.map( ( track ) => {

				const interpolant = track.createInterpolant();

				return {
					name: track.name,
					type: track.constructor.name,
					times: attribute( { itemSize: 1, count: track.times.length, normalized: false, array: track.times } ),
					values: attribute( { itemSize: 1, count: track.values.length, normalized: false, array: track.values } ),
					interpolation: track.getInterpolation() ?? null,
					cubicSpline: track.createInterpolant.isInterpolantFactoryMethodGLTFCubicSpline === true,
					samples: samples.map( ( t ) => Array.from( interpolant.evaluate( t ) ) ),
				};

			} ),
		} ) ),
		geometries: geometries.map( ( { ref, ...g } ) => g ),
		materials: materials.map( ( { ref, ...m } ) => m ),
		textures: textures.map( ( { ref, ...t } ) => t ),
	};

}

const result = { three: pin, files: {} };

for ( const file of files ) {

	const bytes = readFileSync( new URL( file, dir ) );
	const buffer = bytes.buffer.slice( bytes.byteOffset, bytes.byteOffset + bytes.byteLength );
	const gltf = await new GLTFLoader().parseAsync( buffer, dir.href );

	result.files[ file ] = dump( gltf );

}

writeFileSync( new URL( '../../../fixtures/values/gltf_loader.json', here ), JSON.stringify( result, null, '\t' ) + '\n' );

console.log( 'wrote fixtures/values/gltf_loader.json:', files.join( ', ' ) );
