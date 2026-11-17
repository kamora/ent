// Writes fixtures/values/materials.json: material scenarios and what the pinned r187 source produces for them, for
// packages/ent/test/materials/materials_reference_test.dart. Each scenario names a class and its
// constructor parameters; the Dart test builds the same material from the same data.
//
// Parameter values are JSON, with tagged objects for three.js types:
// { "$v2": [ x, y ] }, { "$euler": [ x, y, z, order ] }, { "$planes": [ [ nx, ny, nz, c ], ... ] },
// { "$color": hex }, { "$texture": "uuid" } (a texture without image, its uuid and its source's uuid fixed).
//
// Usage: node tool/reference/js/materials.mjs

import { writeFileSync } from 'node:fs';

const src = '../../../third_party/three.js/src/';
const { Vector2 } = await import( src + 'math/Vector2.js' );
const { Euler } = await import( src + 'math/Euler.js' );
const { Plane } = await import( src + 'math/Plane.js' );
const { Vector3 } = await import( src + 'math/Vector3.js' );
const { Texture } = await import( src + 'textures/Texture.js' );
const { Color } = await import( src + 'math/Color.js' );
const Materials = await import( src + 'materials/Materials.js' );
const { setConsoleFunction } = await import( src + 'utils.js' );

const warnings = [];
setConsoleFunction( ( type, message ) => warnings.push( type + ': ' + message.replaceAll( 'THREE.', 'ENT.' ) ) );

function decode( value ) {

	if ( Array.isArray( value ) ) {

		return value.map( decode );

	}

	if ( value !== null && typeof value === 'object' ) {

		if ( '$color' in value ) return new Color( value.$color );
		if ( '$v2' in value ) return new Vector2( ...value.$v2 );
		if ( '$euler' in value ) return new Euler( ...value.$euler );
		if ( '$planes' in value ) return value.$planes.map( ( p ) => new Plane( new Vector3( p[ 0 ], p[ 1 ], p[ 2 ] ), p[ 3 ] ) );

		if ( '$texture' in value ) {

			const texture = new Texture();
			texture.uuid = value.$texture;
			texture.source.uuid = value.$texture + '-source';
			return texture;

		}

		return Object.fromEntries( Object.entries( value ).map( ( [ k, v ] ) => [ k, decode( v ) ] ) );

	}

	return value;

}

// JSON with non-finite numbers kept as strings, so Infinity survives (JSON.stringify would write null).
function plain( value ) {

	return JSON.parse( JSON.stringify( value, ( key, v ) => typeof v === 'number' && ! Number.isFinite( v ) ? String( v ) : v ) );

}

function build( scenario ) {

	const material = new Materials[ scenario.class ]( scenario.params === undefined ? undefined : decode( scenario.params ) );
	material.uuid = 'material';

	for ( const [ key, value ] of Object.entries( scenario.set ?? {} ) ) {

		material[ key ] = decode( value );

	}

	return material;

}

// ent has no shader materials (exception E-SHADERS).
const classes = Object.keys( Materials )
	.filter( ( name ) => name !== 'Material' && ! name.endsWith( 'ShaderMaterial' ) )
	.sort();

const texture = ( uuid ) => ( { $texture: uuid } );

