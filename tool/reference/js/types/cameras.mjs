// Camera types from src/cameras: how fixtures generate them and the state they record.
// The state layouts are mirrored by packages/ent/test/support/codecs/cameras.dart.
//
// Object3D part (every camera):  position 3, quaternion 4, scale 3, up 3, rotation x y z order,
//   matrix 16, matrixWorld 16, matrixAutoUpdate, matrixWorldNeedsUpdate, layers.mask        (52)
// Camera part:                    matrixWorldInverse 16, projectionMatrix 16, projectionMatrixInverse 16,
//   coordinateSystem, reversedDepth                                                          (50)
// PerspectiveCamera:              fov, zoom, near, far, focus, aspect, filmGauge, filmOffset, view 7
// OrthographicCamera:             left, right, top, bottom, near, far, zoom, view 7
// view: enabled, fullWidth, fullHeight, offsetX, offsetY, width, height, or 7 nulls when there is none.

const src = '../../../../third_party/three.js/src/';

const { Vector3 } = await import( src + 'math/Vector3.js' );
const { Quaternion } = await import( src + 'math/Quaternion.js' );
const { PerspectiveCamera } = await import( src + 'cameras/PerspectiveCamera.js' );
const { OrthographicCamera } = await import( src + 'cameras/OrthographicCamera.js' );
const { StereoCamera } = await import( src + 'cameras/StereoCamera.js' );
const { CubeCamera } = await import( src + 'cameras/CubeCamera.js' );

const WebGL = 2000;
const WebGPU = 2001;

const xyz = ( v, e ) => [ e( v.x ), e( v.y ), e( v.z ) ];
const m16 = ( m, e ) => m.elements.map( e );

function object3d( o, e ) {

	const q = o.quaternion;
	const r = o.rotation;

	return [
		...xyz( o.position, e ), e( q.x ), e( q.y ), e( q.z ), e( q.w ), ...xyz( o.scale, e ), ...xyz( o.up, e ),
		e( r.x ), e( r.y ), e( r.z ), r.order,
		...m16( o.matrix, e ), ...m16( o.matrixWorld, e ), o.matrixAutoUpdate, o.matrixWorldNeedsUpdate, e( o.layers.mask )
	];

}

function camera( c, e ) {

	return [
		...object3d( c, e ),
		...m16( c.matrixWorldInverse, e ), ...m16( c.projectionMatrix, e ), ...m16( c.projectionMatrixInverse, e ),
		e( c.coordinateSystem ), c.reversedDepth
	];

}

function view( v, e ) {

	return v === null ? Array( 7 ).fill( null ) : [ v.enabled, e( v.fullWidth ), e( v.fullHeight ), e( v.offsetX ), e( v.offsetY ), e( v.width ), e( v.height ) ];

}

function perspective( c, e ) {

	return [
		...camera( c, e ),
		e( c.fov ), e( c.zoom ), e( c.near ), e( c.far ), e( c.focus ), e( c.aspect ), e( c.filmGauge ), e( c.filmOffset ),
		...view( c.view, e )
	];

}

function orthographic( c, e ) {

	return [
		...camera( c, e ),
		e( c.left ), e( c.right ), e( c.top ), e( c.bottom ), e( c.near ), e( c.far ), e( c.zoom ),
		...view( c.view, e )
	];

}

// A random placement: position, rotation, sometimes a non-unit scale (the glTF branch of
// Camera.updateMatrixWorld), sometimes a stale world matrix.
function place( r, c ) {

	c.position.set( r.num(), r.num(), r.num() );
	c.quaternion.setFromAxisAngle( new Vector3( r.range( - 1, 1 ), r.range( - 1, 1 ), r.range( - 1, 1 ) ).normalize(), r.range( - Math.PI, Math.PI ) );

	if ( r.next() < 0.3 ) {

		c.scale.set( r.range( 0.5, 2 ), r.range( 0.5, 2 ), r.range( 0.5, 2 ) );

	}

	c.updateMatrixWorld();

	if ( r.next() < 0.2 ) {

		c.position.x += 1;

	}

	return c;

}

