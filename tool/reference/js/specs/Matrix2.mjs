// Reference cases for src/math/Matrix2.js.

export default {
	name: 'Matrix2',
	type: 'Matrix2',
	cases: 10,
	methods: [
		{ name: 'identity' },
		{ name: 'set', args: [ 'num', 'num', 'num', 'num' ] },
		{ name: 'fromArray', args: [ ( r ) => Array.from( { length: 4 }, () => r.num() ) ], label: 'no offset' },
		{ name: 'fromArray', args: [ ( r ) => Array.from( { length: 8 }, () => r.num() ), ( r ) => r.int( 0, 4 ) ] }
	]
};
