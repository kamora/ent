// Reference cases for src/math/SphericalHarmonics3.js (instance members; getBasisAt is in
// SphericalHarmonics3Static.mjs).

import { SphericalHarmonics3 } from '../../../../third_party/three.js/src/math/SphericalHarmonics3.js';
import { Vector3 } from '../../../../third_party/three.js/src/math/Vector3.js';

const unit = ( r ) => new Vector3( r.range( - 1, 1 ), r.range( - 1, 1 ), r.range( - 1, 1 ) ).normalize();
const vectors = ( r ) => Array.from( { length: 9 }, () => new Vector3( r.num(), r.num(), r.num() ) );
const numbers = ( n ) => ( r ) => Array.from( { length: n }, () => r.num() );

export default {
	name: 'SphericalHarmonics3',
	type: 'SphericalHarmonics3',
	cases: 10,
	methods: [
		{ name: 'set', args: [ vectors ] },
		{ name: 'zero' },
		{ name: 'getAt', args: [ unit, 'Vector3' ] },
		{ name: 'getIrradianceAt', args: [ unit, 'Vector3' ] },
		{ name: 'add', args: [ 'SphericalHarmonics3' ] },
		{ name: 'addScaledSH', args: [ 'SphericalHarmonics3', 'num' ] },
		{ name: 'scale', args: [ 'num' ] },
		{ name: 'lerp', args: [ 'SphericalHarmonics3', 'unit' ] },
		{
			name: 'equals', args: [ 'SphericalHarmonics3' ],
			edge: [ () => {

				const a = new SphericalHarmonics3().set( vectors( { num: () => 1 } ) );
				return { self: a, args: [ a.clone() ] };

			} ]
		},
		{ name: 'copy', args: [ 'SphericalHarmonics3' ] },
		{ name: 'clone' },
		{ name: 'fromArray', args: [ numbers( 27 ) ], label: 'no offset' },
		{ name: 'fromArray', args: [ numbers( 30 ), ( r ) => r.int( 0, 3 ) ] },
		{ name: 'toArray', label: 'new array' },
		{ name: 'toArray', args: [ numbers( 30 ), ( r ) => r.int( 0, 3 ) ] }
	]
};
