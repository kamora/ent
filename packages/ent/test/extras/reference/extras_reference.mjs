// Expected values for the extras tests (test/extras/core, test/extras/*_test.dart), computed by the
// reference source. Usage, from the repository root:
//   node packages/ent/test/extras/reference/extras_reference.mjs
// It writes extras_reference.json next to this file.

import { writeFileSync } from 'node:fs';

const src = new URL( '../../../../../third_party/three.js/src/', import.meta.url ).href;
const { Vector2 } = await import( src + 'math/Vector2.js' );
const { Vector3 } = await import( src + 'math/Vector3.js' );
const { Path } = await import( src + 'extras/core/Path.js' );
const { Shape } = await import( src + 'extras/core/Shape.js' );
const { ShapePath } = await import( src + 'extras/core/ShapePath.js' );
const { CurvePath } = await import( src + 'extras/core/CurvePath.js' );
const { ShapeUtils } = await import( src + 'extras/ShapeUtils.js' );
const { Earcut } = await import( src + 'extras/Earcut.js' );
const earcutLib = await import( src + 'extras/lib/earcut.js' );
const C = await import( src + 'extras/curves/Curves.js' );
const { TextureUtils } = await import( src + 'extras/TextureUtils.js' );
const K = await import( src + 'constants.js' );

const out = {};
const pts = ( a ) => a.map( ( p ) => p.toArray() );

// Path with every command
const path = new Path();
path.moveTo( 1, 2 ).lineTo( 3, 4 ).quadraticCurveTo( 5, 6, 7, 2 ).bezierCurveTo( 8, 0, 9, - 3, 6, - 4 )
	.splineThru( [ new Vector2( 4, - 5 ), new Vector2( 2, - 3 ), new Vector2( 0, - 4 ) ] )
	.arc( 1, 1, 2, 0, Math.PI / 2, false ).absellipse( - 2, 0, 3, 1.5, 0, Math.PI, true, 0.3 );
out.pathPoints = pts( path.getPoints() );
out.pathPoints5 = pts( path.getPoints( 5 ) );
out.pathSpaced = pts( path.getSpacedPoints( 10 ) );
out.pathLength = path.getLength();
out.pathCurveLengths = path.getCurveLengths();
out.pathCurrent = path.currentPoint.toArray();
out.pathTypes = path.curves.map( ( c ) => c.type );
out.pathPointAt = pts( [ 0, 0.13, 0.5, 0.77, 1 ].map( ( t ) => path.getPointAt( t ) ) );
out.pathTangents = pts( [ 0, 0.25, 0.5, 0.99 ].map( ( t ) => path.getTangentAt( t ) ) );
out.pathJSON = JSON.parse( JSON.stringify( path.toJSON() ) );

// autoClose and closePath
const cp = new CurvePath();
cp.add( new C.LineCurve3( new Vector3( 0, 0, 0 ), new Vector3( 1, 2, 3 ) ) );
cp.add( new C.CubicBezierCurve3( new Vector3( 1, 2, 3 ), new Vector3( 4, 0, 1 ), new Vector3( 2, - 2, 5 ), new Vector3( 5, 5, 5 ) ) );
cp.closePath();
cp.autoClose = true;
out.cpTypes = cp.curves.map( ( c ) => c.type );
out.cpPoints = pts( cp.getPoints( 4 ) );
out.cpSpaced = pts( cp.getSpacedPoints( 6 ) );
out.cpPointBeyond = cp.getPoint( 1.5 );
const frames = new C.CatmullRomCurve3( [ new Vector3( 0, 0, 0 ), new Vector3( 1, 2, 0 ), new Vector3( 3, 2, 1 ), new Vector3( 4, 0, 3 ) ], true ).computeFrenetFrames( 6, true );
out.closedFrames = { t: pts( frames.tangents ), n: pts( frames.normals ), b: pts( frames.binormals ) };

// Shape with holes
const shape = new Shape( [ new Vector2( 0, 0 ), new Vector2( 10, 0 ), new Vector2( 10, 10 ), new Vector2( 0, 10 ) ] );
const hole = new Path().moveTo( 2, 2 ).absarc( 5, 5, 2, 0, Math.PI * 2, true );
shape.holes.push( hole );
const ex = shape.extractPoints( 6 );
out.shapeExtract = { shape: pts( ex.shape ), holes: ex.holes.map( pts ) };
out.shapeTriangles = ShapeUtils.triangulateShape( ex.shape, ex.holes );
out.shapeArea = ShapeUtils.area( ex.shape );
out.holeClockWise = ShapeUtils.isClockWise( ex.holes[ 0 ] );

// ShapePath.toShapes: outer, hole, island in hole, overlapping duplicate
function sp( fillRule ) {

	const s = new ShapePath();
	if ( fillRule !== undefined ) s.userData.style = { fillRule };
	const rect = ( x0, y0, x1, y1, cw ) => {

		s.moveTo( x0, y0 );
		if ( cw ) {

			s.lineTo( x0, y1 ); s.lineTo( x1, y1 ); s.lineTo( x1, y0 ); s.lineTo( x0, y0 );

		} else {

			s.lineTo( x1, y0 ); s.lineTo( x1, y1 ); s.lineTo( x0, y1 ); s.lineTo( x0, y0 );

		}

	};

	rect( 0, 0, 20, 20, false ); // outer CCW
	rect( 4, 4, 16, 16, true ); // hole CW
	rect( 7, 7, 13, 13, false ); // island CCW
	rect( 30, 0, 40, 10, false ); // separate
	rect( 32, 2, 38, 8, false ); // same winding inside separate
	s.moveTo( 50, 50 ); s.lineTo( 51, 51 ); // degenerate
	const shapes = s.toShapes();
	return shapes.map( ( sh ) => ( { points: pts( sh.getPoints() ), holes: sh.holes.map( ( h ) => pts( h.getPoints() ) ) } ) );

}

