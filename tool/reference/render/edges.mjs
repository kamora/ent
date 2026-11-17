// Lists, per scene, the pixel centres that a silhouette edge passes closer than a threshold (default 0.05
// pixel). The two GPU paths rasterize such pixels differently: ANGLE draws upside down and its edges land
// about 0.02 pixel away from Flutter GPU's (docs/flutter-gpu.md), so a pixel there is covered on one side
// only. On a flat color that is an edge pixel; on a shaded surface (a lit sphere's rim) its color is often
// not found next to it in the reference, and the pixel fails. Run it after changing a scene and move objects
// until their silhouettes keep off pixel centres.
//
// A silhouette edge is an edge of exactly one visible triangle of a mesh (by the material's side), after the
// object's world matrix (after each instance's matrix for an InstancedMesh) and the camera's projection. Vertex
// displacement (displacementMap) and morph targets are not applied.
//
// With --rim <cos>, interior edges near a silhouette count too: those whose two vertex normals face the camera
// less than <cos>. MeshStandardMaterial and MeshPhysicalMaterial derive geometryRoughness from derivatives of the
// normal, which jump from triangle to triangle, steeply in the slivers next to a curved silhouette; a pixel centre
// near such an edge is shaded by the other triangle on the other path.
//
// Usage: node tool/reference/render/edges.mjs [--threshold 0.05] [--rim 0.35] [name ...]

import { register } from 'node:module';

// scenes.mjs imports 'three' through page.html's import map; resolve it to the pinned source here.
register( 'data:text/javascript,' + encodeURIComponent( `
	export async function resolve( specifier, context, next ) {

		return next( specifier === 'three' ? ${ JSON.stringify( new URL( '../../../third_party/three.js/src/Three.js', import.meta.url ).href ) } : specifier, context );

	}
` ) );

// Canvas textures need a 2D context; only geometry matters here.
globalThis.document = {
	createElement: () => ( { getContext: () => new Proxy( {}, { get: () => () => ( { addColorStop() {} } ) } ) } ),
};

const THREE = await import( 'three' );
const { default: scenes, size } = await import( './scenes.mjs' );

const args = process.argv.slice( 2 );
const at = args.indexOf( '--threshold' );
const threshold = at >= 0 ? Number( args.splice( at, 2 )[ 1 ] ) : 0.05;
const rimAt = args.indexOf( '--rim' );
const rim = rimAt >= 0 ? Number( args.splice( rimAt, 2 )[ 1 ] ) : - Infinity;
const names = args.length > 0 ? args : Object.keys( scenes );

for ( const name of names ) {

	const { scene, camera } = scenes[ name ]();
	scene.updateMatrixWorld();
	camera.updateMatrixWorld();

	const near = [];

	scene.traverse( ( object ) => {

		if ( ! object.isMesh || ! object.visible ) return;

		// An InstancedMesh: each of its `count` instances, the instance matrix before the object's.
		const matrices = object.isInstancedMesh ? Array.from( { length: object.count }, ( _, i ) => object.getMatrixAt( i, new THREE.Matrix4() ).premultiply( object.matrixWorld ) ) : [ object.matrixWorld ];

		for ( const matrix of matrices ) {

			const geometry = object.geometry;
			const position = geometry.getAttribute( 'position' );
			const index = geometry.index;
			const count = index ? index.count : position.count;
			const materials = Array.isArray( object.material ) ? object.material : [ object.material ];
			const side = materials[ 0 ].side;
			const mirrored = matrix.determinant() < 0;
			const vector = new THREE.Vector3();

			// How much the vertex normal faces the camera (for --rim).
			const normal = geometry.getAttribute( 'normal' );
			const normalMatrix = new THREE.Matrix3().getNormalMatrix( matrix );
			const eye = new THREE.Vector3().setFromMatrixPosition( camera.matrixWorld );
			const facing = ( i ) => {

				if ( ! normal ) return 1;

				const n = new THREE.Vector3().fromBufferAttribute( normal, i ).applyMatrix3( normalMatrix ).normalize();
				const p = new THREE.Vector3().fromBufferAttribute( position, i ).applyMatrix4( matrix );

				return n.dot( eye.clone().sub( p ).normalize() );

			};

			// Window coordinates, y down, as the frames are stored.
			const screen = ( i ) => {

				vector.fromBufferAttribute( position, i ).applyMatrix4( matrix ).project( camera );

				return [ ( vector.x + 1 ) * size / 2, ( 1 - vector.y ) * size / 2, vector.z ];

			};

			const edges = new Map();
			const key = ( p ) => p[ 0 ].toFixed( 4 ) + ',' + p[ 1 ].toFixed( 4 );

			for ( let t = 0; t < count; t += 3 ) {

				const corners = [ 0, 1, 2 ].map( ( k ) => {

					const i = index ? index.getX( t + k ) : t + k;

					return [ ...screen( i ), facing( i ) ];

				} );

				if ( corners.some( ( p ) => p[ 2 ] < - 1 || p[ 2 ] > 1 ) ) continue;

				// Counter-clockwise in NDC (y up) is clockwise with y down.
				const [ a, b, c ] = corners;
				const area = ( b[ 0 ] - a[ 0 ] ) * ( c[ 1 ] - a[ 1 ] ) - ( c[ 0 ] - a[ 0 ] ) * ( b[ 1 ] - a[ 1 ] );
				const front = ( area < 0 ) !== mirrored;

				if ( area === 0 || ( side === THREE.FrontSide && ! front ) || ( side === THREE.BackSide && front ) ) continue;

				for ( let e = 0; e < 3; e ++ ) {

					const p = corners[ e ], q = corners[ ( e + 1 ) % 3 ];
					const k = [ key( p ), key( q ) ].sort().join( '|' );
					const entry = edges.get( k );

					if ( entry ) {

						entry.count ++;

					} else {

						edges.set( k, { p, q, count: 1, grazing: p[ 3 ] < rim && q[ 3 ] < rim } );

					}

				}

			}

			for ( const { p, q, count: n, grazing } of edges.values() ) {

				if ( n !== 1 && ! grazing ) continue;

				const dx = q[ 0 ] - p[ 0 ], dy = q[ 1 ] - p[ 1 ];
				const length = Math.hypot( dx, dy );

				for ( let y = Math.floor( Math.min( p[ 1 ], q[ 1 ] ) - 1 ); y <= Math.max( p[ 1 ], q[ 1 ] ) + 1; y ++ ) {

					for ( let x = Math.floor( Math.min( p[ 0 ], q[ 0 ] ) - 1 ); x <= Math.max( p[ 0 ], q[ 0 ] ) + 1; x ++ ) {

						if ( x < 0 || y < 0 || x >= size || y >= size || length === 0 ) continue;

						const u = ( ( x + 0.5 - p[ 0 ] ) * dx + ( y + 0.5 - p[ 1 ] ) * dy ) / ( length * length );
						const d = Math.abs( ( x + 0.5 - p[ 0 ] ) * dy - ( y + 0.5 - p[ 1 ] ) * dx ) / length;

						if ( u >= 0 && u <= 1 && d < threshold ) {

							near.push( `(${ x },${ y }) ${ d.toFixed( 3 ) } ${ object.name || object.type }` );

						}

					}

				}

			}

		}

	} );

	console.log( `${ name }: ${ near.length } pixel centres within ${ threshold } of a silhouette edge${ near.length ? ': ' + near.join( ', ' ) : '' }` );

}
