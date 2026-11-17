// Reference cases for src/math/Line3.js.

import { Line3 } from '../../../../third_party/three.js/src/math/Line3.js';
import { Vector3 } from '../../../../third_party/three.js/src/math/Vector3.js';

const v = ( x, y, z ) => new Vector3( x, y, z );
const line = ( a, b ) => new Line3( v( ...a ), v( ...b ) );
const degenerate = () => line( [ 1, 1, 1 ], [ 1, 1, 1 ] );

// Pairs of segments for distanceSqToLine3: crossing, parallel, clamped on one side, both, skew, points.
const pairs = [
	[ [ 0, 0, 0 ], [ 2, 0, 0 ], [ 1, 10, 0 ], [ 1, - 2, 0 ] ],
	[ [ 0, 0, 0 ], [ 2, 0, 0 ], [ - 2, 0, 2 ], [ 20, 0, 2 ] ],
	[ [ 0, 4, 0 ], [ 2, 2, 0 ], [ 0, 0, 0 ], [ 4, 0, 0 ] ],
	[ [ 0, 4, 0 ], [ 3, 1, 0 ], [ 0, 0, 0 ], [ 1, 0, 0 ] ],
	[ [ 0, 4, 0 ], [ 2, 2, 0 ], [ 0, 0, 0 ], [ 1, 0, 0 ] ],
	[ [ 4, 0, 0 ], [ - 4, 0, 0 ], [ 0, 4, 0 ], [ 0, 0, 4 ] ],
	[ [ 1, 1, 1 ], [ 1, 1, 1 ], [ 2, 2, 2 ], [ 2, 2, 2 ] ],
	[ [ 1, 1, 1 ], [ 1, 1, 1 ], [ 0, 0, 0 ], [ 4, 0, 0 ] ],
	[ [ 0, 0, 0 ], [ 4, 0, 0 ], [ 1, 1, 1 ], [ 1, 1, 1 ] ]
];

export default {
	name: 'Line3',
	type: 'Line3',
	cases: 12,
	methods: [
		{ name: 'set', args: [ 'Vector3', 'Vector3' ] },
		{ name: 'copy', args: [ 'Line3' ] },
		{ name: 'getCenter', args: [ 'Vector3' ] },
		{ name: 'delta', args: [ 'Vector3' ] },
		{ name: 'distanceSq' },
		{ name: 'distance' },
		{ name: 'at', args: [ ( r ) => r.range( - 2, 3 ), 'Vector3' ] },
		{
			name: 'closestPointToPointParameter', args: [ 'Vector3', 'bool' ],
			edge: [ true, false ].map( ( c ) => () => ( { self: degenerate(), args: [ v( 0, 0, 0 ), c ] } ) )
		},
		{
			name: 'closestPointToPoint', args: [ 'Vector3', 'bool', 'Vector3' ],
			edge: [ true, false ].map( ( c ) => () => ( { self: degenerate(), args: [ v( 0, 0, 0 ), c, v() ] } ) )
		},
		{
			name: 'distanceSqToLine3', label: 'default targets', args: [ 'Line3' ],
			edge: pairs.map( ( [ a, b, c, d ] ) => () => ( { self: line( a, b ), args: [ line( c, d ) ] } ) )
		},
		{
			name: 'distanceSqToLine3', label: 'given targets', args: [ 'Line3', 'Vector3', 'Vector3' ],
			edge: pairs.map( ( [ a, b, c, d ] ) => () => ( { self: line( a, b ), args: [ line( c, d ), v(), v() ] } ) )
		},
		{ name: 'applyMatrix4', args: [ 'Matrix4' ] },
		{ name: 'equals', args: [ 'Line3' ], edge: [ () => ( { self: degenerate(), args: [ degenerate() ] } ) ] },
		{ name: 'clone' }
	]
};
