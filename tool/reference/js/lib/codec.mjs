// Encodes JS values from the pinned three.js into the fixture JSON that the Dart replay reads.
// The same format is decoded by packages/ent/test/support/fixtures.dart.

const INT = Symbol( 'int' );

// Marks a generated number as an integer argument, so the Dart side passes an `int`.
export function int( value ) {

	return { [ INT ]: true, value };

}

export function isInt( value ) {

	return value !== null && typeof value === 'object' && value[ INT ] === true;

}

export function unwrap( value ) {

	return isInt( value ) ? value.value : value;

}

export function number( v ) {

	if ( Number.isNaN( v ) ) {

		return 'NaN';

	}

	if ( v === Infinity ) {

		return 'Infinity';

	}

	if ( v === - Infinity ) {

		return '-Infinity';

	}

	return Object.is( v, - 0 ) ? '-0' : v;

}

const TYPED = [ 'Float32Array', 'Float64Array', 'Int8Array', 'Uint8Array', 'Uint8ClampedArray', 'Int16Array', 'Uint16Array', 'Int32Array', 'Uint32Array' ];

export function createEncoder( types ) {

	const entries = Object.entries( types );

	function encode( v ) {

		if ( isInt( v ) ) {

			return { int: v.value };

		}

		if ( v === undefined ) {

			return { undefined: true };

		}

		if ( v === null || typeof v === 'boolean' || typeof v === 'string' ) {

			return v;

		}

		if ( typeof v === 'number' ) {

			return number( v );

		}

		if ( Array.isArray( v ) ) {

			return { array: v.map( encode ) };

		}

		if ( ArrayBuffer.isView( v ) ) {

			const name = TYPED.find( ( n ) => v.constructor.name === n );

			if ( ! name ) {

				throw new Error( 'fixture: unsupported typed array ' + v.constructor.name );

			}

			return { typed: name, values: Array.from( v, number ) };

		}

		for ( const [ name, type ] of entries ) {

			if ( type.is( v ) ) {

				return { type: name, value: type.encode( v, encode ) };

			}

		}

		throw new Error( 'fixture: no type registered for ' + ( v?.constructor?.name ?? typeof v ) );

	}

	return encode;

}
