// Value types from src/core/BufferAttribute.js and the interleaved attributes, for fixtures. Mirrored by
// packages/ent/test/support/codecs/buffers.dart.
//
// BufferAttribute / Float16BufferAttribute state: typed array name, itemSize, normalized, then the raw array
// values (half-float bits for Float16). InterleavedBufferAttribute state: typed array name, stride, itemSize,
// offset, normalized, then the raw values of the shared array.

const src = '../../../../third_party/three.js/src/';

const { BufferAttribute, Float16BufferAttribute } = await import( src + 'core/BufferAttribute.js' );
const { InterleavedBuffer } = await import( src + 'core/InterleavedBuffer.js' );
const { InterleavedBufferAttribute } = await import( src + 'core/InterleavedBufferAttribute.js' );
const { toHalfFloat } = await import( src + 'extras/DataUtils.js' );

const INTEGER = {
	Int8Array: [ - 128, 127 ], Uint8Array: [ 0, 255 ], Uint8ClampedArray: [ 0, 255 ],
	Int16Array: [ - 32768, 32767 ], Uint16Array: [ 0, 65535 ], Int32Array: [ - 2147483648, 2147483647 ],
	Uint32Array: [ 0, 4294967295 ]
};

// Mostly Float32, often integers (normalized or not), sometimes Float64.
function kind( r ) {

	const x = r.next();
	return x < 0.45 ? 'Float32Array' : x < 0.55 ? 'Float64Array' : r.pick( Object.keys( INTEGER ) );

}

function values( r, type, length ) {

	const range = INTEGER[ type ];
	return Array.from( { length }, () => range ? Math.floor( r.range( range[ 0 ], range[ 1 ] + 1 ) ) : r.num() );

}

// Four items of four components: every index 0..3 and component 0..3 is in range.
export function attribute( r, itemSize = 4, count = 4 ) {

	const type = kind( r );
	const normalized = type in INTEGER && r.next() < 0.6;
	return new BufferAttribute( new globalThis[ type ]( values( r, type, itemSize * count ) ), itemSize, normalized );

}

export function float16( r, itemSize = 4, count = 4 ) {

	const bits = Array.from( { length: itemSize * count }, () => toHalfFloat( r.num() ) );
	return new Float16BufferAttribute( bits, itemSize, r.next() < 0.2 );

}

export function interleaved( r, itemSize = 3 ) {

	const type = kind( r );
	const stride = itemSize + 1 + Math.floor( r.next() * 2 );
	const offset = Math.floor( r.next() * ( stride - itemSize + 1 ) );
	const buffer = new InterleavedBuffer( new globalThis[ type ]( values( r, type, stride * 4 ) ), stride );
	return new InterleavedBufferAttribute( buffer, itemSize, offset, type in INTEGER && r.next() < 0.6 );

}

const raw = ( array, e ) => Array.from( array, e );

export default {

	Float16BufferAttribute: {
		is: ( v ) => v?.isFloat16BufferAttribute === true,
		encode: ( v, e ) => [ v.array.constructor.name, v.itemSize, v.normalized, ...raw( v.array, e ) ],
		gen: ( r ) => float16( r )
	},

	BufferAttribute: {
		is: ( v ) => v?.isBufferAttribute === true,
		encode: ( v, e ) => [ v.array.constructor.name, v.itemSize, v.normalized, ...raw( v.array, e ) ],
		gen: ( r ) => attribute( r )
	},

	InterleavedBufferAttribute: {
		is: ( v ) => v?.isInterleavedBufferAttribute === true,
		encode: ( v, e ) => [ v.array.constructor.name, v.data.stride, v.itemSize, v.offset, v.normalized, ...raw( v.data.array, e ) ],
		gen: ( r ) => interleaved( r )
	}

};
