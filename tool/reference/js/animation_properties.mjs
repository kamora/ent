// Animates every scalar property that the port writes through `operator []=` with an AnimationMixer in the
// pinned three.js r187 and records the property after each update, plus the warnings. The Dart test
// packages/ent/test/animation/animation_properties_test.dart replays the same scenarios.
//
// Usage: node tool/reference/js/animation_properties.mjs

import { writeFileSync } from 'node:fs';

const src = new URL( '../../../third_party/three.js/src/', import.meta.url );
const load = async ( path ) => import( new URL( path, src ) );

const { AnimationMixer } = await load( 'animation/AnimationMixer.js' );
const { AnimationClip } = await load( 'animation/AnimationClip.js' );
const { NumberKeyframeTrack } = await load( 'animation/tracks/NumberKeyframeTrack.js' );
const { BooleanKeyframeTrack } = await load( 'animation/tracks/BooleanKeyframeTrack.js' );
const { InterpolateDiscrete } = await load( 'constants.js' );
const { setConsoleFunction } = await load( 'utils.js' );

const classes = {
	Object3D: ( await load( 'core/Object3D.js' ) ).Object3D,
	PerspectiveCamera: ( await load( 'cameras/PerspectiveCamera.js' ) ).PerspectiveCamera,
	OrthographicCamera: ( await load( 'cameras/OrthographicCamera.js' ) ).OrthographicCamera,
	ArrayCamera: ( await load( 'cameras/ArrayCamera.js' ) ).ArrayCamera,
	AmbientLight: ( await load( 'lights/AmbientLight.js' ) ).AmbientLight,
	SpotLight: ( await load( 'lights/SpotLight.js' ) ).SpotLight,
	PointLight: ( await load( 'lights/PointLight.js' ) ).PointLight,
	RectAreaLight: ( await load( 'lights/RectAreaLight.js' ) ).RectAreaLight,
	DirectionalLight: ( await load( 'lights/DirectionalLight.js' ) ).DirectionalLight,
	Scene: ( await load( 'scenes/Scene.js' ) ).Scene,
	Mesh: ( await load( 'objects/Mesh.js' ) ).Mesh,
	Sprite: ( await load( 'objects/Sprite.js' ) ).Sprite,
	LOD: ( await load( 'objects/LOD.js' ) ).LOD,
	ClippingGroup: ( await load( 'objects/ClippingGroup.js' ) ).ClippingGroup
};

const { FogExp2 } = await load( 'scenes/FogExp2.js' );

// [ class, property, kind ]: kind 'number' (linear), 'int' (discrete, whole values), 'bool'.
const cases = [
	[ 'Object3D', 'renderOrder', 'int' ], [ 'Object3D', 'visible', 'bool' ], [ 'Object3D', 'castShadow', 'bool' ],
	...[ 'fov', 'zoom', 'near', 'far', 'focus', 'aspect', 'filmGauge', 'filmOffset' ].map( ( p ) => [ 'PerspectiveCamera', p, 'number' ] ),
	...[ 'zoom', 'left', 'right', 'top', 'bottom', 'near', 'far' ].map( ( p ) => [ 'OrthographicCamera', p, 'number' ] ),
	[ 'ArrayCamera', 'perCameraFrustumCulled', 'bool' ], [ 'ArrayCamera', 'fov', 'number' ],
	[ 'AmbientLight', 'intensity', 'number' ],
	...[ 'intensity', 'distance', 'angle', 'penumbra', 'decay', 'power' ].map( ( p ) => [ 'SpotLight', p, 'number' ] ),
	...[ 'distance', 'decay', 'power' ].map( ( p ) => [ 'PointLight', p, 'number' ] ),
	...[ 'width', 'height', 'power' ].map( ( p ) => [ 'RectAreaLight', p, 'number' ] ),
	[ 'DirectionalLight', 'intensity', 'number' ],
	...[ 'backgroundBlurriness', 'backgroundIntensity', 'environmentIntensity' ].map( ( p ) => [ 'Scene', p, 'number' ] ),
	[ 'Mesh', 'count', 'int' ], [ 'Sprite', 'count', 'int' ],
	[ 'LOD', 'autoUpdate', 'bool' ],
	[ 'ClippingGroup', 'enabled', 'bool' ], [ 'ClippingGroup', 'clipIntersection', 'bool' ], [ 'ClippingGroup', 'clipShadows', 'bool' ]
];

const steps = [ 0, 0.25, 0.3, 0.45, 0.7, 0.1 ];

function scenario( make, name, kind, root, read ) {

	const warnings = [];
	setConsoleFunction( ( type, message ) => warnings.push( message.replaceAll( 'THREE.', 'ENT.' ) ) );

	const times = [ 0, 0.5, 1 ];
	const track = kind === 'bool'
		? new BooleanKeyframeTrack( name, times, [ false, true, false ] )
		: kind === 'int'
			? new NumberKeyframeTrack( name, times, [ 1, 5, 2 ], InterpolateDiscrete )
			: new NumberKeyframeTrack( name, times, [ 0.5, 3.25, 1.75 ] );

	const mixer = new AnimationMixer( root );
	mixer.clipAction( new AnimationClip( 'clip', - 1, [ track ] ) ).play();

	const samples = steps.map( ( dt ) => {

		mixer.update( dt );
		return read();

	} );

	setConsoleFunction( null );

	return { make, track: name, kind, steps, samples, warnings };

}

const scenarios = cases.map( ( [ make, property, kind ] ) => {

	const object = new classes[ make ]();
	return scenario( make, '.' + property, kind, object, () => object[ property ] );

} );

// Objects that are not material, materials, bones or map cannot be addressed by a track path in r187.
for ( const [ make, track ] of [ [ 'DirectionalLight', 'target.shadow.bias' ], [ 'SceneFogExp2', 'target.fog.density' ] ] ) {

	const object = make === 'SceneFogExp2' ? new classes.Scene() : new classes[ make ]();
	object.name = 'target';

	if ( make === 'SceneFogExp2' ) {

		object.fog = new FogExp2( 0xffffff, 0.1 );

	}

	const read = make === 'SceneFogExp2' ? () => object.fog.density : () => object.shadow.bias;
	scenarios.push( scenario( make, track, 'number', object, read ) );

}

const out = new URL( '../../../fixtures/values/animation_properties.json', import.meta.url );
writeFileSync( out, JSON.stringify( { reference: 'r187', scenarios }, null, '\t' ) + '\n' );
console.log( scenarios.length + ' scenarios' );
