// Reference round trips for src/loaders: each scene is serialized with the pinned three.js r187 (toJSON),
// parsed back by r187's own ObjectLoader and serialized again. The Dart test parses the first JSON with the
// port's ObjectLoader, serializes it, and compares with the second.
//
// Usage: node tool/reference/js/loaders.mjs  (writes fixtures/values/loaders.json)

import { writeFileSync } from 'node:fs';
import { execSync } from 'node:child_process';

const upstream = new URL( '../../../third_party/three.js/', import.meta.url );
const tag = execSync( 'git describe --tags --exact-match', { cwd: upstream } ).toString().trim();

if ( tag !== 'r187' ) {

	throw new Error( 'three.js checkout is ' + tag + ', the reference requires r187' );

}

// Node has no DOM. ObjectLoader only tests `instanceof HTMLImageElement`, which data images (all these
// scenes use) fail in a browser too.
globalThis.HTMLImageElement = class HTMLImageElement {};

const THREE = await import( new URL( 'src/Three.Core.js', upstream ) );

// Deterministic values; uuids stay random and the Dart side compares them by first appearance.
let seed = 7;
const rand = () => ( seed = ( seed * 16807 ) % 2147483647 ) / 2147483647;

function placed( object, i ) {

	object.position.set( i, rand() * 4 - 2, rand() * 4 - 2 );
	object.rotation.set( rand(), rand(), rand(), [ 'XYZ', 'YXZ', 'ZXY' ][ i % 3 ] );
	object.scale.set( 1 + rand(), 1, 1 + rand() );
	return object;

}

function dataTexture() {

	const data = new Uint8Array( 4 * 4 * 4 );
	for ( let i = 0; i < data.length; i ++ ) data[ i ] = ( i * 37 ) % 256;
	const texture = new THREE.DataTexture( data, 4, 4 );
	texture.name = 'checker';
	texture.wrapS = THREE.RepeatWrapping;
	texture.wrapT = THREE.MirroredRepeatWrapping;
	texture.magFilter = THREE.LinearFilter;
	texture.minFilter = THREE.LinearMipmapLinearFilter;
	texture.repeat.set( 2, 3 );
	texture.offset.set( 0.25, 0.5 );
	texture.center.set( 0.5, 0.5 );
	texture.rotation = 0.3;
	texture.anisotropy = 4;
	texture.colorSpace = THREE.SRGBColorSpace;
	texture.userData = { tag: 'data' };
	texture.needsUpdate = true;
	return texture;

}

const scenarios = {};

