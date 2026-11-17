// Reference cases for src/math/interpolants/DiscreteInterpolant.js: evaluate() from warmed-up receivers (see
// types/interpolants.mjs), covering times before, between, on and after the keys in any call order.

import { int } from '../lib/codec.mjs';
import { time } from '../types/interpolants.mjs';

export default {
	name: 'DiscreteInterpolant',
	type: 'DiscreteInterpolant',
	methods: [
		{ name: 'evaluate', args: [ time ], cases: 120 },
		{ name: 'copySampleValue_', args: [ () => int( 0 ) ], cases: 10 }
	]
};
