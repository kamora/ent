// Writes fixtures/values/geometries.json: the index, every attribute and the groups of each geometry generator of the
// pinned src/geometries, for several parameter sets, for packages/ent/test/geometries/reference_test.dart.
// Each case is a recipe the Dart test rebuilds the same way (see `build` below and its Dart twin).
//
// Usage: node tool/reference/js/geometries.mjs

import { writeFileSync } from 'node:fs';

const src = '../../../third_party/three.js/src/';

const { BoxGeometry } = await import( src + 'geometries/BoxGeometry.js' );
const { CapsuleGeometry } = await import( src + 'geometries/CapsuleGeometry.js' );
const { CircleGeometry } = await import( src + 'geometries/CircleGeometry.js' );
const { ConeGeometry } = await import( src + 'geometries/ConeGeometry.js' );
const { CylinderGeometry } = await import( src + 'geometries/CylinderGeometry.js' );
const { DodecahedronGeometry } = await import( src + 'geometries/DodecahedronGeometry.js' );
const { EdgesGeometry } = await import( src + 'geometries/EdgesGeometry.js' );
const { ExtrudeGeometry } = await import( src + 'geometries/ExtrudeGeometry.js' );
const { IcosahedronGeometry } = await import( src + 'geometries/IcosahedronGeometry.js' );
const { LatheGeometry } = await import( src + 'geometries/LatheGeometry.js' );
const { OctahedronGeometry } = await import( src + 'geometries/OctahedronGeometry.js' );
const { PlaneGeometry } = await import( src + 'geometries/PlaneGeometry.js' );
const { PolyhedronGeometry } = await import( src + 'geometries/PolyhedronGeometry.js' );
const { RingGeometry } = await import( src + 'geometries/RingGeometry.js' );
const { ShapeGeometry } = await import( src + 'geometries/ShapeGeometry.js' );
const { SphereGeometry } = await import( src + 'geometries/SphereGeometry.js' );
const { TetrahedronGeometry } = await import( src + 'geometries/TetrahedronGeometry.js' );
const { TorusGeometry } = await import( src + 'geometries/TorusGeometry.js' );
const { TorusKnotGeometry } = await import( src + 'geometries/TorusKnotGeometry.js' );
const { TubeGeometry } = await import( src + 'geometries/TubeGeometry.js' );
const { WireframeGeometry } = await import( src + 'geometries/WireframeGeometry.js' );
const { Shape } = await import( src + 'extras/core/Shape.js' );
const { Path } = await import( src + 'extras/core/Path.js' );
const { Vector2 } = await import( src + 'math/Vector2.js' );
const { Vector3 } = await import( src + 'math/Vector3.js' );
const Curves = await import( src + 'extras/curves/Curves.js' );

const PI = Math.PI;

// ---------------------------------------------------------------- recipes

// A path drawn by commands: [ name, ...numbers ] or [ 'splineThru', [ [ x, y ], ... ] ].
function draw( path, commands ) {

	for ( const [ name, ...args ] of commands ) {

		if ( name === 'splineThru' ) {

			path.splineThru( args[ 0 ].map( ( [ x, y ] ) => new Vector2( x, y ) ) );

		} else {

			path[ name ]( ...args );

		}

	}

	return path;

}

function shape( recipe ) {

	const s = draw( new Shape(), recipe.commands );

	for ( const hole of recipe.holes ?? [] ) {

		s.holes.push( draw( new Path(), hole ) );

	}

	return s;

}

function curve( recipe ) {

	const points = ( recipe.points ?? [] ).map( ( [ x, y, z ] ) => new Vector3( x, y, z ) );

	switch ( recipe.type ) {

		case 'CatmullRomCurve3': return new Curves.CatmullRomCurve3( points, recipe.closed, recipe.curveType, recipe.tension );
		case 'LineCurve3': return new Curves.LineCurve3( ...points );
		case 'QuadraticBezierCurve3': return new Curves.QuadraticBezierCurve3( ...points );
		case 'CubicBezierCurve3': return new Curves.CubicBezierCurve3( ...points );

	}

	throw new Error( 'unknown curve ' + recipe.type );

}

