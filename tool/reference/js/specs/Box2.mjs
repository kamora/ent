// Reference cases for src/math/Box2.js.

import { Box2 } from '../../../../third_party/three.js/src/math/Box2.js';
import { Vector2 } from '../../../../third_party/three.js/src/math/Vector2.js';

const empty = () => new Box2();
const point = () => new Box2( new Vector2( 1, 1 ), new Vector2( 1, 1 ) );

// Edge cases run each method on an empty box and on a single-point box.
const edges = ( args ) => [ empty, point ].map( ( self ) => () => ( { self: self(), args: args() } ) );

export default {
	name: 'Box2',
	type: 'Box2',
	cases: 12,
	methods: [
		{ name: 'set', args: [ 'Vector2', 'Vector2' ] },
		{ name: 'setFromCenterAndSize', args: [ 'Vector2', 'Vector2' ] },
		{ name: 'setFromPoints', args: [ ( r ) => Array.from( { length: 1 + r.int( 0, 6 ).value }, () => new Vector2( r.num(), r.num() ) ) ] },
		{ name: 'clone' },
		{ name: 'copy', args: [ 'Box2' ] },
		{ name: 'makeEmpty' },
		{ name: 'isEmpty', edge: edges( () => [] ) },
		{ name: 'getCenter', args: [ 'Vector2' ], edge: edges( () => [ new Vector2( 5, 5 ) ] ) },
		{ name: 'getSize', args: [ 'Vector2' ], edge: edges( () => [ new Vector2( 5, 5 ) ] ) },
		{ name: 'expandByPoint', args: [ 'Vector2' ], edge: edges( () => [ new Vector2( 2, - 3 ) ] ) },
		{ name: 'expandByVector', args: [ 'Vector2' ] },
		{ name: 'expandByScalar', args: [ 'num' ], edge: edges( () => [ - 1 ] ) },
		{ name: 'containsPoint', args: [ 'Vector2' ], edge: edges( () => [ new Vector2( 1, 1 ) ] ) },
		{ name: 'containsBox', args: [ 'Box2' ], edge: edges( () => [ new Box2() ] ) },
		{ name: 'getParameter', args: [ 'Vector2', 'Vector2' ], edge: edges( () => [ new Vector2( 1, 1 ), new Vector2() ] ) },
		{ name: 'intersectsBox', args: [ 'Box2' ], edge: edges( () => [ point() ] ) },
		{ name: 'clampPoint', args: [ 'Vector2', 'Vector2' ], edge: edges( () => [ new Vector2( 3, 3 ), new Vector2() ] ) },
		{ name: 'distanceToPoint', args: [ 'Vector2' ], edge: edges( () => [ new Vector2( 3, 3 ) ] ) },
		{ name: 'intersect', args: [ 'Box2' ], edge: edges( () => [ new Box2( new Vector2( 5, 5 ), new Vector2( 6, 6 ) ) ] ) },
		{ name: 'union', args: [ 'Box2' ], edge: edges( () => [ new Box2() ] ) },
		{ name: 'translate', args: [ 'Vector2' ], edge: edges( () => [ new Vector2( 1, 2 ) ] ) },
		{ name: 'equals', args: [ 'Box2' ], edge: edges( () => [ new Box2() ] ) }
	]
};
