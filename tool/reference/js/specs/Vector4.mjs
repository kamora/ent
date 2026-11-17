// Reference cases for src/math/Vector4.js. Not covered here: random() (Math.random), fromBufferAttribute (M2),
// the iterator, the width/height accessors, and toArray() past the end of an
// array (JS leaves holes, Dart pads with 0.0: unit tests).

import { Vector3 } from '../../../../third_party/three.js/src/math/Vector3.js';
import { Vector4 } from '../../../../third_party/three.js/src/math/Vector4.js';
import { Matrix4 } from '../../../../third_party/three.js/src/math/Matrix4.js';
import { Quaternion } from '../../../../third_party/three.js/src/math/Quaternion.js';
import { int } from '../lib/codec.mjs';

const v = ( x, y, z, w ) => new Vector4( x, y, z, w );
const zero = ( args ) => () => ( { self: v( 0, 0, 0, 0 ), args: args() } );
const low = ( r ) => v( r.range( - 10, 0 ), r.range( - 10, 0 ), r.range( - 10, 0 ), r.range( - 10, 0 ) );
const high = ( r ) => v( r.range( 0, 10 ), r.range( 0, 10 ), r.range( 0, 10 ), r.range( 0, 10 ) );
const array = ( r ) => Array.from( { length: 8 }, () => r.num() );
const unit3 = ( r ) => new Vector3( r.range( - 1, 1 ), r.range( - 1, 1 ), r.range( - 1, 1 ) ).normalize();
const rotation = ( r ) => new Matrix4().makeRotationAxis( unit3( r ), r.range( - Math.PI, Math.PI ) );
const diagonal = ( x, y, z ) => () => ( { self: v( 9, 9, 9, 9 ), args: [ new Matrix4().makeScale( x, y, z ) ] } );

