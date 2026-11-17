// Reference cases for src/math/Matrix4.js.

import { Matrix4 } from '../../../../third_party/three.js/src/math/Matrix4.js';
import { Vector3 } from '../../../../third_party/three.js/src/math/Vector3.js';
import { Quaternion } from '../../../../third_party/three.js/src/math/Quaternion.js';
import { Euler } from '../../../../third_party/three.js/src/math/Euler.js';
import { int } from '../lib/codec.mjs';

const WebGL = 2000;
const WebGPU = 2001;

const nums = ( n ) => Array.from( { length: n }, () => 'num' );
const unit3 = ( r ) => new Vector3( r.range( - 1, 1 ), r.range( - 1, 1 ), r.range( - 1, 1 ) ).normalize();
const quat = ( r ) => new Quaternion().setFromAxisAngle( unit3( r ), r.range( - Math.PI, Math.PI ) );
const zero = () => new Matrix4().set( ...Array( 16 ).fill( 0 ) );

// A transform with a random, sometimes negative or zero, scale.
function transform( r ) {

	const s = () => r.pick( [ r.range( 0.1, 3 ), - r.range( 0.1, 3 ), r.range( 0.1, 3 ) ] );
	return new Matrix4().compose( new Vector3( r.num(), r.num(), r.num() ), quat( r ), new Vector3( s(), s(), s() ) );

}

// A frustum box: left < right, bottom < top, 0 < near < far.
const frustum = ( r ) => {

	const near = r.range( 0.1, 2 );
	return [ - r.range( 0.1, 5 ), r.range( 0.1, 5 ), r.range( 0.1, 5 ), - r.range( 0.1, 5 ), near, near + r.range( 1, 100 ) ];

};

const projections = ( name ) => [
	{ name, label: 'default', ...withFrustum( [] ) },
	{ name, label: 'WebGL', ...withFrustum( [ () => int( WebGL ) ] ) },
	{ name, label: 'WebGPU', ...withFrustum( [ () => int( WebGPU ) ] ) },
	{ name, label: 'reversed depth', ...withFrustum( [ ( r ) => int( r.pick( [ WebGL, WebGPU ] ) ), () => true ] ) },
	{ name, label: 'not reversed', ...withFrustum( [ ( r ) => int( r.pick( [ WebGL, WebGPU ] ) ), () => false ] ) },
	{
		name, label: 'invalid coordinate system', cases: 0,
		edge: [ () => ( { self: new Matrix4(), args: [ - 1, 1, 1, - 1, 1, 100, int( 1234 ) ] } ), () => ( { self: new Matrix4(), args: [ - 1, 1, 1, - 1, 1, 100, int( 1234 ), true ] } ) ]
	}
];

// Six frustum numbers drawn together, followed by the given extra arguments.
function withFrustum( extra ) {

	let box = null;
	const part = ( i ) => ( r ) => {

		if ( i === 0 ) {

			box = frustum( r );

		}

		return box[ i ];

	};

	return { args: [ 0, 1, 2, 3, 4, 5 ].map( part ).concat( extra ) };

}

