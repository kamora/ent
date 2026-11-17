// A seeded generator for fixture inputs, independent of three.js (so fixtures do not move when
// MathUtils.seededRandom changes).

import { int } from './codec.mjs';

export function createRng( seed ) {

	let s = seed >>> 0;

	function next() {

		s = ( s + 0x9E3779B9 ) >>> 0;
		let t = s;
		t = Math.imul( t ^ ( t >>> 16 ), 0x21F0AAAD );
		t = Math.imul( t ^ ( t >>> 15 ), 0x735A2D97 );
		return ( ( t ^ ( t >>> 15 ) ) >>> 0 ) / 4294967296;

	}

	const rng = {
		next,

		// A uniform float in [min, max).
		range( min, max ) {

			return min + next() * ( max - min );

		},

		// A float in [-10, 10), and one time in ten a "round" value: 0, 1, -1, 0.5, 2.
		num() {

			if ( next() < 0.1 ) {

				return rng.pick( [ 0, 1, - 1, 0.5, 2 ] );

			}

			return rng.range( - 10, 10 );

		},

		// A float in [0, 1).
		unit() {

			return next();

		},

		// An integer argument in [min, max], marked so the Dart side passes an `int`.
		int( min, max ) {

			return int( min + Math.floor( next() * ( max - min + 1 ) ) );

		},

		bool() {

			return next() < 0.5;

		},

		pick( list ) {

			return list[ Math.floor( next() * list.length ) ];

		}
	};

	return rng;

}
