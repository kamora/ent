// Interpolant receivers from src/math/interpolants: how fixtures generate them and the state they record.
// Mirrored by packages/ent/test/support/codecs/interpolants.dart.
//
// State: [ arrayKind, valueSize, _cachedIndex,
//   n, ...parameterPositions, n, ...sampleValues, n, ...resultBuffer,
//   settings.endingStart, settings.endingEnd (null when settings is null),
//   _weightPrev, _offsetPrev, _weightNext, _offsetNext (CubicInterpolant, else null),
//   n, ...inTangents, n, ...outTangents (BezierInterpolant; n = -1 when the property is unset) ]

import { ZeroCurvatureEnding, ZeroSlopeEnding, WrapAroundEnding } from '../../../../third_party/three.js/src/constants.js';

const src = '../../../../third_party/three.js/src/math/interpolants/';

const { LinearInterpolant } = await import( src + 'LinearInterpolant.js' );
const { DiscreteInterpolant } = await import( src + 'DiscreteInterpolant.js' );
const { CubicInterpolant } = await import( src + 'CubicInterpolant.js' );
const { QuaternionLinearInterpolant } = await import( src + 'QuaternionLinearInterpolant.js' );
const { BezierInterpolant } = await import( src + 'BezierInterpolant.js' );

const ENDINGS = [ ZeroCurvatureEnding, ZeroSlopeEnding, WrapAroundEnding ];
const KINDS = [ 'Float32Array', 'Float64Array', 'Array' ];

// Key times on a 0.5 grid, so that `time()` hits keys exactly now and then.
function positions( r, count ) {

	const list = [ r.pick( [ 0, 0.5, 1, 2 ] ) ];

	while ( list.length < count ) {

		list.push( list[ list.length - 1 ] + r.pick( [ 0.5, 1, 1.5, 2 ] ) );

	}

	return list;

}

function array( kind, values ) {

	return kind === 'Array' ? values : new globalThis[ kind ]( values );

}

// A time before, inside or after the keys; one time in three exactly on the 0.5 grid.
export function time( r ) {

	return r.next() < 0.35 ? r.pick( Array.from( { length: 30 }, ( _, i ) => i * 0.5 - 1.5 ) ) : r.range( - 2, 14 );

}

function build( r, Type, valueSize, sample ) {

	// QuaternionLinearInterpolant with two quaternions per sample writes only result[ 0..3 ] (upstream behaviour);
	// a plain array would keep holes there, which the Dart side cannot represent.
	const kind = r.pick( Type === QuaternionLinearInterpolant && valueSize === 8 ? KINDS.slice( 0, 2 ) : KINDS );
	const pp = positions( r, 1 + Math.floor( r.next() * 7 ) );
	const values = pp.flatMap( () => sample( r, valueSize ) );
	const interpolant = new Type( array( kind, pp ), array( kind, values ), valueSize );

	if ( Type === CubicInterpolant && r.next() < 0.7 ) {

		interpolant.settings = { endingStart: r.pick( ENDINGS ), endingEnd: r.pick( ENDINGS ) };

	}

	if ( Type === BezierInterpolant && r.next() < 0.8 ) {

		const tangents = () => array( kind, pp.flatMap( ( t ) => Array.from( { length: valueSize }, () => [ t + r.range( - 0.5, 0.5 ), r.num() ] ).flat() ) );
		interpolant.inTangents = tangents();
		interpolant.outTangents = tangents();

	}

	// Warm up: leaves a cached index, cubic weights and a fully written result buffer behind.
	for ( let i = 0, n = 1 + Math.floor( r.next() * 3 ); i < n; i ++ ) {

		interpolant.evaluate( time( r ) );

	}

	return interpolant;

}

const scalars = ( r, size ) => Array.from( { length: size }, () => r.num() );

function quaternions( r, size ) {

	const out = [];

	for ( let i = 0; i < size; i += 4 ) {

		const q = [ r.range( - 1, 1 ), r.range( - 1, 1 ), r.range( - 1, 1 ), r.range( - 1, 1 ) ];
		const length = Math.hypot( ...q ) || 1;
		out.push( ...q.map( ( c ) => c / length ) );

	}

	return out;

}

function encode( v, e ) {

	const list = ( a ) => a === undefined ? [ - 1 ] : [ a.length, ...Array.from( a, e ) ];
	const kind = v.sampleValues.constructor.name;
	const cubic = v instanceof CubicInterpolant;
	const bezier = v instanceof BezierInterpolant;

	return [
		kind === 'Array' ? 'Array' : kind,
		v.valueSize,
		v._cachedIndex,
		...list( v.parameterPositions ),
		...list( v.sampleValues ),
		...list( v.resultBuffer ),
		v.settings ? v.settings.endingStart : null,
		v.settings ? v.settings.endingEnd : null,
		cubic ? e( v._weightPrev ) : null,
		cubic ? e( v._offsetPrev ) : null,
		cubic ? e( v._weightNext ) : null,
		cubic ? e( v._offsetNext ) : null,
		...( bezier ? list( v.inTangents ) : [ - 1 ] ),
		...( bezier ? list( v.outTangents ) : [ - 1 ] )
	];

}

const type = ( Type, valueSize, sample ) => ( {
	is: ( v ) => v?.constructor === Type,
	encode,
	gen: ( r ) => build( r, Type, valueSize( r ), sample )
} );

export default {
	LinearInterpolant: type( LinearInterpolant, ( r ) => 1 + Math.floor( r.next() * 3 ), scalars ),
	DiscreteInterpolant: type( DiscreteInterpolant, ( r ) => 1 + Math.floor( r.next() * 3 ), scalars ),
	CubicInterpolant: type( CubicInterpolant, ( r ) => 1 + Math.floor( r.next() * 3 ), scalars ),
	QuaternionLinearInterpolant: type( QuaternionLinearInterpolant, ( r ) => r.next() < 0.8 ? 4 : 8, quaternions ),
	BezierInterpolant: type( BezierInterpolant, ( r ) => 1 + Math.floor( r.next() * 2 ), scalars )
};