const scenarios = [

	...[ 'Material', ...classes ].map( ( name ) => ( { name: name + ' defaults', class: name } ) ),

	...classes.map( ( name ) => ( {
		name: name + ' common parameters',
		class: name,
		params: { name: 'm', opacity: 0.5, transparent: true, side: 2, alphaTest: 0.25, depthWrite: false, blendColor: 0x336699, userData: { a: 1, b: [ 1, 2 ] } }
	} ) ),

	{
		name: 'MeshStandardMaterial maps',
		class: 'MeshStandardMaterial',
		params: {
			color: 0xff8800, roughness: 0.3, metalness: 0.7, map: texture( 'map' ), normalMap: texture( 'normal' ),
			normalScale: { $v2: [ 2, - 1 ] }, envMap: texture( 'env' ), envMapRotation: { $euler: [ 0.1, 0.2, 0.3, 'ZYX' ] },
			aoMap: texture( 'ao' ), aoMapIntensity: 0.5, displacementMap: texture( 'disp' ), displacementScale: 2,
			emissive: '#102030', emissiveIntensity: 3, wireframe: true, flatShading: true
		}
	},

	{
		name: 'MeshPhysicalMaterial physical parameters',
		class: 'MeshPhysicalMaterial',
		params: {
			clearcoat: 0.5, clearcoatRoughness: 0.2, clearcoatNormalMap: texture( 'ccn' ), clearcoatNormalScale: { $v2: [ 3, 4 ] },
			sheen: 1, sheenColor: 0x00ff00, sheenRoughness: 0.4, ior: 2, iridescence: 0.7, iridescenceIOR: 1.5,
			iridescenceThicknessMinimum: 50, iridescenceThicknessMaximum: 500, transmission: 0.9, thickness: 2,
			attenuationDistance: 10, attenuationColor: 0x8080ff, specularIntensity: 0.5, specularColor: 0xff0000,
			anisotropy: 0.3, anisotropyRotation: 1.2, dispersion: 0.1, retroreflectivity: 0.6, diffuseRoughness: 0.2
		}
	},

	{ name: 'MeshPhysicalMaterial reflectivity sets ior', class: 'MeshPhysicalMaterial', set: { reflectivity: 0.8 } },

	{
		name: 'MeshPhongMaterial parameters',
		class: 'MeshPhongMaterial',
		params: { specular: 0x222222, shininess: 50, combine: 1, reflectivity: 0.4, refractionRatio: 0.9, envMap: texture( 'env' ), bumpMap: texture( 'bump' ), bumpScale: 0.5 }
	},

	{
		name: 'LineDashedMaterial parameters',
		class: 'LineDashedMaterial',
		params: { color: 'red', linewidth: 2, scale: 2, dashSize: 4, gapSize: 0.5 }
	},

	{
		name: 'PointsMaterial parameters',
		class: 'PointsMaterial',
		params: { size: 4, sizeAttenuation: false, map: texture( 'sprite' ), alphaMap: texture( 'alpha' ), vertexColors: true }
	},

	{
		name: 'SpriteMaterial parameters',
		class: 'SpriteMaterial',
		params: { rotation: 1.5, sizeAttenuation: false, color: 0x0000ff }
	},

	{
		name: 'MeshDepthMaterial parameters',
		class: 'MeshDepthMaterial',
		params: { depthPacking: 3201, displacementMap: texture( 'disp' ), displacementBias: - 1, wireframe: true }
	},

	{
		name: 'Material clipping planes and blending',
		class: 'MeshBasicMaterial',
		params: {
			clippingPlanes: { $planes: [ [ 1, 0, 0, 2 ], [ 0, - 1, 0, - 3 ] ] }, clipIntersection: true, clipShadows: true,
			blending: 5, blendSrc: 202, blendDst: 203, blendSrcAlpha: 204, blendEquationAlpha: 101,
			stencilWrite: true, stencilRef: 3, stencilFunc: 514, polygonOffset: true, polygonOffsetFactor: - 1, polygonOffsetUnits: - 4,
			shadowSide: 1, toneMapped: false, visible: false, forceSinglePass: true, allowOverride: false
		}
	},

	{
		name: 'MeshMatcapMaterial matcap',
		class: 'MeshMatcapMaterial',
		params: { matcap: texture( 'matcap' ), color: 0x123456 }
	},

	{
		name: 'MeshToonMaterial gradient',
		class: 'MeshToonMaterial',
		params: { gradientMap: texture( 'gradient' ), lightMap: texture( 'light' ), lightMapIntensity: 2 }
	},

	{ name: 'setValues unknown and undefined keys', class: 'MeshBasicMaterial', params: { notAProperty: 1, roughness: 0.5 } },

	...classes.map( ( name ) => ( { name: name + ' every property', class: name, params: everyProperty( name ) } ) )

];

// Non-default values for every own property a class has (numbers + 1, flipped booleans, other colors,
// vectors, eulers and strings, textures for null maps), so a property missing from copy, toJSON or fromJSON
// shows up. Identity, bookkeeping, maps and shader sources are left alone.
function everyProperty( name ) {

	const skip = new Set( [ 'id', 'uuid', 'type', 'version', 'userData', 'defines', 'uniforms', 'uniformsGroups', 'extensions', 'defaultAttributeValues', 'index0AttributeName', 'glslVersion', 'precision', 'vertexShader', 'fragmentShader' ] );
	const material = new Materials[ name ]();
	const params = {};

	for ( const [ key, value ] of Object.entries( material ) ) {

		if ( skip.has( key ) || key.startsWith( '_' ) || key.startsWith( 'is' ) ) continue;

		if ( typeof value === 'number' ) params[ key ] = Number.isFinite( value ) ? value + 1 : 7;
		else if ( typeof value === 'boolean' ) params[ key ] = ! value;
		else if ( typeof value === 'string' ) params[ key ] = key === 'name' ? 'n' : 'bevel';
		else if ( value?.isColor ) params[ key ] = 0x123456;
		else if ( value?.isVector2 ) params[ key ] = { $v2: [ value.x + 1, value.y + 2 ] };
		else if ( value?.isEuler ) params[ key ] = { $euler: [ 0.1, 0.2, 0.3, 'YXZ' ] };
		else if ( value === null && /Map$|^map$|^matcap$/.test( key ) ) params[ key ] = { $texture: key };

	}

	return params;

}

const out = [];

for ( const scenario of scenarios ) {

	warnings.length = 0;

	const material = build( scenario );

	const json = material.toJSON();
	const clone = material.clone();
	clone.uuid = 'material';

	// fromJSON into a fresh material of the same class, with the referenced textures resolved by uuid.
	const textures = {};

	for ( const t of json.textures ?? [] ) {

		const texture = new Texture();
		texture.uuid = t.uuid;
		texture.source.uuid = t.image;
		textures[ t.uuid ] = texture;

	}

	const restored = new Materials[ scenario.class ]().fromJSON( json, textures );
	restored.uuid = 'material';

	out.push( {
		...scenario,
		version: material.version,
		warnings: [ ...warnings ],
		reflectivity: material.reflectivity,
		ior: material.ior,
		toJSON: plain( json ),
		cloneToJSON: plain( clone.toJSON() ),
		fromJSONToJSON: plain( restored.toJSON() )
	} );

}

writeFileSync( new URL( '../../../fixtures/values/materials.json', import.meta.url ), JSON.stringify( { reference: 'r187', scenarios: out }, null, '\t' ) + '\n' );
console.log( out.length + ' scenarios' );