// Scene graph: fog, background, cameras, lights (targets, shadows, map), meshes, lines, points, sprite, LOD.
scenarios.scene = () => {

	const scene = new THREE.Scene();
	scene.name = 'root';
	scene.background = new THREE.Color( 0x336699 );
	scene.fog = new THREE.Fog( 0xaabbcc, 2, 50 );
	scene.fog.name = 'mist';
	scene.backgroundBlurriness = 0.2;
	scene.backgroundIntensity = 0.8;
	scene.backgroundRotation.set( 0.1, 0.2, 0.3 );
	scene.environmentIntensity = 0.7;
	scene.environmentRotation.set( 0.3, 0.2, 0.1, 'ZYX' );
	scene.userData = { level: 3, tags: [ 'a', 'b' ] };

	const texture = dataTexture();

	const standard = new THREE.MeshStandardMaterial( { color: 0xff8800, roughness: 0.3, metalness: 0.6, map: texture } );
	const basic = new THREE.MeshBasicMaterial( { color: 0x00ff00, wireframe: true } );
	const box = new THREE.BoxGeometry( 1, 2, 3, 2, 1, 1 );
	scene.add( placed( new THREE.Mesh( box, standard ), 0 ) );
	scene.add( placed( new THREE.Mesh( box, [ standard, basic, standard, basic, standard, basic ] ), 1 ) );

	const group = placed( new THREE.Group(), 2 );
	group.name = 'group';
	group.visible = false;
	group.renderOrder = 4;
	group.layers.set( 3 );
	group.frustumCulled = false;
	group.castShadow = true;
	group.receiveShadow = true;
	group.pivot = new THREE.Vector3( 1, - 2, 3 );
	group.up.set( 0, 0, 1 );
	scene.add( group );

	const sphere = new THREE.Mesh( new THREE.SphereGeometry( 1, 8, 6 ), new THREE.MeshPhongMaterial( { shininess: 12 } ) );
	sphere.matrixAutoUpdate = false;
	sphere.matrix.makeTranslation( 1, 2, 3 );
	group.add( sphere );

	const camera = placed( new THREE.PerspectiveCamera( 60, 1.5, 0.5, 300 ), 3 );
	camera.zoom = 2;
	camera.focus = 7;
	camera.filmGauge = 30;
	camera.filmOffset = 1;
	camera.setViewOffset( 1920, 1080, 100, 50, 800, 600 );
	scene.add( camera );

	const ortho = placed( new THREE.OrthographicCamera( - 3, 3, 2, - 2, 0.1, 100 ), 4 );
	ortho.zoom = 0.5;
	scene.add( ortho );

	const target = placed( new THREE.Object3D(), 5 );
	target.name = 'target';
	scene.add( target );

	const sun = new THREE.DirectionalLight( 0xffeedd, 2.5 );
	sun.target = target;
	sun.castShadow = true;
	sun.shadow.bias = - 0.001;
	sun.shadow.normalBias = 0.02;
	sun.shadow.radius = 3;
	sun.shadow.blurSamples = 12;
	sun.shadow.intensity = 0.8;
	sun.shadow.mapSize.set( 1024, 512 );
	sun.shadow.camera.left = - 20;
	sun.shadow.camera.updateProjectionMatrix();
	scene.add( placed( sun, 6 ) );

	const spot = new THREE.SpotLight( 0xffffff, 3, 40, Math.PI / 5, 0.3, 1.5 );
	spot.map = texture;
	spot.shadow.focus = 0.7;
	spot.shadow.aspect = 1.25;
	scene.add( placed( spot, 7 ) );

	const point = new THREE.PointLight( 0x00ffff, 4, 25, 1 );
	point.shadow.mapType = THREE.HalfFloatType;
	scene.add( placed( point, 8 ) );

	scene.add( new THREE.AmbientLight( 0x202020, 0.5 ) );
	scene.add( new THREE.HemisphereLight( 0x8888ff, 0x442200, 0.6 ) );
	scene.add( placed( new THREE.RectAreaLight( 0xff00ff, 2, 4, 3 ), 9 ) );

	const sh = new THREE.SphericalHarmonics3();
	for ( let i = 0; i < 9; i ++ ) sh.coefficients[ i ].set( rand(), rand(), rand() );
	scene.add( new THREE.LightProbe( sh, 0.9 ) );

	const linePositions = new THREE.BufferGeometry().setFromPoints( [ new THREE.Vector3( 0, 0, 0 ), new THREE.Vector3( 1, 1, 0 ), new THREE.Vector3( 2, 0, 1 ) ] );
	const lineMaterial = new THREE.LineDashedMaterial( { color: 0x123456, dashSize: 2, gapSize: 0.5 } );
	scene.add( placed( new THREE.Line( linePositions, lineMaterial ), 10 ) );
	scene.add( placed( new THREE.LineLoop( linePositions, lineMaterial ), 11 ) );
	scene.add( placed( new THREE.LineSegments( linePositions, new THREE.LineBasicMaterial() ), 12 ) );
	scene.add( placed( new THREE.Points( linePositions, new THREE.PointsMaterial( { size: 3, sizeAttenuation: false } ) ), 13 ) );

	const sprite = new THREE.Sprite( new THREE.SpriteMaterial( { color: 0xff0000, rotation: 0.4 } ) );
	sprite.center.set( 0.5, 0 );
	scene.add( placed( sprite, 14 ) );

	const lod = new THREE.LOD();
	lod.autoUpdate = false;
	lod.addLevel( new THREE.Mesh( box, basic ), 0 );
	lod.addLevel( new THREE.Mesh( new THREE.IcosahedronGeometry( 1, 1 ), basic ), 20, 0.1 );
	scene.add( placed( lod, 15 ) );

	return scene;

};

