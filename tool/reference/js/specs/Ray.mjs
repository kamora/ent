// Reference cases for src/math/Ray.js. Generators aim rays at their targets so hits and misses both occur.

const src = '../../../../third_party/three.js/src/math/';

const { Ray } = await import( src + 'Ray.js' );
const { Vector3 } = await import( src + 'Vector3.js' );
const { Sphere } = await import( src + 'Sphere.js' );
const { Plane } = await import( src + 'Plane.js' );
const { Box3 } = await import( src + 'Box3.js' );

const near = ( r ) => new Vector3( r.range( - 3, 3 ), r.range( - 3, 3 ), r.range( - 3, 3 ) );
const unit = ( r ) => new Vector3( r.range( - 1, 1 ), r.range( - 1, 1 ), r.range( - 1, 1 ) ).normalize();

// A ray from a random point towards (roughly) the origin, so shapes around the origin are often hit.
const aimed = ( r ) => {

	const origin = near( r ).multiplyScalar( 3 );
	return new Ray( origin, near( r ).multiplyScalar( 0.3 ).sub( origin ).normalize() );

};

const sphere = ( r ) => new Sphere( near( r ).multiplyScalar( 0.5 ), r.range( 0, 4 ) );
const plane = ( r ) => new Plane( unit( r ), r.range( - 5, 5 ) );

const box = ( r ) => {

	const min = near( r );
	return new Box3( min, min.clone().add( new Vector3( r.range( 0, 4 ), r.range( 0, 4 ), r.range( 0, 4 ) ) ) );

};

