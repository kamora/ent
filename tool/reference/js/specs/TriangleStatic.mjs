// Reference cases for the static members of src/math/Triangle.js. Dart renames them with a `Static`
// suffix, because a Dart class cannot have a static and an instance member of the same name (E-STATIC).
// getInterpolatedAttribute needs BufferAttribute (M2).

const src = '../../../../third_party/three.js/src/math/';

const { Triangle } = await import( src + 'Triangle.js' );
const { Vector3 } = await import( src + 'Vector3.js' );

const v3 = ( r ) => new Vector3( r.num(), r.num(), r.num() );
const collinear = () => [ new Vector3( 0, 0, 0 ), new Vector3( 1, 1, 1 ), new Vector3( 2, 2, 2 ) ];

// A triangle and a point in its plane, inside it or slightly outside.
function inPlane( r ) {

	const [ a, b, c ] = [ v3( r ), v3( r ), v3( r ) ];
	const u = r.range( - 0.2, 1 ), v = r.range( - 0.2, 1 - u );
	return [ a.clone().multiplyScalar( 1 - u - v ).addScaledVector( b, u ).addScaledVector( c, v ), a, b, c ];

}

export default {
	name: 'Triangle',
	fixture: 'TriangleStatic',
	static: Triangle,
	cases: 20,
	methods: [
		{
			name: 'getNormal', dart: 'getNormalStatic', args: [ 'Vector3', 'Vector3', 'Vector3', 'Vector3' ],
			edge: [ () => ( { args: [ ...collinear(), new Vector3() ] } ) ]
		},
		{
			name: 'getBarycoord', dart: 'getBarycoordStatic', args: ( r ) => [ ...inPlane( r ), new Vector3() ],
			edge: [ () => ( { args: [ new Vector3( 1, 1, 1 ), ...collinear(), new Vector3() ] } ) ]
		},
		{
			name: 'containsPoint', dart: 'containsPointStatic', args: inPlane,
			edge: [ () => ( { args: [ new Vector3( 1, 1, 1 ), ...collinear() ] } ) ]
		},
		{
			name: 'getInterpolation', dart: 'getInterpolationStatic', args: ( r ) => [ ...inPlane( r ), v3( r ), v3( r ), v3( r ), new Vector3() ],
			edge: [ () => ( { args: [ new Vector3( 1, 1, 1 ), ...collinear(), new Vector3( 1, 0, 0 ), new Vector3( 0, 1, 0 ), new Vector3( 0, 0, 1 ), new Vector3() ] } ) ]
		},
		{ name: 'isFrontFacing', dart: 'isFrontFacingStatic', args: [ 'Vector3', 'Vector3', 'Vector3', 'Vector3' ] }
	]
};
