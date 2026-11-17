// Reference cases for src/math/Vector3.js. Not covered here: random() and randomDirection() (Math.random),
// fromBufferAttribute (M2), the iterator.

import { Vector3 } from '../../../../third_party/three.js/src/math/Vector3.js';
import { Matrix4 } from '../../../../third_party/three.js/src/math/Matrix4.js';
import { int } from '../lib/codec.mjs';

const v = ( x, y, z ) => new Vector3( x, y, z );
const unit = ( r ) => new Vector3( r.range( - 1, 1 ), r.range( - 1, 1 ), r.range( - 1, 1 ) ).normalize();
const zero = ( args ) => () => ( { self: v( 0, 0, 0 ), args: args() } );

// min/max for clamp: componentwise min <= max.
const ordered = ( r ) => {

	const a = v( r.num(), r.num(), r.num() );
	const b = v( r.num(), r.num(), r.num() );
	return [ a.clone().min( b ), a.max( b ) ];

};

export default {
	name: 'Vector3',
	type: 'Vector3',
	cases: 10,
	methods: [
		{ name: 'set', args: [ 'num', 'num', 'num' ] },
		{ name: 'set', label: 'z omitted', args: [ 'num', 'num' ] },
		{ name: 'setScalar', args: [ 'num' ] },
		{ name: 'setX', args: [ 'num' ] },
		{ name: 'setY', args: [ 'num' ] },
		{ name: 'setZ', args: [ 'num' ] },
		{ name: 'setComponent', args: [ ( r ) => r.int( 0, 2 ), 'num' ], edge: [ () => ( { self: v( 1, 2, 3 ), args: [ int( 3 ), 1 ] } ) ] },
		{ name: 'getComponent', args: [ ( r ) => r.int( 0, 2 ) ], edge: [ () => ( { self: v( 1, 2, 3 ), args: [ int( - 1 ) ] } ) ] },
		{ name: 'clone' },
		{ name: 'copy', args: [ 'Vector3' ] },
		{ name: 'add', args: [ 'Vector3' ] },
		{ name: 'addScalar', args: [ 'num' ] },
		{ name: 'addVectors', args: [ 'Vector3', 'Vector3' ] },
		{ name: 'addScaledVector', args: [ 'Vector3', 'num' ] },
		{ name: 'addScaledVector', label: 'Vector4', args: [ 'Vector4', 'num' ] },
		{ name: 'sub', args: [ 'Vector3' ] },
		{ name: 'subScalar', args: [ 'num' ] },
		{ name: 'subVectors', args: [ 'Vector3', 'Vector3' ] },
		{ name: 'multiply', args: [ 'Vector3' ] },
		{ name: 'multiplyScalar', args: [ 'num' ] },
		{ name: 'multiplyVectors', args: [ 'Vector3', 'Vector3' ] },
		{ name: 'applyEuler', args: [ 'Euler' ] },
		{ name: 'applyAxisAngle', args: [ unit, ( r ) => r.range( - Math.PI, Math.PI ) ] },
		{ name: 'applyMatrix3', args: [ 'Matrix3' ] },
		{ name: 'applyNormalMatrix', args: [ 'Matrix3' ] },
		{ name: 'applyMatrix4', args: [ 'Matrix4' ], edge: [ () => ( { self: v( 1, 2, 3 ), args: [ new Matrix4().set( 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0 ) ] } ) ] },
		{ name: 'applyQuaternion', args: [ 'Quaternion' ] },
		{ name: 'project', args: [ 'PerspectiveCamera' ] },
		{ name: 'project', label: 'orthographic', args: [ 'OrthographicCamera' ] },
		{ name: 'unproject', args: [ 'PerspectiveCamera' ] },
		{ name: 'unproject', label: 'orthographic', args: [ 'OrthographicCamera' ] },
		{ name: 'transformDirection', args: [ 'Matrix4' ] },
		{ name: 'divide', args: [ 'Vector3' ], edge: [ () => ( { self: v( 1, - 1, 0 ), args: [ v( 0, 0, 0 ) ] } ) ] },
		{ name: 'divideScalar', args: [ 'num' ], edge: [ () => ( { self: v( 1, - 1, 0 ), args: [ 0 ] } ) ] },
		{ name: 'min', args: [ 'Vector3' ] },
		{ name: 'max', args: [ 'Vector3' ] },
		{ name: 'clamp', args: [ ( r ) => ordered( r )[ 0 ], ( r ) => ordered( r )[ 1 ] ] },
		{ name: 'clampScalar', args: [ ( r ) => r.range( - 10, 0 ), ( r ) => r.range( 0, 10 ) ] },
		{
			name: 'clampLength', args: [ ( r ) => r.range( 0, 5 ), ( r ) => r.range( 5, 20 ) ],
			edge: [ zero( () => [ 1, 2 ] ), zero( () => [ 0, 0 ] ) ]
		},
		{ name: 'floor' },
		{ name: 'ceil' },
		{
			name: 'round',
			edge: [ () => ( { self: v( 0.5, - 0.5, 2.5 ), args: [] } ), () => ( { self: v( - 2.5, - 0.4, 1.4999999999999998 ), args: [] } ) ]
		},
		{ name: 'roundToZero', edge: [ () => ( { self: v( - 0.5, 0.5, - 3.7 ), args: [] } ) ] },
		{ name: 'negate', edge: [ zero( () => [] ) ] },
		{ name: 'dot', args: [ 'Vector3' ] },
		{ name: 'lengthSq' },
		{ name: 'length' },
		{ name: 'manhattanLength' },
		{ name: 'normalize', edge: [ zero( () => [] ) ] },
		{ name: 'setLength', args: [ 'num' ], edge: [ zero( () => [ 3 ] ) ] },
		{ name: 'lerp', args: [ 'Vector3', 'unit' ] },
		{ name: 'lerpVectors', args: [ 'Vector3', 'Vector3', 'unit' ] },
		{ name: 'cross', args: [ 'Vector3' ] },
		{ name: 'crossVectors', args: [ 'Vector3', 'Vector3' ] },
		{ name: 'projectOnVector', args: [ 'Vector3' ], edge: [ () => ( { self: v( 1, 2, 3 ), args: [ v( 0, 0, 0 ) ] } ) ] },
		{ name: 'projectOnPlane', args: [ unit ] },
		{ name: 'reflect', args: [ unit ] },
		{
			name: 'angleTo', args: [ 'Vector3' ],
			edge: [ zero( () => [ v( 1, 0, 0 ) ] ), () => ( { self: v( 1, 2, 3 ), args: [ v( 2, 4, 6 ) ] } ), () => ( { self: v( 1, 2, 3 ), args: [ v( - 1, - 2, - 3 ) ] } ) ]
		},
		{ name: 'distanceTo', args: [ 'Vector3' ] },
		{ name: 'distanceToSquared', args: [ 'Vector3' ] },
		{ name: 'manhattanDistanceTo', args: [ 'Vector3' ] },
		{ name: 'setFromSpherical', args: [ 'Spherical' ] },
		{ name: 'setFromSphericalCoords', args: [ 'num', 'num', 'num' ] },
		{ name: 'setFromCylindrical', args: [ 'Cylindrical' ] },
		{ name: 'setFromCylindricalCoords', args: [ 'num', 'num', 'num' ] },
		{ name: 'setFromMatrixPosition', args: [ 'Matrix4' ] },
		{ name: 'setFromMatrixScale', args: [ 'Matrix4' ] },
		{ name: 'setFromMatrixColumn', args: [ 'Matrix4', ( r ) => r.int( 0, 3 ) ] },
		{ name: 'setFromMatrix3Column', args: [ 'Matrix3', ( r ) => r.int( 0, 2 ) ] },
		{ name: 'setFromEuler', args: [ 'Euler' ] },
		{ name: 'setFromColor', args: [ 'Color' ] },
		{
			name: 'equals', args: [ 'Vector3' ],
			edge: [ () => ( { self: v( 1, 2, 3 ), args: [ v( 1, 2, 3 ) ] } ), () => ( { self: v( 0, 0, 0 ), args: [ v( - 0, 0, - 0 ) ] } ), () => ( { self: v( NaN, 0, 0 ), args: [ v( NaN, 0, 0 ) ] } ) ]
		},
		{ name: 'fromArray', args: [ ( r ) => Array.from( { length: 3 }, () => r.num() ) ] },
		{ name: 'fromArray', label: 'offset', args: [ ( r ) => Array.from( { length: 8 }, () => r.num() ), ( r ) => r.int( 0, 5 ) ] },
		{ name: 'toArray' },
		{ name: 'toArray', label: 'array, offset', args: [ ( r ) => Array.from( { length: 8 }, () => r.num() ), ( r ) => r.int( 0, 5 ) ] },
		{ name: 'toArray', label: 'growing array', args: [ () => [], ( r ) => r.int( 0, 0 ) ] }
	]
};
