// Writes fixtures/values/helpers.json: the geometry arrays, matrices and colors every helper produces in
// representative setups, from the pinned src/, for packages/ent/test/helpers.
//
// Usage: node tool/reference/js/helpers.mjs

import { writeFileSync } from 'node:fs';

const T = await import( '../../../third_party/three.js/src/Three.Core.js' );

const array = ( attribute ) => Array.from( attribute.array );
const xyz = ( v ) => [ v.x, v.y, v.z ];
const quat = ( q ) => [ q.x, q.y, q.z, q.w ];
const rgb = ( c ) => [ c.r, c.g, c.b ];
const sphere = ( s ) => [ ...xyz( s.center ), s.radius ];
const out = {};

// AxesHelper

const axes = new T.AxesHelper( 5 );
out.axes = { position: array( axes.geometry.attributes.position ), color: array( axes.geometry.attributes.color ) };
axes.setColors( 0x123456, 'red', new T.Color( 0.1, 0.2, 0.3 ) );
out.axes.setColors = array( axes.geometry.attributes.color );

// GridHelper

for ( const [ name, args ] of [ [ 'gridDefault', [] ], [ 'grid', [ 7, 5, 0xff0000, 'blue' ] ] ] ) {

	const grid = new T.GridHelper( ...args );
	out[ name ] = { position: array( grid.geometry.attributes.position ), color: array( grid.geometry.attributes.color ) };

}

// PolarGridHelper

for ( const [ name, args ] of [ [ 'polarDefault', [] ], [ 'polar', [ 3, 5, 3, 7, 0x00ff00, 0x0000ff ] ], [ 'polarOneSector', [ 2, 1, 2, 4 ] ] ] ) {

	const polar = new T.PolarGridHelper( ...args );
	out[ name ] = { position: array( polar.geometry.attributes.position ), color: array( polar.geometry.attributes.color ) };

}

// ArrowHelper

const arrowState = ( a ) => ( {
	position: xyz( a.position ),
	quaternion: quat( a.quaternion ),
	line: a.line.matrix.elements.slice(),
	cone: a.cone.matrix.elements.slice(),
	lineColor: rgb( a.line.material.color ),
	coneColor: rgb( a.cone.material.color )
} );

const arrow = new T.ArrowHelper( new T.Vector3( 1, 2, 3 ).normalize(), new T.Vector3( 1, - 2, 3 ), 4, 0xff00ff, 1, 0.5 );
out.arrow = arrowState( arrow );
arrow.setDirection( new T.Vector3( 0, 1, 0 ) );
out.arrow.up = quat( arrow.quaternion );
arrow.setDirection( new T.Vector3( 0, - 1, 0 ) );
out.arrow.down = quat( arrow.quaternion );
arrow.setLength( 2 );
arrow.setColor( '#00ff88' );
out.arrow.after = arrowState( arrow );
out.arrowDefault = arrowState( new T.ArrowHelper() );
out.arrowShort = arrowState( new T.ArrowHelper( new T.Vector3( 1, 0, 0 ), undefined, 0.1 ) );

// Box3Helper

const box3 = new T.Box3Helper( new T.Box3( new T.Vector3( - 1, - 2, - 3 ), new T.Vector3( 4, 5, 6 ) ), 0x00ffff );
box3.updateMatrixWorld();
out.box3 = { matrixWorld: box3.matrixWorld.elements.slice(), boundingSphere: sphere( box3.geometry.boundingSphere ), color: rgb( box3.material.color ) };

// BoxHelper

const boxMesh = new T.Mesh( new T.BoxGeometry( 1, 2, 3 ) );
boxMesh.position.set( 1, 2, 3 );
boxMesh.rotation.set( 0.3, 0.5, 0.7 );
boxMesh.updateMatrixWorld();
const boxHelper = new T.BoxHelper( boxMesh, 0xff0000 );
out.boxHelper = { position: array( boxHelper.geometry.attributes.position ), boundingSphere: sphere( boxHelper.geometry.boundingSphere ) };
const sphereMesh = new T.Mesh( new T.SphereGeometry( 2 ) );
sphereMesh.position.set( - 3, 0, 1 );
sphereMesh.updateMatrixWorld();
boxHelper.setFromObject( sphereMesh );
out.boxHelper.setFromObject = array( boxHelper.geometry.attributes.position );

// CameraHelper

const cameraState = ( h ) => ( { position: array( h.geometry.attributes.position ), color: array( h.geometry.attributes.color ) } );

const perspective = new T.PerspectiveCamera( 50, 1.5, 0.1, 100 );
perspective.position.set( 1, 2, 3 );
perspective.updateMatrixWorld();
out.cameraPerspective = cameraState( new T.CameraHelper( perspective ) );

