// Reference cases for src/math/Vector2.js. Not covered here: random() (Math.random), fromBufferAttribute (M2),
// the iterator, the width/height accessors, and toArray() past the end of an
// array (JS leaves holes, Dart pads with 0.0: unit tests).

import { Vector2 } from '../../../../third_party/three.js/src/math/Vector2.js';
import { Matrix3 } from '../../../../third_party/three.js/src/math/Matrix3.js';
import { int } from '../lib/codec.mjs';

const v = ( x, y ) => new Vector2( x, y );
const zero = ( args ) => () => ( { self: v( 0, 0 ), args: args() } );
const low = ( r ) => v( r.range( - 10, 0 ), r.range( - 10, 0 ) );
const high = ( r ) => v( r.range( 0, 10 ), r.range( 0, 10 ) );
const array = ( r ) => Array.from( { length: 6 }, () => r.num() );

export default {
	name: 'Vector2',
	type: 'Vector2',
	cases: 10,
	methods: [
		{ name: 'set', args: [ 'num', 'num' ] },
		{ name: 'setScalar', args: [ 'num' ] },
		{ name: 'setX', args: [ 'num' ] },
		{ name: 'setY', args: [ 'num' ] },
		{ name: 'setComponent', args: [ ( r ) => r.int( 0, 1 ), 'num' ], edge: [ () => ( { self: v( 1, 2 ), args: [ int( 2 ), 1 ] } ) ] },
		{ name: 'getComponent', args: [ ( r ) => r.int( 0, 1 ) ], edge: [ () => ( { self: v( 1, 2 ), args: [ int( - 1 ) ] } ) ] },
		{ name: 'clone' },
		{ name: 'copy', args: [ 'Vector2' ] },
		{ name: 'add', args: [ 'Vector2' ] },
		{ name: 'addScalar', args: [ 'num' ] },
		{ name: 'addVectors', args: [ 'Vector2', 'Vector2' ] },
		{ name: 'addScaledVector', args: [ 'Vector2', 'num' ] },
		{ name: 'sub', args: [ 'Vector2' ] },
		{ name: 'subScalar', args: [ 'num' ] },
		{ name: 'subVectors', args: [ 'Vector2', 'Vector2' ] },
		{ name: 'multiply', args: [ 'Vector2' ] },
		{ name: 'multiplyScalar', args: [ 'num' ] },
		{ name: 'divide', args: [ 'Vector2' ], edge: [ () => ( { self: v( 1, - 1 ), args: [ v( 0, 0 ) ] } ), () => ( { self: v( 0, 0 ), args: [ v( 0, - 0 ) ] } ) ] },
		{ name: 'divideScalar', args: [ 'num' ], edge: [ () => ( { self: v( 1, - 1 ), args: [ 0 ] } ) ] },
		{ name: 'applyMatrix3', args: [ 'Matrix3' ], edge: [ () => ( { self: v( 2, 3 ), args: [ new Matrix3().set( 2, 3, 5, 7, 11, 13, 17, 19, 23 ) ] } ) ] },
		{ name: 'min', args: [ 'Vector2' ] },
		{ name: 'max', args: [ 'Vector2' ] },
		{ name: 'clamp', args: [ low, high ], edge: [ () => ( { self: v( 5, - 5 ), args: [ v( 1, 1 ), v( 0, 0 ) ] } ) ] },
		{ name: 'clampScalar', args: [ ( r ) => r.range( - 10, 0 ), ( r ) => r.range( 0, 10 ) ] },
		{ name: 'clampLength', args: [ ( r ) => r.range( 0, 5 ), ( r ) => r.range( 5, 15 ) ], edge: [ zero( () => [ 1, 2 ] ), zero( () => [ 0, 0 ] ) ] },
		{ name: 'floor', edge: [ () => ( { self: v( - 0.5, - 0 ), args: [] } ) ] },
		{ name: 'ceil', edge: [ () => ( { self: v( - 0.5, 0.5 ), args: [] } ) ] },
		{
			name: 'round',
			edge: [ () => ( { self: v( 0.5, - 0.5 ), args: [] } ), () => ( { self: v( - 2.5, - 0.4 ), args: [] } ), () => ( { self: v( 1.4999999999999998, 0.49999999999999994 ), args: [] } ) ]
		},
		{ name: 'roundToZero', edge: [ () => ( { self: v( - 0.5, 3.7 ), args: [] } ) ] },
		{ name: 'negate', edge: [ zero( () => [] ) ] },
		{ name: 'dot', args: [ 'Vector2' ] },
		{ name: 'cross', args: [ 'Vector2' ] },
		{ name: 'lengthSq' },
		{ name: 'length' },
		{ name: 'manhattanLength' },
		{ name: 'normalize', edge: [ zero( () => [] ) ] },
		{ name: 'angle', edge: [ zero( () => [] ), () => ( { self: v( 0, - 1 ), args: [] } ), () => ( { self: v( - 1, 0 ), args: [] } ) ] },
		{ name: 'angleTo', args: [ 'Vector2' ], edge: [ zero( () => [ v( 1, 0 ) ] ), () => ( { self: v( 1, 2 ), args: [ v( 2, 4 ) ] } ), () => ( { self: v( 1, 2 ), args: [ v( - 1, - 2 ) ] } ) ] },
		{ name: 'distanceTo', args: [ 'Vector2' ] },
		{ name: 'distanceToSquared', args: [ 'Vector2' ] },
		{ name: 'manhattanDistanceTo', args: [ 'Vector2' ] },
		{ name: 'setLength', args: [ 'num' ], edge: [ zero( () => [ 3 ] ) ] },
		{ name: 'lerp', args: [ 'Vector2', 'unit' ] },
		{ name: 'lerpVectors', args: [ 'Vector2', 'Vector2', 'unit' ] },
		{ name: 'equals', args: [ 'Vector2' ], edge: [ () => ( { self: v( 1, 2 ), args: [ v( 1, 2 ) ] } ), () => ( { self: v( 0, 0 ), args: [ v( - 0, 0 ) ] } ), () => ( { self: v( NaN, 0 ), args: [ v( NaN, 0 ) ] } ) ] },
		{ name: 'fromArray', args: [ array ], label: 'no offset' },
		{ name: 'fromArray', args: [ array, ( r ) => r.int( 0, 4 ) ] },
		{ name: 'toArray', label: 'no array' },
		{ name: 'toArray', args: [ () => [] ], label: 'empty array' },
		{ name: 'toArray', args: [ array, ( r ) => r.int( 0, 4 ) ] },
		{ name: 'rotateAround', args: [ 'Vector2', ( r ) => r.range( - 7, 7 ) ] }
	]
};
