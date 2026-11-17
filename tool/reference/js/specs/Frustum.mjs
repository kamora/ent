// Reference cases for src/math/Frustum.js. intersectsObject and intersectsSprite need Object3D/Sprite (M2).

import { int } from '../lib/codec.mjs';

const src = '../../../../third_party/three.js/src/math/';

const { Frustum } = await import( src + 'Frustum.js' );
const { Matrix4 } = await import( src + 'Matrix4.js' );
const { Vector3 } = await import( src + 'Vector3.js' );
const { Sphere } = await import( src + 'Sphere.js' );
const { Box3 } = await import( src + 'Box3.js' );
const { Plane } = await import( src + 'Plane.js' );

const near = ( r ) => new Vector3( r.range( - 4, 4 ), r.range( - 4, 4 ), r.range( - 8, 2 ) );
const perspective = ( r, system = 2000, reversed = false ) => new Matrix4().makePerspective( - r.range( 0.2, 2 ), r.range( 0.2, 2 ), r.range( 0.2, 2 ), - r.range( 0.2, 2 ), r.range( 0.1, 1 ), r.range( 5, 20 ), system, reversed );

// The frustum of a camera near the origin, so points, spheres and boxes around it fall inside and outside.
const frustum = ( r ) => {

	const view = new Matrix4().makeRotationAxis( new Vector3( r.range( - 1, 1 ), r.range( - 1, 1 ), r.range( - 1, 1 ) ).normalize(), r.range( - 0.5, 0.5 ) ).invert();
	return new Frustum().setFromProjectionMatrix( perspective( r ).multiply( view ) );

};

const box = ( r ) => {

	const min = near( r );
	return new Box3( min, min.clone().add( new Vector3( r.range( 0, 3 ), r.range( 0, 3 ), r.range( 0, 3 ) ) ) );

};

export default {
	name: 'Frustum',
	type: 'Frustum',
	self: frustum,
	cases: 20,
	methods: [
		{ name: 'set', args: [ 'Plane', 'Plane', 'Plane', 'Plane', 'Plane', 'Plane' ], cases: 5 },
		{ name: 'copy', args: [ 'Frustum' ], cases: 5 },
		{ name: 'setFromProjectionMatrix', label: 'default system', args: [ perspective ] },
		{ name: 'setFromProjectionMatrix', label: 'any matrix', args: [ 'Matrix4' ] },
		{
			name: 'setFromProjectionMatrix',
			args: [ ( r ) => perspective( r ), ( r ) => int( r.pick( [ 2000, 2001 ] ) ), 'bool' ],
			edge: [
				() => ( { self: new Frustum(), args: [ new Matrix4().makeOrthographic( - 1, 1, 1, - 1, 1, 100 ), int( 2001 ), false ] } ),
				() => ( { self: new Frustum(), args: [ new Matrix4(), int( 9999 ), false ] } ),
				() => ( { self: new Frustum(), args: [ new Matrix4(), int( 9999 ), true ] } )
			]
		},
		{
			name: 'intersectsSphere', args: [ ( r ) => new Sphere( near( r ), r.range( 0, 2 ) ) ], cases: 40,
			edge: [ () => ( { self: new Frustum().setFromProjectionMatrix( new Matrix4().makePerspective( - 1, 1, 1, - 1, 1, 100 ) ), args: [ new Sphere( new Vector3(), - 1 ) ] } ) ]
		},
		{
			name: 'intersectsBox', args: [ box ], cases: 40,
			edge: [

				// empty box (min +Infinity, max -Infinity), a frustum of default planes
				() => ( { self: new Frustum().setFromProjectionMatrix( new Matrix4().makePerspective( - 1, 1, 1, - 1, 1, 100 ) ), args: [ new Box3() ] } ),
				() => ( { self: new Frustum(), args: [ new Box3( new Vector3( - 1, - 1, - 1 ), new Vector3( 1, 1, 1 ) ) ] } )
			]
		},
		{ name: 'containsPoint', args: [ near ], cases: 40, edge: [ () => ( { self: new Frustum( new Plane( new Vector3( 1, 0, 0 ), 0 ) ), args: [ new Vector3() ] } ) ] },
		{ name: 'clone', cases: 5 }
	]
};
