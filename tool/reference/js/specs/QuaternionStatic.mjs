// Reference cases for the static members of src/math/Quaternion.js, which work on flat arrays.

import { Quaternion } from '../../../../third_party/three.js/src/math/Quaternion.js';
import { int } from '../lib/codec.mjs';

const quat = ( r ) => new Quaternion( r.num(), r.num(), r.num(), r.num() ).normalize().toArray();
const flat = ( r ) => [ ...quat( r ), ...quat( r ) ];
const offset = ( r ) => r.int( 0, 4 );

export default {
	name: 'Quaternion',
	fixture: 'QuaternionStatic',
	static: Quaternion,
	cases: 20,
	methods: [
		{
			name: 'slerpFlat', args: [ flat, offset, flat, offset, flat, offset, 'unit' ],
			edge: [ 0, 1 ].map( ( t ) => () => ( { args: [ [ 0, 0, 0, 0 ], int( 0 ), [ 0, 0, 0, 1 ], int( 0 ), [ 0, 1, 0, 0 ], int( 0 ), t ] } ) )
				.concat( [ () => ( { args: [ [ 0, 0, 0, 0 ], int( 0 ), [ 0, 0, 0, 1 ], int( 0 ), [ 0, 0, 0, - 1 ], int( 0 ), 0.5 ] } ) ] )
		},
		{ name: 'multiplyQuaternionsFlat', args: [ flat, offset, flat, offset, flat, offset ] }
	]
};
