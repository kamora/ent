// Reference cases for src/math/Sphere.js. toJSON returns a plain object; the ported unit tests cover it.

import { Sphere } from '../../../../third_party/three.js/src/math/Sphere.js';
import { Vector3 } from '../../../../third_party/three.js/src/math/Vector3.js';

const points = ( r ) => Array.from( { length: 1 + r.int( 0, 6 ).value }, () => new Vector3( r.num(), r.num(), r.num() ) );
import { Box3 } from '../../../../third_party/three.js/src/math/Box3.js';
import { Plane } from '../../../../third_party/three.js/src/math/Plane.js';
import { Matrix4 } from '../../../../third_party/three.js/src/math/Matrix4.js';

const empty = () => new Sphere();
const point = () => new Sphere( new Vector3( 1, 2, 3 ), 0 );

// Edge cases run each method on an empty sphere (radius -1) and on a zero-radius sphere.
const edges = ( args ) => [ empty, point ].map( ( self ) => () => ( { self: self(), args: args() } ) );

export default {
	name: 'Sphere',
	type: 'Sphere',
	cases: 12,
	methods: [
		{ name: 'set', args: [ 'Vector3', 'num' ] },
		{ name: 'setFromPoints', args: [ points ] },
		{ name: 'setFromPoints', label: 'with center', args: [ points, 'Vector3' ] },
		{ name: 'copy', args: [ 'Sphere' ] },
		{ name: 'isEmpty', edge: edges( () => [] ) },
		{ name: 'makeEmpty' },
		{ name: 'containsPoint', args: [ 'Vector3' ], edge: edges( () => [ new Vector3( 1, 2, 3 ) ] ) },
		{ name: 'distanceToPoint', args: [ 'Vector3' ], edge: edges( () => [ new Vector3( 1, 2, 3 ) ] ) },
		{ name: 'intersectsSphere', args: [ 'Sphere' ], edge: edges( () => [ new Sphere( new Vector3( 1, 2, 4 ), 1 ) ] ) },
		{ name: 'intersectsBox', args: [ 'Box3' ], edge: edges( () => [ new Box3() ] ) },
		{ name: 'intersectsPlane', args: [ 'Plane' ], edge: edges( () => [ new Plane( new Vector3( 1, 0, 0 ), - 1 ) ] ) },
		{
			name: 'clampPoint', args: [ 'Vector3', 'Vector3' ],
			edge: edges( () => [ new Vector3( 5, 5, 5 ), new Vector3() ] ).concat( [ () => ( { self: new Sphere( new Vector3(), 1 ), args: [ new Vector3(), new Vector3() ] } ) ] )
		},
		{ name: 'getBoundingBox', args: [ 'Box3' ], edge: edges( () => [ new Box3() ] ) },
		{ name: 'applyMatrix4', args: [ 'Matrix4' ], edge: edges( () => [ new Matrix4().makeScale( 2, 3, 4 ) ] ) },
		{ name: 'translate', args: [ 'Vector3' ] },
		{
			name: 'expandByPoint', args: [ 'Vector3' ],
			edge: edges( () => [ new Vector3( 4, 5, 6 ) ] ).concat( [ () => ( { self: new Sphere( new Vector3(), 2 ), args: [ new Vector3( 1, 0, 0 ) ] } ) ] )
		},
		{
			name: 'union', args: [ 'Sphere' ],
			edge: [
				() => ( { self: empty(), args: [ new Sphere( new Vector3( 1, 1, 1 ), 2 ) ] } ),
				() => ( { self: new Sphere( new Vector3( 1, 1, 1 ), 2 ), args: [ empty() ] } ),
				() => ( { self: new Sphere( new Vector3( 1, 1, 1 ), 2 ), args: [ new Sphere( new Vector3( 1, 1, 1 ), 3 ) ] } ),
				() => ( { self: new Sphere( new Vector3(), 1 ), args: [ new Sphere( new Vector3( 1, 0, 0 ), 4 ) ] } )
			]
		},
		{ name: 'equals', args: [ 'Sphere' ], edge: edges( () => [ empty() ] ) },
		{ name: 'clone' }
	]
};
