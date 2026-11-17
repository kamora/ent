// Reference cases for src/math/Cylindrical.js.

import { Cylindrical } from '../../../../third_party/three.js/src/math/Cylindrical.js';
import { Vector3 } from '../../../../third_party/three.js/src/math/Vector3.js';

export default {
	name: 'Cylindrical',
	type: 'Cylindrical',
	cases: 15,
	methods: [
		{ name: 'set', args: [ 'num', 'num', 'num' ] },
		{ name: 'copy', args: [ 'Cylindrical' ] },
		{ name: 'setFromVector3', args: [ 'Vector3' ], edge: [ () => ( { self: new Cylindrical( 1, 1, 1 ), args: [ new Vector3() ] } ) ] },
		{
			name: 'setFromCartesianCoords', args: [ 'num', 'num', 'num' ],
			edge: [ [ 0, 0, 0 ], [ - 0, 3, - 1 ], [ 0, 1, - 0 ] ].map( ( args ) => () => ( { self: new Cylindrical( 1, 1, 1 ), args } ) )
		},
		{ name: 'clone' }
	]
};
