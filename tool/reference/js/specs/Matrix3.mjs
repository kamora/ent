// Reference cases for src/math/Matrix3.js. scale/rotate/translate are deprecated upstream (r185) and log a
// warning; they are still part of the API and covered here. toArray() past the end of an array (JS leaves
// holes, Dart pads with 0.0) is covered by the unit tests.

import { Matrix3 } from '../../../../third_party/three.js/src/math/Matrix3.js';
import { Matrix4 } from '../../../../third_party/three.js/src/math/Matrix4.js';

const singular = () => new Matrix3().set( 1, 2, 3, 2, 4, 6, 7, 8, 9 );
const nine = ( r ) => Array.from( { length: 9 }, () => r.num() );

export default {
	name: 'Matrix3',
	type: 'Matrix3',
	cases: 10,
	methods: [
		{ name: 'set', args: [ 'num', 'num', 'num', 'num', 'num', 'num', 'num', 'num', 'num' ] },
		{ name: 'identity' },
		{ name: 'copy', args: [ 'Matrix3' ] },
		{ name: 'extractBasis', args: [ 'Vector3', 'Vector3', 'Vector3' ] },
		{ name: 'setFromMatrix4', args: [ 'Matrix4' ] },
		{ name: 'multiply', args: [ 'Matrix3' ] },
		{ name: 'premultiply', args: [ 'Matrix3' ] },
		{ name: 'multiplyMatrices', args: [ 'Matrix3', 'Matrix3' ] },
		{ name: 'multiplyScalar', args: [ 'num' ] },
		{ name: 'determinant', edge: [ () => ( { self: singular(), args: [] } ) ] },
		{
			name: 'invert',
			edge: [ () => ( { self: singular(), args: [] } ), () => ( { self: new Matrix3().set( 0, 0, 0, 0, 0, 0, 0, 0, 0 ), args: [] } ), () => ( { self: new Matrix3(), args: [] } ) ]
		},
		{ name: 'transpose' },
		{ name: 'getNormalMatrix', args: [ 'Matrix4' ], edge: [ () => ( { self: new Matrix3(), args: [ new Matrix4().makeScale( 0, 1, 1 ) ] } ) ] },
		{ name: 'transposeIntoArray', args: [ () => [] ], label: 'empty array' },
		{ name: 'transposeIntoArray', args: [ nine ] },
		{ name: 'setUvTransform', args: [ 'num', 'num', 'num', 'num', ( r ) => r.range( - 7, 7 ), 'unit', 'unit' ] },
		{ name: 'scale', args: [ 'num', 'num' ] },
		{ name: 'rotate', args: [ ( r ) => r.range( - 7, 7 ) ] },
		{ name: 'translate', args: [ 'num', 'num' ] },
		{ name: 'makeTranslation', args: [ 'num', 'num' ] },
		{ name: 'makeTranslation', label: 'Vector2', args: [ 'Vector2' ] },
		{ name: 'makeRotation', args: [ ( r ) => r.range( - 7, 7 ) ] },
		{ name: 'makeScale', args: [ 'num', 'num' ] },
		{
			name: 'equals', args: [ 'Matrix3' ],
			edge: [ () => ( { self: new Matrix3().set( 1, 2, 3, 4, 5, 6, 7, 8, 9 ), args: [ new Matrix3().set( 1, 2, 3, 4, 5, 6, 7, 8, 9 ) ] } ), () => ( { self: new Matrix3(), args: [ new Matrix3().set( 1, - 0, 0, 0, 1, 0, 0, 0, 1 ) ] } ) ]
		},
		{ name: 'fromArray', args: [ nine ], label: 'no offset' },
		{ name: 'fromArray', args: [ ( r ) => Array.from( { length: 14 }, () => r.num() ), ( r ) => r.int( 0, 5 ) ] },
		{ name: 'toArray', label: 'no array' },
		{ name: 'toArray', args: [ () => [] ], label: 'empty array' },
		{ name: 'toArray', args: [ ( r ) => Array.from( { length: 12 }, () => r.num() ), ( r ) => r.int( 0, 3 ) ] },
		{ name: 'clone' }
	]
};