// Projection settings shared by both camera kinds: coordinate system, reversed depth, view offset.
function project( r, c ) {

	c.coordinateSystem = r.next() < 0.5 ? WebGL : WebGPU;
	c._reversedDepth = r.next() < 0.3;
	c.zoom = r.next() < 0.7 ? 1 : r.range( 0.25, 4 );

	if ( r.next() < 0.3 ) {

		const fullWidth = r.range( 100, 2000 ), fullHeight = r.range( 100, 2000 );
		c.setViewOffset( fullWidth, fullHeight, r.range( 0, fullWidth / 2 ), r.range( 0, fullHeight / 2 ), r.range( 10, fullWidth / 2 ), r.range( 10, fullHeight / 2 ) );

		if ( r.next() < 0.3 ) {

			c.clearViewOffset();

		}

	}

	c.updateProjectionMatrix();

}

export function perspectiveCamera( r ) {

	const near = r.range( 0.01, 2 );
	const c = new PerspectiveCamera( r.range( 10, 120 ), r.range( 0.3, 3 ), near, near + r.range( 1, 1000 ) );

	if ( r.next() < 0.3 ) {

		c.filmOffset = r.range( - 10, 10 );

	}

	if ( r.next() < 0.2 ) {

		c.focus = r.range( 0.5, 50 );

	}

	project( r, c );

	// Sometimes a changed property whose projection was not updated yet.
	if ( r.next() < 0.2 ) {

		c.fov = r.range( 10, 120 );

	}

	return place( r, c );

}

export function orthographicCamera( r ) {

	const near = r.range( 0, 2 );
	const c = new OrthographicCamera( - r.range( 0.5, 20 ), r.range( 0.5, 20 ), r.range( 0.5, 20 ), - r.range( 0.5, 20 ), near, near + r.range( 1, 1000 ) );
	project( r, c );

	if ( r.next() < 0.2 ) {

		c.left = - r.range( 0.5, 20 );

	}

	return place( r, c );

}

const PX = 6;

export default {

	PerspectiveCamera: {
		is: ( v ) => v?.isPerspectiveCamera === true && v.isArrayCamera !== true,
		encode: perspective,
		gen: perspectiveCamera
	},

	OrthographicCamera: {
		is: ( v ) => v?.isOrthographicCamera === true,
		encode: orthographic,
		gen: orthographicCamera
	},

	// aspect, eyeSep, cache 7 (focus fov aspect near far zoom eyeSep, null before the first update),
	// cameraL perspective state, cameraR perspective state
	StereoCamera: {
		is: ( v ) => v instanceof StereoCamera,
		encode: ( s, e ) => {

			const c = s._cache;
			const cache = [ c.focus, c.fov, c.aspect, c.near, c.far, c.zoom, c.eyeSep ].map( ( x ) => x === null ? null : e( x ) );
			return [ e( s.aspect ), e( s.eyeSep ), ...cache, ...perspective( s.cameraL, e ), ...perspective( s.cameraR, e ) ];

		},
		gen: ( r ) => {

			const s = new StereoCamera();
			s.aspect = r.next() < 0.5 ? 1 : r.range( 0.5, 2 );
			s.eyeSep = r.range( 0.01, 0.2 );

			if ( r.next() < 0.5 ) {

				s.update( perspectiveCamera( r ) );

			}

			return s;

		}
	},

	// coordinateSystem (null or a number), activeMipmapLevel, the cube camera's own Object3D state, then the
	// perspective state of its 6 children (in children order).
	CubeCamera: {
		is: ( v ) => v?.type === 'CubeCamera',
		encode: ( c, e ) => {

			if ( c.children.length !== PX ) {

				throw new Error( 'fixture: CubeCamera with ' + c.children.length + ' children' );

			}

			return [
				c.coordinateSystem === null ? null : e( c.coordinateSystem ), e( c.activeMipmapLevel ), ...object3d( c, e ),
				...c.children.flatMap( ( child ) => perspective( child, e ) )
			];

		},
		gen: ( r ) => {

			const near = r.range( 0.01, 2 );
			const c = new CubeCamera( near, near + r.range( 1, 1000 ) );
			c.position.set( r.num(), r.num(), r.num() );
			c.quaternion.copy( new Quaternion().setFromAxisAngle( new Vector3( 0, 1, 0 ), r.range( - Math.PI, Math.PI ) ) );
			c.updateMatrixWorld();

			if ( r.next() < 0.5 ) {

				c.coordinateSystem = r.next() < 0.5 ? WebGL : WebGPU;
				c.updateCoordinateSystem();

			}

			return c;

		}
	}

};
