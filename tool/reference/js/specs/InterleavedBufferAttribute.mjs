// Reference cases for src/core/InterleavedBufferAttribute.js: accessors through stride and offset,
// normalization, the matrix helpers and the de-interleaving clone(). clone( data )/toJSON( data ) work on
// plain objects; the ported unit tests cover them.

const index = ( r ) => r.int( 0, 3 );
const component = ( r ) => r.int( 0, 2 );
const value = ( r ) => r.next() < 0.3 ? r.unit() : r.num();

export default {
	name: 'InterleavedBufferAttribute',
	type: 'InterleavedBufferAttribute',
	cases: 16,
	methods: [
		{ name: 'applyMatrix4', args: [ 'Matrix4' ] },
		{ name: 'applyNormalMatrix', args: [ 'Matrix3' ] },
		{ name: 'transformDirection', args: [ 'Matrix4' ] },
		{ name: 'getComponent', args: [ index, component ] },
		{ name: 'setComponent', args: [ index, component, value ] },
		{ name: 'getX', args: [ index ] },
		{ name: 'getY', args: [ index ] },
		{ name: 'getZ', args: [ index ] },
		{ name: 'setX', args: [ index, value ] },
		{ name: 'setY', args: [ index, value ] },
		{ name: 'setZ', args: [ index, value ] },
		{ name: 'setXY', args: [ index, value, value ] },
		{ name: 'setXYZ', args: [ index, value, value, value ] },
		{ name: 'clone', args: [] }
	]
};
