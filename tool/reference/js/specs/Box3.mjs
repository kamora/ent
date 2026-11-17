// Reference cases for src/math/Box3.js. toJSON returns a plain object; the ported unit tests cover it.
// setFromBufferAttribute, setFromObject and expandByObject wait for core (M2).

import { Box3 } from '../../../../third_party/three.js/src/math/Box3.js';
import { Vector3 } from '../../../../third_party/three.js/src/math/Vector3.js';
import { Triangle } from '../../../../third_party/three.js/src/math/Triangle.js';
import { Plane } from '../../../../third_party/three.js/src/math/Plane.js';
import { Sphere } from '../../../../third_party/three.js/src/math/Sphere.js';
import { Matrix4 } from '../../../../third_party/three.js/src/math/Matrix4.js';

const empty = () => new Box3();
const point = () => new Box3( new Vector3( 1, 1, 1 ), new Vector3( 1, 1, 1 ) );
const unit = () => new Box3( new Vector3( 0, 0, 0 ), new Vector3( 1, 1, 1 ) );

// Edge cases run each method on an empty box and on a single-point box.
const edges = ( args ) => [ empty, point ].map( ( self ) => () => ( { self: self(), args: args() } ) );

// A triangle near the unit box, so intersectsTriangle is not almost always false.
const nearTriangle = ( r ) => new Triangle( ...[ 0, 1, 2 ].map( () => new Vector3( r.range( - 1, 2 ), r.range( - 1, 2 ), r.range( - 1, 2 ) ) ) );

export default {
	name: 'Box3',
	type: 'Box3',
	cases: 12,
	methods: [
		{ name: 'set', args: [ 'Vector3', 'Vector3' ] },
		{
			name: 'setFromArray', args: [ ( r ) => Array.from( { length: 3 * ( 1 + Math.floor( r.next() * 5 ) ) }, () => r.num() ) ],
			edge: [ () => ( { self: unit(), args: [ [] ] } ) ]
		},
		{ name: 'setFromCenterAndSize', args: [ 'Vector3', 'Vector3' ] },
		{ name: 'setFromPoints', args: [ ( r ) => Array.from( { length: 1 + r.int( 0, 6 ).value }, () => new Vector3( r.num(), r.num(), r.num() ) ) ] },
		{ name: 'clone' },
		{ name: 'copy', args: [ 'Box3' ] },
		{ name: 'makeEmpty' },
		{ name: 'isEmpty', edge: edges( () => [] ) },
		{ name: 'getCenter', args: [ 'Vector3' ], edge: edges( () => [ new Vector3( 5, 5, 5 ) ] ) },
		{ name: 'getSize', args: [ 'Vector3' ], edge: edges( () => [ new Vector3( 5, 5, 5 ) ] ) },
		{ name: 'expandByPoint', args: [ 'Vector3' ], edge: edges( () => [ new Vector3( 2, - 3, 4 ) ] ) },
		{ name: 'expandByVector', args: [ 'Vector3' ] },
		{ name: 'expandByScalar', args: [ 'num' ], edge: edges( () => [ - 1 ] ) },
		{ name: 'containsPoint', args: [ 'Vector3' ], edge: edges( () => [ new Vector3( 1, 1, 1 ) ] ) },
		{ name: 'containsBox', args: [ 'Box3' ], edge: edges( () => [ new Box3() ] ) },
		{ name: 'getParameter', args: [ 'Vector3', 'Vector3' ], edge: edges( () => [ new Vector3( 1, 1, 1 ), new Vector3() ] ) },
		{ name: 'intersectsBox', args: [ 'Box3' ], edge: edges( () => [ point() ] ) },
		{ name: 'intersectsSphere', args: [ 'Sphere' ], edge: edges( () => [ new Sphere( new Vector3( 1, 1, 2 ), 1 ) ] ) },
		{
			name: 'intersectsPlane', args: [ 'Plane' ],
			edge: [ - 1, 0, - 0.5, 0.5 ].map( ( c ) => () => ( { self: unit(), args: [ new Plane( new Vector3( 0, 1, 0 ), c ) ] } ) )
		},
		{
			name: 'intersectsTriangle', args: [ nearTriangle ], self: unit, cases: 40,
			edge: [
				() => ( { self: empty(), args: [ new Triangle( new Vector3(), new Vector3( 1, 0, 0 ), new Vector3( 0, 1, 0 ) ) ] } ),
				() => ( { self: unit(), args: [ new Triangle( new Vector3( 0.5, 0.5, 0.5 ), new Vector3( 0.5, 0.5, 0.5 ), new Vector3( 0.5, 0.5, 0.5 ) ) ] } ),
				() => ( { self: unit(), args: [ new Triangle( new Vector3( 2, 0, 0 ), new Vector3( 2, 1, 0 ), new Vector3( 2, 0, 1 ) ) ] } )
			]
		},
		{ name: 'clampPoint', args: [ 'Vector3', 'Vector3' ], edge: edges( () => [ new Vector3( 3, 3, 3 ), new Vector3() ] ) },
		{ name: 'distanceToPoint', args: [ 'Vector3' ], edge: edges( () => [ new Vector3( 3, 3, 3 ) ] ) },
		{ name: 'getBoundingSphere', args: [ 'Sphere' ], edge: edges( () => [ new Sphere() ] ) },
		{ name: 'intersect', args: [ 'Box3' ], edge: edges( () => [ new Box3( new Vector3( 5, 5, 5 ), new Vector3( 6, 6, 6 ) ) ] ) },
		{ name: 'union', args: [ 'Box3' ], edge: edges( () => [ new Box3() ] ) },
		{ name: 'applyMatrix4', args: [ 'Matrix4' ], edge: edges( () => [ new Matrix4().makeRotationZ( 1 ) ] ) },
		{ name: 'translate', args: [ 'Vector3' ], edge: edges( () => [ new Vector3( 1, 2, 3 ) ] ) },
		{ name: 'equals', args: [ 'Box3' ], edge: edges( () => [ new Box3() ] ) }
	]
};