export default {
	name: 'Matrix4',
	type: 'Matrix4',
	cases: 10,
	methods: [
		{ name: 'set', args: nums( 16 ) },
		{ name: 'identity' },
		{ name: 'clone' },
		{ name: 'copy', args: [ 'Matrix4' ] },
		{ name: 'copyPosition', args: [ 'Matrix4' ] },
		{ name: 'setFromMatrix3', args: [ 'Matrix3' ] },
		{
			name: 'extractBasis', args: [ 'Vector3', 'Vector3', 'Vector3' ],
			edge: [ () => ( { self: new Matrix4().makeScale( 0, 1, 1 ), args: [ new Vector3( 5, 5, 5 ), new Vector3( 5, 5, 5 ), new Vector3( 5, 5, 5 ) ] } ) ]
		},
		{ name: 'makeBasis', args: [ 'Vector3', 'Vector3', 'Vector3' ] },
		{
			name: 'extractRotation', args: [ transform ],
			edge: [ () => ( { self: new Matrix4(), args: [ new Matrix4().makeScale( 1, 0, 1 ) ] } ), () => ( { self: new Matrix4(), args: [ zero() ] } ) ]
		},
		{ name: 'makeRotationFromEuler', args: [ 'Euler' ], cases: 30 },
		{ name: 'makeRotationFromQuaternion', args: [ 'Quaternion' ] },
		{
			name: 'lookAt', args: [ 'Vector3', 'Vector3', unit3 ],
			edge: [
				() => ( { self: new Matrix4(), args: [ new Vector3( 1, 2, 3 ), new Vector3( 1, 2, 3 ), new Vector3( 0, 1, 0 ) ] } ),
				() => ( { self: new Matrix4(), args: [ new Vector3( 0, 1, 0 ), new Vector3( 0, 0, 0 ), new Vector3( 0, 1, 0 ) ] } ),
				() => ( { self: new Matrix4(), args: [ new Vector3( 0, 0, 5 ), new Vector3( 0, 0, 0 ), new Vector3( 0, 0, 1 ) ] } ),
				() => ( { self: new Matrix4(), args: [ new Vector3( 0, 0, - 5 ), new Vector3( 0, 0, 0 ), new Vector3( 0, 0, - 1 ) ] } )
			]
		},
		{ name: 'multiply', args: [ 'Matrix4' ] },
		{ name: 'premultiply', args: [ 'Matrix4' ] },
		{ name: 'multiplyMatrices', args: [ 'Matrix4', 'Matrix4' ] },
		{ name: 'multiplyScalar', args: [ 'num' ] },
		{ name: 'determinant' },
		{ name: 'determinantAffine' },
		{ name: 'transpose' },
		{ name: 'setPosition', label: 'vector', args: [ 'Vector3' ] },
		{ name: 'setPosition', label: 'numbers', args: nums( 3 ) },
		{
			name: 'invert', cases: 20,
			edge: [ () => ( { self: zero() } ), () => ( { self: new Matrix4().makeScale( 1, 0, 1 ) } ), () => ( { self: new Matrix4() } ) ]
		},
		{ name: 'invert', label: 'transform', self: transform },
		{ name: 'scale', args: [ 'Vector3' ] },
		{ name: 'getMaxScaleOnAxis' },
		{ name: 'makeTranslation', label: 'vector', args: [ 'Vector3' ] },
		{ name: 'makeTranslation', label: 'numbers', args: nums( 3 ) },
		{ name: 'makeRotationX', args: [ 'num' ] },
		{ name: 'makeRotationY', args: [ 'num' ] },
		{ name: 'makeRotationZ', args: [ 'num' ] },
		{ name: 'makeRotationAxis', args: [ unit3, 'num' ] },
		{ name: 'makeScale', args: nums( 3 ), edge: [ () => ( { self: new Matrix4(), args: [ 0, 0, 0 ] } ) ] },
		{ name: 'makeShear', args: nums( 6 ) },
		{ name: 'compose', args: [ 'Vector3', 'Quaternion', 'Vector3' ] },
		{
			name: 'decompose', args: [ 'Vector3', 'Quaternion', 'Vector3' ], self: transform, cases: 30,
			edge: [
				() => ( { self: new Matrix4().makeScale( 0, 2, 3 ), args: [ new Vector3(), new Quaternion( 1, 2, 3, 4 ), new Vector3() ] } ),
				() => ( { self: new Matrix4().compose( new Vector3( 1, 2, 3 ), new Quaternion(), new Vector3( - 1, - 1, - 1 ) ), args: [ new Vector3(), new Quaternion(), new Vector3() ] } ),
				() => ( { self: new Matrix4().compose( new Vector3( 1, 2, 3 ), new Quaternion().setFromEuler( new Euler( 1, - 1, 1 ) ), new Vector3( 2, - 2, 1 ) ), args: [ new Vector3(), new Quaternion(), new Vector3() ] } )
			]
		},
		...projections( 'makePerspective' ),
		...projections( 'makeOrthographic' ),
		{
			name: 'equals', args: [ 'Matrix4' ],
			edge: [ () => ( { self: new Matrix4(), args: [ new Matrix4() ] } ), () => ( { self: new Matrix4().makeScale( - 0, 1, 1 ), args: [ new Matrix4().makeScale( 0, 1, 1 ) ] } ) ]
		},
		{ name: 'fromArray', args: [ ( r ) => Array.from( { length: 16 }, () => r.num() ) ] },
		{ name: 'fromArray', label: 'offset', args: [ ( r ) => Array.from( { length: 20 }, () => r.num() ), ( r ) => r.int( 0, 4 ) ] },
		{ name: 'fromArray', label: 'Float32Array', args: [ ( r ) => new Float32Array( Array.from( { length: 16 }, () => r.num() ) ) ] },
		{ name: 'toArray' },
		{ name: 'toArray', label: 'array and offset', args: [ ( r ) => [ r.num(), r.num(), r.num() ], ( r ) => r.int( 0, 3 ) ] },
		{ name: 'toArray', label: 'Float32Array', args: [ () => new Float32Array( 18 ), ( r ) => r.int( 0, 2 ) ] }
	]
};