out.toShapesNonzero = sp();
out.toShapesEvenodd = sp( 'evenodd' );
out.toShapesBadRule = sp( 'weird' );

// Earcut cases
const ring = ( n, r, cx = 0, cy = 0, phase = 0 ) => Array.from( { length: n }, ( _, i ) => [ cx + r * Math.cos( phase + 2 * Math.PI * i / n ), cy + r * Math.sin( phase + 2 * Math.PI * i / n ) ] ).flat();
const cases = {
	square: [ [ 0, 0, 1, 0, 1, 1, 0, 1 ], null ],
	concave: [ [ 0, 0, 4, 0, 4, 4, 2, 1, 0, 4 ], null ],
	withHole: [ [ 0, 0, 10, 0, 10, 10, 0, 10, 3, 3, 3, 7, 7, 7, 7, 3 ], [ 4 ] ],
	twoHoles: [ [ ...ring( 12, 10 ), ...ring( 6, 2, - 4, 0 ).reverse(), ...ring( 5, 2, 4, 1 ) ], [ 12, 18 ] ],
	hashed: [ ring( 60, 50, 0, 0, 0.1 ).map( ( v, i ) => v * ( 1 + 0.3 * Math.sin( i * 1.7 ) ) ), null ],
	hashedHoles: [ [ ...ring( 50, 100 ), ...ring( 8, 10, - 40, 0 ), ...ring( 8, 10, 40, 0 ), ...ring( 7, 10, 0, 40 ) ], [ 50, 58, 66 ] ],
	// More than 80 vertices: earcut switches to its z-order hashed ear test.
	hashedLarge: [ ring( 150, 100, 0, 0, 0.05 ).map( ( v, i ) => v * ( 1 + 0.2 * Math.sin( i * 0.9 ) ) ), null ],
	hashedLargeHoles: [ [ ...ring( 120, 200 ), ...ring( 16, 20, - 80, 0 ), ...ring( 12, 15, 60, 40 ), ...ring( 10, 12, 20, - 90 ) ], [ 120, 136, 148 ] ],
	degenerate: [ [ 0, 0, 1, 1, 2, 2 ], null ],
	selfIntersecting: [ [ 0, 0, 10, 10, 10, 0, 0, 10 ], null ],
	duplicates: [ [ 0, 0, 5, 0, 5, 0, 5, 5, 0, 5, 0, 0 ], null ],
	touchingHole: [ [ 0, 0, 10, 0, 10, 10, 0, 10, 0, 5, 5, 3, 5, 7 ], [ 4 ] ],
	dim3: [ [ 0, 0, 9, 4, 0, 9, 4, 4, 9, 0, 4, 9 ], null, 3 ]
};
// JSON has no NaN or Infinity: non-finite numbers are written as strings.
const finite = ( v ) => Number.isFinite( v ) ? v : String( v );

out.earcut = {};
for ( const [ k, [ data, holes, dim ] ] of Object.entries( cases ) ) {

	const tri = Earcut.triangulate( data, holes, dim );
	out.earcut[ k ] = { data, holes, dim: dim ?? 2, triangles: tri, deviation: finite( earcutLib.deviation( data, holes, dim ?? 2, tri ) ) };

}

out.flatten = earcutLib.flatten( [ [ [ 0, 0 ], [ 10, 0 ], [ 10, 10 ] ], [ [ 1, 1 ], [ 2, 1 ], [ 1, 2 ] ] ] );

// TextureUtils.getByteLength
const fmts = Object.entries( K ).filter( ( [ k ] ) => /Format$/.test( k ) ).map( ( [ k, v ] ) => [ k, v ] );
const types = [ 'UnsignedByteType', 'ShortType', 'UnsignedShort4444Type', 'FloatType', 'UnsignedInt5999Type' ];
out.byteLength = [];
for ( const [ fk, fv ] of fmts ) {

	for ( const tk of types ) {

		let r;
		try { r = TextureUtils.getByteLength( 37, 21, fv, K[ tk ] ); } catch ( e ) { r = 'throws:' + e.message; }
		out.byteLength.push( [ fk, tk, r ] );

	}

}

try {
	TextureUtils.getByteLength( 4, 4, K.RGBAFormat, 9999 );
} catch ( e ) {
	out.badType = e.message.replaceAll( 'THREE.', 'ENT.' );
}

// contain/cover
const tex = ( w, h ) => ( { image: { width: w, height: h }, repeat: new Vector2(), offset: new Vector2() } );
out.fit = [ [ 200, 100, 1.5 ], [ 100, 200, 1.5 ], [ 0, 100, 2 ], [ 300, 300, 1 ] ].map( ( [ w, h, a ] ) => {

	const c = TextureUtils.contain( tex( w, h ), a );
	const v = TextureUtils.cover( tex( w, h ), a );
	return { w, h, a, contain: [ c.repeat.x, c.repeat.y, c.offset.x, c.offset.y ], cover: [ v.repeat.x, v.repeat.y, v.offset.x, v.offset.y ] };

} );

writeFileSync( new URL( 'extras_reference.json', import.meta.url ), JSON.stringify( out, null, '\t' ) + '\n' );
