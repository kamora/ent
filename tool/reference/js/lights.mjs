// Writes fixtures/values/lights.json: shadow matrices, spot shadow camera updates and the toJSON output of every
// light, fog and scene, from the pinned src/, for packages/ent/test/lights and test/scenes.
// `uuid` and `target` (a uuid) are stripped, since they are random.
//
// Usage: node tool/reference/js/lights.mjs

import { writeFileSync } from 'node:fs';

const T = await import( '../../../third_party/three.js/src/Three.Core.js' );
const strip = ( o ) => JSON.parse( JSON.stringify( o, ( k, v ) => ( k === 'uuid' || k === 'target' ) ? undefined : v ) );
const out = {};

// Directional light shadow
const d = new T.DirectionalLight( 0xff8800, 2 );
d.position.set( 3, 4, 5 );
d.target.position.set( 1, 0, - 1 );
d.updateMatrixWorld(); d.target.updateMatrixWorld();
d.shadow.updateMatrices( d );
out.dirShadowMatrix = d.shadow.matrix.elements;
out.dirCameraInverse = d.shadow.camera.matrixWorldInverse.elements;
out.dirFrustum = d.shadow.getFrustum().planes.map( p => [ p.normal.x, p.normal.y, p.normal.z, p.constant ] );

// WebGPU branch
const w = new T.DirectionalLight();
w.shadow.camera.coordinateSystem = T.WebGPUCoordinateSystem;
w.shadow.camera.updateProjectionMatrix();
w.position.set( - 2, 6, 1 );
w.updateMatrixWorld(); w.target.updateMatrixWorld();
w.shadow.updateMatrices( w );
out.gpuShadowMatrix = w.shadow.matrix.elements;

// Spot light shadow
const s = new T.SpotLight( 0xffffff, 3, 50, 0.5, 0.2, 1.5 );
s.shadow.focus = 0.8; s.shadow.aspect = 1.5; s.shadow.mapSize.set( 1024, 512 );
s.position.set( 0, 10, 2 ); s.target.position.set( 1, 0, 0 );
s.updateMatrixWorld(); s.target.updateMatrixWorld();
s.shadow.updateMatrices( s );
out.spotCamera = [ s.shadow.camera.fov, s.shadow.camera.aspect, s.shadow.camera.far ];
out.spotShadowMatrix = s.shadow.matrix.elements;
const s0 = new T.SpotLight( 0xffffff, 1, 0 );
s0.updateMatrixWorld(); s0.target.updateMatrixWorld();
s0.shadow.updateMatrices( s0 );
out.spot0Camera = [ s0.shadow.camera.fov, s0.shadow.camera.aspect, s0.shadow.camera.far ];

// _updateMatrix with a viewport
const v = new T.PointLight();
v.shadow._frameExtents.set( 4, 2 );
v.shadow.camera.position.set( 1, 2, 3 ); v.shadow.camera.lookAt( 0, 0, 0 ); v.shadow.camera.updateMatrixWorld();
const vm = new T.Matrix4(); const vf = new T.Frustum();
v.shadow._updateMatrix( v.shadow.camera, vm, vf, new T.Vector4( 1, 0.5, 2, 1 ) );
out.viewportMatrix = vm.elements;

// toJSON
const lights = {
	Directional: Object.assign( new T.DirectionalLight( 0x123456, 0.5 ), { name: 'sun' } ),
	Point: new T.PointLight( 0xabcdef, 2, 30, 1 ),
	Spot: new T.SpotLight( 0x00ff00, 4, 20, 0.7, 0.3, 2 ),
	Hemisphere: new T.HemisphereLight( 0xffffbb, 0x080820, 0.7 ),
	RectArea: new T.RectAreaLight( 0xff0000, 3, 4, 2 ),
	Ambient: new T.AmbientLight( 0x404040 ),
	Probe: new T.LightProbe( new T.SphericalHarmonics3().set( Array.from( { length: 9 }, ( _, i ) => new T.Vector3( i, i * 0.5, - i ) ) ), 0.25 )
};
lights.Spot.shadow.bias = - 0.001; lights.Spot.shadow.focus = 0.5; lights.Spot.shadow.mapSize.set( 256, 128 );
lights.Point.position.set( 1, 2, 3 ); lights.Point.updateMatrix();
out.json = Object.fromEntries( Object.entries( lights ).map( ( [ k, l ] ) => [ k, strip( l.toJSON() ) ] ) );
out.power = { point: new T.PointLight( 0, 3 ).power, spot: new T.SpotLight( 0, 3 ).power, rect: new T.RectAreaLight( 0, 3, 2, 5 ).power };

const scene = new T.Scene();
scene.fog = new T.Fog( 0xcccccc, 10, 15 );
scene.backgroundBlurriness = 0.3; scene.backgroundRotation.set( 0.1, 0.2, 0.3 ); scene.environmentIntensity = 0.5;
out.sceneJson = strip( scene.toJSON() );
out.fogJson = [ new T.Fog( 0x112233, 2, 9 ).toJSON(), new T.FogExp2( 0x445566, 0.01 ).toJSON() ];
writeFileSync( new URL( '../../../fixtures/values/lights.json', import.meta.url ), JSON.stringify( { reference: 'r187', ...out }, null, '\t' ) + '\n' );
console.log( Object.keys( out ).length + ' values' );
