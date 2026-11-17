// Value types from src/core/Object3D.js for fixtures: a single object (no parent or children) and the state
// of its transform. Mirrored by packages/ent/test/support/codecs/objects.dart.
//
// State: position (3), quaternion (4), scale (3), rotation x/y/z/order (4), matrix (16), matrixWorld (16),
// matrixWorldNeedsUpdate, matrixAutoUpdate, up (3), then the pivot (3 numbers, or 3 nulls).

const src = '../../../../third_party/three.js/src/';

const { Object3D } = await import( src + 'core/Object3D.js' );
const { Vector3 } = await import( src + 'math/Vector3.js' );
const { Quaternion } = await import( src + 'math/Quaternion.js' );

const ORDERS = [ 'XYZ', 'YXZ', 'ZXY', 'ZYX', 'YZX', 'XZY' ];

function gen( r ) {

	const o = new Object3D();
	o.rotation.order = r.pick( ORDERS );
	o.position.set( r.num(), r.num(), r.num() );

	const axis = new Vector3( r.range( - 1, 1 ), r.range( - 1, 1 ), r.range( - 1, 1 ) ).normalize();
	o.quaternion.copy( new Quaternion().setFromAxisAngle( axis, r.range( - Math.PI, Math.PI ) ) );
	o.scale.set( r.range( 0.2, 3 ), r.range( 0.2, 3 ), r.range( 0.2, 3 ) );

	if ( r.next() < 0.3 ) {

		o.pivot = new Vector3( r.num(), r.num(), r.num() );

	}

	if ( r.next() < 0.2 ) {

		o.up.set( r.range( - 1, 1 ), r.range( - 1, 1 ), r.range( - 1, 1 ) ).normalize();

	}

	if ( r.next() < 0.5 ) {

		o.updateMatrixWorld();

	}

	o.matrixAutoUpdate = r.next() < 0.85;

	return o;

}

export default {

	Object3D: {
		is: ( v ) => v?.isObject3D === true,
		encode: ( o, e ) => [
			...o.position.toArray().map( e ), ...o.quaternion.toArray().map( e ), ...o.scale.toArray().map( e ),
			e( o.rotation.x ), e( o.rotation.y ), e( o.rotation.z ), o.rotation.order,
			...o.matrix.elements.map( e ), ...o.matrixWorld.elements.map( e ),
			o.matrixWorldNeedsUpdate, o.matrixAutoUpdate,
			...o.up.toArray().map( e ),
			...( o.pivot === null ? [ null, null, null ] : o.pivot.toArray().map( e ) )
		],
		gen
	}

};
