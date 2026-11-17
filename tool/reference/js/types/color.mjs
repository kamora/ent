// Value types for the color group that are not three.js classes: the `{ h, s, l }` object that
// Color.getHSL fills. Mirrored by packages/ent/test/support/codecs/color.dart (Dart class `HSL`).

export default {

	HSL: {
		is: ( v ) => v !== null && typeof v === 'object' && Object.getPrototypeOf( v ) === Object.prototype && Object.keys( v ).join() === 'h,s,l',
		encode: ( v, e ) => [ e( v.h ), e( v.s ), e( v.l ) ],
		gen: ( r ) => ( { h: r.unit(), s: r.unit(), l: r.unit() } )
	}

};