export default {
	name: 'Vector4',
	type: 'Vector4',
	cases: 10,
	methods: [
		{ name: 'set', args: [ 'num', 'num', 'num', 'num' ] },
		{ name: 'setScalar', args: [ 'num' ] },
		{ name: 'setX', args: [ 'num' ] },
		{ name: 'setY', args: [ 'num' ] },
		{ name: 'setZ', args: [ 'num' ] },
		{ name: 'setW', args: [ 'num' ] },
		{ name: 'setComponent', args: [ ( r ) => r.int( 0, 3 ), 'num' ], edge: [ () => ( { self: v( 1, 2, 3, 4 ), args: [ int( 4 ), 1 ] } ) ] },
		{ name: 'getComponent', args: [ ( r ) => r.int( 0, 3 ) ], edge: [ () => ( { self: v( 1, 2, 3, 4 ), args: [ int( - 1 ) ] } ) ] },
		{ name: 'clone' },
		{ name: 'copy', args: [ 'Vector4' ] },
		{ name: 'copy', label: 'from Vector3', args: [ 'Vector3' ] },
		{ name: 'add', args: [ 'Vector4' ] },
		{ name: 'addScalar', args: [ 'num' ] },
		{ name: 'addVectors', args: [ 'Vector4', 'Vector4' ] },
		{ name: 'addScaledVector', args: [ 'Vector4', 'num' ] },
		{ name: 'sub', args: [ 'Vector4' ] },
		{ name: 'subScalar', args: [ 'num' ] },
		{ name: 'subVectors', args: [ 'Vector4', 'Vector4' ] },
		{ name: 'multiply', args: [ 'Vector4' ] },
		{ name: 'multiplyScalar', args: [ 'num' ] },
		{ name: 'applyMatrix4', args: [ 'Matrix4' ] },
		{ name: 'divide', args: [ 'Vector4' ], edge: [ () => ( { self: v( 1, - 1, 0, 2 ), args: [ v( 0, 0, 0, - 0 ) ] } ) ] },
		{ name: 'divideScalar', args: [ 'num' ], edge: [ () => ( { self: v( 1, - 1, 0, 2 ), args: [ 0 ] } ) ] },
		{
			name: 'setAxisAngleFromQuaternion',
			args: [ ( r ) => new Quaternion().setFromAxisAngle( unit3( r ), r.range( - Math.PI, Math.PI ) ) ],
			edge: [ () => ( { self: v( 9, 9, 9, 9 ), args: [ new Quaternion() ] } ), () => ( { self: v( 9, 9, 9, 9 ), args: [ new Quaternion( 0, 0, 0.00005, 0.9999999987 ) ] } ) ]
		},
		{
			name: 'setAxisAngleFromRotationMatrix',
			args: [ rotation ],
			edge: [
				() => ( { self: v( 9, 9, 9, 9 ), args: [ new Matrix4() ] } ),
				() => ( { self: v( 9, 9, 9, 9 ), args: [ new Matrix4().makeRotationX( Math.PI ) ] } ),
				() => ( { self: v( 9, 9, 9, 9 ), args: [ new Matrix4().makeRotationY( Math.PI ) ] } ),
				() => ( { self: v( 9, 9, 9, 9 ), args: [ new Matrix4().makeRotationZ( Math.PI ) ] } ),
				() => ( { self: v( 9, 9, 9, 9 ), args: [ new Matrix4().makeRotationAxis( new Vector3( 0, 1, 1 ).normalize(), Math.PI ) ] } ),
				() => ( { self: v( 9, 9, 9, 9 ), args: [ new Matrix4().makeRotationAxis( new Vector3( 1, 1, 0 ).normalize(), Math.PI ) ] } ),
				diagonal( - 1, - 1, - 1 ),
				diagonal( - 0.99, - 1, - 1 ),
				diagonal( - 1, - 0.99, - 1 ),
				diagonal( 1, 1, 1.05 )
			]
		},
		{ name: 'setFromMatrixPosition', args: [ 'Matrix4' ] },
		{ name: 'min', args: [ 'Vector4' ] },
		{ name: 'max', args: [ 'Vector4' ] },
		{ name: 'clamp', args: [ low, high ] },
		{ name: 'clampScalar', args: [ ( r ) => r.range( - 10, 0 ), ( r ) => r.range( 0, 10 ) ] },
		{ name: 'clampLength', args: [ ( r ) => r.range( 0, 5 ), ( r ) => r.range( 5, 15 ) ], edge: [ zero( () => [ 1, 2 ] ) ] },
		{ name: 'floor', edge: [ () => ( { self: v( - 0.5, - 0, 0.5, 2 ), args: [] } ) ] },
		{ name: 'ceil', edge: [ () => ( { self: v( - 0.5, - 0, 0.5, 2 ), args: [] } ) ] },
		{ name: 'round', edge: [ () => ( { self: v( 0.5, - 0.5, - 2.5, 0.49999999999999994 ), args: [] } ) ] },
		{ name: 'roundToZero', edge: [ () => ( { self: v( - 0.5, 3.7, - 3.7, 0 ), args: [] } ) ] },
		{ name: 'negate', edge: [ zero( () => [] ) ] },
		{ name: 'dot', args: [ 'Vector4' ] },
		{ name: 'lengthSq' },
		{ name: 'length' },
		{ name: 'manhattanLength' },
		{ name: 'normalize', edge: [ zero( () => [] ) ] },
		{ name: 'setLength', args: [ 'num' ], edge: [ zero( () => [ 3 ] ) ] },
		{ name: 'lerp', args: [ 'Vector4', 'unit' ] },
		{ name: 'lerpVectors', args: [ 'Vector4', 'Vector4', 'unit' ] },
		{ name: 'equals', args: [ 'Vector4' ], edge: [ () => ( { self: v( 1, 2, 3, 4 ), args: [ v( 1, 2, 3, 4 ) ] } ), () => ( { self: v( 0, 0, 0, 0 ), args: [ v( - 0, 0, 0, 0 ) ] } ) ] },
		{ name: 'fromArray', args: [ array ], label: 'no offset' },
		{ name: 'fromArray', args: [ array, ( r ) => r.int( 0, 4 ) ] },
		{ name: 'toArray', label: 'no array' },
		{ name: 'toArray', args: [ () => [] ], label: 'empty array' },
		{ name: 'toArray', args: [ array, ( r ) => r.int( 0, 4 ) ] }
	]
};