// Geometries: shapes (Extrude, Shape), curves (Tube), raw buffers with interleaving, morphs, groups, instancing.
scenarios.geometries = () => {

	const group = new THREE.Group();
	const material = new THREE.MeshNormalMaterial();

	const shape = new THREE.Shape();
	shape.moveTo( 0, 0 );
	shape.lineTo( 2, 0 );
	shape.quadraticCurveTo( 3, 1, 2, 2 );
	shape.bezierCurveTo( 1, 3, 0, 2, 0, 1 );
	const hole = new THREE.Path();
	hole.absarc( 1, 1, 0.3, 0, Math.PI * 2, false );
	shape.holes.push( hole );

	group.add( new THREE.Mesh( new THREE.ShapeGeometry( shape, 6 ), material ) );
	group.add( new THREE.Mesh( new THREE.ExtrudeGeometry( shape, { depth: 0.5, bevelEnabled: true, bevelSize: 0.1, bevelSegments: 2, curveSegments: 4 } ), material ) );

	const path = new THREE.CatmullRomCurve3( [ new THREE.Vector3( 0, 0, 0 ), new THREE.Vector3( 1, 2, 0 ), new THREE.Vector3( 3, 1, 1 ) ] );
	group.add( new THREE.Mesh( new THREE.TubeGeometry( path, 8, 0.2, 5, false ), material ) );
	group.add( new THREE.Mesh( new THREE.LatheGeometry( [ new THREE.Vector2( 0, 0 ), new THREE.Vector2( 1, 1 ), new THREE.Vector2( 0.5, 2 ) ], 6 ), material ) );
	group.add( new THREE.Mesh( new THREE.TorusKnotGeometry( 1, 0.3, 16, 4, 2, 3 ), material ) );
	group.add( new THREE.Mesh( new THREE.CylinderGeometry( 1, 0.5, 2, 6, 2, true, 0.2, 4 ), material ) );
	group.add( new THREE.Mesh( new THREE.PlaneGeometry( 2, 1, 2, 2 ), material ) );
	group.add( new THREE.Mesh( new THREE.RingGeometry( 0.5, 1, 6, 2 ), material ) );
	group.add( new THREE.Mesh( new THREE.CapsuleGeometry( 0.5, 1, 2, 6, 1 ), material ) );

	const raw = new THREE.BufferGeometry();
	const interleaved = new THREE.InterleavedBuffer( new Float32Array( [ 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1 ] ), 4 );
	raw.setAttribute( 'position', new THREE.InterleavedBufferAttribute( interleaved, 3, 0 ) );
	raw.setAttribute( 'uv', new THREE.Float32BufferAttribute( [ 0, 0, 1, 0, 1, 1, 0, 1 ], 2 ) );
	const color = new THREE.Uint8BufferAttribute( [ 255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255 ], 3, true );
	color.name = 'colors';
	color.setUsage( THREE.DynamicDrawUsage );
	raw.setAttribute( 'color', color );
	raw.setIndex( [ 0, 1, 2, 0, 2, 3 ] );
	raw.morphAttributes.position = [ new THREE.Float32BufferAttribute( [ 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1 ], 3 ) ];
	raw.morphTargetsRelative = true;
	raw.addGroup( 0, 3, 0 );
	raw.addGroup( 3, 3, 1 );
	raw.computeBoundingSphere();
	raw.name = 'raw';
	raw.userData = { source: 'hand' };
	const morphed = new THREE.Mesh( raw, [ material, new THREE.MeshLambertMaterial() ] );
	morphed.morphTargetInfluences = [ 0.25 ];
	morphed.morphTargetDictionary = { lift: 0 };
	group.add( morphed );

	const instancedGeometry = new THREE.InstancedBufferGeometry();
	instancedGeometry.setAttribute( 'position', new THREE.Float32BufferAttribute( [ 0, 0, 0, 1, 0, 0, 0, 1, 0 ], 3 ) );
	instancedGeometry.setAttribute( 'offset', new THREE.InstancedBufferAttribute( new Float32Array( [ 0, 0, 0, 2, 0, 0 ] ), 3 ) );
	instancedGeometry.instanceCount = 2;
	group.add( new THREE.Mesh( instancedGeometry, material ) );

	return group;

};

