// Reference cases for src/math/interpolants/BezierInterpolant.js: evaluate() from warmed-up receivers (see
// types/interpolants.mjs), covering times before, between, on and after the keys in any call order.

import { int } from '../lib/codec.mjs';
import { time } from '../types/interpolants.mjs';

export default {
	name: 'BezierInterpolant',
	type: 'BezierInterpolant',
	methods: [
		{ name: 'evaluate', args: [ time ], cases: 120 },
		{ name: 'copySampleValue_', args: [ () => int( 0 ) ], cases: 10 }
	]
};
