// Triangle.getInterpolatedAttribute reference cases (a static with its upstream name); see
// lib/buffer_readers.mjs.

import { any, index } from '../lib/buffer_readers.mjs';

const { Triangle } = await import( '../../../../third_party/three.js/src/math/Triangle.js' );
const { Vector2 } = await import( '../../../../third_party/three.js/src/math/Vector2.js' );
const { Vector3 } = await import( '../../../../third_party/three.js/src/math/Vector3.js' );
const { Vector4 } = await import( '../../../../third_party/three.js/src/math/Vector4.js' );

const barycoord = ( r ) => {

	const u = r.unit(), v = r.unit() * ( 1 - u );
	return new Vector3( 1 - u - v, u, v );

};

export default {
	name: 'Triangle',
	static: Triangle,
	fixture: 'TriangleStaticFromBufferAttribute',
	cases: 24,
	methods: [
		{ name: 'getInterpolatedAttribute', label: 'Vector2', args: [ any, index, index, index, barycoord, () => new Vector2() ] },
		{ name: 'getInterpolatedAttribute', label: 'Vector3', args: [ any, index, index, index, barycoord, () => new Vector3() ] },
		{ name: 'getInterpolatedAttribute', label: 'Vector4', args: [ any, index, index, index, barycoord, () => new Vector4() ] }
	]
};