export default {
	name: 'Ray',
	type: 'Ray',
	cases: 12,
	methods: [
		{ name: 'set', args: [ 'Vector3', 'Vector3' ] },
		{ name: 'copy', args: [ 'Ray' ] },
		{ name: 'at', args: [ 'num', 'Vector3' ] },
		{ name: 'lookAt', args: [ 'Vector3' ], edge: [ () => ( { self: new Ray(), args: [ new Vector3() ] } ) ] },
		{ name: 'recast', args: [ 'num' ] },
		{ name: 'closestPointToPoint', args: [ 'Vector3', 'Vector3' ] },
		{ name: 'distanceToPoint', args: [ 'Vector3' ] },
		{ name: 'distanceSqToPoint', args: [ 'Vector3' ] },
		{
			name: 'distanceSqToSegment', label: 'no targets', args: [ near, near ],
			cases: 30
		},
		{
			name: 'distanceSqToSegment', args: [ near, near, 'Vector3', 'Vector3' ],
			cases: 30,
			edge: [

				// parallel, anti-parallel, degenerate segment, segment through the origin
				() => ( { self: new Ray( new Vector3(), new Vector3( 0, 0, 1 ) ), args: [ new Vector3( 1, 0, 2 ), new Vector3( 1, 0, 5 ), new Vector3(), new Vector3() ] } ),
				() => ( { self: new Ray( new Vector3(), new Vector3( 0, 0, 1 ) ), args: [ new Vector3( 1, 0, 5 ), new Vector3( 1, 0, - 2 ), new Vector3(), new Vector3() ] } ),
				() => ( { self: new Ray( new Vector3(), new Vector3( 0, 0, 1 ) ), args: [ new Vector3( 1, 1, 1 ), new Vector3( 1, 1, 1 ), new Vector3(), new Vector3() ] } ),
				() => ( { self: new Ray( new Vector3( 0, 0, - 1 ), new Vector3( 0, 0, 1 ) ), args: [ new Vector3( - 1, 0, 0 ), new Vector3( 1, 0, 0 ), new Vector3(), new Vector3() ] } )
			]
		},
		{
			name: 'intersectSphere', self: aimed, args: [ sphere, 'Vector3' ], cases: 30,
			edge: [
				() => ( { self: new Ray(), args: [ new Sphere( new Vector3( 0, 0, - 1 ), - 1 ), new Vector3() ] } ),
				() => ( { self: new Ray(), args: [ new Sphere( new Vector3(), 1 ), new Vector3() ] } ),
				() => ( { self: new Ray(), args: [ new Sphere( new Vector3( 0, 0, 5 ), 1 ), new Vector3() ] } )
			]
		},
		{
			name: 'intersectsSphere', self: aimed, args: [ sphere ], cases: 30,
			edge: [ () => ( { self: new Ray(), args: [ new Sphere( new Vector3( 0, 0, - 1 ), - 1 ) ] } ) ]
		},
		{
			name: 'distanceToPlane', self: aimed, args: [ plane ], cases: 20,
			edge: [

				// parallel and coplanar, parallel and apart, behind
				() => ( { self: new Ray( new Vector3( 1, 0, 0 ), new Vector3( 0, 1, 0 ) ), args: [ new Plane( new Vector3( 1, 0, 0 ), - 1 ) ] } ),
				() => ( { self: new Ray( new Vector3( 2, 0, 0 ), new Vector3( 0, 1, 0 ) ), args: [ new Plane( new Vector3( 1, 0, 0 ), - 1 ) ] } ),
				() => ( { self: new Ray( new Vector3( 2, 0, 0 ), new Vector3( 1, 0, 0 ) ), args: [ new Plane( new Vector3( 1, 0, 0 ), - 1 ) ] } )
			]
		},
		{
			name: 'intersectPlane', self: aimed, args: [ plane, 'Vector3' ], cases: 20,
			edge: [ () => ( { self: new Ray( new Vector3( 2, 0, 0 ), new Vector3( 0, 1, 0 ) ), args: [ new Plane( new Vector3( 1, 0, 0 ), - 1 ), new Vector3() ] } ) ]
		},
		{
			name: 'intersectsPlane', self: aimed, args: [ plane ], cases: 20,
			edge: [ () => ( { self: new Ray( new Vector3( 1, 0, 0 ), new Vector3( 0, 1, 0 ) ), args: [ new Plane( new Vector3( 1, 0, 0 ), - 1 ) ] } ) ]
		},
		{
			name: 'intersectBox', self: aimed, args: [ box, 'Vector3' ], cases: 40,
			edge: [

				// empty box, ray inside, axis-aligned rays on a face (0 * Infinity = NaN paths), zero direction
				() => ( { self: new Ray(), args: [ new Box3(), new Vector3() ] } ),
				() => ( { self: new Ray( new Vector3(), new Vector3( 1, 0, 0 ) ), args: [ new Box3( new Vector3( - 1, - 1, - 1 ), new Vector3( 1, 1, 1 ) ), new Vector3() ] } ),
				() => ( { self: new Ray( new Vector3( 1, - 2, 1 ), new Vector3( 0, 1, 0 ) ), args: [ new Box3( new Vector3( - 1, - 1, - 1 ), new Vector3( 1, 1, 1 ) ), new Vector3() ] } ),
				() => ( { self: new Ray( new Vector3( - 1, - 1, - 5 ), new Vector3( 0, 0, 1 ) ), args: [ new Box3( new Vector3( - 1, - 1, - 1 ), new Vector3( 1, 1, 1 ) ), new Vector3() ] } ),
				() => ( { self: new Ray( new Vector3( 1, - 2, 0 ), new Vector3( 0, - 1, 0 ) ), args: [ new Box3( new Vector3( - 1, - 1, - 1 ), new Vector3( 1, 1, 1 ) ), new Vector3() ] } ),
				() => ( { self: new Ray( new Vector3( 0, 0, 0 ), new Vector3( 0, 0, 0 ) ), args: [ new Box3( new Vector3( - 1, - 1, - 1 ), new Vector3( 1, 1, 1 ) ), new Vector3() ] } )
			]
		},
		{
			name: 'intersectsBox', self: aimed, args: [ box ], cases: 80,
			edge: [
				() => ( { self: new Ray(), args: [ new Box3() ] } ),
				() => ( { self: new Ray( new Vector3( - 5, 0, 0 ), new Vector3( 1, 0, 0 ) ), args: [ new Box3( new Vector3( - 1, - 1, - 1 ), new Vector3( 1, 1, 1 ) ) ] } )
			]
		},
		{
			name: 'intersectTriangle', self: aimed, args: [ near, near, near, 'bool', 'Vector3' ], cases: 60,
			edge: [
				() => ( { self: new Ray( new Vector3(), new Vector3() ), args: [ new Vector3( 1, 1, 0 ), new Vector3( 0, 1, 1 ), new Vector3( 1, 0, 1 ), false, new Vector3() ] } ),
				() => ( { self: new Ray( new Vector3(), new Vector3( 1, 1, 1 ).normalize() ), args: [ new Vector3( 1, 1, 0 ), new Vector3( 0, 1, 1 ), new Vector3( 1, 0, 1 ), true, new Vector3() ] } ),
				() => ( { self: new Ray( new Vector3(), new Vector3( 1, 1, 1 ).normalize() ), args: [ new Vector3( 1, 1, 0 ), new Vector3( 0, 1, 1 ), new Vector3( 1, 0, 1 ), false, new Vector3() ] } ),

				// coplanar ray, degenerate triangle, each dominant axis with both signs
				() => ( { self: new Ray( new Vector3( - 5, 0, 0 ), new Vector3( 1, 0, 0 ) ), args: [ new Vector3( 0, 0, 0 ), new Vector3( 1, 0, 0 ), new Vector3( 0, 1, 0 ), false, new Vector3() ] } ),
				() => ( { self: new Ray( new Vector3( 0, 0, 5 ), new Vector3( 0, 0, - 1 ) ), args: [ new Vector3( 0, 0, 0 ), new Vector3( 1, 1, 0 ), new Vector3( 2, 2, 0 ), false, new Vector3() ] } ),
				...[ [ 1, 0, 0 ], [ - 1, 0, 0 ], [ 0, 1, 0 ], [ 0, - 1, 0 ], [ 0, 0, 1 ], [ 0, 0, - 1 ] ].map( ( d ) => () => {

					const dir = new Vector3( ...d );
					const tri = [ new Vector3( 1, 0.2, 0.3 ), new Vector3( - 0.4, 1, 0.1 ), new Vector3( 0.2, - 0.6, 1 ) ].map( ( v ) => v.clone().addScaledVector( dir, 4 ) );
					return { self: new Ray( new Vector3( 0.1, 0.1, 0.1 ), dir ), args: [ ...tri, false, new Vector3() ] };

				} )
			]
		},
		{ name: 'applyMatrix4', args: [ 'Matrix4' ] },
		{ name: 'equals', args: [ 'Ray' ], edge: [ () => ( { self: new Ray(), args: [ new Ray() ] } ) ] },
		{ name: 'clone' }
	]
};
