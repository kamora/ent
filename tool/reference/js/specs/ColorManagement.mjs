// Reference cases for the ColorManagement object of src/math/ColorManagement.js (Dart: static members of
// ColorManagement). Its internal _getMatrix is covered by the ported upstream test.

import { ColorManagement } from '../../../../third_party/three.js/src/math/ColorManagement.js';

const SPACES = [ 'srgb', 'srgb-linear' ];
const space = ( r ) => r.pick( SPACES );
const maybe = ( r ) => r.pick( [ ...SPACES, '' ] );

export default {
	name: 'ColorManagement',
	static: ColorManagement,
	cases: 20,
	methods: [
		{ name: 'convert', args: [ 'Color', maybe, maybe ] },
		{ name: 'workingToColorSpace', args: [ 'Color', space ] },
		{ name: 'colorSpaceToWorking', args: [ 'Color', space ] },
		{ name: 'getPrimaries', args: [ space ], cases: 2 },
		{ name: 'getTransfer', args: [ maybe ], cases: 6 },
		{ name: 'getToneMappingMode', args: [ space ], cases: 2 },
		{ name: 'getLuminanceCoefficients', args: [ 'Vector3' ], cases: 2 },
		{ name: 'getLuminanceCoefficients', label: 'colorSpace', args: [ 'Vector3', space ], cases: 4 }
	]
};
