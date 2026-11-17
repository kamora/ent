// Value types from src/math: how fixtures generate them and the state they record.
// The state layouts are mirrored by packages/ent/test/support/codecs.dart.

const src = '../../../../third_party/three.js/src/math/';

const { Vector2 } = await import( src + 'Vector2.js' );
const { Vector3 } = await import( src + 'Vector3.js' );
const { Vector4 } = await import( src + 'Vector4.js' );
const { Quaternion } = await import( src + 'Quaternion.js' );
const { Euler } = await import( src + 'Euler.js' );
const { Matrix2 } = await import( src + 'Matrix2.js' );
const { Matrix3 } = await import( src + 'Matrix3.js' );
const { Matrix4 } = await import( src + 'Matrix4.js' );
const { Color } = await import( src + 'Color.js' );
const { Box2 } = await import( src + 'Box2.js' );
const { Box3 } = await import( src + 'Box3.js' );
const { Sphere } = await import( src + 'Sphere.js' );
const { Plane } = await import( src + 'Plane.js' );
const { Ray } = await import( src + 'Ray.js' );
const { Triangle } = await import( src + 'Triangle.js' );
const { Line3 } = await import( src + 'Line3.js' );
const { Spherical } = await import( src + 'Spherical.js' );
const { Cylindrical } = await import( src + 'Cylindrical.js' );
const { Frustum } = await import( src + 'Frustum.js' );
const { SphericalHarmonics3 } = await import( src + 'SphericalHarmonics3.js' );

const ORDERS = [ 'XYZ', 'YXZ', 'ZXY', 'ZYX', 'YZX', 'XZY' ];

const v2 = ( r ) => new Vector2( r.num(), r.num() );
const v3 = ( r ) => new Vector3( r.num(), r.num(), r.num() );
const unit3 = ( r ) => new Vector3( r.range( - 1, 1 ), r.range( - 1, 1 ), r.range( - 1, 1 ) ).normalize();
const quat = ( r ) => new Quaternion().setFromAxisAngle( unit3( r ), r.range( - Math.PI, Math.PI ) );
const xyz = ( v, e ) => [ e( v.x ), e( v.y ), e( v.z ) ];
const elements = ( m, e ) => m.elements.map( e );

function matrix4( r ) {

	if ( r.next() < 0.5 ) {

		const scale = new Vector3( r.range( 0.1, 3 ), r.range( 0.1, 3 ), r.range( 0.1, 3 ) );
		return new Matrix4().compose( v3( r ), quat( r ), scale );

	}

	return new Matrix4().fromArray( Array.from( { length: 16 }, () => r.num() ) );

}

function box( r, Box, vector ) {

	if ( r.next() < 0.1 ) {

		return new Box();

	}

	const min = vector( r );
	const size = min.toArray().map( () => r.range( 0, 5 ) );
	return new Box( min, min.clone().add( new min.constructor( ...size ) ) );

}

