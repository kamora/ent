// Reference cases for src/math/Plane.js. toJSON returns a plain object; the ported unit tests cover it.

import { Plane } from '../../../../third_party/three.js/src/math/Plane.js';
import { Vector3 } from '../../../../third_party/three.js/src/math/Vector3.js';
import { Matrix3 } from '../../../../third_party/three.js/src/math/Matrix3.js';
import { Line3 } from '../../../../third_party/three.js/src/math/Line3.js';
import { Sphere } from '../../../../third_party/three.js/src/math/Sphere.js';
import { Matrix4 } from '../../../../third_party/three.js/src/math/Matrix4.js';

const xPlane = () => new Plane( new Vector3( 1, 0, 0 ), - 2 );

// A line through or near x = 2, so intersections happen inside and outside the segment.
const crossing = ( r ) => new Line3( new Vector3( r.range( - 4, 4 ), r.num(), r.num() ), new Vector3( r.range( - 4, 4 ), r.num(), r.num() ) );

export default {
	name: 'Plane',
	type: 'Plane',
	cases: 12,
	methods: [
		{ name: 'set', args: [ 'Vector3', 'num' ] },
		{ name: 'setComponents', args: [ 'num', 'num', 'num', 'num' ] },
		{ name: 'setFromNormalAndCoplanarPoint', args: [ 'Vector3', 'Vector3' ] },
		{
			name: 'setFromCoplanarPoints', args: [ 'Vector3', 'Vector3', 'Vector3' ],
			edge: [ () => ( { self: new Plane(), args: [ new Vector3( 1, 1, 1 ), new Vector3( 1, 1, 1 ), new Vector3( 2, 2, 2 ) ] } ) ]
		},
		{ name: 'copy', args: [ 'Plane' ] },
		{
			name: 'normalize', self: ( r ) => new Plane( new Vector3( r.num(), r.num(), r.num() ), r.num() ),
			edge: [ () => ( { self: new Plane( new Vector3( 0, 0, 0 ), 1 ) } ) ]
		},
		{ name: 'negate' },
		{ name: 'distanceToPoint', args: [ 'Vector3' ] },
		{ name: 'distanceToSphere', args: [ 'Sphere' ] },
		{ name: 'projectPoint', args: [ 'Vector3', 'Vector3' ] },
		{
			name: 'intersectLine', label: 'default clamp', args: [ crossing, 'Vector3' ], self: xPlane, cases: 20,
			edge: [
				() => ( { self: xPlane(), args: [ new Line3( new Vector3( 2, 0, 0 ), new Vector3( 2, 5, 0 ) ), new Vector3() ] } ),
				() => ( { self: xPlane(), args: [ new Line3( new Vector3( 3, 0, 0 ), new Vector3( 3, 5, 0 ) ), new Vector3() ] } )
			]
		},
		{ name: 'intersectLine', label: 'clampToLine', args: [ crossing, 'Vector3', 'bool' ], self: xPlane, cases: 20 },
		{
			name: 'intersectsLine', args: [ crossing ], self: xPlane, cases: 20,
			edge: [ () => ( { self: xPlane(), args: [ new Line3( new Vector3( 2, 0, 0 ), new Vector3( 4, 0, 0 ) ) ] } ) ]
		},
		{ name: 'intersectsBox', args: [ 'Box3' ] },
		{ name: 'intersectsSphere', args: [ 'Sphere' ], edge: [ () => ( { self: xPlane(), args: [ new Sphere( new Vector3( 3, 0, 0 ), 1 ) ] } ) ] },
		{ name: 'coplanarPoint', args: [ 'Vector3' ] },
		{ name: 'applyMatrix4', label: 'computed normal matrix', args: [ 'Matrix4' ] },
		{
			name: 'applyMatrix4', label: 'given normal matrix', args: [ 'Matrix4', 'Matrix3' ],
			edge: [ 0.5, 2 ].map( ( k ) => () => {

				const m = new Matrix4().makeRotationY( k ).scale( new Vector3( k, 1, 3 ) ).setPosition( k, - 1, 2 );
				return { self: xPlane(), args: [ m, new Matrix3().getNormalMatrix( m ) ] };

			} )
		},
		{ name: 'translate', args: [ 'Vector3' ] },
		{ name: 'equals', args: [ 'Plane' ], edge: [ () => ( { self: xPlane(), args: [ xPlane() ] } ) ] },
		{ name: 'clone' }
	]
};
