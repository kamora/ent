// Reference cases for src/math/Color.js, with ColorManagement enabled (the default). Not covered here:
// fromBufferAttribute (M2), the iterator (unit tests), and NaN components in getHex/toJSON (upstream
// returns NaN, Dart's int cannot; exception E-NUM).

import { Color } from '../../../../third_party/three.js/src/math/Color.js';
import { int } from '../lib/codec.mjs';

const SPACES = [ 'srgb', 'srgb-linear' ];
const space = ( r ) => r.pick( SPACES );
const hex = ( r ) => r.int( 0, 0xffffff );
const c = ( r, g, b ) => new Color( r, g, b );

// Every branch of setStyle: rgb/rgba (ints, percentages, alpha, spaces), hsl/hsla, #rgb, #rrggbb, names,
// and the invalid forms that warn and keep the color.
const STYLES = [
	'rgb(255,0,0)', 'rgb( 8 , 25,178 )', 'rgba(8,25,178,200)', 'rgba(255,0,0,0.5)', 'rgb(300,0,999)',
	'rgb(100%,50%,10%)', 'rgb(100%,50.5%,10.25%)', 'rgba( 100% ,50%  ,  10%, 0.5 )', 'rgb(250%,0%,0%)', 'rgb(.5%,0%,0%)',
	'hsl(120,50%,50%)', 'hsl(-120,100%,50%)', 'hsla(360,100.0%,50.0%,0.5)', 'hsl(+30.5,20%,80%)', 'hsl(.5,.5%,.5%)',
	'#F8A', '#f8abc1', '#87cEeB', '#ff00', '#12345', 'aliceblue', 'SkyBlue', 'rebeccapurple', 'notacolor',
	'cmyk(1,2,3,4)', 'rgb(1,2)', 'hsl(1,2,3)', 'rgb(1,2,3)garbage', ''
];

const styleEdges = STYLES.map( ( style ) => () => ( { self: c(), args: [ style ] } ) );

