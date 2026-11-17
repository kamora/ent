// Shared inputs for the specs of the math methods that read buffer attributes (specs/*FromBufferAttribute.mjs):
// fromBufferAttribute on Vector2/3/4, Quaternion and Color, Box3.setFromBufferAttribute, Triangle's
// setFromAttributeAndIndices and getInterpolatedAttribute. Attributes have four components per item, so every
// read is in range (out-of-range reads are exception E-ARRAY).

import { attribute, float16, interleaved } from '../types/buffers.mjs';

const any = ( r ) => {

	const x = r.next();
	return x < 0.6 ? attribute( r ) : x < 0.8 ? float16( r ) : interleaved( r, 4 );

};

const index = ( r ) => r.int( 0, 3 );

export function reader( name, type ) {

	return {
		name,
		type,
		fixture: name + 'FromBufferAttribute',
		cases: 24,
		methods: [ { name: 'fromBufferAttribute', args: [ any, index ] } ]
	};

}

export { any, index };