export default {

	Vector2: {
		is: ( v ) => v?.isVector2 === true,
		encode: ( v, e ) => [ e( v.x ), e( v.y ) ],
		gen: v2
	},

	Vector3: {
		is: ( v ) => v?.isVector3 === true,
		encode: xyz,
		gen: v3
	},

	Vector4: {
		is: ( v ) => v?.isVector4 === true,
		encode: ( v, e ) => [ e( v.x ), e( v.y ), e( v.z ), e( v.w ) ],
		gen: ( r ) => new Vector4( r.num(), r.num(), r.num(), r.num() )
	},

	Quaternion: {
		is: ( v ) => v?.isQuaternion === true,
		encode: ( v, e ) => [ e( v.x ), e( v.y ), e( v.z ), e( v.w ) ],
		gen: ( r ) => r.next() < 0.8 ? quat( r ) : new Quaternion( r.num(), r.num(), r.num(), r.num() )
	},

	Euler: {
		is: ( v ) => v?.isEuler === true,
		encode: ( v, e ) => [ e( v.x ), e( v.y ), e( v.z ), v.order ],
		gen: ( r ) => new Euler( r.range( - Math.PI, Math.PI ), r.range( - Math.PI, Math.PI ), r.range( - Math.PI, Math.PI ), r.pick( ORDERS ) )
	},

	Matrix2: {
		is: ( v ) => v?.isMatrix2 === true,
		encode: elements,
		gen: ( r ) => new Matrix2().fromArray( Array.from( { length: 4 }, () => r.num() ) )
	},

	Matrix3: {
		is: ( v ) => v?.isMatrix3 === true,
		encode: elements,
		gen: ( r ) => new Matrix3().fromArray( Array.from( { length: 9 }, () => r.num() ) )
	},

	Matrix4: {
		is: ( v ) => v?.isMatrix4 === true,
		encode: elements,
		gen: matrix4
	},

	Color: {
		is: ( v ) => v?.isColor === true,
		encode: ( v, e ) => [ e( v.r ), e( v.g ), e( v.b ) ],
		gen: ( r ) => new Color( r.unit(), r.unit(), r.unit() )
	},

	Box2: {
		is: ( v ) => v?.isBox2 === true,
		encode: ( v, e ) => [ e( v.min.x ), e( v.min.y ), e( v.max.x ), e( v.max.y ) ],
		gen: ( r ) => box( r, Box2, v2 )
	},

	Box3: {
		is: ( v ) => v?.isBox3 === true,
		encode: ( v, e ) => [ ...xyz( v.min, e ), ...xyz( v.max, e ) ],
		gen: ( r ) => box( r, Box3, v3 )
	},

	Sphere: {
		is: ( v ) => v?.isSphere === true,
		encode: ( v, e ) => [ ...xyz( v.center, e ), e( v.radius ) ],
		gen: ( r ) => new Sphere( v3( r ), r.range( 0, 5 ) )
	},

	Plane: {
		is: ( v ) => v?.isPlane === true,
		encode: ( v, e ) => [ ...xyz( v.normal, e ), e( v.constant ) ],
		gen: ( r ) => new Plane( unit3( r ), r.num() )
	},

	Ray: {
		is: ( v ) => v instanceof Ray, // upstream has no isRay flag
		encode: ( v, e ) => [ ...xyz( v.origin, e ), ...xyz( v.direction, e ) ],
		gen: ( r ) => new Ray( v3( r ), unit3( r ) )
	},

	Triangle: {
		is: ( v ) => v instanceof Triangle, // upstream has no isTriangle flag
		encode: ( v, e ) => [ ...xyz( v.a, e ), ...xyz( v.b, e ), ...xyz( v.c, e ) ],
		gen: ( r ) => new Triangle( v3( r ), v3( r ), v3( r ) )
	},

	Line3: {
		is: ( v ) => v instanceof Line3, // upstream has no isLine3 flag
		encode: ( v, e ) => [ ...xyz( v.start, e ), ...xyz( v.end, e ) ],
		gen: ( r ) => new Line3( v3( r ), v3( r ) )
	},

	Spherical: {
		is: ( v ) => v instanceof Spherical, // upstream has no isSpherical flag
		encode: ( v, e ) => [ e( v.radius ), e( v.phi ), e( v.theta ) ],
		gen: ( r ) => new Spherical( r.range( 0, 10 ), r.range( 0, Math.PI ), r.range( - Math.PI, Math.PI ) )
	},

	Cylindrical: {
		is: ( v ) => v instanceof Cylindrical, // upstream has no isCylindrical flag
		encode: ( v, e ) => [ e( v.radius ), e( v.theta ), e( v.y ) ],
		gen: ( r ) => new Cylindrical( r.range( 0, 10 ), r.range( - Math.PI, Math.PI ), r.num() )
	},

	Frustum: {
		is: ( v ) => v instanceof Frustum, // upstream has no isFrustum flag
		encode: ( v, e ) => v.planes.flatMap( ( p ) => [ ...xyz( p.normal, e ), e( p.constant ) ] ),
		gen: ( r ) => {

			const near = r.range( 0.1, 2 );
			const projection = new Matrix4().makePerspective( - r.range( 0.1, 2 ), r.range( 0.1, 2 ), r.range( 0.1, 2 ), - r.range( 0.1, 2 ), near, near + r.range( 1, 100 ) );
			const view = new Matrix4().compose( v3( r ), quat( r ), new Vector3( 1, 1, 1 ) ).invert();
			return new Frustum().setFromProjectionMatrix( projection.multiply( view ) );

		}
	},

	SphericalHarmonics3: {
		is: ( v ) => v?.isSphericalHarmonics3 === true,
		encode: ( v, e ) => v.coefficients.flatMap( ( c ) => xyz( c, e ) ),
		gen: ( r ) => new SphericalHarmonics3().set( Array.from( { length: 9 }, () => v3( r ) ) )
	}

};