const ortho = new T.OrthographicCamera( - 2, 3, 4, - 1, 0.5, 20 );
ortho.coordinateSystem = T.WebGPUCoordinateSystem;
ortho.updateProjectionMatrix();
out.cameraOrthoWebGPU = cameraState( new T.CameraHelper( ortho ) );

const reversed = new T.PerspectiveCamera( 70, 0.8, 1, 50 );
reversed._reversedDepth = true;
reversed.updateProjectionMatrix();
out.cameraReversed = cameraState( new T.CameraHelper( reversed ) );

// DirectionalLightHelper

const directionalState = ( h ) => ( {
	plane: quat( h.lightPlane.quaternion ),
	target: quat( h.targetLine.quaternion ),
	targetScale: xyz( h.targetLine.scale ),
	planePosition: array( h.lightPlane.geometry.attributes.position ),
	color: rgb( h.lightPlane.material.color )
} );

const directional = new T.DirectionalLight( 0x8899aa );
directional.position.set( 3, 4, 5 );
directional.target.position.set( 1, 0, - 1 );
out.directional = directionalState( new T.DirectionalLightHelper( directional, 2 ) );
out.directionalColor = directionalState( new T.DirectionalLightHelper( directional, undefined, 0xff0000 ) );

// HemisphereLightHelper

const hemisphere = new T.HemisphereLight( 0x123456, 0xabcdef );
hemisphere.position.set( 1, 2, 3 );
const hemisphereHelper = new T.HemisphereLightHelper( hemisphere, 2 );
out.hemisphere = {
	color: array( hemisphereHelper.children[ 0 ].geometry.attributes.color ),
	quaternion: quat( hemisphereHelper.children[ 0 ].quaternion ),
	vertexColors: hemisphereHelper.material.vertexColors
};
const hemisphereColored = new T.HemisphereLightHelper( hemisphere, 1, 0x00ff00 );
out.hemisphereColor = { color: rgb( hemisphereColored.material.color ), vertexColors: hemisphereColored.material.vertexColors };

// PointLightHelper

const point = new T.PointLight( 0xff0000 );
point.position.set( 1, 2, 3 );
const pointHelper = new T.PointLightHelper( point, 3 );
out.point = { color: rgb( pointHelper.material.color ), position: array( pointHelper.geometry.attributes.position ) };
out.pointColor = rgb( new T.PointLightHelper( point, 1, 'blue' ).material.color );

// SpotLightHelper

const spotState = ( h ) => ( {
	matrix: h.matrix.elements.slice(),
	scale: xyz( h.cone.scale ),
	quaternion: quat( h.cone.quaternion ),
	color: rgb( h.cone.material.color )
} );

const spot = new T.SpotLight( 0x00ff00, 1, 10, Math.PI / 6 );
spot.position.set( 1, 2, 3 );
const spotHelper = new T.SpotLightHelper( spot );
out.spot = spotState( spotHelper );
out.spot.position = array( spotHelper.cone.geometry.attributes.position );

const group = new T.Group();
group.position.set( - 1, 0.5, 2 );
group.rotation.set( 0.2, - 0.4, 0.1 );
const spotChild = new T.SpotLightHelper( spot, 0xff00ff );
group.add( spotChild );
spot.distance = 0;
spot.target.position.set( 2, - 1, 0 );
spotChild.update();
out.spotParent = spotState( spotChild );

// PlaneHelper

const planeHelper = new T.PlaneHelper( new T.Plane( new T.Vector3( 1, 1, 0.2 ).normalize(), 3 ), 2, 0xff0000 );
planeHelper.updateMatrixWorld();
out.plane = { matrixWorld: planeHelper.matrixWorld.elements.slice(), child: planeHelper.children[ 0 ].matrixWorld.elements.slice() };

// SkeletonHelper

const root = new T.Object3D();
root.position.set( 0.5, - 1, 2 );
root.rotation.set( 0, 0.3, 0 );
const b0 = new T.Bone(), b1 = new T.Bone(), b2 = new T.Bone(), loose = new T.Object3D(), b3 = new T.Bone();
b1.position.set( 0, 1, 0 );
b2.position.set( 0.5, 1, 0 );
b2.rotation.set( 0.4, 0, 0.2 );
b3.position.set( 1, 0, 0 );
root.add( b0 );
b0.add( b1 );
b1.add( b2 );
b2.add( loose );
loose.add( b3 );
root.updateMatrixWorld( true );
const skeleton = new T.SkeletonHelper( root );
skeleton.updateMatrixWorld();
out.skeleton = { bones: skeleton.bones.length, position: array( skeleton.geometry.attributes.position ), color: array( skeleton.geometry.attributes.color ) };

writeFileSync( new URL( '../../../fixtures/values/helpers.json', import.meta.url ), JSON.stringify( out, null, '\t' ) + '\n' );
console.log( Object.keys( out ).length + ' setups' );
