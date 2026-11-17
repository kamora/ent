// Reference cases for src/cameras/OrthographicCamera.js (and the Camera and Object3D methods it inherits
// that cameras change). Receivers are random cameras in both coordinate systems, with reversed depth, zoom
// and view offsets (types/cameras.mjs). toJSON returns a plain object; the Dart unit tests cover it.

import { orthographicCamera } from '../types/cameras.mjs';
import { createRng } from '../lib/rng.mjs';

const offset = ( r ) => {

	const fullWidth = r.range( 100, 2000 ), fullHeight = r.range( 100, 2000 );
	return [ fullWidth, fullHeight, r.range( 0, fullWidth / 2 ), r.range( 0, fullHeight / 2 ), r.range( 10, fullWidth / 2 ), r.range( 10, fullHeight / 2 ) ];

};

export default {
	name: 'OrthographicCamera',
	type: 'OrthographicCamera',
	cases: 20,
	methods: [
		{ name: 'setViewOffset', args: offset },
		{ name: 'clearViewOffset' },
		{
			name: 'updateProjectionMatrix',
			edge: [ () => {

				const c = orthographicCamera( createRng( 7 ) );
				c.coordinateSystem = 1234;
				return { self: c };

			} ]
		},
		{ name: 'updateMatrixWorld', args: [ 'bool' ] },
		{ name: 'updateWorldMatrix', args: [ 'bool', 'bool' ] },
		{ name: 'getWorldDirection', args: [ 'Vector3' ] },
		{ name: 'lookAt', args: [ 'Vector3' ] },
		{ name: 'copy', args: [ 'OrthographicCamera' ] },
		{ name: 'clone' }
	]
};
