// Curve types from src/extras/curves: how fixtures generate them and the state they record.
// The state layouts are mirrored by packages/ent/test/support/codecs/curves.dart.

const src = '../../../../third_party/three.js/src/';

const { Vector2 } = await import( src + 'math/Vector2.js' );
const { Vector3 } = await import( src + 'math/Vector3.js' );
const C = await import( src + 'extras/curves/Curves.js' );

const v2 = ( r ) => new Vector2( r.num(), r.num() );
const v3 = ( r ) => new Vector3( r.num(), r.num(), r.num() );
const flat = ( points, e ) => points.flatMap( ( p ) => p.toArray().map( e ) );
const angle = ( r ) => r.range( - 2 * Math.PI, 2 * Math.PI );

// The methods every curve spec replays; `vec` names the point type ('Vector2' or 'Vector3').
export function curveSpec( name, vec, extra = [] ) {

	const t = ( r ) => r.pick( [ 0, 1, 0.5, r.unit(), r.unit() ] );

	return {
		name,
		type: name,
		cases: 12,
		methods: [
			{ name: 'getPoint', args: [ t ] },
			{ name: 'getPoint', label: 'target', args: [ t, vec ] },
			{ name: 'getPointAt', args: [ t ] },
			{ name: 'getPointAt', label: 'target', args: [ t, vec ] },
			{ name: 'getPoints', label: 'default divisions', args: [] },
			{ name: 'getPoints', args: [ ( r ) => r.int( 1, 12 ) ] },
			{ name: 'getSpacedPoints', label: 'default divisions', args: [] },
			{ name: 'getSpacedPoints', args: [ ( r ) => r.int( 1, 12 ) ] },
			{ name: 'getLength', args: [] },
			{ name: 'getLengths', label: 'default divisions', args: [] },
			{ name: 'getLengths', args: [ ( r ) => r.int( 1, 30 ) ] },
			{ name: 'getUtoTmapping', args: [ 'unit' ] },
			{ name: 'getUtoTmapping', label: 'distance', args: [ 'unit', ( r ) => r.pick( [ 0, r.range( 0, 20 ) ] ) ] },
			{ name: 'getTangent', args: [ t ] },
			{ name: 'getTangent', label: 'target', args: [ t, vec ] },
			{ name: 'getTangentAt', args: [ t ] },
			{ name: 'getTangentAt', label: 'target', args: [ t, vec ] },
			{ name: 'copy', args: [ name ] },
			{ name: 'clone', args: [] },
			...extra
		]
	};

}

export default {

	LineCurve: {
		is: ( v ) => v?.isLineCurve === true,
		encode: ( v, e ) => flat( [ v.v1, v.v2 ], e ),
		gen: ( r ) => new C.LineCurve( v2( r ), v2( r ) )
	},

	LineCurve3: {
		is: ( v ) => v?.isLineCurve3 === true,
		encode: ( v, e ) => flat( [ v.v1, v.v2 ], e ),
		gen: ( r ) => new C.LineCurve3( v3( r ), v3( r ) )
	},

	QuadraticBezierCurve: {
		is: ( v ) => v?.isQuadraticBezierCurve === true,
		encode: ( v, e ) => flat( [ v.v0, v.v1, v.v2 ], e ),
		gen: ( r ) => new C.QuadraticBezierCurve( v2( r ), v2( r ), v2( r ) )
	},

	QuadraticBezierCurve3: {
		is: ( v ) => v?.isQuadraticBezierCurve3 === true,
		encode: ( v, e ) => flat( [ v.v0, v.v1, v.v2 ], e ),
		gen: ( r ) => new C.QuadraticBezierCurve3( v3( r ), v3( r ), v3( r ) )
	},

	CubicBezierCurve: {
		is: ( v ) => v?.isCubicBezierCurve === true,
		encode: ( v, e ) => flat( [ v.v0, v.v1, v.v2, v.v3 ], e ),
		gen: ( r ) => new C.CubicBezierCurve( v2( r ), v2( r ), v2( r ), v2( r ) )
	},

	CubicBezierCurve3: {
		is: ( v ) => v?.isCubicBezierCurve3 === true,
		encode: ( v, e ) => flat( [ v.v0, v.v1, v.v2, v.v3 ], e ),
		gen: ( r ) => new C.CubicBezierCurve3( v3( r ), v3( r ), v3( r ), v3( r ) )
	},

	// ArcCurve before EllipseCurve: an ArcCurve also has isEllipseCurve.
	ArcCurve: {
		is: ( v ) => v?.isArcCurve === true,
		encode: ( v, e ) => [ v.aX, v.aY, v.xRadius, v.yRadius, v.aStartAngle, v.aEndAngle ].map( e ).concat( [ v.aClockwise, e( v.aRotation ) ] ),
		gen: ( r ) => new C.ArcCurve( r.num(), r.num(), r.range( 0, 5 ), angle( r ), angle( r ), r.bool() )
	},

	EllipseCurve: {
		is: ( v ) => v?.isEllipseCurve === true,
		encode: ( v, e ) => [ v.aX, v.aY, v.xRadius, v.yRadius, v.aStartAngle, v.aEndAngle ].map( e ).concat( [ v.aClockwise, e( v.aRotation ) ] ),
		gen: ( r ) => {

			const start = angle( r );

			// One time in five the same start and end angle (the samePoints branch).
			const end = r.next() < 0.2 ? start : angle( r );
			return new C.EllipseCurve( r.num(), r.num(), r.range( 0, 5 ), r.range( 0, 5 ), start, end, r.bool(), r.pick( [ 0, angle( r ) ] ) );

		}
	},

	SplineCurve: {
		is: ( v ) => v?.isSplineCurve === true,
		encode: ( v, e ) => flat( v.points, e ),
		gen: ( r ) => new C.SplineCurve( Array.from( { length: 2 + r.int( 0, 5 ).value }, () => v2( r ) ) )
	},

	CatmullRomCurve3: {
		is: ( v ) => v?.isCatmullRomCurve3 === true,
		encode: ( v, e ) => [ v.closed, v.curveType, e( v.tension ) ].concat( flat( v.points, e ) ),
		gen: ( r ) => new C.CatmullRomCurve3(
			Array.from( { length: 2 + r.int( 0, 5 ).value }, () => v3( r ) ),
			r.bool(),
			r.pick( [ 'centripetal', 'chordal', 'catmullrom' ] ),
			r.range( 0, 1 )
		)
	}

};
