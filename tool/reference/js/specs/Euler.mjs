// Reference cases for src/math/Euler.js.

import { Euler } from '../../../../third_party/three.js/src/math/Euler.js';
import { Matrix4 } from '../../../../third_party/three.js/src/math/Matrix4.js';

const ORDERS = [ 'XYZ', 'YXZ', 'ZXY', 'ZYX', 'YZX', 'XZY' ];
const order = ( r ) => r.pick( ORDERS );
const angle = ( r ) => r.range( - Math.PI, Math.PI );
const rotation = ( r ) => new Matrix4().makeRotationFromEuler( new Euler( angle( r ), angle( r ), angle( r ), order( r ) ) );

// For each order, the middle rotation at ±90° puts the matrix into the gimbal-lock branch.
const MIDDLE = { XYZ: 1, YXZ: 0, ZXY: 0, ZYX: 1, YZX: 2, XZY: 2 };
const gimbal = ORDERS.flatMap( ( o ) => [ 1, - 1 ].map( ( sign ) => () => {

	const angles = [ 0.3, - 0.4, 0.5 ];
	angles[ MIDDLE[ o ] ] = sign * Math.PI / 2;
	return { self: new Euler(), args: [ new Matrix4().makeRotationFromEuler( new Euler( ...angles, o ) ), o ] };

} ) );

export default {
	name: 'Euler',
	type: 'Euler',
	cases: 12,
	methods: [
		{ name: 'set', args: [ 'num', 'num', 'num' ] },
		{ name: 'set', label: 'order', args: [ 'num', 'num', 'num', order ] },
		{ name: 'clone' },
		{ name: 'copy', args: [ 'Euler' ] },
		{ name: 'setFromRotationMatrix', args: [ rotation ] },
		{
			name: 'setFromRotationMatrix', label: 'order', args: [ rotation, order ],
			edge: [ ...gimbal, () => ( { self: new Euler( 1, 2, 3 ), args: [ new Matrix4(), 'ABC' ] } ) ]
		},
		{ name: 'setFromRotationMatrix', label: 'update', args: [ rotation, order, 'bool' ] },
		{ name: 'setFromRotationMatrix', label: 'any matrix', args: [ 'Matrix4', order ] },
		{ name: 'setFromQuaternion', args: [ 'Quaternion' ] },
		{ name: 'setFromQuaternion', label: 'order', args: [ 'Quaternion', order ] },
		{ name: 'setFromVector3', args: [ 'Vector3' ] },
		{ name: 'setFromVector3', label: 'order', args: [ 'Vector3', order ] },
		{ name: 'reorder', args: [ order ] },
		{
			name: 'equals', args: [ 'Euler' ],
			edge: [
				() => ( { self: new Euler( 1, 2, 3, 'ZXY' ), args: [ new Euler( 1, 2, 3, 'ZXY' ) ] } ),
				() => ( { self: new Euler( 1, 2, 3, 'ZXY' ), args: [ new Euler( 1, 2, 3, 'XYZ' ) ] } )
			]
		},
		{ name: 'fromArray', args: [ ( r ) => [ r.num(), r.num(), r.num() ] ] },
		{ name: 'fromArray', label: 'order', args: [ ( r ) => [ r.num(), r.num(), r.num(), order( r ) ] ] },
		{ name: 'toArray' }
	]
};