// Skinning and animation clips.
scenarios.skinning = () => {

	const root = new THREE.Bone();
	root.name = 'root';
	const child = new THREE.Bone();
	child.name = 'child';
	child.position.y = 1;
	root.add( child );

	const geometry = new THREE.CylinderGeometry( 0.2, 0.2, 2, 4, 2 );
	const position = geometry.getAttribute( 'position' );
	const skinIndex = [];
	const skinWeight = [];

	for ( let i = 0; i < position.count; i ++ ) {

		const y = position.getY( i ) + 1;
		skinIndex.push( 0, 1, 0, 0 );
		skinWeight.push( 1 - y / 2, y / 2, 0, 0 );

	}

	geometry.setAttribute( 'skinIndex', new THREE.Uint16BufferAttribute( skinIndex, 4 ) );
	geometry.setAttribute( 'skinWeight', new THREE.Float32BufferAttribute( skinWeight, 4 ) );

	const mesh = new THREE.SkinnedMesh( geometry, new THREE.MeshStandardMaterial() );
	mesh.add( root );
	mesh.bind( new THREE.Skeleton( [ root, child ] ) );
	mesh.bindMode = THREE.DetachedBindMode;

	const times = [ 0, 1, 2 ];
	const clip = new THREE.AnimationClip( 'wave', 2, [
		new THREE.QuaternionKeyframeTrack( 'child.quaternion', times, [ 0, 0, 0, 1, 0, 0, 0.383, 0.924, 0, 0, 0, 1 ] ),
		new THREE.VectorKeyframeTrack( 'root.position', times, [ 0, 0, 0, 0, 1, 0, 0, 0, 0 ], THREE.InterpolateSmooth ),
		new THREE.NumberKeyframeTrack( '.material.opacity', [ 0, 2 ], [ 1, 0.5 ] )
	] );
	clip.userData = { loop: true };
	mesh.animations.push( clip );

	const group = new THREE.Group();
	group.add( mesh );
	return group;

};

// Instancing and batching.
scenarios.instancing = () => {

	const group = new THREE.Group();

	const instanced = new THREE.InstancedMesh( new THREE.BoxGeometry(), new THREE.MeshBasicMaterial(), 3 );
	const matrix = new THREE.Matrix4();

	for ( let i = 0; i < 3; i ++ ) {

		instanced.setMatrixAt( i, matrix.makeTranslation( i, rand(), 0 ) );
		instanced.setColorAt( i, new THREE.Color( rand(), rand(), rand() ) );

	}

	instanced.computeBoundingSphere();
	group.add( instanced );

	const batched = new THREE.BatchedMesh( 4, 200, 400, new THREE.MeshStandardMaterial() );
	const boxId = batched.addGeometry( new THREE.BoxGeometry() );
	const sphereId = batched.addGeometry( new THREE.SphereGeometry( 0.5, 6, 4 ) );
	const a = batched.addInstance( boxId );
	const b = batched.addInstance( sphereId );
	batched.addInstance( boxId );
	batched.setMatrixAt( a, matrix.makeTranslation( 1, 0, 0 ) );
	batched.setMatrixAt( b, matrix.makeTranslation( 0, 2, 0 ) );
	batched.setColorAt( b, new THREE.Color( 0.2, 0.4, 0.6 ) );
	batched.deleteInstance( 2 );
	batched.perObjectFrustumCulled = false;
	batched.sortObjects = false;
	batched.computeBoundingBox();
	batched.computeBoundingSphere();
	group.add( batched );

	return group;

};

// Textures and shader materials.
scenarios.textures = () => {

	const group = new THREE.Group();

	const faces = [];
	for ( let i = 0; i < 6; i ++ ) faces.push( new THREE.DataTexture( new Uint8Array( [ i * 40, 0, 0, 255 ] ), 1, 1 ) );
	const cube = new THREE.CubeTexture( faces );
	cube.mapping = THREE.CubeRefractionMapping;
	cube.needsUpdate = true;

	const material = new THREE.MeshPhysicalMaterial( { envMap: cube, clearcoat: 0.5, sheen: 0.2, iridescence: 0.3, transmission: 0.4 } );
	group.add( new THREE.Mesh( new THREE.BoxGeometry(), material ) );

	const fogScene = new THREE.Scene();
	fogScene.fog = new THREE.FogExp2( 0x101010, 0.02 );
	fogScene.background = dataTexture();
	fogScene.environment = dataTexture();
	group.add( fogScene );

	return group;

};

const values = { reference: { tag }, scenarios: {} };

for ( const [ name, build ] of Object.entries( scenarios ) ) {

	const json = build().toJSON();
	const parsed = new THREE.ObjectLoader().parse( JSON.parse( JSON.stringify( json ) ) );
	const roundtrip = parsed.toJSON();

	values.scenarios[ name ] = { json: JSON.parse( JSON.stringify( json ) ), roundtrip: JSON.parse( JSON.stringify( roundtrip ) ) };

}

writeFileSync( new URL( '../../../fixtures/values/loaders.json', import.meta.url ), JSON.stringify( values, null, '\t' ) + '\n' );
console.log( Object.keys( values.scenarios ).join( ', ' ) );
