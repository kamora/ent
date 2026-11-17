// Reference cases for Float16BufferAttribute in src/core/BufferAttribute.js: half-float conversion on every
// accessor it overrides, and the inherited getComponent/setComponent, which upstream leaves raw.

import { float16 } from '../types/buffers.mjs';

const index = ( r ) => r.int( 0, 3 );
const value = ( r ) => r.next() < 0.1 ? r.pick( [ 70000, - 70000, 1e-8, 65504 ] ) : r.num();

export default {
	name: 'Float16BufferAttribute',
	type: 'Float16BufferAttribute',
	cases: 16,
	methods: [
		{ name: 'getComponent', args: [ index, index ] },
		{ name: 'setComponent', args: [ index, index, value ] },
		{ name: 'getX', args: [ index ] },
		{ name: 'getY', args: [ index ] },
		{ name: 'getZ', args: [ index ] },
		{ name: 'getW', args: [ index ] },
		{ name: 'setX', args: [ index, value ] },
		{ name: 'setY', args: [ index, value ] },
		{ name: 'setZ', args: [ index, value ] },
		{ name: 'setW', args: [ index, value ] },
		{ name: 'setXY', args: [ index, value, value ] },
		{ name: 'setXYZ', args: [ index, value, value, value ] },
		{ name: 'setXYZW', args: [ index, value, value, value, value ] },
		{ name: 'applyMatrix4', self: ( r ) => float16( r, 3 ), args: [ 'Matrix4' ] },
		{ name: 'clone', args: [] }
	]
};
