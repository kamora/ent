// Triangle.setFromAttributeAndIndices and the static getInterpolatedAttribute reference cases; see
// lib/buffer_readers.mjs. The static has no instance twin, so it keeps its upstream name in Dart.

import { any, index } from '../lib/buffer_readers.mjs';

export default {
	name: 'Triangle',
	type: 'Triangle',
	fixture: 'TriangleFromBufferAttribute',
	cases: 24,
	methods: [ { name: 'setFromAttributeAndIndices', args: [ any, index, index, index ] } ]
};