function build( recipe ) {

	const a = recipe.args ?? [];

	switch ( recipe.class ) {

		case 'BoxGeometry': return new BoxGeometry( ...a );
		case 'CapsuleGeometry': return new CapsuleGeometry( ...a );
		case 'CircleGeometry': return new CircleGeometry( ...a );
		case 'ConeGeometry': return new ConeGeometry( ...a );
		case 'CylinderGeometry': return new CylinderGeometry( ...a );
		case 'DodecahedronGeometry': return new DodecahedronGeometry( ...a );
		case 'IcosahedronGeometry': return new IcosahedronGeometry( ...a );
		case 'OctahedronGeometry': return new OctahedronGeometry( ...a );
		case 'TetrahedronGeometry': return new TetrahedronGeometry( ...a );
		case 'PlaneGeometry': return new PlaneGeometry( ...a );
		case 'PolyhedronGeometry': return new PolyhedronGeometry( ...a );
		case 'RingGeometry': return new RingGeometry( ...a );
		case 'SphereGeometry': return new SphereGeometry( ...a );
		case 'TorusGeometry': return new TorusGeometry( ...a );
		case 'TorusKnotGeometry': return new TorusKnotGeometry( ...a );
		case 'LatheGeometry': return new LatheGeometry( recipe.points?.map( ( [ x, y ] ) => new Vector2( x, y ) ), ...a );
		case 'ShapeGeometry': return new ShapeGeometry( recipe.shapes ? recipe.shapes.map( shape ) : recipe.shape ? shape( recipe.shape ) : undefined, ...a );
		case 'ExtrudeGeometry': {

			const options = { ...recipe.options };

			if ( options.extrudePath ) {

				options.extrudePath = curve( options.extrudePath );

			}

			return new ExtrudeGeometry( recipe.shapes ? recipe.shapes.map( shape ) : recipe.shape ? shape( recipe.shape ) : undefined, options );

		}

		case 'TubeGeometry': return new TubeGeometry( recipe.path ? curve( recipe.path ) : undefined, ...a );
		case 'EdgesGeometry': return new EdgesGeometry( build( recipe.of ), ...a );
		case 'WireframeGeometry': return new WireframeGeometry( build( recipe.of ) );
		case 'toNonIndexed': return build( recipe.of ).toNonIndexed();

	}

	throw new Error( 'unknown recipe ' + recipe.class );

}

// ---------------------------------------------------------------- cases

const square = { commands: [ [ 'moveTo', 0, 0 ], [ 'lineTo', 0, 1 ], [ 'lineTo', 1, 1 ], [ 'lineTo', 1, 0 ], [ 'lineTo', 0, 0 ] ] };

const heart = { commands: [
	[ 'moveTo', 2.5, 2.5 ], [ 'bezierCurveTo', 2.5, 2.5, 2, 0, 0, 0 ], [ 'bezierCurveTo', - 3, 0, - 3, 3.5, - 3, 3.5 ],
	[ 'bezierCurveTo', - 3, 5.5, - 1, 7.7, 2.5, 9.5 ], [ 'bezierCurveTo', 6, 7.7, 8, 5.5, 8, 3.5 ],
	[ 'bezierCurveTo', 8, 3.5, 8, 0, 5, 0 ], [ 'bezierCurveTo', 3.5, 0, 2.5, 2.5, 2.5, 2.5 ]
] };

const ring = {
	commands: [ [ 'moveTo', 2, 0 ], [ 'absarc', 0, 0, 2, 0, PI * 2, false ] ],
	holes: [ [ [ 'moveTo', 1, 0 ], [ 'absarc', 0, 0, 1, 0, PI * 2, true ] ] ]
};

const blob = { commands: [ [ 'moveTo', 0, 0 ], [ 'quadraticCurveTo', 1, 2, 2, 0 ], [ 'splineThru', [ [ 3, 1 ], [ 2, 3 ], [ 0, 2 ] ] ], [ 'lineTo', 0, 0 ] ] };

const clockwise = { commands: [ [ 'moveTo', 0, 0 ], [ 'lineTo', 1, 0 ], [ 'lineTo', 1, 1 ], [ 'lineTo', 0, 1 ] ] };

const spline = { type: 'CatmullRomCurve3', points: [ [ - 4, 0, 0 ], [ - 2, 2, 1 ], [ 0, 0, 2 ], [ 2, - 2, 1 ], [ 4, 0, 0 ] ], closed: false, curveType: 'centripetal', tension: 0.5 };
const loop = { type: 'CatmullRomCurve3', points: [ [ 2, 0, 0 ], [ 0, 2, 1 ], [ - 2, 0, 0 ], [ 0, - 2, - 1 ] ], closed: true, curveType: 'catmullrom', tension: 0.3 };

