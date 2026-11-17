// Reference cases for src/core/BufferAttribute.js on every typed array kind (normalized or not): the
// conversions of a JS typed-array store, normalization, and the matrix helpers. toJSON returns a plain
// object and onUpload/dispose take callbacks or fire events; the ported unit tests cover them.

import { attribute } from '../types/buffers.mjs';
import { int } from '../lib/codec.mjs';

const { BufferAttribute } = await import( '../../../../third_party/three.js/src/core/BufferAttribute.js' );

const index = ( r ) => r.int( 0, 3 );
const value = ( r ) => r.next() < 0.3 ? r.unit() : r.num();
const list = ( r, length ) => Array.from( { length }, () => value( r ) );

export default {
	name: 'BufferAttribute',
	type: 'BufferAttribute',
	cases: 16,
	methods: [
		{ name: 'setUsage', args: [ ( r ) => r.int( 35044, 35050 ) ] },
		{ name: 'copy', args: [ 'BufferAttribute' ] },
		{ name: 'copyAt', args: [ index, 'BufferAttribute', index ] },
		{ name: 'copyArray', args: [ ( r ) => list( r, 16 ) ] },
		{
			name: 'set', args: [ ( r ) => list( r, r.int( 0, 8 ).value ), ( r ) => r.int( 0, 14 ) ],
			edge: [ () => ( { self: new BufferAttribute( new Float32Array( 4 ), 2 ), args: [ [ 1, 2, 3 ], int( 2 ) ] } ) ]
		},
		{ name: 'applyMatrix3', label: 'itemSize 2', self: ( r ) => attribute( r, 2 ), args: [ 'Matrix3' ] },
		{ name: 'applyMatrix3', label: 'itemSize 3', self: ( r ) => attribute( r, 3 ), args: [ 'Matrix3' ] },
		{ name: 'applyMatrix3', label: 'itemSize 4 (unchanged)', args: [ 'Matrix3' ] },
		{ name: 'applyMatrix4', self: ( r ) => attribute( r, 3 ), args: [ 'Matrix4' ] },
		{ name: 'applyNormalMatrix', self: ( r ) => attribute( r, 3 ), args: [ 'Matrix3' ] },
		{ name: 'transformDirection', self: ( r ) => attribute( r, 3 ), args: [ 'Matrix4' ] },
		{
			name: 'getComponent', args: [ index, index ],
			edge: [ () => ( { self: new BufferAttribute( new Float64Array( 4 ), 1, true ), args: [ int( 0 ), int( 0 ) ] } ) ]
		},
		{ name: 'setComponent', args: [ index, index, value ] },
		{ name: 'getX', args: [ index ] },
		{ name: 'getY', args: [ index ] },
		{ name: 'getZ', args: [ index ] },
		{ name: 'getW', args: [ index ] },
		{
			name: 'setX', args: [ index, value ],
			edge: [ NaN, Infinity, - Infinity, 2 ** 40, - 0.5, 0.5, 1.5, 2.5, 255.5 ].flatMap( ( v ) => [ Int8Array, Uint8ClampedArray, Uint32Array ].map(
				( T ) => () => ( { self: new BufferAttribute( new T( 4 ), 1 ), args: [ int( 1 ), v ] } )
			) )
		},
		{ name: 'setY', args: [ index, value ] },
		{ name: 'setZ', args: [ index, value ] },
		{ name: 'setW', args: [ index, value ] },
		{ name: 'setXY', args: [ index, value, value ] },
		{ name: 'setXYZ', args: [ index, value, value, value ] },
		{ name: 'setXYZW', args: [ index, value, value, value, value ] },
		{ name: 'clone', args: [] }
	]
};
