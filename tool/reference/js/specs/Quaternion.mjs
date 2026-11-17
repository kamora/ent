// Reference cases for src/math/Quaternion.js (instance methods). random() uses Math.random() and
// fromBufferAttribute() needs BufferAttribute (M2); the statics slerpFlat and multiplyQuaternionsFlat are
// checked in test/math/quaternion_test.dart, since a static spec named Quaternion would overwrite this fixture.

import { Quaternion } from '../../../../third_party/three.js/src/math/Quaternion.js';
import { Vector3 } from '../../../../third_party/three.js/src/math/Vector3.js';
import { Matrix4 } from '../../../../third_party/three.js/src/math/Matrix4.js';
import { Euler } from '../../../../third_party/three.js/src/math/Euler.js';

const ORDERS = [ 'XYZ', 'YXZ', 'ZXY', 'ZYX', 'YZX', 'XZY' ];
const unit = ( r ) => new Vector3( r.range( - 1, 1 ), r.range( - 1, 1 ), r.range( - 1, 1 ) ).normalize();
const euler = ( r ) => new Euler( r.range( - Math.PI, Math.PI ), r.range( - Math.PI, Math.PI ), r.range( - Math.PI, Math.PI ), r.pick( ORDERS ) );
const rotation = ( r ) => new Matrix4().makeRotationFromEuler( euler( r ) );
const unitQ = ( r ) => new Quaternion().setFromAxisAngle( unit( r ), r.range( - Math.PI, Math.PI ) );
const D = Math.SQRT1_2;

export default {
	name: 'Quaternion',
	type: 'Quaternion',
	cases: 12,
	methods: [
		{ name: 'set', args: [ 'num', 'num', 'num', 'num' ] },
		{ name: 'clone' },
		{ name: 'copy', args: [ 'Quaternion' ] },
		{
			name: 'setFromEuler', args: [ euler ],
			edge: [ () => ( { self: new Quaternion(), args: [ new Euler( 1, 2, 3, 'ABC' ) ] } ) ]
		},
		{ name: 'setFromEuler', label: 'update', args: [ euler, 'bool' ] },
		{ name: 'setFromAxisAngle', args: [ unit, 'num' ] },
		{
			name: 'setFromRotationMatrix', args: [ rotation ],
			edge: [
				() => ( { self: new Quaternion(), args: [ new Matrix4().makeRotationX( Math.PI ) ] } ),
				() => ( { self: new Quaternion(), args: [ new Matrix4().makeRotationY( Math.PI ) ] } ),
				() => ( { self: new Quaternion(), args: [ new Matrix4().makeRotationZ( Math.PI ) ] } ),
				() => ( { self: new Quaternion(), args: [ new Matrix4() ] } )
			]
		},
		{ name: 'setFromRotationMatrix', label: 'any matrix', args: [ 'Matrix4' ] },
		{
			name: 'setFromUnitVectors', args: [ unit, unit ],
			edge: [
				() => ( { self: new Quaternion(), args: [ new Vector3( 1, 0, 0 ), new Vector3( - 1, 0, 0 ) ] } ),
				() => ( { self: new Quaternion(), args: [ new Vector3( 0, 0, 1 ), new Vector3( 0, 0, - 1 ) ] } ),
				() => ( { self: new Quaternion(), args: [ new Vector3( 0, 1, 0 ), new Vector3( 0, - 1, 0 ) ] } ),
				() => ( { self: new Quaternion(), args: [ new Vector3( 0, 1, 0 ), new Vector3( 0, 1, 0 ) ] } )
			]
		},
		{ name: 'angleTo', args: [ 'Quaternion' ], edge: [ () => ( { self: new Quaternion(), args: [ new Quaternion() ] } ) ] },
		{
			name: 'rotateTowards', self: unitQ, args: [ unitQ, ( r ) => r.range( 0, 4 ) ],
			edge: [ () => ( { self: new Quaternion(), args: [ new Quaternion(), 1 ] } ) ]
		},
		{ name: 'identity' },
		{ name: 'invert' },
		{ name: 'conjugate' },
		{ name: 'dot', args: [ 'Quaternion' ] },
		{ name: 'lengthSq' },
		{ name: 'length' },
		{ name: 'normalize', edge: [ () => ( { self: new Quaternion( 0, 0, 0, 0 ) } ) ] },
		{ name: 'multiply', args: [ 'Quaternion' ] },
		{ name: 'premultiply', args: [ 'Quaternion' ] },
		{ name: 'multiplyQuaternions', args: [ 'Quaternion', 'Quaternion' ] },
		{
			name: 'slerp', self: unitQ, args: [ unitQ, ( r ) => r.range( - 0.5, 1.5 ) ],
			edge: [
				() => ( { self: new Quaternion( 0.1, 0.2, 0.3, 0.9 ).normalize(), args: [ new Quaternion( 0.4, 0.1, - 0.3, 0.7 ).normalize(), 0 ] } ),
				() => ( { self: new Quaternion( 0.1, 0.2, 0.3, 0.9 ).normalize(), args: [ new Quaternion( 0.4, 0.1, - 0.3, 0.7 ).normalize(), 1 ] } ),
				() => ( { self: new Quaternion( 0.1, 0.2, 0.3, 0.9 ).normalize(), args: [ new Quaternion( 0.1, 0.2, 0.3, 0.9 ).normalize(), 0.5 ] } ),
				() => ( { self: new Quaternion( 0.1, 0.2, 0.3, 0.9 ).normalize(), args: [ new Quaternion( - 0.1, - 0.2, - 0.3, - 0.9 ).normalize(), 0.5 ] } ),
				() => ( { self: new Quaternion( 0, 0, 0.01, 1 ).normalize(), args: [ new Quaternion( 0, 0, 0.011, 1 ).normalize(), 0.5 ] } ),
				() => ( { self: new Quaternion( 1, 0, 0, 0 ), args: [ new Quaternion( 0, 0, 1, 0 ), 0.5 ] } ),
				() => ( { self: new Quaternion( 0, D, 0, D ), args: [ new Quaternion( 0, - D, 0, D ), 0.5 ] } )
			]
		},
		{ name: 'slerpQuaternions', args: [ unitQ, unitQ, 'unit' ] },
		{
			name: 'equals', args: [ 'Quaternion' ],
			edge: [ () => ( { self: new Quaternion( 1, 2, 3, 4 ), args: [ new Quaternion( 1, 2, 3, 4 ) ] } ) ]
		},
		{ name: 'fromArray', args: [ ( r ) => [ r.num(), r.num(), r.num(), r.num() ] ] },
		{ name: 'fromArray', label: 'offset', args: [ ( r ) => Array.from( { length: 7 }, () => r.num() ), ( r ) => r.int( 0, 3 ) ] },
		{ name: 'toArray' },
		{ name: 'toArray', label: 'array and offset', args: [ ( r ) => [ r.num(), r.num() ], ( r ) => r.int( 0, 2 ) ] },
		{ name: 'toJSON' }
	]
};
