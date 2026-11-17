// Reference cases for src/math/MathUtils.js. generateUUID, randInt, randFloat and randFloatSpread use
// Math.random() and are covered by the ported unit tests instead.

import { MathUtils } from '../../../../third_party/three.js/src/math/MathUtils.js';
import { Quaternion } from '../../../../third_party/three.js/src/math/Quaternion.js';

const TYPES = [ 'Uint8Array', 'Uint16Array', 'Uint32Array', 'Int8Array', 'Int16Array', 'Int32Array', 'Float32Array' ];
const typed = ( name ) => () => new globalThis[ name ]( 1 );

export default {
	name: 'MathUtils',
	static: MathUtils,
	cases: 20,
	methods: [
		{ name: 'clamp', args: [ 'num', 'num', 'num' ] },
		{ name: 'euclideanModulo', args: [ 'num', 'num' ], edge: [ () => ( { args: [ - 7, 3 ] } ), () => ( { args: [ 7, - 3 ] } ), () => ( { args: [ 1, 0 ] } ) ] },
		{ name: 'mapLinear', args: [ 'num', 'num', 'num', 'num', 'num' ] },
		{ name: 'inverseLerp', args: [ 'num', 'num', 'num' ], edge: [ () => ( { args: [ 2, 2, 5 ] } ) ] },
		{ name: 'lerp', args: [ 'num', 'num', 'unit' ] },
		{ name: 'damp', args: [ 'num', 'num', 'unit', 'unit' ] },
		{ name: 'pingpong', args: [ 'num' ], label: 'default length' },
		{ name: 'pingpong', args: [ 'num', ( r ) => r.range( 0.5, 5 ) ] },
		{ name: 'smoothstep', args: [ 'num', ( r ) => r.range( - 5, 0 ), ( r ) => r.range( 0, 5 ) ] },
		{ name: 'smootherstep', args: [ 'num', ( r ) => r.range( - 5, 0 ), ( r ) => r.range( 0, 5 ) ] },
		{
			name: 'seededRandom', args: [ ( r ) => r.int( 0, 2 ** 31 ) ],
			edge: [ () => ( { args: [] } ), () => ( { args: [] } ), () => ( { args: [ 0 ] } ), () => ( { args: [] } ) ]
		},
		{
			name: 'setQuaternionFromProperEuler', args: [ 'Quaternion', 'num', 'num', 'num', ( r ) => r.pick( [ 'XYX', 'XZX', 'YXY', 'YZY', 'ZXZ', 'ZYZ' ] ) ],
			edge: [ () => ( { args: [ new Quaternion( 1, 2, 3, 4 ), 1, 2, 3, 'XYZ' ] } ) ]
		},
		{ name: 'degToRad', args: [ ( r ) => r.range( - 720, 720 ) ] },
		{ name: 'radToDeg', args: [ ( r ) => r.range( - 10, 10 ) ] },
		{
			name: 'isPowerOfTwo', args: [ ( r ) => r.int( 0, 1100 ) ],
			edge: [ 1, 2, 4, 1024, 2 ** 30, 3, 0, 0.5, 6 ].map( ( v ) => () => ( { args: [ v ] } ) )
		},
		{ name: 'ceilPowerOfTwo', args: [ ( r ) => r.range( 0.01, 5000 ) ] },
		{ name: 'floorPowerOfTwo', args: [ ( r ) => r.range( 0.01, 5000 ) ] },
		{
			name: 'normalize', args: [ 'unit', ( r ) => typed( r.pick( TYPES ) )() ],
			edge: [ () => ( { args: [ 0.5, new Float64Array( 1 ) ] } ), () => ( { args: [ 0.5, new Uint8ClampedArray( 1 ) ] } ) ]
		},
		{
			name: 'denormalize', args: [ ( r ) => r.range( - 300, 300 ), ( r ) => typed( r.pick( TYPES ) )() ],
			edge: [ () => ( { args: [ - 200, new Int8Array( 1 ) ] } ), () => ( { args: [ 1, new Float64Array( 1 ) ] } ) ]
		}
	]
};
