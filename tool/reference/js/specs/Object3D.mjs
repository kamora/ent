// Reference cases for the transform methods of src/core/Object3D.js on a single object (no parent or
// children; hierarchy, events, toJSON and copy are covered by the ported unit tests and the Dart regression
// tests). The receiver's state is defined in types/objects.mjs.

const src = '../../../../third_party/three.js/src/';

const { Vector3 } = await import( src + 'math/Vector3.js' );

const unit3 = ( r ) => new Vector3( r.range( - 1, 1 ), r.range( - 1, 1 ), r.range( - 1, 1 ) ).normalize();
const angle = ( r ) => r.range( - Math.PI, Math.PI );

export default {
	name: 'Object3D',
	type: 'Object3D',
	cases: 15,
	methods: [
		{ name: 'applyMatrix4', args: [ 'Matrix4' ] },
		{ name: 'applyQuaternion', args: [ 'Quaternion' ] },
		{ name: 'setRotationFromAxisAngle', args: [ unit3, angle ] },
		{ name: 'setRotationFromEuler', args: [ 'Euler' ] },
		{ name: 'setRotationFromMatrix', args: [ 'Matrix4' ] },
		{ name: 'setRotationFromQuaternion', args: [ 'Quaternion' ] },
		{ name: 'rotateOnAxis', args: [ unit3, angle ] },
		{ name: 'rotateOnWorldAxis', args: [ unit3, angle ] },
		{ name: 'rotateX', args: [ angle ] },
		{ name: 'rotateY', args: [ angle ] },
		{ name: 'rotateZ', args: [ angle ] },
		{ name: 'translateOnAxis', args: [ unit3, 'num' ] },
		{ name: 'translateX', args: [ 'num' ] },
		{ name: 'translateY', args: [ 'num' ] },
		{ name: 'translateZ', args: [ 'num' ] },
		{ name: 'localToWorld', args: [ 'Vector3' ] },
		{ name: 'worldToLocal', args: [ 'Vector3' ] },
		{ name: 'lookAt', args: [ 'Vector3' ] },
		{ name: 'lookAt', label: 'coordinates', args: [ 'num', 'num', 'num' ] },
		{ name: 'getWorldPosition', args: [ 'Vector3' ] },
		{ name: 'getWorldQuaternion', args: [ 'Quaternion' ] },
		{ name: 'getWorldScale', args: [ 'Vector3' ] },
		{ name: 'getWorldDirection', args: [ 'Vector3' ] },
		{ name: 'updateMatrix' },
		{ name: 'updateMatrixWorld' },
		{ name: 'updateMatrixWorld', label: 'force', args: [ () => true ] },
		{ name: 'updateWorldMatrix', args: [ 'bool', 'bool' ] },
		{ name: 'updateWorldMatrix', label: 'force', args: [ 'bool', 'bool', 'bool' ] }
	]
};
