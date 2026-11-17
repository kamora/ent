// Reference cases for src/cameras/CubeCamera.js. update( renderer, scene ) needs a renderer (pending in the
// port); clone() gives 12 children upstream (six from the constructor, six copied), which the CubeCamera
// fixture state cannot hold, so the Dart unit tests cover it.

const src = '../../../../third_party/three.js/src/';
const { CubeCamera } = await import( src + 'cameras/CubeCamera.js' );

const cube = ( coordinateSystem ) => () => {

	const c = new CubeCamera( 1, 10 );
	c.coordinateSystem = coordinateSystem;
	return { self: c };

};

export default {
	name: 'CubeCamera',
	type: 'CubeCamera',
	cases: 20,
	methods: [
		{
			name: 'updateCoordinateSystem',
			self: ( r ) => {

				const near = r.range( 0.01, 2 );
				const camera = new CubeCamera( near, near + r.range( 1, 1000 ) );
				camera.position.set( r.num(), r.num(), r.num() );
				camera.updateMatrixWorld();
				camera.coordinateSystem = r.next() < 0.5 ? 2000 : 2001;
				return camera;

			},
			edge: [ cube( 2000 ), cube( 2001 ), cube( null ), cube( 1234 ) ]
		}
	]
};