const cases = [

	{ class: 'BoxGeometry' },
	{ class: 'BoxGeometry', args: [ 10, 20, 30, 2, 3, 4 ] },
	{ class: 'BoxGeometry', args: [ 1.5, - 2, 0.25, 3, 1, 2 ] },

	{ class: 'CapsuleGeometry' },
	{ class: 'CapsuleGeometry', args: [ 0.5, 2, 3, 6, 2 ] },
	{ class: 'CapsuleGeometry', args: [ 1, - 1, 1, 3, 1 ] },

	{ class: 'CircleGeometry' },
	{ class: 'CircleGeometry', args: [ 2, 7, 0.5, PI ] },
	{ class: 'CircleGeometry', args: [ 1, 1 ] },

	{ class: 'ConeGeometry', args: [ 1, 2, 8 ] },
	{ class: 'ConeGeometry', args: [ 2, 3, 5, 3, true, 0.25, PI ] },

	{ class: 'CylinderGeometry', args: [ 1, 1, 1, 8 ] },
	{ class: 'CylinderGeometry', args: [ 0.5, 1.5, 2, 6, 3, false, 0.3, 4 ] },
	{ class: 'CylinderGeometry', args: [ 1, 0, 2, 5, 2 ] },
	{ class: 'CylinderGeometry', args: [ 1, 2, 1, 4, 1, true ] },

	{ class: 'DodecahedronGeometry' },
	{ class: 'DodecahedronGeometry', args: [ 2, 1 ] },
	{ class: 'IcosahedronGeometry' },
	{ class: 'IcosahedronGeometry', args: [ 1.5, 2 ] },
	{ class: 'OctahedronGeometry', args: [ 1, 1 ] },
	{ class: 'OctahedronGeometry', args: [ 3, 0 ] },
	{ class: 'TetrahedronGeometry' },
	{ class: 'TetrahedronGeometry', args: [ 1, 3 ] },
	{ class: 'PolyhedronGeometry', args: [ [ 1, 1, 1, - 1, - 1, 1, - 1, 1, - 1, 1, - 1, - 1 ], [ 2, 1, 0, 0, 3, 2, 1, 3, 0, 2, 3, 1 ], 2, 1 ] },

	{ class: 'LatheGeometry' },
	{ class: 'LatheGeometry', points: [ [ 0.1, - 1 ], [ 0.6, - 0.6 ], [ 0.4, 0 ], [ 0.8, 0.7 ], [ 0.2, 1 ] ], args: [ 9, 0.2, 5 ] },
	{ class: 'LatheGeometry', points: [ [ 1, 0 ], [ 1, 1 ] ], args: [ 4, 0, 8 ] },

	{ class: 'PlaneGeometry' },
	{ class: 'PlaneGeometry', args: [ 4, 2, 3, 2 ] },

	{ class: 'RingGeometry' },
	{ class: 'RingGeometry', args: [ 0.25, 2, 5, 3, 0.5, 3 ] },

	{ class: 'SphereGeometry', args: [ 1, 8, 6 ] },
	{ class: 'SphereGeometry', args: [ 2, 5, 4, 0.5, 4, 0.3, 2 ] },
	{ class: 'SphereGeometry', args: [ 1, 6, 4, 0, PI * 2, 0, PI / 2 ] },

	{ class: 'TorusGeometry', args: [ 1, 0.4, 6, 12 ] },
	{ class: 'TorusGeometry', args: [ 2, 0.5, 4, 9, PI, 0.5, 3 ] },

	{ class: 'TorusKnotGeometry', args: [ 1, 0.4, 24, 6 ] },
	{ class: 'TorusKnotGeometry', args: [ 2, 0.3, 30, 5, 3, 7 ] },

	{ class: 'ShapeGeometry' },
	{ class: 'ShapeGeometry', shape: heart, args: [ 6 ] },
	{ class: 'ShapeGeometry', shape: ring, args: [ 8 ] },
	{ class: 'ShapeGeometry', shapes: [ square, blob, clockwise ], args: [ 5 ] },

	{ class: 'ExtrudeGeometry' },
	{ class: 'ExtrudeGeometry', shape: square, options: { steps: 2, depth: 3, bevelEnabled: true, bevelThickness: 0.3, bevelSize: 0.2, bevelOffset: 0.05, bevelSegments: 2 } },
	{ class: 'ExtrudeGeometry', shape: heart, options: { depth: 1, bevelEnabled: false, curveSegments: 4 } },
	{ class: 'ExtrudeGeometry', shape: ring, options: { curveSegments: 6, bevelSegments: 1 } },
	{ class: 'ExtrudeGeometry', shapes: [ square, blob ], options: { curveSegments: 3, steps: 1, bevelThickness: 0.1 } },
	{ class: 'ExtrudeGeometry', shape: { commands: [ [ 'moveTo', 0, 0 ], [ 'lineTo', 0.5, 0 ], [ 'lineTo', 0.5, 0.5 ], [ 'lineTo', 0, 0.5 ] ] }, options: { steps: 6, extrudePath: spline } },
	{ class: 'ExtrudeGeometry', shape: { commands: [ [ 'moveTo', 0, 0 ], [ 'lineTo', 0.4, 0 ], [ 'lineTo', 0.2, 0.3 ] ] }, options: { steps: 8, extrudePath: loop } },

	{ class: 'TubeGeometry', args: [ 8, 0.5, 4 ] },
	{ class: 'TubeGeometry', path: spline, args: [ 12, 0.3, 5, false ] },
	{ class: 'TubeGeometry', path: loop, args: [ 10, 0.25, 6, true ] },
	{ class: 'TubeGeometry', path: { type: 'LineCurve3', points: [ [ 0, 0, 0 ], [ 0, 1, 0 ] ] }, args: [ 3, 1, 4 ] },
	{ class: 'TubeGeometry', path: { type: 'CubicBezierCurve3', points: [ [ - 1, 0, 0 ], [ - 1, 2, 1 ], [ 1, 2, - 1 ], [ 1, 0, 0 ] ] }, args: [ 7, 0.2, 3 ] },

	{ class: 'EdgesGeometry', of: { class: 'BoxGeometry' } },
	{ class: 'EdgesGeometry', of: { class: 'SphereGeometry', args: [ 1, 8, 6 ] }, args: [ 15 ] },
	{ class: 'EdgesGeometry', of: { class: 'toNonIndexed', of: { class: 'BoxGeometry', args: [ 1, 1, 1, 2, 2, 1 ] } }, args: [ 1 ] },
	{ class: 'EdgesGeometry', of: { class: 'CylinderGeometry', args: [ 1, 1, 2, 6, 2 ] }, args: [ 30 ] },
	{ class: 'EdgesGeometry', of: { class: 'ExtrudeGeometry', shape: ring, options: { curveSegments: 6, bevelSegments: 1 } }, args: [ 20 ] },

	{ class: 'WireframeGeometry', of: { class: 'BoxGeometry', args: [ 1, 1, 1, 2, 1, 1 ] } },
	{ class: 'WireframeGeometry', of: { class: 'PlaneGeometry', args: [ 2, 2, 2, 2 ] } },
	{ class: 'WireframeGeometry', of: { class: 'OctahedronGeometry' } },
	{ class: 'WireframeGeometry', of: { class: 'toNonIndexed', of: { class: 'PlaneGeometry', args: [ 1, 1, 2, 1 ] } } },
	{ class: 'WireframeGeometry', of: { class: 'TorusGeometry', args: [ 1, 0.4, 4, 6 ] } }

];

