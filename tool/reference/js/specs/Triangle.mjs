// Reference cases for the instance methods of src/math/Triangle.js. The statics share their names with
// instance methods, which Dart forbids; the port suffixes them (`getNormalStatic`, E-STATIC), so they are
// covered through the instance methods, which delegate to them, and by the Dart unit tests.
// setFromAttributeAndIndices needs BufferAttribute (M2); setFromPointsAndIndices takes a list of vectors,
// which the fixture codec cannot type, and is covered by the ported unit test.

const src = '../../../../third_party/three.js/src/math/';

const { Triangle } = await import( src + 'Triangle.js' );
const { Vector2 } = await import( src + 'Vector2.js' );
const { Vector3 } = await import( src + 'Vector3.js' );
const { Vector4 } = await import( src + 'Vector4.js' );
const { Box3 } = await import( src + 'Box3.js' );

const near = ( r ) => new Vector3( r.range( - 3, 3 ), r.range( - 3, 3 ), r.range( - 3, 3 ) );

// Degenerate triangles one time in ten: all corners equal, or collinear.
const triangle = ( r ) => {

	const k = r.next();

	if ( k < 0.05 ) {

		const p = near( r );
		return new Triangle( p, p.clone(), p.clone() );

	}

	if ( k < 0.1 ) {

		const p = near( r ), d = near( r );
		return new Triangle( p, p.clone().add( d ), p.clone().addScaledVector( d, 2 ) );

	}

	return new Triangle( near( r ), near( r ), near( r ) );

};

// A point mixed from the corners with weights in [-0.5, 1.5], plus an offset off the plane: inside, outside,
// on edges and corners.
let current = null;

const self = ( r ) => ( current = triangle( r ) );

const point = ( r ) => {

	const u = r.range( - 0.5, 1.5 ), v = r.range( - 0.5, 1.5 );
	const p = current.a.clone().multiplyScalar( 1 - u - v ).addScaledVector( current.b, u ).addScaledVector( current.c, v );
	return r.next() < 0.3 ? p.add( near( r ).multiplyScalar( 0.3 ) ) : p;

};

const box = ( r ) => {

	const min = near( r );
	return new Box3( min, min.clone().add( new Vector3( r.range( 0, 3 ), r.range( 0, 3 ), r.range( 0, 3 ) ) ) );

};

const v2 = ( r ) => new Vector2( r.num(), r.num() );
const v4 = ( r ) => new Vector4( r.num(), r.num(), r.num(), r.num() );

export default {
	name: 'Triangle',
	type: 'Triangle',
	self,
	cases: 20,
	methods: [
		{ name: 'set', args: [ 'Vector3', 'Vector3', 'Vector3' ] },
		{ name: 'clone' },
		{ name: 'copy', args: [ 'Triangle' ] },
		{ name: 'getArea' },
		{ name: 'getMidpoint', args: [ 'Vector3' ] },
		{ name: 'getNormal', args: [ 'Vector3' ] },
		{ name: 'getPlane', args: [ 'Plane' ] },
		{ name: 'getBarycoord', args: [ point, 'Vector3' ], cases: 40 },
		{ name: 'getInterpolation', label: 'Vector2', args: [ point, v2, v2, v2, v2 ], cases: 30 },
		{ name: 'getInterpolation', label: 'Vector3', args: [ point, 'Vector3', 'Vector3', 'Vector3', 'Vector3' ], cases: 30 },
		{ name: 'getInterpolation', label: 'Vector4', args: [ point, v4, v4, v4, v4 ], cases: 30 },
		{ name: 'containsPoint', args: [ point ], cases: 40 },
		{ name: 'isFrontFacing', args: [ 'Vector3' ] },
		{ name: 'intersectsBox', args: [ box ], cases: 40 },
		{
			name: 'closestPointToPoint', args: [ point, 'Vector3' ], cases: 60,
			edge: [

				// a and b coincide; all corners coincide; each Voronoi region of a reference triangle
				() => ( { self: new Triangle( new Vector3(), new Vector3(), new Vector3( 2, 0, 0 ) ), args: [ new Vector3( 1, 1, 0 ), new Vector3() ] } ),
				() => ( { self: new Triangle( new Vector3( 1, 1, 1 ), new Vector3( 1, 1, 1 ), new Vector3( 1, 1, 1 ) ), args: [ new Vector3(), new Vector3() ] } ),
				...[ [ - 2, - 1, 0 ], [ 2, - 1, 0 ], [ 0, 3, 0 ], [ 0, - 1, 0 ], [ - 1, 1, 0 ], [ 1, 1, 0 ], [ 0, 0.3, 1 ] ].map( ( p ) => () => ( {
					self: new Triangle( new Vector3( - 1, 0, 0 ), new Vector3( 1, 0, 0 ), new Vector3( 0, 1, 0 ) ),
					args: [ new Vector3( ...p ), new Vector3() ]
				} ) )
			]
		},
		{ name: 'equals', args: [ 'Triangle' ], edge: [ () => ( { self: new Triangle(), args: [ new Triangle() ] } ) ] }
	]
};
