// Reference cases for src/cameras/PerspectiveCamera.js (and the Camera and Object3D methods it inherits
// that cameras change: getWorldDirection, updateMatrixWorld, updateWorldMatrix, lookAt, copy, clone).
// Receivers are random cameras in both coordinate systems, with reversed depth, zoom, film offset and view
// offsets (types/cameras.mjs). toJSON returns a plain object; the Dart unit tests cover it.

import { perspectiveCamera } from '../types/cameras.mjs';
import { createRng } from '../lib/rng.mjs';

const offset = ( r ) => {

	const fullWidth = r.range( 100, 2000 ), fullHeight = r.range( 100, 2000 );
	return [ fullWidth, fullHeight, r.range( 0, fullWidth / 2 ), r.range( 0, fullHeight / 2 ), r.range( 10, fullWidth / 2 ), r.range( 10, fullHeight / 2 ) ];

};

export default {
	name: 'PerspectiveCamera',
	type: 'PerspectiveCamera',
	cases: 20,
	methods: [
		{ name: 'setFocalLength', args: [ ( r ) => r.range( 5, 200 ) ] },
		{ name: 'getFocalLength' },
		{ name: 'getEffectiveFOV' },
		{ name: 'getFilmWidth' },
		{ name: 'getFilmHeight' },
		{ name: 'getViewBounds', args: [ ( r ) => r.range( 0.1, 100 ), 'Vector2', 'Vector2' ] },
		{ name: 'getViewSize', args: [ ( r ) => r.range( 0.1, 100 ), 'Vector2' ] },
		{ name: 'setViewOffset', args: offset },
		{ name: 'clearViewOffset' },
		{
			name: 'updateProjectionMatrix',
			edge: [ () => {

				const c = perspectiveCamera( createRng( 7 ) );
				c.coordinateSystem = 1234;
				return { self: c };

			} ]
		},
		{ name: 'updateMatrixWorld', args: [ 'bool' ] },
		{ name: 'updateMatrixWorld', label: 'no argument' },
		{ name: 'updateWorldMatrix', args: [ 'bool', 'bool' ] },
		{ name: 'getWorldDirection', args: [ 'Vector3' ] },
		{ name: 'lookAt', args: [ 'Vector3' ] },
		{ name: 'copy', args: [ 'PerspectiveCamera' ] },
		{ name: 'clone' }
	]
};