function dump( geometry ) {

	const index = geometry.getIndex();
	const attributes = {};

	for ( const name of Object.keys( geometry.attributes ).sort() ) {

		const attribute = geometry.attributes[ name ];
		attributes[ name ] = { itemSize: attribute.itemSize, type: attribute.array.constructor.name, array: Array.from( attribute.array, encode ) };

	}

	return {
		type: geometry.type,
		index: index ? { type: index.array.constructor.name, array: Array.from( index.array ) } : null,
		attributes,
		groups: geometry.groups.map( ( g ) => [ g.start, g.count, g.materialIndex ] )
	};

}

function encode( v ) {

	if ( Number.isNaN( v ) ) {

		return 'NaN';

	}

	if ( ! Number.isFinite( v ) ) {

		return v > 0 ? 'Infinity' : '-Infinity';

	}

	return Object.is( v, - 0 ) ? '-0' : v;

}

const out = cases.map( ( recipe ) => ( { recipe, expected: dump( build( recipe ) ) } ) );

writeFileSync( new URL( '../../../fixtures/values/geometries.json', import.meta.url ), JSON.stringify( { reference: 'r187', cases: out }, null, '\t' ) + '\n' );

const numbers = out.reduce( ( n, c ) => n + Object.values( c.expected.attributes ).reduce( ( m, a ) => m + a.array.length, 0 ) + ( c.expected.index?.array.length ?? 0 ), 0 );
console.log( out.length + ' geometries, ' + numbers + ' numbers' );