export default {
	name: 'Color',
	type: 'Color',
	cases: 10,
	methods: [
		{ name: 'set', label: 'Color', args: [ 'Color' ] },
		{ name: 'set', label: 'hex', args: [ hex ] },
		{ name: 'set', label: 'style', args: [ ( r ) => r.pick( STYLES ) ] },
		{ name: 'set', label: 'components', args: [ 'unit', 'unit', 'unit' ] },
		{ name: 'setScalar', args: [ 'num' ] },
		{
			name: 'setHex', args: [ hex ],
			edge: [ 0xff8000 + 0.5, - 1, 0x1ffffff, 2 ** 32 + 0x123456, - 0x123456, NaN, Infinity, - Infinity, 2 ** 70 ].map( ( h ) => () => ( { self: c(), args: [ h ] } ) )
		},
		{ name: 'setHex', label: 'colorSpace', args: [ hex, space ] },
		{ name: 'setRGB', args: [ 'unit', 'unit', 'unit' ] },
		{ name: 'setRGB', label: 'colorSpace', args: [ 'unit', 'unit', 'unit', space ] },
		{
			name: 'setHSL', args: [ 'num', 'num', 'num' ],
			edge: [ [ 0.75, 0, 0.25 ], [ 1, 1, 0.5 ], [ - 0.25, 2, - 1 ], [ 0.5, 0.5, 0.75 ] ].map( ( a ) => () => ( { self: c(), args: a } ) )
		},
		{ name: 'setHSL', label: 'colorSpace', args: [ 'unit', 'unit', 'unit', space ] },
		{ name: 'setStyle', args: [ ( r ) => r.pick( STYLES ) ], edge: styleEdges },
		{ name: 'setStyle', label: 'colorSpace', args: [ ( r ) => r.pick( STYLES ), space ] },
		{
			name: 'setColorName', args: [ ( r ) => r.pick( [ 'red', 'Teal', 'NAVY', 'grey', 'nothing' ] ) ],
			edge: [ () => ( { self: c(), args: [ 'powderblue', 'srgb-linear' ] } ) ]
		},
		{ name: 'clone' },
		{ name: 'copy', args: [ 'Color' ] },
		{ name: 'copySRGBToLinear', args: [ 'Color' ] },
		{ name: 'copyLinearToSRGB', args: [ 'Color' ] },
		{ name: 'convertSRGBToLinear', edge: [ () => ( { self: c( 4, 9, 16 ) } ), () => ( { self: c( 0.04, 0.0031, - 1 ) } ) ] },
		{ name: 'convertLinearToSRGB', edge: [ () => ( { self: c( 4, 9, 16 ) } ), () => ( { self: c( 0.04, 0.0031, - 1 ) } ) ] },
		{
			name: 'getHex',
			edge: [ () => ( { self: c( - 1, 2, 0.5 ) } ), () => ( { self: c( 0.5 / 255, 1.5 / 255, 2.5 / 255 ) } ) ]
		},
		{ name: 'getHex', label: 'colorSpace', args: [ space ] },
		{ name: 'getHexString', edge: [ () => ( { self: c( 0, 0, 1 / 255 ) } ) ] },
		{ name: 'getHexString', label: 'colorSpace', args: [ space ] },
		{
			name: 'getHSL', args: [ 'HSL' ],
			edge: [ c( 1, 1, 1 ), c( 0, 0, 0 ), c( 1, 0, 0 ), c( 0, 1, 0 ), c( 0, 0, 1 ), c( 1, 0, 1 ), c( 0.2, 0.2, 0.8 ), c( 0.9, 0.95, 0.95 ) ]
				.map( ( self ) => () => ( { self, args: [ { h: 0, s: 0, l: 0 } ] } ) )
		},
		{ name: 'getHSL', label: 'colorSpace', args: [ 'HSL', space ] },
		{ name: 'getRGB', args: [ 'Color' ] },
		{ name: 'getRGB', label: 'colorSpace', args: [ 'Color', space ] },
		{
			name: 'getStyle',
			edge: [ () => ( { self: c( - 0.5, 2, 0.5 / 255 ) } ), () => ( { self: c( 0, 0, 0 ) } ) ]
		},
		{
			name: 'getStyle', label: 'colorSpace', args: [ space ],
			edge: [ () => ( { self: c( - 0.0001, 0.0625, 1.0005 ), args: [ 'srgb-linear' ] } ), () => ( { self: c( 12.3456, - 7, 0 ), args: [ 'srgb-linear' ] } ), () => ( { self: c( - 0, 0.5, - 0 ), args: [ 'srgb-linear' ] } ) ]
		},
		{ name: 'offsetHSL', args: [ 'num', 'num', 'num' ] },
		{ name: 'add', args: [ 'Color' ] },
		{ name: 'addColors', args: [ 'Color', 'Color' ] },
		{ name: 'addScalar', args: [ 'num' ] },
		{ name: 'sub', args: [ 'Color' ] },
		{ name: 'multiply', args: [ 'Color' ] },
		{ name: 'multiplyScalar', args: [ 'num' ] },
		{ name: 'lerp', args: [ 'Color', 'unit' ] },
		{ name: 'lerpColors', args: [ 'Color', 'Color', 'unit' ] },
		{ name: 'lerpHSL', args: [ 'Color', 'unit' ] },
		{ name: 'setFromVector3', args: [ 'Vector3' ] },
		{ name: 'applyMatrix3', args: [ 'Matrix3' ] },
		{
			name: 'equals', args: [ 'Color' ],
			edge: [ () => ( { self: c( 0.5, 0, 1 ), args: [ c( 0.5, 0, 1 ) ] } ), () => ( { self: c( NaN, 0, 0 ), args: [ c( NaN, 0, 0 ) ] } ), () => ( { self: c( - 0, 0, 0 ), args: [ c( 0, 0, 0 ) ] } ) ]
		},
		{ name: 'fromArray', args: [ ( r ) => [ r.num(), r.num(), r.num(), r.num(), r.num() ], ( r ) => r.int( 0, 2 ) ] },
		{ name: 'toArray', label: 'new array' },
		{ name: 'toArray', args: [ ( r ) => [ r.num(), r.num(), r.num(), r.num(), r.num() ], ( r ) => r.int( 0, 2 ) ] },
		{ name: 'toJSON' }
	]
};
