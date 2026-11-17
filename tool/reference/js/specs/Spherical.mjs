// Reference cases for src/math/Spherical.js.

import { Spherical } from '../../../../third_party/three.js/src/math/Spherical.js';
import { Vector3 } from '../../../../third_party/three.js/src/math/Vector3.js';

export default {
	name: 'Spherical',
	type: 'Spherical',
	cases: 15,
	methods: [
		{ name: 'set', args: [ 'num', 'num', 'num' ] },
		{ name: 'copy', args: [ 'Spherical' ] },
		{
			name: 'makeSafe',
			edge: [ 0, Math.PI, - 1, 4, 1.5, 0.0000001 ].map( ( phi ) => () => ( { self: new Spherical( 1, phi, 0 ), args: [] } ) )
		},
		{ name: 'setFromVector3', args: [ 'Vector3' ], edge: [ () => ( { self: new Spherical( 1, 1, 1 ), args: [ new Vector3() ] } ) ] },
		{
			name: 'setFromCartesianCoords', args: [ 'num', 'num', 'num' ],
			edge: [ [ 0, 0, 0 ], [ 0, 5, 0 ], [ 0, - 5, 0 ], [ - 0, 0, - 1 ] ].map( ( args ) => () => ( { self: new Spherical( 1, 1, 1 ), args } ) )
		},
		{ name: 'clone' }
	]
};
