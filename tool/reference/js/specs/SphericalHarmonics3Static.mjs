// Reference cases for the static SphericalHarmonics3.getBasisAt, which fills a flat array.

import { SphericalHarmonics3 } from '../../../../third_party/three.js/src/math/SphericalHarmonics3.js';
import { Vector3 } from '../../../../third_party/three.js/src/math/Vector3.js';

const unit = ( r ) => new Vector3( r.range( - 1, 1 ), r.range( - 1, 1 ), r.range( - 1, 1 ) ).normalize();

export default {
	name: 'SphericalHarmonics3',
	fixture: 'SphericalHarmonics3Static',
	static: SphericalHarmonics3,
	cases: 20,
	methods: [
		{ name: 'getBasisAt', args: [ unit, ( r ) => Array.from( { length: 9 }, () => r.num() ) ] }
	]
};
