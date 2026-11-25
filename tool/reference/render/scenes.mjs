// Reference scenes for renderer parity. Each entry builds a scene and a camera with the pinned three.js r187;
// render.mjs draws it with r187's WebGLRenderer in headless Chrome and saves the frame and the scene's JSON,
// which the Dart test loads with ObjectLoader and draws with FlutterGpuRenderer. An entry may also return
// `renderer`: WebGLRenderer properties to set (toneMapping, toneMappingExposure, outputColorSpace,
// sortObjects), saved in the JSON for the Dart side, and `edges`: the most edge pixels the Dart test accepts
// (a differing pixel whose color appears within one pixel; the rule hides a missing or extra one-pixel feature),
// and `animate`: `times` at which page.html draws a frame each through an AnimationMixer playing the clips in the
// objects' `animations`, with `actions` per clip name (weight, loop, timeScale, fadeIn, fadeOut).

import * as THREE from 'three';

const size = 128;

function camera( fov = 50, position = [ 0, 0.6, 3 ] ) {

	const camera = new THREE.PerspectiveCamera( fov, 1, 0.1, 100 );
	camera.position.fromArray( position );
	camera.lookAt( 0, 0, 0 );

	return camera;

}

// A camera straight down -z, so quads in the z = 0 plane appear square.
function front() {

	const camera = new THREE.PerspectiveCamera( 50, 1, 0.1, 100 );
	camera.position.set( 0, 0, 3 );

	return camera;

}

function triangle( material, z = 0 ) {

	const geometry = new THREE.BufferGeometry();
	geometry.setAttribute( 'position', new THREE.Float32BufferAttribute( [ - 1.2, - 0.8, 0, 1.2, - 0.8, 0, 0, 1.2, 0 ], 3 ) );

	const mesh = new THREE.Mesh( geometry, material );
	mesh.position.z = z;

	return mesh;

}

function quad( material, x = 0, y = 0, z = 0, width = 1, height = 1 ) {

	const mesh = new THREE.Mesh( new THREE.PlaneGeometry( width, height ), material );
	mesh.position.set( x, y, z );

	return mesh;

}

// A plain BufferGeometry copy, so attributes added to it are serialized (a PlaneGeometry serializes only its
// parameters).
function plain( geometry ) {

	return new THREE.BufferGeometry().copy( geometry );

}

// RGBA bytes of a width × height checkerboard of two colors, in cells of `cell` texels.
function checker( width, height, cell, a, b ) {

	const data = new Uint8Array( width * height * 4 );

	for ( let y = 0; y < height; y ++ ) {

		for ( let x = 0; x < width; x ++ ) {

			const color = ( Math.floor( x / cell ) + Math.floor( y / cell ) ) % 2 === 0 ? a : b;
			data.set( color, ( y * width + x ) * 4 );

		}

	}

	return data;

}

// A 4×4 texture with a distinct color per texel, to see orientation, filtering and wrapping. `lift` raises
// every channel toward white: linearly filtered next to a zero channel, the GPUs' last-bit differences in the
// filter weights grow past 2/255 under the sRGB encoding (slope 12.92 near zero).
function palette( options = {}, lift = 0 ) {

	const colors = [
		[ 255, 0, 0, 255 ], [ 0, 255, 0, 255 ], [ 0, 0, 255, 255 ], [ 255, 255, 0, 255 ],
		[ 255, 0, 255, 255 ], [ 0, 255, 255, 255 ], [ 255, 255, 255, 255 ], [ 64, 64, 64, 255 ],
		[ 255, 128, 0, 255 ], [ 128, 0, 255, 255 ], [ 0, 128, 64, 255 ], [ 200, 160, 120, 255 ],
		[ 32, 96, 160, 255 ], [ 160, 32, 96, 255 ], [ 96, 160, 32, 255 ], [ 0, 0, 0, 255 ],
	];
	const texture = new THREE.DataTexture( new Uint8Array( colors.flat().map( ( c ) => Math.round( lift + c * ( 255 - lift ) / 255 ) ) ), 4, 4 );
	texture.colorSpace = THREE.SRGBColorSpace;
	Object.assign( texture, options );
	texture.needsUpdate = true;

	return texture;

}

// A 2D canvas drawn by `draw`, as a CanvasTexture (serialized as a PNG data URL).
function canvas( width, height, draw, options = {} ) {

	const element = document.createElement( 'canvas' );
	element.width = width;
	element.height = height;
	draw( element.getContext( '2d' ) );

	const texture = new THREE.CanvasTexture( element );
	texture.colorSpace = THREE.SRGBColorSpace;
	Object.assign( texture, options );

	return texture;

}

// Two overlapping quads of one blending mode over a background of two colors: the clear color and an opaque
// band. `options` are material properties.
function blending( options ) {

	const scene = new THREE.Scene();
	scene.add( quad( new THREE.MeshBasicMaterial( { color: 0xffcc00 } ), 0, - 0.55, - 0.2, 2.4, 0.7 ) );
	scene.add( quad( new THREE.MeshBasicMaterial( { color: 0xff3366, transparent: true, opacity: 0.6, ...options } ), - 0.3, 0, 0, 1, 1.4 ) );
	scene.add( quad( new THREE.MeshBasicMaterial( { color: 0x33cc99, transparent: true, opacity: 0.5, ...options } ), 0.3, 0.1, 0.1, 1, 1.4 ) );

	return { scene, camera: front(), clear: [ 0x2244aa, 1 ] };

}

// Five unit cubes from z = 1 to z = -11, for fog over distance.
function cubes( fog, material = {} ) {

	const scene = new THREE.Scene();
	scene.fog = fog;

	for ( let i = 0; i < 5; i ++ ) {

		const cube = new THREE.Mesh( new THREE.BoxGeometry( 1, 1, 1 ), new THREE.MeshBasicMaterial( { color: 0xff6600, ...material } ) );
		cube.position.set( i * 0.9 - 1.8, 0, 1 - i * 3 );
		cube.rotation.set( 0.5, 0.6, 0 );
		scene.add( cube );

	}

	return { scene, camera: camera( 50, [ 0, 1, 4 ] ), clear: [ 0x8899aa, 1 ] };

}

// Quads of bright linear colors (beyond 1, as vertex colors: material colors serialize as clamped hex) and a
// quad that is not tone mapped, for tone mapping.
function bright( renderer ) {

	const scene = new THREE.Scene();
	const colors = [ [ 4, 2, 1 ], [ 0.2, 1.5, 0.6 ], [ 0.5, 0.5, 3 ], [ 1, 1, 1 ], [ 0.05, 0.1, 0.2 ], [ 8, 8, 8 ] ];

	colors.forEach( ( color, i ) => {

		const corners = [ color, color, color.map( ( c ) => c * 0.25 ), color.map( ( c ) => c * 0.25 ) ];
		const geometry = plain( new THREE.PlaneGeometry( 0.75, 0.85 ) );
		geometry.setAttribute( 'color', new THREE.Float32BufferAttribute( corners.flat(), 3 ) );

		const mesh = new THREE.Mesh( geometry, new THREE.MeshBasicMaterial( { vertexColors: true } ) );
		mesh.position.set( ( i % 3 ) * 0.8 - 0.8, i < 3 ? 0.45 : - 0.45, 0 );
		scene.add( mesh );

	} );

	const geometry = plain( new THREE.PlaneGeometry( 0.3, 0.3 ) );
	geometry.setAttribute( 'color', new THREE.Float32BufferAttribute( new Array( 4 ).fill( [ 2, 0.5, 0.25 ] ).flat(), 3 ) );

	const untoned = new THREE.Mesh( geometry, new THREE.MeshBasicMaterial( { vertexColors: true, toneMapped: false } ) );
	untoned.position.z = 0.1;
	scene.add( untoned );

	return { scene, camera: front(), clear: [ 0x000000, 1 ], renderer };

}

// Small quads of linear colors above 1 (vertex colors: a material color is serialized clamped) and dim ones on
// black, seen by flat() under ACES: UnrealBloomPass's scenes.
function glowing() {

	const scene = new THREE.Scene();
	const quads = [
		[ [ 3, 3, 3 ], - 0.5, 0.5, 0.12, 0.12 ], [ [ 2, 0.8, 0.3 ], 0.4, 0.45, 0.2, 0.2 ], [ [ 0.2, 0.6, 1.5 ], - 0.3, - 0.35, 0.3, 0.08 ],
		[ [ 0.3, 0.3, 0.3 ], 0.45, - 0.4, 0.25, 0.25 ], [ [ 0.05, 0.05, 0.08 ], 0, - 0.85, 2, 0.3 ]
	];

	for ( const [ color, x, y, width, height ] of quads ) {

		const geometry = plain( new THREE.PlaneGeometry( width, height ) );
		geometry.setAttribute( 'color', new THREE.Float32BufferAttribute( new Array( 4 ).fill( color ).flat(), 3 ) );

		const mesh = new THREE.Mesh( geometry, new THREE.MeshBasicMaterial( { vertexColors: true } ) );
		mesh.position.set( x, y, 0 );
		scene.add( mesh );

	}

	return { scene, camera: flat(), clear: [ 0x000000, 1 ], renderer: { toneMapping: THREE.ACESFilmicToneMapping } };

}

// A smooth sphere of `material` at x, y, z. Fewer segments make the rim band wider, so its shading changes
// more gently from pixel to pixel where the silhouette's pixels may differ (edges.mjs).
function sphere( material, x = 0, y = 0, z = 0, radius = 0.55, segments = 32 ) {

	const mesh = new THREE.Mesh( new THREE.SphereGeometry( radius, segments, segments / 2 ), material );
	mesh.position.set( x, y, z );

	return mesh;

}

// A no-color-space DataTexture of size × size texels from `texel( u, v )` (RGBA bytes, u and v in [0, 1] at
// texel centres), linearly filtered without mipmaps and repeated.
function field( size, texel, options = {} ) {

	const data = new Uint8Array( size * size * 4 );

	for ( let y = 0; y < size; y ++ ) {

		for ( let x = 0; x < size; x ++ ) {

			data.set( texel( ( x + 0.5 ) / size, ( y + 0.5 ) / size ).map( Math.round ), ( y * size + x ) * 4 );

		}

	}

	const texture = new THREE.DataTexture( data, size, size );
	texture.magFilter = THREE.LinearFilter;
	texture.minFilter = THREE.LinearFilter;
	texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
	Object.assign( texture, options );
	texture.needsUpdate = true;

	return texture;

}

// A gentle height field: two bumps per side, in [0, 1].
function height( u, v ) {

	return 0.5 + 0.25 * Math.sin( u * 2 * Math.PI * 2 ) * Math.sin( v * 2 * Math.PI * 2 + 0.6 );

}

// The tangent-space normal map of `height` (derivatives scaled by `steep`), encoded as n * 0.5 + 0.5.
function normals( size, steep = 0.12 ) {

	return field( size, ( u, v ) => {

		const e = 1 / size;
		const dx = ( height( u + e, v ) - height( u - e, v ) ) / ( 2 * e ) * steep;
		const dy = ( height( u, v + e ) - height( u, v - e ) ) / ( 2 * e ) * steep;
		const n = new THREE.Vector3( - dx, - dy, 1 ).normalize();

		return [ n.x * 127.5 + 127.5, n.y * 127.5 + 127.5, n.z * 127.5 + 127.5, 255 ];

	} );

}

// A lit stage: ambient light and a directional light from the upper left front, added to `scene`.
function stage( scene, ambient = 0.6, sun = 2.2 ) {

	scene.add( new THREE.AmbientLight( 0xffffff, ambient ) );

	const light = new THREE.DirectionalLight( 0xffffff, sun );
	light.position.set( - 1, 1.5, 2 );
	scene.add( light );

	return scene;

}

// A cube map of six 16 × 16 canvas faces (+X, -X, +Y, -Y, +Z, -Z), sRGB: per face a soft vertical gradient and
// a disc, distinct per face so that orientation and the x mirror of cube textures show. Gentle, so that the two
// GPU paths' filtering and level-of-detail differences stay small. A minified map (texels of about a pixel, mip
// levels blended) needs lower contrast still: `contrast` moves every color toward a gray, `glow` scales the disc.
function skybox( mapping = THREE.CubeReflectionMapping, contrast = 1, glow = 1 ) {

	const faces = [
		[ '#d08a62', '#f2c9a0', '#fff0c0' ], [ '#5b78a8', '#9ab4d8', '#c0d8f0' ], [ '#9cc4ec', '#cfe4f8', '#ffffff' ],
		[ '#5a4a3a', '#7a6a58', '#a08c70' ], [ '#7aa86a', '#b6d49c', '#e8f4c8' ], [ '#a07ab0', '#c8acd4', '#f0d8f4' ],
	].map( ( colors ) => colors.map( ( color ) => new THREE.Color( 0xb0a8a0 ).lerp( new THREE.Color( color ), contrast ).getStyle() ) ).map( ( [ low, high, disc ] ) => {

		const element = document.createElement( 'canvas' );
		element.width = element.height = 16;

		const context = element.getContext( '2d' );
		const gradient = context.createLinearGradient( 0, 0, 0, 16 );
		gradient.addColorStop( 0, high );
		gradient.addColorStop( 1, low );
		context.fillStyle = gradient;
		context.fillRect( 0, 0, 16, 16 );

		const radial = context.createRadialGradient( 5, 6, 0, 5, 6, 6 );
		radial.addColorStop( 0, disc );
		radial.addColorStop( 1, 'rgba(255, 255, 255, 0)' );
		context.globalAlpha = glow;
		context.fillStyle = radial;
		context.fillRect( 0, 0, 16, 16 );

		return element;

	} );

	const texture = new THREE.CubeTexture( faces, mapping );
	texture.colorSpace = THREE.SRGBColorSpace;
	texture.needsUpdate = true;

	return texture;

}

// A cube map of six DataTexture faces (sRGB bytes) of one smooth function of the direction, continuous across the
// faces: warmer toward +x, darker below, a soft spot toward (0.4, 0.5, 0.75). For minified reflections, where
// texels are about a pixel and the canvas faces' seams were too steep a contrast for the two GPU paths.
function smoothCube( mapping = THREE.CubeReflectionMapping, size = 16 ) {

	const faces = [];
	const direction = new THREE.Vector3();
	const spot = new THREE.Vector3( 0.4, 0.5, 0.75 ).normalize();

	for ( let face = 0; face < 6; face ++ ) {

		const data = new Uint8Array( size * size * 4 );

		for ( let j = 0; j < size; j ++ ) {

			for ( let i = 0; i < size; i ++ ) {

				const sc = ( i + 0.5 ) / size * 2 - 1, tc = ( j + 0.5 ) / size * 2 - 1;
				const table = [ [ 1, - tc, - sc ], [ - 1, - tc, sc ], [ sc, 1, tc ], [ sc, - 1, - tc ], [ sc, - tc, 1 ], [ - sc, - tc, - 1 ] ];
				direction.fromArray( table[ face ] ).normalize();

				const light = 0.55 + 0.3 * direction.y + 0.25 * Math.exp( - 4 * ( 1 - direction.dot( spot ) ) );
				const color = [ light * ( 0.9 + 0.25 * direction.x ), light * 0.85, light * ( 0.8 - 0.2 * direction.x ), 1 ];
				data.set( color.map( ( c ) => Math.round( 255 * THREE.MathUtils.clamp( c, 0, 1 ) ) ), ( j * size + i ) * 4 );

			}

		}

		faces.push( new THREE.DataTexture( data, size, size ) );

	}

	const texture = new THREE.CubeTexture( faces, mapping );
	texture.colorSpace = THREE.SRGBColorSpace;
	texture.needsUpdate = true;

	return texture;

}

// A 64 × 32 HalfFloatType equirectangular sky in linear light: dark ground to a blue zenith, warmer toward +x,
// with a soft bright sun of `sun` times the sky (less where its rim would be sampled at a steep angle).
// Linearly filtered without mipmaps.
function sky( options = {}, sun = 4 ) {

	const width = 64, height = 32;
	const data = new Uint16Array( width * height * 4 );
	const toward = new THREE.Vector3( 0.6, 0.55, 0.58 ).normalize();
	const direction = new THREE.Vector3();

	for ( let y = 0; y < height; y ++ ) {

		for ( let x = 0; x < width; x ++ ) {

			// The inverse of equirectUv at the texel centre.
			const phi = ( ( x + 0.5 ) / width - 0.5 ) * 2 * Math.PI;
			const theta = ( ( y + 0.5 ) / height - 0.5 ) * Math.PI;
			direction.set( Math.cos( phi ) * Math.cos( theta ), Math.sin( theta ), Math.sin( phi ) * Math.cos( theta ) );

			const up = THREE.MathUtils.smoothstep( direction.y, - 0.3, 0.7 );
			const warm = 0.5 + 0.5 * direction.x;
			const glow = sun * Math.exp( - 12 * ( 1 - direction.dot( toward ) ) );
			const color = [
				0.12 + 0.25 * up + 0.3 * warm * ( 1 - up ) + glow,
				0.1 + 0.4 * up + 0.12 * warm + glow * 0.9,
				0.08 + 0.75 * up + glow * 0.7,
				1,
			];

			color.forEach( ( c, i ) => data[ ( y * width + x ) * 4 + i ] = THREE.DataUtils.toHalfFloat( c ) );

		}

	}

	const texture = new THREE.DataTexture( data, width, height, THREE.RGBAFormat, THREE.HalfFloatType );
	texture.mapping = THREE.EquirectangularReflectionMapping;
	texture.magFilter = THREE.LinearFilter;
	texture.minFilter = THREE.LinearFilter;
	Object.assign( texture, options );
	texture.needsUpdate = true;

	return texture;

}

// A grid of spheres of `material( roughness, metalness )`, seen by front(): roughness 0.45, 0.7, 0.95 from left
// to right, metalness 1 and 0 from top to bottom. The physical materials' geometryRoughness jumps from triangle to
// triangle, steeply in the slivers at a silhouette, so the offsets keep pixel centres 0.025 pixel off the
// silhouettes and off the interior edges near them (edges.mjs --threshold 0.025 --rim 0.35); 12 segments made
// that possible at this size. A 3 × 3 grid of smaller spheres, 16 or 32 segments, and roughness 0.3 to 0.4 on the
// metal spheres still left rim pixels or highlights differing by 3 to 40/255 (docs/flutter-gpu.md).
const gridOffsets = [ [ - 0.009, 0.0405 ], [ 0, - 0.0435 ], [ - 0.009, 0.036 ], [ 0.009, - 0.036 ], [ 0, 0.0435 ], [ 0.009, - 0.0405 ] ];

function grid( scene, material, offsets = gridOffsets ) {

	[ 1, 0 ].forEach( ( metalness, row ) => {

		[ 0.45, 0.7, 0.95 ].forEach( ( roughness, column ) => {

			const [ dx, dy ] = offsets[ row * 3 + column ] ?? [ 0, 0 ];
			const mesh = sphere( material( roughness, metalness ), ( column - 1 ) * 0.92 + dx, ( 0.5 - row ) * 1.05 + dy, 0, 0.44, 12 );
			mesh.name = `sphere ${ row * 3 + column }`;
			scene.add( mesh );

		} );

	} );

	return scene;

}

// Four front-facing quads in a 2 × 2 layout (front()), `materials` from the top left, row by row; edges off
// pixel centres.
function quads( scene, materials ) {

	const places = [ [ - 0.547, 0.513 ], [ 0.553, 0.513 ], [ - 0.547, - 0.487 ], [ 0.553, - 0.487 ] ];

	materials.forEach( ( material, i ) => {

		const mesh = material.isMesh ? material : quad( material, places[ i ][ 0 ], places[ i ][ 1 ], 0, 1.031, 0.97 );

		if ( material.isMesh ) mesh.position.set( places[ i ][ 0 ], places[ i ][ 1 ], 0 );

		scene.add( mesh );

	} );

	return scene;

}

// A front-facing quad's plain geometry with tangents (computeTangents), for anisotropy and normal maps that use
// USE_TANGENT.
function tangentQuad( material ) {

	const geometry = plain( new THREE.PlaneGeometry( 1.031, 0.97 ) );
	geometry.computeTangents();

	return new THREE.Mesh( geometry, material );

}

// A floor and two boxes under a directional light that casts shadows (a 256 × 256 map over a 3.2 × 3.2 frustum),
// for the shadow scenes: the floor receives, the boxes cast and receive. Returns the parts for a scene to adjust.
// The shadow map is rasterized too: the light shines in the xy plane and the boxes are axis-aligned, so their
// silhouettes are rectangles in the map, placed with their edges off texel centres (texel coordinates of the
// edges: u 116 and 156, v 129.003 and 180.997 for the floating box; u 80 and 112, v 68.67 and 119.18 for the
// standing one).
function shadowed( floorMaterial, boxMaterial ) {

	const scene = new THREE.Scene();
	scene.add( new THREE.AmbientLight( 0xffffff, 0.4 ) );

	const light = new THREE.DirectionalLight( 0xfff4e8, 2.4 );
	light.position.set( - 1.2, 3, 0 );
	light.castShadow = true;
	light.shadow.mapSize.set( 256, 256 );
	Object.assign( light.shadow.camera, { left: - 1.6, right: 1.6, top: 1.6, bottom: - 1.6, near: 0.5, far: 8 } );

	const floor = new THREE.Mesh( new THREE.PlaneGeometry( 6, 6 ), floorMaterial );
	floor.rotation.x = - Math.PI / 2;
	floor.receiveShadow = true;

	const floating = new THREE.Mesh( new THREE.BoxGeometry( 0.5, 0.5, 0.5 ), boxMaterial );
	floating.position.set( 0.1435, 0.55, 0.1 );

	const standing = new THREE.Mesh( new THREE.BoxGeometry( 0.4, 0.7, 0.4 ), boxMaterial );
	standing.position.set( - 0.6, 0.353, - 0.4 );

	for ( const box of [ floating, standing ] ) {

		box.castShadow = true;
		box.receiveShadow = true;

	}

	scene.add( light, floor, floating, standing );

	return { scene, light, floor, floating, standing, camera: camera( 45, [ 0.6, 2.2, 2.8 ] ) };

}

// The floor and boxes of shadowed() under a spot light that casts shadows (a perspective shadow camera of fov
// 2 × angle × focus, a 256 × 256 map). Returns the parts for a scene to adjust. The light stays in the xy plane,
// so the boxes' edges along z are rows in the map, placed off texel centres (v at least 0.29 texel from one; at
// (- 1.2, 3) the floating box's top edge fell on a centre, v 180.50, and the paths' coverage of that row moved
// the end of its PCF shadow by a pixel).
function spotted( floorMaterial, boxMaterial ) {

	const { scene, light: sun, floor, floating, standing, camera } = shadowed( floorMaterial, boxMaterial );
	scene.remove( sun );

	const light = new THREE.SpotLight( 0xfff4e8, 24, 0, 0.55, 0.2, 2 );
	light.position.set( - 1.28, 3.08, 0 );
	light.castShadow = true;
	light.shadow.mapSize.set( 256, 256 );
	scene.add( light );

	return { scene, light, floor, floating, standing, camera };

}

// The floor and boxes of shadowed() under a point light that casts shadows (a 256 × 256 cube map, near 0.5 and
// far 500). Returns the parts for a scene to adjust.
function pointed( floorMaterial, boxMaterial ) {

	const { scene, light: sun, floor, floating, standing, camera } = shadowed( floorMaterial, boxMaterial );
	scene.remove( sun );

	const light = new THREE.PointLight( 0xfff4e8, 10, 0, 2 );
	light.position.set( - 0.25, 1.9, 0.05 );
	light.castShadow = true;
	light.shadow.mapSize.set( 256, 256 );
	scene.add( light );

	return { scene, light, floor, floating, standing, camera };

}

// pointed() with a back wall at z = - 1 that receives shadows and a tall box before it, under PCFShadowMap. The
// light moved to (- 0.28, 1.98, 0.11) keeps every box corner at least 0.15 texel from a texel centre's row and
// column in the cube map (the PCF samples read the texels around a silhouette, whose coverage ties went either
// way), and the camera moved slightly from shadowed()'s keeps fewer silhouette edges on pixel centres
// (edges.mjs). The wall's points below y 0.87 lie in the cube map's - Y face, those above in its - Z face, so
// the tall box's shadow on the wall crosses the border between them. A shelf's front edge lies along that border
// in the map, a quarter texel inside the - Z face, so its shadow's edge on the wall runs along the border and
// the PCF samples of the pixels below it read the shelf from the - Z face's last row (seamless cube sampling).
function walled() {

	const { scene, light } = pointed( new THREE.MeshLambertMaterial( { color: 0xcccccc } ), new THREE.MeshLambertMaterial( { color: 0xdd8855 } ) );

	const wall = new THREE.Mesh( new THREE.PlaneGeometry( 6, 3 ), new THREE.MeshLambertMaterial( { color: 0xaabbcc } ) );
	wall.position.set( 0, 1.5, - 1 );
	wall.receiveShadow = true;

	const tall = new THREE.Mesh( new THREE.BoxGeometry( 0.3, 1.2, 0.3 ), new THREE.MeshLambertMaterial( { color: 0x66aa77 } ) );
	tall.position.set( 0.4, 0.6, - 0.7 );
	tall.castShadow = true;
	tall.receiveShadow = true;

	const shelf = new THREE.Mesh( new THREE.BoxGeometry( 0.6, 0.05, 0.32 ), new THREE.MeshLambertMaterial( { color: 0x8877aa } ) );
	shelf.position.set( - 0.55, 1.2964, - 0.76 );
	shelf.castShadow = true;
	shelf.receiveShadow = true;

	light.position.set( - 0.28, 1.98, 0.11 );
	scene.add( wall, tall, shelf );

	return { scene, light, camera: camera( 45, [ 0.62, 2.2, 2.78 ] ) };

}

// The world size of `pixels` window pixels at view depth `depth` for front(), the scale of an attenuated sprite.
function span( pixels, depth ) {

	return pixels * 2 * Math.tan( THREE.MathUtils.degToRad( 25 ) ) * depth / size;

}

// A sprite of `material` centred on window pixel [ x, y ] at view depth `depth`, `width` × `height` pixels.
// An orthographic camera down -z over the [-1, 1] square.
function flat() {

	const camera = new THREE.OrthographicCamera( - 1, 1, 1, - 1, 0.1, 10 );
	camera.position.set( 0, 0, 3 );

	return camera;

}

// The frame_* scenes: with autoClear off, renderer.clear(), the main scene (a lit quad near the camera over a red one
// far behind), then, after renderer.clearDepth() when `clearDepth` is set, the overlay scene drawn into the same
// frame: opaque quads farther away than the near quad, which its kept depth hides without the clearDepth, and a
// half-transparent one blended over the main scene's color.
function overlaid( clearDepth ) {

	const scene = stage( new THREE.Scene() );
	scene.add( texels( new THREE.MeshLambertMaterial( { color: 0x44cc66 } ), 14.2, 50.8, 10.3, 40.7, 1 ) );
	scene.add( texels( new THREE.MeshBasicMaterial( { color: 0xff3020 } ), 4.3, 30.7, 30.2, 60.8, - 2 ) );

	const overlay = new THREE.Scene();
	overlay.add( texels( new THREE.MeshBasicMaterial( { color: 0xffcc33 } ), 6.2, 24.8, 4.3, 22.7, - 1 ) );
	overlay.add( texels( new THREE.MeshBasicMaterial( { color: 0x3060ff } ), 40.3, 60.7, 30.2, 54.8, - 1 ) );
	overlay.add( texels( new THREE.MeshBasicMaterial( { color: 0xffffff, transparent: true, opacity: 0.5 } ), 20.2, 44.8, 34.3, 58.7, - 1 ) );

	return { scene, camera: flat(), clear: [ 0x203040, 1 ], overlay: { scene: overlay, camera: flat(), clearDepth } };

}

// The scene of the depth_texture_* scenes: their target, with a depth texture of `depthTexture` ({ type, format }),
// shown texel for pixel (nearest filtering) on a quad filling the frame, so its silhouettes fall under the edge rule.
function depthView( depthTexture ) {

	const target = new THREE.Scene();
	const material = new THREE.MeshBasicMaterial( { color: 0xffffff } );
	const plane = quad( material, 0, 0, - 1, 3.2, 3.2 );
	plane.rotation.x = - 1.1;
	const box = new THREE.Mesh( new THREE.BoxGeometry( 0.8, 0.8, 0.8 ), material );
	box.position.set( - 0.5, 0.35, 0.6 );
	box.rotation.set( 0.5, 0.7, 0.2 );
	target.add( plane, box, sphere( material, 0.6, - 0.1, - 0.2, 0.5, 24 ) );

	const camera = new THREE.PerspectiveCamera( 50, 1, 1.5, 5 );
	camera.position.set( 0, 0, 3 );

	const scene = new THREE.Scene();
	scene.add( quad( new THREE.MeshBasicMaterial( { userData: { depthTexture: true } } ), 0, 0, 0, 2, 2 ) );

	return {
		scene,
		camera: flat(),
		clear: [ 0x000000, 1 ],
		target: { scene: target, camera, size: [ 128, 128 ], clear: [ 0x336699, 1 ], options: {}, depthTexture },
	};

}

// A quad between the texel edges x0..x1 and y0..y1 (from the bottom left) of a 64 × 64 target seen by flat().
function texels( material, x0, x1, y0, y1, z = 0 ) {

	return quad( material, ( x0 + x1 ) / 64 - 1, ( y0 + y1 ) / 64 - 1, z, ( x1 - x0 ) / 32, ( y1 - y0 ) / 32 );

}

function sprite( material, [ x, y ], depth, width, height ) {

	const object = new THREE.Sprite( material );
	object.position.fromArray( at( [ [ x, y ] ], depth ) );
	object.scale.set( span( width, depth ), span( height, depth ), 1 );

	return object;

}

// Positions for front() of window pixels [ x, y ] (from the top left) at view depth `depth`: a point's square
// covers the pixel centres within size / 2 of its window position, so the scenes put an even-sized point near a
// pixel corner and an odd-sized one near a pixel centre, with its edges far from pixel centres.
function at( pixels, depth ) {

	const t = Math.tan( THREE.MathUtils.degToRad( 25 ) ) * depth;

	return pixels.flatMap( ( [ x, y ] ) => [ ( x / 64 - 1 ) * t, ( 1 - y / 64 ) * t, 3 - depth ] );

}

// A vertical bar (8 rows of quads, 0.4 × 1.6, facing +z) skinned to two bones: the root at its foot, the second
// at its middle, posed with `rotation`; the weights blend linearly between y = -0.4 and 0.4. The bones are
// children of the mesh (attached) or of `parent` (detached, bound with the mesh's world matrix). With `bones`
// above 2 the skeleton has that many, the bar's two last, the others children of the root turned by 0.01 i
// about z (so reading a wrong bone shows); `geometry` replaces the bar's (morphed()'s, which has its vertices).
function skinned( material, [ x, y ], rotation, parent = null, { bones = 2, geometry = null } = {} ) {

	const positions = [], normals = [], indices = [], skinIndices = [], skinWeights = [];

	for ( let i = 0; i <= 8; i ++ ) {

		const v = - 0.8 + 0.2 * i;
		const w = THREE.MathUtils.clamp( ( v + 0.4 ) / 0.8, 0, 1 );

		for ( const u of [ - 0.2, 0.2 ] ) {

			positions.push( u, v, 0 );
			normals.push( 0, 0, 1 );
			skinIndices.push( bones - 2, bones - 1, 0, 0 );
			skinWeights.push( 1 - w, w, 0, 0 );

		}

		if ( i < 8 ) {

			indices.push( 2 * i, 2 * i + 1, 2 * i + 2, 2 * i + 1, 2 * i + 3, 2 * i + 2 );

		}

	}

	if ( geometry === null ) {

		geometry = new THREE.BufferGeometry();
		geometry.setAttribute( 'position', new THREE.Float32BufferAttribute( positions, 3 ) );
		geometry.setAttribute( 'normal', new THREE.Float32BufferAttribute( normals, 3 ) );
		geometry.setIndex( indices );

	}

	geometry.setAttribute( 'skinIndex', new THREE.Uint16BufferAttribute( skinIndices, 4 ) );
	geometry.setAttribute( 'skinWeight', new THREE.Float32BufferAttribute( skinWeights, 4 ) );

	const mesh = new THREE.SkinnedMesh( geometry, material );
	mesh.position.set( x, y, 0 );

	const root = new THREE.Bone();
	root.position.set( x, y - 0.8, 0 );
	const middle = new THREE.Bone();
	middle.position.y = 0.8;
	root.add( middle );

	const others = [];

	for ( let i = 0; i < bones - 2; i ++ ) {

		others.push( new THREE.Bone() );
		root.add( others[ i ] );

	}

	if ( parent ) {

		mesh.bindMode = THREE.DetachedBindMode;
		parent.add( root );

	} else {

		root.position.sub( mesh.position );
		mesh.add( root );

	}

	mesh.updateMatrixWorld( true );
	root.updateMatrixWorld( true );
	mesh.bind( new THREE.Skeleton( [ ...others, root, middle ] ), mesh.matrixWorld );
	middle.rotation.set( ...rotation );
	others.forEach( ( bone, i ) => bone.rotation.z = 0.01 * i );

	return mesh;

}

// A bar of 2 × 9 vertices like skinned()'s, with two morph targets: 0 bends it (x, or z with `bend: 'z'`, by
// 0.35 t² over its height t from 0 to 1, with the matching normals), 1 widens its top (by 0.5 t). Absolute
// targets unless `relative`; `colors` adds morphed vertex colors (base grey, targets red and blue); `flat`
// draws it non-indexed from its second quad (a group from vertex 6: toJSON keeps groups, not drawRange), where
// the vertex buffers start past the first vertex.
function morphed( material, [ x, y ], influences, { relative = false, normals = false, colors = false, bend = 'x', flat = false } = {} ) {

	const positions = [], baseNormals = [], baseColors = [], indices = [];
	const targets = [ [], [] ], targetNormals = [ [], [] ], targetColors = [ [], [] ];

	for ( let i = 0; i <= 8; i ++ ) {

		const v = - 0.8 + 0.2 * i;
		const t = i / 8;
		const curve = 0.35 * t * t;

		for ( const u of [ - 0.2, 0.2 ] ) {

			const bent = bend === 'x' ? [ curve, 0, 0 ] : [ 0, 0, curve ];
			const bentNormal = bend === 'x' ? [ - 0.7 * t, 0, 0 ] : [ 0, - 0.7 * t, 0 ];
			const wide = [ u * 0.5 * t, 0, 0 ];

			positions.push( u, v, 0 );
			baseNormals.push( 0, 0, 1 );
			baseColors.push( 0.5, 0.5, 0.5 );

			targets[ 0 ].push( ...bent.map( ( d, k ) => relative ? d : d + [ u, v, 0 ][ k ] ) );
			targets[ 1 ].push( ...wide.map( ( d, k ) => relative ? d : d + [ u, v, 0 ][ k ] ) );
			targetNormals[ 0 ].push( ...bentNormal.map( ( d, k ) => relative ? d : d + [ 0, 0, 1 ][ k ] ) );
			targetNormals[ 1 ].push( 0, 0, relative ? 0 : 1 );
			targetColors[ 0 ].push( ...[ 0.4, - 0.3, - 0.3 ].map( ( d ) => relative ? d : d + 0.5 ) );
			targetColors[ 1 ].push( ...[ - 0.3, - 0.2, 0.4 * t ].map( ( d ) => relative ? d : d + 0.5 ) );

		}

		if ( i < 8 ) {

			indices.push( 2 * i, 2 * i + 1, 2 * i + 2, 2 * i + 1, 2 * i + 3, 2 * i + 2 );

		}

	}

	let geometry = new THREE.BufferGeometry();
	geometry.setAttribute( 'position', new THREE.Float32BufferAttribute( positions, 3 ) );
	geometry.setAttribute( 'normal', new THREE.Float32BufferAttribute( baseNormals, 3 ) );

	if ( colors ) {

		geometry.setAttribute( 'color', new THREE.Float32BufferAttribute( baseColors, 3 ) );

	}

	geometry.morphAttributes.position = targets.map( ( array ) => new THREE.Float32BufferAttribute( array, 3 ) );

	if ( normals ) {

		geometry.morphAttributes.normal = targetNormals.map( ( array ) => new THREE.Float32BufferAttribute( array, 3 ) );

	}

	if ( colors ) {

		geometry.morphAttributes.color = targetColors.map( ( array ) => new THREE.Float32BufferAttribute( array, 3 ) );

	}

	geometry.morphTargetsRelative = relative;
	geometry.setIndex( indices );

	if ( flat ) {

		geometry = geometry.toNonIndexed();
		geometry.addGroup( 6, 42, 0 );

	}

	const mesh = new THREE.Mesh( geometry, flat ? [ material ] : material );
	mesh.position.set( x, y, 0 );
	mesh.morphTargetInfluences = influences;

	return mesh;

}

// A 0.3 box copied into a BufferGeometry (toJSON keeps a BoxGeometry's parameters only) with two absolute
// morph targets: stretched 1.6 times along y, and twisted about y (a quarter turn from bottom to top).
function twisted() {

	const geometry = new THREE.BufferGeometry().copy( new THREE.BoxGeometry( 0.3, 0.3, 0.3 ) );
	const position = geometry.getAttribute( 'position' );
	const stretched = [], turned = [];

	for ( let i = 0; i < position.count; i ++ ) {

		const [ x, y, z ] = [ position.getX( i ), position.getY( i ), position.getZ( i ) ];
		const angle = ( y / 0.3 + 0.5 ) * Math.PI / 2;
		stretched.push( x, y * 1.6, z );
		turned.push( x * Math.cos( angle ) - z * Math.sin( angle ), y, x * Math.sin( angle ) + z * Math.cos( angle ) );

	}

	geometry.morphAttributes.position = [ stretched, turned ].map( ( array ) => new THREE.Float32BufferAttribute( array, 3 ) );

	return geometry;

}

// An InstancedMesh of `geometry` with one instance per [ x, y, z, rotation x, y, z, scale x, y ] (scale z 1) and,
// with `colors`, an instanceColor per instance. The mesh sits at `offset` and its instances are shifted back, so
// only the instanced bounding sphere keeps it in the frustum. `count` may draw fewer instances than it holds.
// `morphs` gives each instance its morph target influences (setMorphAt).
function instanced( geometry, material, places, { colors = null, offset = [ 0, 0, 0 ], count = places.length, morphs = null } = {} ) {

	const mesh = new THREE.InstancedMesh( geometry, material, places.length );
	const matrix = new THREE.Matrix4();
	const at = new THREE.Vector3();

	mesh.position.fromArray( offset );

	places.forEach( ( [ x, y, z, rx, ry, rz, sx, sy ], i ) => {

		at.set( x, y, z ).sub( mesh.position );
		matrix.compose( at, new THREE.Quaternion().setFromEuler( new THREE.Euler( rx, ry, rz ) ), new THREE.Vector3( sx, sy, 1 ) );
		mesh.setMatrixAt( i, matrix );

		if ( colors !== null ) {

			mesh.setColorAt( i, new THREE.Color( colors[ i ] ) );

		}

		if ( morphs !== null ) {

			const source = new THREE.Mesh();
			source.morphTargetInfluences = morphs[ i ];
			mesh.setMorphAt( i, source );

		}

	} );

	// toJSON drops the morphTexture: the influences ride in userData, where parity_test.dart sets them again.
	if ( morphs !== null ) {

		mesh.morphTexture.needsUpdate = true;
		mesh.userData.morphs = morphs;

	}

	mesh.count = count;

	return mesh;

}

// A BatchedMesh of `geometries` with one instance per [ geometry, x, y, z, rotation x, y, z, scale x, y ] (scale
// z 1) and, with `colors`, a color per instance; the instances listed in `hidden` are set invisible. Its own
// culling and sorting stay on, as upstream's defaults.
function batched( geometries, material, places, { colors = null, hidden = [] } = {} ) {

	const vertices = geometries.reduce( ( sum, g ) => sum + g.getAttribute( 'position' ).count, 0 );
	const indices = geometries.reduce( ( sum, g ) => sum + g.getIndex().count, 0 );
	const mesh = new THREE.BatchedMesh( places.length, vertices, indices, material );
	const ids = geometries.map( ( g ) => mesh.addGeometry( g ) );
	const matrix = new THREE.Matrix4();

	places.forEach( ( [ g, x, y, z, rx, ry, rz, sx, sy ], i ) => {

		const instance = mesh.addInstance( ids[ g ] );
		matrix.compose( new THREE.Vector3( x, y, z ), new THREE.Quaternion().setFromEuler( new THREE.Euler( rx, ry, rz ) ), new THREE.Vector3( sx, sy, 1 ) );
		mesh.setMatrixAt( instance, matrix );

		if ( colors !== null ) {

			mesh.setColorAt( instance, new THREE.Color( colors[ i ] ) );

		}

		if ( hidden.includes( i ) ) {

			mesh.setVisibleAt( instance, false );

		}

	} );

	return mesh;

}

// A room for CubeCamera scenes: the inside of an 8 × 8 × 8 box (BackSide) whose corners have distinct vertex
// colors, smooth across its faces, so a reflected face swap or mirror shows. No sharp-edged meshes: the 32 × 32
// faces are reflected at about a texel per pixel, where the two paths differed by up to 9/255 at a quad's edges. The reflective sphere (`material`,
// `userData.cubeTarget`) sits where grid() puts its first sphere, rims clear of pixel centres; `reflector`, a mesh
// of `material`, replaces it.
function room( material, reflector = null ) {

	const scene = new THREE.Scene();
	const geometry = plain( new THREE.BoxGeometry( 8, 8, 8 ) );
	const position = geometry.getAttribute( 'position' );
	const colors = [];

	for ( let i = 0; i < position.count; i ++ ) {

		const [ x, y, z ] = [ position.getX( i ), position.getY( i ), position.getZ( i ) ].map( ( v ) => v > 0 ? 1 : 0 );
		colors.push( 0.15 + 0.7 * x, 0.2 + 0.6 * y, 0.25 + 0.5 * z );

	}

	geometry.setAttribute( 'color', new THREE.Float32BufferAttribute( colors, 3 ) );
	scene.add( new THREE.Mesh( geometry, new THREE.MeshBasicMaterial( { vertexColors: true, side: THREE.BackSide } ) ) );

	material.userData.cubeTarget = true;
	scene.add( reflector ?? sphere( material, - 0.929, 0.5655, 0, 0.44, 12 ) );

	return scene;

}

// A Khronos glTF sample model (fixtures/gltf/khronos/, fetched by tool/fetch_gltf_samples.sh), loaded as in
// gltf_meshes: sky.hdr as scene.environment and background, one directional light, a perspective camera at
// `position` looking at `target`, both picked by hand to frame the model.
function khronos( file, position, target = [ 0, 0, 0 ] ) {

	const scene = new THREE.Scene();

	const light = new THREE.DirectionalLight( 0xffffff, 2 );
	light.position.set( 1, 2, 3 );
	scene.add( light );

	const camera = new THREE.PerspectiveCamera( 45, 1, 0.1, 100 );
	camera.position.fromArray( position );
	camera.lookAt( ...target );

	return {
		scene,
		camera,
		clear: [ 0x000000, 1 ],
		gltf: `/fixtures/gltf/khronos/${ file }`,
		hdr: { url: '/fixtures/hdr/sky.hdr' },
	};

}

export default {

	gltf_meshes() {

		// fixtures/gltf/render.gltf (tool/reference/js/gltf_files.mjs): page.html loads it with r187's
		// GLTFLoader and adds its scene last, after taking the JSON without it; parity_test.dart loads the same file
		// with the Dart GLTFLoader. Lit, unlit, emissive, blended, strip and interleaved quads with vertex colors
		// and the asset's directional light; quad edges lie halfway between pixel centres.
		const scene = new THREE.Scene();
		scene.add( new THREE.AmbientLight( 0xffffff, 0.6 ) );

		const camera = new THREE.OrthographicCamera( - 1, 1, 1, - 1, 0.1, 10 );
		camera.position.set( 0, 0, 2 );

		return { scene, camera, clear: [ 0x202020, 1 ], gltf: '/fixtures/gltf/render.gltf' };

	},

	gltf_textured() {

		// fixtures/gltf/render_textured.gltf (gltf_files.mjs), loaded as in gltf_meshes: a nearest-filtered
		// checker with a KHR_texture_transform (offset, rotation, scale), linear normal, occlusion/roughness/metalness
		// and emissive maps, a clearcoat + sheen quad, a transmissive quad over an opaque bar, a line strip and
		// vertex-colored points along pixel centres.
		const scene = new THREE.Scene();
		scene.add( new THREE.AmbientLight( 0xffffff, 0.6 ) );

		const camera = new THREE.OrthographicCamera( - 1, 1, 1, - 1, 0.1, 10 );
		camera.position.set( 0, 0, 2 );

		return { scene, camera, clear: [ 0x202020, 1 ], gltf: '/fixtures/gltf/render_textured.gltf' };

	},

	gltf_skinned_anim() {

		// fixtures/gltf/skinned.gltf (gltf_files.mjs), loaded as in gltf_meshes, with its two clips playing
		// (page.html puts them on the glTF scene): a lit column skinned to two bones whose root moves along a cubic
		// spline and turns linearly, the tip turning along a quaternion cubic spline and scaling in steps, both
		// morph targets weighted linearly; an unlit quad whose weights follow a cubic spline and whose rotation
		// steps from normalized int16 keys. Times: between keys of every channel, and past the clips' ends (LoopRepeat
		// wraps).
		const scene = new THREE.Scene();
		scene.add( new THREE.AmbientLight( 0xffffff, 0.6 ) );

		const light = new THREE.DirectionalLight( 0xffffff, 2 );
		light.position.set( 0.5, 0.8, 1 );
		scene.add( light );

		const camera = new THREE.OrthographicCamera( - 1, 1, 1, - 1, 0.1, 10 );
		camera.position.set( 0, 0, 2 );

		return { scene, camera, clear: [ 0x202020, 1 ], gltf: '/fixtures/gltf/skinned.gltf', animate: { times: [ 0.3, 0.7, 1.4 ] } };

	},

	// Khronos samples (khronos above): the textured box at an angle, its sampler NEAREST_MIPMAP_LINEAR.
	khronos_box_textured() {

		return khronos( 'BoxTextured/glTF-Binary/BoxTextured.glb', [ 1.4, 1.1, 1.9 ] );

	},

	// TEXCOORD_0 orientation: four double-sided textured quads before a back plane, seen straight on.
	khronos_texture_coordinate() {

		return khronos( 'TextureCoordinateTest/glTF-Binary/TextureCoordinateTest.glb', [ 0, 0, 3.4 ] );

	},

	// COLOR_0 multiplied with the base color texture, and the labels' plane.
	khronos_vertex_color() {

		return khronos( 'VertexColorTest/glTF-Binary/VertexColorTest.glb', [ 0, 0.3, 3.2 ] );

	},

	// OPAQUE, BLEND and MASK with cutoffs 0.25, 0.5 (default) and 0.75 on JPEG-textured strips over a bed.
	khronos_alpha_blend_mode() {

		return khronos( 'AlphaBlendModeTest/glTF-Binary/AlphaBlendModeTest.glb', [ 0, 2.2, 10.5 ], [ 0, 1, 0 ] );

	},

	// A normal map baked on mirrored UVs with per-vertex tangents, plus occlusion and metallic-roughness maps, seen at
	// an angle so the light shows which way the bumps face.
	khronos_normal_tangent_mirror() {

		return khronos( 'NormalTangentMirrorTest/glTF-Binary/NormalTangentMirrorTest.glb', [ 0.8, 0.4, 3.6 ], [ 0, - 0.08, 0 ] );

	},

	// KHR_texture_transform offsets, rotation, scale and all three on six quads; the glTF variant with an external
	// .bin and PNGs, which the Dart test reads through the loader's manager.
	khronos_texture_transform() {

		return khronos( 'TextureTransformTest/glTF/TextureTransformTest.gltf', [ 0, 0, 4.3 ] );

	},

	// KHR_materials_clearcoat: six rows of base, coated and coating-only spheres (plain, partial through a clearcoat
	// texture, roughness texture, base normals, coat normals, shared normals), the row labels left out of frame.
	khronos_clearcoat() {

		return khronos( 'ClearCoatTest/glTF-Binary/ClearCoatTest.glb', [ 0, 0.4, 17 ], [ 0, 0.4, 0 ] );

	},

	// KHR_materials_transmission: plain, textured, masked and rough or metallic transmissive shapes before a
	// textured cloth backdrop, which the transmission pass draws first.
	khronos_transmission() {

		return khronos( 'TransmissionTest/glTF-Binary/TransmissionTest.glb', [ - 0.02, 0.03, 1.35 ], [ - 0.02, 0, 0 ] );

	},

	// Morph target animation: the cube's `Square` clip (127 LINEAR keys over 4.2 s) weights its two targets, which
	// pull the top face out. Times: rest, between keys and two shapes along the clip. Edge pixels capped at 8 (Metal
	// draws 0, SwiftShader 1 to 3 per frame; the LINEAR keys played as discrete steps gave 68 at 0.85 s).
	khronos_animated_morph_cube() {

		return { ...khronos( 'AnimatedMorphCube/glTF-Binary/AnimatedMorphCube.glb', [ 5, 2.5, 3 ], [ 0, 0, - 1 ] ), animate: { times: [ 0, 0.85, 2.1, 3.5 ] }, edges: 8 };

	},

	// Skinning with a JPEG-textured body: CesiumMan's walk (57 LINEAR channels on 19 joints, keys every 1/24 s from
	// 1/24 to 2 s). Times: the first key (t = 0 clamps to it), between keys and two poses along the clip.
	khronos_cesium_man() {

		return { ...khronos( 'CesiumMan/glTF-Binary/CesiumMan.glb', [ 1.35, 1.05, 1.7 ], [ 0, 0.78, 0 ] ), animate: { times: [ 0, 0.55, 1.1, 1.75 ] } };

	},

	basic_triangle() {

		const scene = new THREE.Scene();
		scene.add( triangle( new THREE.MeshBasicMaterial( { color: 0xff8000 } ) ) );

		return { scene, camera: camera(), clear: [ 0x202020, 1 ] };

	},

	normal_cube_over_triangle() {

		const cube = new THREE.Mesh( new THREE.BoxGeometry( 1, 1, 1 ), new THREE.MeshNormalMaterial() );
		cube.rotation.set( 0.4, Math.PI / 5, 0 );

		const scene = new THREE.Scene();
		scene.add( cube, triangle( new THREE.MeshBasicMaterial( { color: 0xff8000 } ), - 0.8 ) );

		return { scene, camera: camera(), clear: [ 0x202020, 1 ] };

	},

	basic_box_groups() {

		const colors = [ 0xff0000, 0x00ff00, 0x0000ff, 0xffff00, 0x00ffff, 0xff00ff ];
		const cube = new THREE.Mesh(
			new THREE.BoxGeometry( 1.2, 1.2, 1.2 ),
			colors.map( ( color ) => new THREE.MeshBasicMaterial( { color } ) )
		);
		cube.rotation.set( 0.5, 0.7, 0 );

		const scene = new THREE.Scene();
		scene.add( cube );

		return { scene, camera: camera(), clear: [ 0x000000, 1 ] };

	},

	normal_double_side_back() {

		const plane = new THREE.Mesh(
			new THREE.PlaneGeometry( 1.6, 1.6 ),
			new THREE.MeshNormalMaterial( { side: THREE.DoubleSide } )
		);
		plane.rotation.y = 2.6;

		const scene = new THREE.Scene();
		scene.add( plane );

		return { scene, camera: camera(), clear: [ 0x101010, 1 ] };

	},

	// MeshNormalMaterial: flatShading on a sphere, BackSide (FLIP_SIDED normals) on an open cylinder.
	normal_flat_and_back() {

		const sphere = new THREE.Mesh( new THREE.SphereGeometry( 0.7, 8, 6 ), new THREE.MeshNormalMaterial( { flatShading: true } ) );
		sphere.position.x = - 0.6;
		sphere.rotation.set( 0.3, 0.4, 0 );

		const tube = new THREE.Mesh( new THREE.CylinderGeometry( 0.5, 0.5, 1.2, 12, 1, true ), new THREE.MeshNormalMaterial( { side: THREE.BackSide } ) );
		tube.position.x = 0.7;
		tube.rotation.x = 0.6;

		const scene = new THREE.Scene();
		scene.add( sphere, tube );

		return { scene, camera: camera(), clear: [ 0x101010, 1 ] };

	},

	// Vertex colors, vec3 (USE_COLOR) and vec4 (USE_COLOR_ALPHA, blended), and vertexColors without a color
	// attribute (WebGL reads the disabled attribute as black). Edges that pass near pixel centres rasterize
	// differently (ANGLE draws upside down, so sub-pixel snapping and ties go the other way); the gradients are
	// kept gentle so an edge pixel still finds its color within one pixel of the reference.
	basic_vertex_colors() {

		const rgb = new THREE.BufferGeometry();
		rgb.setAttribute( 'position', new THREE.Float32BufferAttribute( [ - 1.2913, - 0.913, 0, 0.1037, - 0.913, 0, - 0.6047, 0.8962, 0 ], 3 ) );
		rgb.setAttribute( 'color', new THREE.Float32BufferAttribute( [ 0.9, 0.3, 0.2, 0.6, 0.5, 0.2, 0.7, 0.3, 0.5 ], 3 ) );

		const rgba = new THREE.BufferGeometry();
		rgba.setAttribute( 'position', new THREE.Float32BufferAttribute( [ - 0.2917, - 0.913, 0.1, 1.3083, - 0.913, 0.1, 0.5021, 0.8962, 0.1 ], 3 ) );
		rgba.setAttribute( 'color', new THREE.Float32BufferAttribute( [ 0.2, 0.6, 0.9, 1, 0.4, 0.8, 0.7, 0.7, 0.2, 0.8, 0.9, 0.85 ], 4 ) );

		const scene = new THREE.Scene();
		scene.add( new THREE.Mesh( rgb, new THREE.MeshBasicMaterial( { vertexColors: true } ) ) );
		scene.add( new THREE.Mesh( rgba, new THREE.MeshBasicMaterial( { vertexColors: true, transparent: true } ) ) );
		scene.add( quad( new THREE.MeshBasicMaterial( { vertexColors: true } ), 0, 0.85, - 0.2, 0.4, 0.2 ) );

		return { scene, camera: front(), clear: [ 0x808080, 1 ] };

	},

	// Opacity and transparency sorting: overlapping transparent quads at different depths, added front to
	// back; an opaque quad behind them; a renderOrder that overrides depth; an invisible material and object.
	basic_transparent_sorting() {

		const scene = new THREE.Scene();
		scene.add( quad( new THREE.MeshBasicMaterial( { color: 0x0000ff, transparent: true, opacity: 0.5 } ), 0.3, - 0.2, 0.4 ) );
		scene.add( quad( new THREE.MeshBasicMaterial( { color: 0x00ff00, transparent: true, opacity: 0.5 } ), 0, 0, 0 ) );
		scene.add( quad( new THREE.MeshBasicMaterial( { color: 0xff0000, transparent: true, opacity: 0.5 } ), - 0.3, 0.2, - 0.4 ) );
		scene.add( quad( new THREE.MeshBasicMaterial( { color: 0xffffff } ), 0, 0, - 1, 3, 0.4 ) );

		const late = quad( new THREE.MeshBasicMaterial( { color: 0xffff00, transparent: true, opacity: 0.7, depthTest: false } ), - 0.9, - 0.7, - 0.6, 0.6, 0.6 );
		late.renderOrder = 1;
		scene.add( late );

		scene.add( quad( new THREE.MeshBasicMaterial( { color: 0xff00ff, visible: false } ), 0.9, 0.7, 0.5, 0.5, 0.5 ) );

		const hidden = quad( new THREE.MeshBasicMaterial( { color: 0x00ffff } ), 0.9, - 0.7, 0.5, 0.5, 0.5 );
		hidden.visible = false;
		scene.add( hidden );

		return { scene, camera: front(), clear: [ 0x303030, 1 ] };

	},

	// A transparent DoubleSide box: back faces are drawn first, then front faces.
	basic_transparent_double_side() {

		const cube = new THREE.Mesh(
			new THREE.BoxGeometry( 1.2, 1.2, 1.2 ),
			new THREE.MeshBasicMaterial( { color: 0x44aaff, transparent: true, opacity: 0.4, side: THREE.DoubleSide } )
		);
		cube.rotation.set( 0.5, 0.7, 0 );

		const scene = new THREE.Scene();
		scene.add( cube );
		scene.add( quad( new THREE.MeshBasicMaterial( { color: 0xff8800 } ), 0, 0, - 1.5, 1.2, 1.2 ) );

		return { scene, camera: camera(), clear: [ 0x202020, 1 ] };

	},

	// depthFunc, depthWrite, depthTest, colorWrite: quads crossing a reference quad at z = 0.
	basic_depth_state() {

		const scene = new THREE.Scene();
		const base = quad( new THREE.MeshBasicMaterial( { color: 0x808080 } ), 0, 0, 0, 2.4, 2.4 );
		base.renderOrder = - 1;
		scene.add( base );

		// Behind the reference quad: drawn where the depth test passes anyway.
		const greater = quad( new THREE.MeshBasicMaterial( { color: 0xff0000, depthFunc: THREE.GreaterDepth } ), - 0.6, 0.6, - 0.3, 0.8, 0.8 );
		const always = quad( new THREE.MeshBasicMaterial( { color: 0x00ff00, depthFunc: THREE.AlwaysDepth } ), 0.6, 0.6, - 0.3, 0.8, 0.8 );
		const noTest = quad( new THREE.MeshBasicMaterial( { color: 0x0000ff, depthTest: false } ), - 0.6, - 0.6, - 0.3, 0.8, 0.8 );

		// Writes no color but its depth, so the yellow quad behind it is hidden where they overlap.
		const mask = quad( new THREE.MeshBasicMaterial( { color: 0xffffff, colorWrite: false } ), 0.45, - 0.45, 0.2, 0.5, 0.5 );
		const yellow = quad( new THREE.MeshBasicMaterial( { color: 0xffff00 } ), 0.6, - 0.6, 0.1, 0.8, 0.8 );

		// Writes no depth: the cyan quad drawn after it, behind it, still shows.
		const noWrite = quad( new THREE.MeshBasicMaterial( { color: 0xff00ff, depthWrite: false } ), 0, 0, 0.4, 0.5, 0.5 );
		const cyan = quad( new THREE.MeshBasicMaterial( { color: 0x00ffff } ), 0.15, 0.15, 0.3, 0.5, 0.5 );

		[ greater, always, noTest, mask, yellow, noWrite, cyan ].forEach( ( mesh, i ) => {

			mesh.renderOrder = i;
			scene.add( mesh );

		} );

		return { scene, camera: front(), clear: [ 0x000000, 1 ] };

	},

	// polygonOffset: coplanar quads drawn after the base; negative offsets pull a quad in front, a positive
	// one pushes it behind (the base wins).
	basic_polygon_offset() {

		const scene = new THREE.Scene();
		const base = new THREE.Mesh( new THREE.PlaneGeometry( 2.4, 2.4 ), new THREE.MeshBasicMaterial( { color: 0x808080 } ) );
		base.rotation.x = - 1.1;
		scene.add( base );

		const front = new THREE.Mesh(
			new THREE.PlaneGeometry( 1, 1 ),
			new THREE.MeshBasicMaterial( { color: 0xff0000, depthFunc: THREE.LessDepth, polygonOffset: true, polygonOffsetFactor: - 1, polygonOffsetUnits: - 4 } )
		);
		front.rotation.x = - 1.1;
		front.position.x = - 0.6;
		front.renderOrder = 1;

		const back = new THREE.Mesh(
			new THREE.PlaneGeometry( 1, 1 ),
			new THREE.MeshBasicMaterial( { color: 0x00ff00, polygonOffset: true, polygonOffsetFactor: 1, polygonOffsetUnits: 4 } )
		);
		back.rotation.x = - 1.1;
		back.position.x = 0.6;
		back.renderOrder = 1;

		scene.add( front, back );

		return { scene, camera: camera( 50, [ 0, 1.2, 2.6 ] ), clear: [ 0x000000, 1 ] };

	},

	// A negative scale flips the winding (frontFaceCW): FrontSide still shows the faces toward the camera.
	basic_negative_scale() {

		const cube = new THREE.Mesh(
			new THREE.BoxGeometry( 1, 1, 1 ),
			[ 0xff0000, 0x00ff00, 0x0000ff, 0xffff00, 0x00ffff, 0xff00ff ].map( ( color ) => new THREE.MeshBasicMaterial( { color } ) )
		);
		cube.rotation.set( 0.5, 0.7, 0 );
		cube.scale.set( - 1, 1, 1 );

		const scene = new THREE.Scene();
		scene.add( cube );

		return { scene, camera: camera(), clear: [ 0x000000, 1 ] };

	},

	// A Color background replaces the clear color.
	basic_background_color() {

		const scene = new THREE.Scene();
		scene.background = new THREE.Color( 0x335577 );
		scene.add( triangle( new THREE.MeshBasicMaterial( { color: 0xff8000, transparent: true, opacity: 0.5 } ) ) );

		return { scene, camera: camera(), clear: [ 0xff0000, 1 ] };

	},

	// DataTexture map, nearest filtering, sRGB: one texel per color.
	map_data_nearest() {

		const scene = new THREE.Scene();
		scene.add( quad( new THREE.MeshBasicMaterial( { map: palette() } ), 0, 0, 0, 2, 2 ) );

		return { scene, camera: front(), clear: [ 0x000000, 1 ] };

	},

	// Linear magnification of a no-color-space texture, flipY and premultiplyAlpha on a DataTexture, color
	// times map.
	map_data_linear_flip_premultiply() {

		const data = new Uint8Array( [
			255, 60, 40, 255, 50, 255, 70, 128,
			60, 50, 255, 64, 255, 255, 255, 0,
		] );
		const texture = new THREE.DataTexture( data, 2, 2 );
		texture.magFilter = THREE.LinearFilter;
		texture.flipY = true;
		texture.premultiplyAlpha = true;
		texture.needsUpdate = true;

		const scene = new THREE.Scene();
		// Edges and texel centres kept off pixel centres; no zero channels (see palette).
		scene.add( quad( new THREE.MeshBasicMaterial( { map: texture, transparent: true, premultipliedAlpha: true } ), - 0.565, 0.06, 0, 1.031, 1.6 ) );
		scene.add( quad( new THREE.MeshBasicMaterial( { map: palette( { magFilter: THREE.LinearFilter }, 48 ), color: 0x99ccff } ), 0.547, 0.06, 0, 1.031, 1.6 ) );

		return { scene, camera: front(), clear: [ 0x404040, 1 ] };

	},

	// uvTransform (offset, repeat, rotation, center) with RepeatWrapping and MirroredRepeatWrapping, and
	// ClampToEdge outside [0, 1].
	map_uv_transform() {

		const repeat = palette( {
			wrapS: THREE.RepeatWrapping,
			wrapT: THREE.MirroredRepeatWrapping,
			repeat: new THREE.Vector2( 2, 1.5 ),
			offset: new THREE.Vector2( 0.125, 0.25 ),
			rotation: 0.4,
			center: new THREE.Vector2( 0.5, 0.5 ),
		} );
		const clamp = palette( { repeat: new THREE.Vector2( 2, 2 ), offset: new THREE.Vector2( - 0.5, - 0.5 ) } );

		const scene = new THREE.Scene();
		scene.add( quad( new THREE.MeshBasicMaterial( { map: repeat } ), - 0.55, 0, 0, 1, 2 ) );
		scene.add( quad( new THREE.MeshBasicMaterial( { map: clamp } ), 0.55, 0, 0, 1, 2 ) );

		return { scene, camera: front(), clear: [ 0x000000, 1 ] };

	},

	// Generated mipmaps at a constant level of detail (front-facing quads, 64 texels on 14 to 25 pixels): a
	// CanvasTexture (an image in the JSON: a PNG data URL, sRGB) with LinearMipmapLinear, NearestMipmapNearest
	// and LinearMipmapNearest, and a no-color-space DataTexture with generateMipmaps. The lower right quad
	// samples level 2 of a 2-texel checker, uniform there: light and dark average in linear light. Where a texel
	// covers about a pixel, sampled values differ by up to 10/255 on high-contrast texels between the two GPU
	// paths (levels of detail and level contents match; sample positions differ by about 0.02 pixel,
	// docs/flutter-gpu.md), so the trilinear quad's checker has a low contrast, in a texture without a color
	// space (an sRGB one still differs by 3/255 at its cell edges). No zero channels (see palette).
	map_mipmaps_minified() {

		// Checkers of `cell` texels: `light` against `dark` (top half) or `red` (bottom half).
		const draw = ( cell, light = '#f0f0f0', dark = '#141414', red = '#ff3018' ) => ( context ) => {

			for ( let y = 0; y < 64; y += cell ) {

				for ( let x = 0; x < 64; x += cell ) {

					context.fillStyle = ( x + y ) % ( 2 * cell ) === 0 ? light : ( y < 32 ? dark : red );
					context.fillRect( x, y, cell, cell );

				}

			}

		};
		const data = new Uint8Array( 64 * 64 * 4 );

		for ( let i = 0; i < 64 * 64; i ++ ) {

			const x = i % 64, y = Math.floor( i / 64 );
			data.set( ( x >> 1 ) % 2 === ( y >> 2 ) % 2 ? [ 230, 40, 60, 255 ] : [ 30, 200, 240, 255 ], i * 4 );

		}

		const generated = new THREE.DataTexture( data, 64, 64 );
		generated.generateMipmaps = true;
		generated.minFilter = THREE.LinearMipmapLinearFilter;
		generated.magFilter = THREE.LinearFilter;
		generated.needsUpdate = true;

		const scene = new THREE.Scene();
		scene.add( quad( new THREE.MeshBasicMaterial( { map: canvas( 64, 64, draw( 8, '#b4a08c', '#6e7c8a', '#c87868' ), { colorSpace: THREE.NoColorSpace } ) } ), - 0.513, 0.497, 0, 0.5, 0.5 ) );
		scene.add( quad( new THREE.MeshBasicMaterial( { map: canvas( 64, 64, draw( 2 ), { minFilter: THREE.NearestMipmapNearestFilter } ) } ), 0.487, 0.517, 0, 0.55, 0.55 ) );
		scene.add( quad( new THREE.MeshBasicMaterial( { map: generated } ), - 0.493, - 0.483, 0, 0.42, 0.42 ) );
		scene.add( quad( new THREE.MeshBasicMaterial( { map: canvas( 64, 64, draw( 2 ), { minFilter: THREE.LinearMipmapNearestFilter } ) } ), 0.507, - 0.503, 0, 0.33, 0.33 ) );

		return { scene, camera: front(), clear: [ 0x000000, 1 ] };

	},

	// Mipmapped minification on a receding plane, LinearMipmapLinear. The level of detail varies along the
	// plane, and the GPU derives it per 2×2 quad from coarse derivatives; ANGLE draws upside down, so its quads
	// take their derivatives from the other row and the level differs by up to about 0.05 at grazing angles.
	// The checker's two colors are close, so that changes a pixel by less than 2/255. The far end stays below
	// level 5 of 6: Flutter GPU allocates no 1×1 level (docs/flutter-gpu.md).
	map_receding_plane() {

		const draw = ( context ) => {

			for ( let y = 0; y < 64; y += 4 ) {

				for ( let x = 0; x < 64; x += 4 ) {

					context.fillStyle = ( x + y ) % 8 === 0 ? '#c09070' : '#a8a088';
					context.fillRect( x, y, 4, 4 );

				}

			}

		};
		const map = canvas( 64, 64, draw, { wrapS: THREE.RepeatWrapping, wrapT: THREE.RepeatWrapping, repeat: new THREE.Vector2( 2, 3 ) } );
		const plane = new THREE.Mesh( new THREE.PlaneGeometry( 2.4, 12 ), new THREE.MeshBasicMaterial( { map } ) );
		plane.rotation.x = - Math.PI / 2;
		plane.position.set( 0.013, - 0.5, - 5.17 );

		const scene = new THREE.Scene();
		scene.add( plane );

		return { scene, camera: camera( 50, [ 0, 0.4, 1.4 ] ), clear: [ 0x000000, 1 ] };

	},

	// Anisotropic filtering (anisotropy 16) on map_receding_plane's plane. The checker's two colors (NoColorSpace)
	// average exactly at every level (120 in each channel), so a CPU-built and a GPU-built mip chain are the same
	// and only the sampler's anisotropy shapes the far rows; without it they blur toward the average much sooner.
	map_anisotropy() {

		const map = new THREE.DataTexture( checker( 64, 64, 4, [ 40, 200, 120, 255 ], [ 200, 40, 120, 255 ] ), 64, 64 );
		Object.assign( map, {
			wrapS: THREE.RepeatWrapping,
			wrapT: THREE.RepeatWrapping,
			minFilter: THREE.LinearMipmapLinearFilter,
			magFilter: THREE.LinearFilter,
			generateMipmaps: true,
			anisotropy: 16,
		} );
		map.repeat.set( 2, 6 );
		map.needsUpdate = true;

		const plane = new THREE.Mesh( new THREE.PlaneGeometry( 2.4, 12 ), new THREE.MeshBasicMaterial( { map } ) );
		plane.rotation.x = - Math.PI / 2;
		plane.position.set( 0.013, - 0.5, - 5.17 );

		const scene = new THREE.Scene();
		scene.add( plane );

		return { scene, camera: camera( 50, [ 0, 0.4, 1.4 ] ), clear: [ 0x000000, 1 ] };

	},

	// alphaMap (green channel, linear filtering, from uv1 on one quad) with alphaTest: hard cut-out edges.
	map_alpha_map_alpha_test() {

		const data = new Uint8Array( 8 * 8 * 4 );

		for ( let i = 0; i < 64; i ++ ) {

			const x = i % 8, y = Math.floor( i / 8 );
			data.set( [ 0, Math.round( 255 * Math.hypot( x - 3.5, y - 3.5 ) / 5 ), 0, 255 ], i * 4 );

		}

		const alphaMap = new THREE.DataTexture( data, 8, 8 );
		alphaMap.magFilter = THREE.LinearFilter;
		alphaMap.needsUpdate = true;

		const cut = plain( new THREE.PlaneGeometry( 1, 1.6 ) );
		cut.setAttribute( 'uv1', cut.getAttribute( 'uv' ).clone() );
		const uv1 = alphaMap.clone();
		uv1.channel = 1;
		uv1.needsUpdate = true;

		const scene = new THREE.Scene();
		scene.add( quad( new THREE.MeshBasicMaterial( { color: 0xffaa00, alphaMap, alphaTest: 0.5 } ), - 0.55, 0, 0, 1, 1.6 ) );
		scene.add( new THREE.Mesh( cut, new THREE.MeshBasicMaterial( { color: 0x00aaff, alphaMap: uv1, transparent: true } ) ) );
		scene.children[ 1 ].position.x = 0.55;

		return { scene, camera: front(), clear: [ 0x202020, 1 ] };

	},

	blend_normal() {

		return blending( {} );

	},

	blend_normal_premultiplied() {

		return blending( { premultipliedAlpha: true } );

	},

	blend_additive() {

		return blending( { blending: THREE.AdditiveBlending } );

	},

	blend_additive_premultiplied() {

		return blending( { blending: THREE.AdditiveBlending, premultipliedAlpha: true } );

	},

	blend_subtractive() {

		return blending( { blending: THREE.SubtractiveBlending, premultipliedAlpha: true } );

	},

	blend_multiply() {

		return blending( { blending: THREE.MultiplyBlending, premultipliedAlpha: true } );

	},

	blend_no_blending() {

		return blending( { blending: THREE.NoBlending } );

	},

	blend_custom() {

		return blending( {
			blending: THREE.CustomBlending,
			blendEquation: THREE.ReverseSubtractEquation,
			blendSrc: THREE.SrcColorFactor,
			blendDst: THREE.OneMinusDstColorFactor,
			blendEquationAlpha: THREE.AddEquation,
			blendSrcAlpha: THREE.OneFactor,
			blendDstAlpha: THREE.ZeroFactor,
		} );

	},

	blend_custom_saturate() {

		return blending( {
			blending: THREE.CustomBlending,
			blendSrc: THREE.SrcAlphaSaturateFactor,
			blendDst: THREE.OneMinusSrcAlphaFactor,
		} );

	},

	fog_linear() {

		return cubes( new THREE.Fog( 0x8899aa, 2, 12 ) );

	},

	fog_exp2() {

		return cubes( new THREE.FogExp2( 0x8899aa, 0.12 ) );

	},

	fog_material_off() {

		const result = cubes( new THREE.Fog( 0x8899aa, 2, 12 ) );
		result.scene.children.filter( ( cube, i ) => i % 2 === 1 ).forEach( ( cube ) => cube.material.fog = false );

		return result;

	},

	// The bright quads through an EffectComposer: a RenderPass into its HalfFloatType target (linear, no tone
	// mapping, the untoned quad included), then an OutputPass applying ACES and the sRGB transfer.
	composer_output() {

		return { ...bright( { toneMapping: THREE.ACESFilmicToneMapping, toneMappingExposure: 1.2 } ), composer: {} };

	},

	// The same with ShaderPasses of VignetteShader and CopyShader (opacity 1) between them, under Neutral tone
	// mapping.
	composer_effect() {

		return { ...bright( { toneMapping: THREE.NeutralToneMapping } ), composer: { vignette: { offset: 1.3, darkness: 0.8 }, copy: 1 } };

	},

	// Small bright quads on black through RenderPass, UnrealBloomPass and OutputPass under ACES: the example's
	// setting (strength 1.5, radius 0.4, threshold 0.85), so only the quads above the threshold bloom.
	composer_bloom() {

		return { ...glowing(), composer: { bloom: { strength: 1.5, radius: 0.4, threshold: 0.85 } } };

	},

	// The same with a wide, weaker bloom over a low threshold (strength 0.8, radius 1, threshold 0.2): the dim quads
	// bloom too, the mips weighted towards the widest. Each mip has its own tint, so a mip composited with another's
	// tint shows.
	composer_bloom_wide() {

		const tints = [ [ 1, 0.2, 0.2 ], [ 0.2, 1, 0.2 ], [ 0.2, 0.2, 1 ], [ 1, 1, 0.2 ], [ 0.2, 1, 1 ] ];
		return { ...glowing(), composer: { bloom: { strength: 0.8, radius: 1, threshold: 0.2, tints } } };

	},

	tone_mapping_none() {

		return bright( {} );

	},

	tone_mapping_linear() {

		return bright( { toneMapping: THREE.LinearToneMapping, toneMappingExposure: 0.7 } );

	},

	tone_mapping_reinhard() {

		return bright( { toneMapping: THREE.ReinhardToneMapping } );

	},

	tone_mapping_cineon() {

		return bright( { toneMapping: THREE.CineonToneMapping } );

	},

	tone_mapping_aces() {

		return bright( { toneMapping: THREE.ACESFilmicToneMapping, toneMappingExposure: 1.2 } );

	},

	tone_mapping_agx() {

		return bright( { toneMapping: THREE.AgXToneMapping } );

	},

	tone_mapping_neutral() {

		return bright( { toneMapping: THREE.NeutralToneMapping } );

	},

	// A linear output color space: no sRGB encoding of colors, the clear color or fog.
	output_linear() {

		const result = cubes( new THREE.Fog( 0x8899aa, 2, 12 ) );
		result.scene.add( quad( new THREE.MeshBasicMaterial( { map: palette() } ), - 1.2, 0.9, 0, 0.6, 0.6 ) );
		result.renderer = { outputColorSpace: THREE.LinearSRGBColorSpace };

		return result;

	},

	// sortObjects false: transparent quads are drawn in scene order.
	sort_objects_off() {

		const result = this.basic_transparent_sorting();
		result.renderer = { sortObjects: false };

		return result;

	},

	// AmbientLight: irradiance times BRDF_Lambert (diffuse / PI) on Lambert and Phong spheres, two lights summed.
	light_ambient() {

		const scene = new THREE.Scene();
		scene.add( new THREE.AmbientLight( 0xffffff, 1.8 ), new THREE.AmbientLight( 0xff8844, 1.2 ) );
		scene.add( sphere( new THREE.MeshLambertMaterial( { color: 0x66aaff } ), - 0.607, 0.013 ) );
		scene.add( sphere( new THREE.MeshPhongMaterial( { color: 0xffcc66, emissive: 0x220011 } ), 0.6335, 0.011 ) );

		return { scene, camera: front(), clear: [ 0x202020, 1 ] };

	},

	// HemisphereLight: sky and ground colors mixed by the normal's direction; two lights, one tilted.
	light_hemisphere() {

		const tilted = new THREE.HemisphereLight( 0xff6040, 0x2040a0, 0.8 );
		tilted.position.set( 1, 0.3, 0 );

		const scene = new THREE.Scene();
		scene.add( new THREE.HemisphereLight( 0x99ccff, 0x775533, 2.4 ), tilted );
		scene.add( sphere( new THREE.MeshLambertMaterial( { color: 0xffffff } ), - 0.616, 0, 0, 0.58 ) );
		scene.add( sphere( new THREE.MeshPhongMaterial( { color: 0xddeedd, shininess: 10 } ), 0.616, 0, 0, 0.58 ) );

		return { scene, camera: front(), clear: [ 0x101010, 1 ] };

	},

	// DirectionalLight: direction from the target (one moved, so its target is in the scene) to the light.
	light_directional() {

		const key = new THREE.DirectionalLight( 0xfff0dd, 2.5 );
		key.position.set( - 2, 2, 1.5 );

		const rim = new THREE.DirectionalLight( 0x6699ff, 1.6 );
		rim.position.set( 0, 0, - 1 );
		rim.target.position.set( 1, - 1, 2 );

		const floor = new THREE.Mesh( new THREE.PlaneGeometry( 3, 3 ), new THREE.MeshLambertMaterial( { color: 0xbbbbbb } ) );
		floor.rotation.x = - Math.PI / 2;
		floor.position.y = - 0.602;

		const scene = new THREE.Scene();
		scene.add( key, rim, rim.target, floor, new THREE.AmbientLight( 0xffffff, 0.5 ) );
		scene.add( sphere( new THREE.MeshLambertMaterial( { color: 0xff8866 } ), - 0.4915, - 0.0005, 0 ) );
		scene.add( sphere( new THREE.MeshPhongMaterial( { color: 0x88cc88, specular: 0x444444 } ), 0.5925, 0.0025, - 0.3 ) );

		return { scene, camera: camera(), clear: [ 0x000000, 1 ] };

	},

	// PointLight decay and distance over a front-facing plane: decay 2 without a cutoff, decay 1 with distance
	// 1.6 (the window falls to zero), decay 0 (constant) with distance 1.2.
	light_point_decay() {

		const scene = new THREE.Scene();
		scene.add( new THREE.AmbientLight( 0xffffff, 0.3 ) );
		scene.add( quad( new THREE.MeshLambertMaterial( { color: 0xeeeeee } ), 0.013, 0.007, 0, 2.9, 2.9 ) );

		const lights = [
			[ 0xff8040, 1.2, 0, 2, - 0.9, 0.5 ],
			[ 0x40ff80, 0.9, 1.6, 1, 0.8, 0.6 ],
			[ 0x6080ff, 0.5, 1.2, 0, 0, - 0.7 ],
		];

		for ( const [ color, intensity, distance, decay, x, y ] of lights ) {

			const light = new THREE.PointLight( color, intensity, distance, decay );
			light.position.set( x, y, 0.4 );
			scene.add( light );

		}

		return { scene, camera: front(), clear: [ 0x000000, 1 ] };

	},

	// SpotLight cones on a front-facing plane: a wide penumbra with decay 2, a narrow one with a cutoff
	// distance and decay 1, aimed by a target in the scene.
	light_spot_penumbra() {

		const scene = new THREE.Scene();
		scene.add( new THREE.AmbientLight( 0xffffff, 0.2 ) );
		scene.add( quad( new THREE.MeshLambertMaterial( { color: 0xffffff } ), 0.013, 0.007, 0, 2.9, 2.9 ) );

		const soft = new THREE.SpotLight( 0xffcc88, 6, 0, 0.45, 0.6, 2 );
		soft.position.set( - 0.5, 0.4, 1.5 );
		soft.target.position.set( - 0.5, 0.3, 0 );

		const narrow = new THREE.SpotLight( 0x88aaff, 3, 4, 0.3, 0.15, 1 );
		narrow.position.set( 0.9, - 0.6, 1.2 );
		narrow.target.position.set( 0.5, - 0.4, 0 );

		scene.add( soft, soft.target, narrow, narrow.target );

		return { scene, camera: front(), clear: [ 0x000000, 1 ] };

	},

	// Mixed lights on Phong and Lambert objects: ambient, hemisphere, two directional, three point and two spot
	// lights (shininess, specular color, emissive) on a box, a sphere and a floor.
	light_mixed() {

		const scene = new THREE.Scene();
		scene.add( new THREE.AmbientLight( 0x404040, 1 ), new THREE.HemisphereLight( 0x8899ff, 0x332211, 0.8 ) );

		const sun = new THREE.DirectionalLight( 0xffffff, 1.2 );
		sun.position.set( 1, 2, 1 );
		const back = new THREE.DirectionalLight( 0xff8844, 0.7 );
		back.position.set( - 1, - 0.5, - 1 );
		scene.add( sun, back );

		[ [ 0xff3333, - 1, 0.8, 0.8 ], [ 0x33ff66, 1.1, 0.5, 0.6 ], [ 0x3366ff, 0, - 0.9, 0.9 ] ].forEach( ( [ color, x, y, z ] ) => {

			const light = new THREE.PointLight( color, 1.5, 0, 2 );
			light.position.set( x, y, z );
			scene.add( light );

		} );

		const spot = new THREE.SpotLight( 0xffffaa, 5, 0, 0.5, 0.5, 2 );
		spot.position.set( 0, 1.5, 1.5 );
		const side = new THREE.SpotLight( 0xaaffff, 3, 6, 0.4, 0.3, 1.5 );
		side.position.set( 2, 0, 1 );
		scene.add( spot, side );

		const box = new THREE.Mesh( new THREE.BoxGeometry( 0.7, 0.7, 0.7 ), new THREE.MeshPhongMaterial( { color: 0xcc9966, specular: 0x666666, shininess: 50 } ) );
		box.position.set( - 0.591, 0.129, 0 );
		box.rotation.set( 0.6, 0.3, 0 );
		scene.add( box );
		scene.add( sphere( new THREE.MeshPhongMaterial( { color: 0x6688aa, emissive: 0x110800, shininess: 15 } ), 0.6135, 0.0745, 0, 0.5, 16 ) );

		const floor = new THREE.Mesh( new THREE.PlaneGeometry( 3, 3 ), new THREE.MeshLambertMaterial( { color: 0x999999 } ) );
		floor.rotation.x = - Math.PI / 2;
		floor.position.y = - 0.5485;
		scene.add( floor );

		return { scene, camera: camera(), clear: [ 0x000000, 1 ] };

	},

	// LightProbe: spherical-harmonics irradiance in world space, with an ambient light.
	light_probe() {

		const probe = new THREE.LightProbe();
		const coefficients = [
			[ 0.6, 0.55, 0.5 ], [ 0.3, 0.35, 0.5 ], [ 0.1, - 0.05, 0.05 ], [ - 0.2, 0.1, 0.25 ], [ 0.05, 0.08, 0.02 ],
			[ - 0.04, 0.06, 0.1 ], [ 0.08, 0.02, - 0.05 ], [ 0.03, - 0.06, 0.04 ], [ - 0.05, 0.04, 0.07 ],
		];
		coefficients.forEach( ( c, i ) => probe.sh.coefficients[ i ].fromArray( c ) );
		probe.intensity = 2.5;

		const scene = new THREE.Scene();
		scene.add( probe, new THREE.AmbientLight( 0x334466, 1.5 ) );
		scene.add( sphere( new THREE.MeshLambertMaterial( { color: 0xffffff } ), - 0.605, 0.0015, 0, 0.58, 16 ) );

		const turned = sphere( new THREE.MeshPhongMaterial( { color: 0xffddbb } ), 0.6295, 0.0035, 0, 0.58, 16 );
		turned.rotation.set( 0.8, 1.2, 0 );
		scene.add( turned );

		return { scene, camera: camera( 50, [ 0.4, 0.8, 2.9 ] ), clear: [ 0x000000, 1 ] };

	},

	// An orthographic camera: geometryViewDir is +z, which moves Phong highlights.
	light_orthographic_phong() {

		const scene = stage( new THREE.Scene(), 0.4, 1.8 );
		const point = new THREE.PointLight( 0xffffff, 2, 0, 1 );
		point.position.set( 1, 0.5, 1.5 );
		scene.add( point );
		scene.add( sphere( new THREE.MeshPhongMaterial( { color: 0x3366cc, shininess: 60 } ), - 0.4785, 0.2105, 0, 0.42 ) );
		scene.add( sphere( new THREE.MeshPhongMaterial( { color: 0xcc6633, specular: 0x888888, shininess: 12 } ), 0.4725, - 0.2885, 0, 0.42 ) );

		const camera = new THREE.OrthographicCamera( - 1.1, 1.1, 1.1, - 1.1, 0.1, 10 );
		camera.position.set( 0.3, 0.4, 3 );
		camera.lookAt( 0, 0, 0 );

		return { scene, camera, clear: [ 0x181818, 1 ] };

	},

	// MeshLambertMaterial with map, vertex colors, emissive with emissiveMap and emissiveIntensity, alphaMap
	// with alphaTest, on front-facing quads under a directional and an ambient light.
	lambert_maps() {

		const scene = stage( new THREE.Scene() );
		scene.add( quad( new THREE.MeshLambertMaterial( { map: palette( { magFilter: THREE.LinearFilter }, 48 ) } ), - 0.547, 0.513, 0, 1.031, 0.97 ) );

		const glow = palette( { magFilter: THREE.LinearFilter }, 40 );
		scene.add( quad( new THREE.MeshLambertMaterial( { color: 0x445566, emissive: 0xffaa66, emissiveIntensity: 0.6, emissiveMap: glow } ), 0.553, 0.513, 0, 1.031, 0.97 ) );

		const colored = plain( new THREE.PlaneGeometry( 1.031, 0.97 ) );
		colored.setAttribute( 'color', new THREE.Float32BufferAttribute( [ 0.9, 0.4, 0.3, 0.3, 0.8, 0.4, 0.4, 0.5, 0.9, 0.8, 0.8, 0.3 ], 3 ) );
		const tinted = new THREE.Mesh( colored, new THREE.MeshLambertMaterial( { vertexColors: true } ) );
		tinted.position.set( - 0.547, - 0.487, 0 );
		scene.add( tinted );

		const ring = field( 8, ( u, v ) => [ 128, 255 * Math.min( 1, Math.hypot( u - 0.5, v - 0.5 ) * 2.2 ), 128, 255 ], { wrapS: THREE.ClampToEdgeWrapping, wrapT: THREE.ClampToEdgeWrapping } );
		scene.add( quad( new THREE.MeshLambertMaterial( { color: 0x66ccff, alphaMap: ring, alphaTest: 0.5 } ), 0.553, - 0.487, 0, 1.031, 0.97 ) );

		return { scene, camera: front(), clear: [ 0x202020, 1 ] };

	},

	// aoMap (red channel, aoMapIntensity) and lightMap (lightMapIntensity) on Lambert, Phong and Basic quads:
	// the light map adds to the indirect irradiance of the lit materials and is the only light of the basic one.
	ao_light_maps() {

		const ao = field( 8, ( u, v ) => [ 255 * ( 0.35 + 0.65 * height( u, v ) ), 200, 200, 255 ] );
		const light = field( 8, ( u, v ) => [ 120 + 100 * u, 140, 120 + 100 * v, 255 ] );

		const scene = stage( new THREE.Scene(), 0.8, 1.2 );
		scene.add( quad( new THREE.MeshLambertMaterial( { color: 0xddccbb, aoMap: ao, aoMapIntensity: 0.8 } ), - 0.547, 0.513, 0, 1.031, 0.97 ) );
		scene.add( quad( new THREE.MeshLambertMaterial( { color: 0xbbccdd, lightMap: light, lightMapIntensity: 1.5, aoMap: ao } ), 0.553, 0.513, 0, 1.031, 0.97 ) );
		scene.add( quad( new THREE.MeshPhongMaterial( { color: 0xccddbb, lightMap: light, lightMapIntensity: 0.7 } ), - 0.547, - 0.487, 0, 1.031, 0.97 ) );
		scene.add( quad( new THREE.MeshBasicMaterial( { color: 0xffeedd, lightMap: light, lightMapIntensity: 2.5, aoMap: ao, aoMapIntensity: 0.6 } ), 0.553, - 0.487, 0, 1.031, 0.97 ) );

		return { scene, camera: front(), clear: [ 0x202020, 1 ] };

	},

	// Blinn-Phong specular: shininess 5, 30 and 120, specular colors, under a point and a directional light.
	phong_specular() {

		const scene = stage( new THREE.Scene(), 0.3, 1.5 );
		const point = new THREE.PointLight( 0xffeedd, 3, 0, 2 );
		point.position.set( 0.5, 1, 1.6 );
		scene.add( point );

		[ [ 5, 0x222222, - 0.833, 0.0085 ], [ 30, 0x886644, 0.0105, 0.007 ], [ 120, 0xffffff, 0.843, 0.0105 ] ].forEach( ( [ shininess, specular, x, y ] ) => {

			scene.add( sphere( new THREE.MeshPhongMaterial( { color: 0x4477aa, specular, shininess } ), x, y, 0, 0.38 ) );

		} );

		return { scene, camera: front(), clear: [ 0x101010, 1 ] };

	},

	// specularMap (red channel) scaling the Phong highlight on a front-facing quad, next to one without.
	phong_specular_map() {

		const strength = field( 8, ( u, v ) => [ 40 + 215 * height( u, v ), 128, 128, 255 ] );

		const scene = new THREE.Scene();
		scene.add( new THREE.AmbientLight( 0xffffff, 0.5 ) );

		for ( const x of [ - 0.65, 0.65 ] ) {

			const light = new THREE.PointLight( 0xffffff, 1.5, 0, 1 );
			light.position.set( x, 0.2, 0.7 );
			scene.add( light );

		}

		scene.add( quad( new THREE.MeshPhongMaterial( { color: 0x335577, specular: 0xffffff, shininess: 20, specularMap: strength } ), - 0.647, 0.013, 0, 1.231, 2.3 ) );
		scene.add( quad( new THREE.MeshPhongMaterial( { color: 0x335577, specular: 0xffffff, shininess: 20 } ), 0.653, 0.013, 0, 1.231, 2.3 ) );

		return { scene, camera: front(), clear: [ 0x000000, 1 ] };

	},

	// flatShading on Lambert and Phong (normals from derivatives), Phong with vertex colors.
	lit_flat_vertex_colors() {

		const scene = stage( new THREE.Scene(), 1.2, 1.2 );
		const ico = new THREE.Mesh( new THREE.IcosahedronGeometry( 0.5, 1 ), new THREE.MeshLambertMaterial( { color: 0xffaa55, flatShading: true } ) );
		ico.position.set( - 0.8025, 0.3625, 0 );
		ico.rotation.set( 0.2, 0.9, 0.1 );
		scene.add( ico );

		const faceted = sphere( new THREE.MeshPhongMaterial( { color: 0x55aaff, flatShading: true, shininess: 40 } ), 0.5985, 0.445, 0, 0.45 );
		faceted.geometry = new THREE.SphereGeometry( 0.45, 10, 7 );
		scene.add( faceted );

		const colored = plain( new THREE.SphereGeometry( 0.5, 32, 16 ) );
		const position = colored.getAttribute( 'position' );
		const colors = [];

		for ( let i = 0; i < position.count; i ++ ) {

			colors.push( 0.5 + 0.4 * position.getX( i ), 0.5 + 0.4 * position.getY( i ), 0.5 + 0.4 * position.getZ( i ) );

		}

		colored.setAttribute( 'color', new THREE.Float32BufferAttribute( colors, 3 ) );
		const tinted = new THREE.Mesh( colored, new THREE.MeshPhongMaterial( { vertexColors: true, shininess: 25 } ) );
		tinted.position.set( - 0.011, - 0.502, 0 );
		scene.add( tinted );

		return { scene, camera: camera(), clear: [ 0x202020, 1 ] };

	},

	// Sides on lit materials: a DoubleSide plane seen from behind (normals flipped), a BackSide open cylinder
	// (FLIP_SIDED), a transparent DoubleSide Phong box (back faces, then front faces).
	lit_sides() {

		const scene = stage( new THREE.Scene(), 0.5, 2 );
		const point = new THREE.PointLight( 0xffffff, 2, 0, 1 );
		point.position.set( 0, 0, 2 );
		scene.add( point );

		const plane = new THREE.Mesh( new THREE.PlaneGeometry( 1.1, 1.1 ), new THREE.MeshLambertMaterial( { color: 0xff9966, side: THREE.DoubleSide } ) );
		plane.position.set( - 0.7595, 0.4395, 0 );
		plane.rotation.y = 2.5;
		scene.add( plane );

		const tube = new THREE.Mesh( new THREE.CylinderGeometry( 0.4, 0.4, 0.9, 24, 1, true ), new THREE.MeshPhongMaterial( { color: 0x66cc99, side: THREE.BackSide } ) );
		tube.position.set( 0.703, 0.4415, 0 );
		tube.rotation.x = 0.7;
		scene.add( tube );

		const box = new THREE.Mesh( new THREE.BoxGeometry( 0.8, 0.8, 0.8 ), new THREE.MeshPhongMaterial( { color: 0x88aaff, transparent: true, opacity: 0.5, side: THREE.DoubleSide } ) );
		box.position.set( 0, - 0.55, 0 );
		box.rotation.set( 0.5, 0.7, 0 );
		scene.add( box );

		return { scene, camera: camera(), clear: [ 0x303030, 1 ] };

	},

	// Fog on lit materials: Lambert, Phong and Toon cubes at increasing distance.
	lit_fog() {

		const result = cubes( new THREE.Fog( 0x8899aa, 2, 12 ) );
		const kinds = [ THREE.MeshLambertMaterial, THREE.MeshPhongMaterial, THREE.MeshToonMaterial ];
		result.scene.children.forEach( ( cube, i ) => cube.material = new kinds[ i % 3 ]( { color: 0xff6600 } ) );
		stage( result.scene );

		return result;

	},

	// MeshToonMaterial without a gradientMap: the default two-tone ramp, smoothed over a pixel (fwidth).
	toon_default() {

		const scene = stage( new THREE.Scene(), 0.5, 2.5 );
		scene.add( sphere( new THREE.MeshToonMaterial( { color: 0xff7755 } ), - 0.616, 0, 0, 0.58 ) );
		scene.add( sphere( new THREE.MeshToonMaterial( { color: 0x55aaff, emissive: 0x111122 } ), 0.616, 0, 0, 0.58 ) );

		return { scene, camera: front(), clear: [ 0x202020, 1 ] };

	},

	// MeshToonMaterial with gradient maps of three and five steps (RedFormat, nearest filtering).
	toon_gradient() {

		const ramp = ( values ) => {

			const texture = new THREE.DataTexture( new Uint8Array( values ), values.length, 1, THREE.RedFormat );
			texture.needsUpdate = true;

			return texture;

		};

		const scene = stage( new THREE.Scene(), 0.5, 2.5 );
		const point = new THREE.PointLight( 0xffccaa, 1.5, 0, 1 );
		point.position.set( 1.1, - 0.4, 1.5 );
		scene.add( point );
		scene.add( sphere( new THREE.MeshToonMaterial( { color: 0xff7755, gradientMap: ramp( [ 70, 160, 255 ] ) } ), - 0.616, 0, 0, 0.58 ) );
		scene.add( sphere( new THREE.MeshToonMaterial( { color: 0x55aaff, gradientMap: ramp( [ 40, 90, 140, 200, 255 ] ) } ), 0.616, 0, 0, 0.58 ) );

		return { scene, camera: front(), clear: [ 0x202020, 1 ] };

	},

	// MeshMatcapMaterial: a matcap texture (sRGB canvas, linear filtering), the default ramp without one, and a
	// tinted matcap with flatShading.
	matcap() {

		const draw = ( context ) => {

			const gradient = context.createRadialGradient( 22, 20, 2, 32, 32, 34 );
			gradient.addColorStop( 0, '#fff4e0' );
			gradient.addColorStop( 0.4, '#d09060' );
			gradient.addColorStop( 1, '#402818' );
			context.fillStyle = gradient;
			context.fillRect( 0, 0, 64, 64 );

		};
		const texture = canvas( 64, 64, draw, { minFilter: THREE.LinearFilter, generateMipmaps: false } );

		const scene = new THREE.Scene();
		scene.add( sphere( new THREE.MeshMatcapMaterial( { matcap: texture } ), - 0.8185, 0.0065, 0, 0.4 ) );
		scene.add( sphere( new THREE.MeshMatcapMaterial(), 0.0065, 0.0115, 0, 0.4 ) );

		const faceted = new THREE.Mesh( new THREE.IcosahedronGeometry( 0.4, 1 ), new THREE.MeshMatcapMaterial( { matcap: texture, color: 0x99ccff, flatShading: true } ) );
		faceted.position.set( 0.843, 0.0135, 0 );
		scene.add( faceted );

		return { scene, camera: front(), clear: [ 0x101010, 1 ] };

	},

	// MeshDepthMaterial with BasicDepthPacking (1 - depth) on spheres and a box, a tight near and far.
	depth_basic() {

		const scene = new THREE.Scene();
		scene.add( sphere( new THREE.MeshDepthMaterial(), - 0.616, 0.202, 0, 0.6 ) );
		scene.add( sphere( new THREE.MeshDepthMaterial( { opacity: 0.6, transparent: true } ), 0.5965, 0.2045, - 0.5, 0.6 ) );

		const box = new THREE.Mesh( new THREE.BoxGeometry( 0.7, 0.7, 0.7 ), new THREE.MeshDepthMaterial() );
		box.position.set( - 0.007, - 0.6535, 0.5 );
		box.rotation.set( 0.5, 0.6, 0 );
		scene.add( box );

		const camera = new THREE.PerspectiveCamera( 50, 1, 2, 4.5 );
		camera.position.set( 0, 0, 3.2 );

		return { scene, camera, clear: [ 0x000000, 1 ] };

	},

	// depthPacking RGBA, RGB and RG (and Basic) on front-facing quads under an orthographic camera with exact
	// binary matrices, at depths with bits in every packed byte: packed bytes amplify the last bits of the depth,
	// which the two GPU paths compute differently (z / w here, 0.5 * z / w + 0.5 there) unless it is exact.
	depth_packing() {

		// near 1, far 3: depth = ( -viewZ - 1 ) / 2; the camera is at z = 5.
		const depths = [ 0.5 + 2 ** - 4 + 2 ** - 9 + 2 ** - 17 + 2 ** - 22, 0.25 + 2 ** - 7 + 2 ** - 12 + 2 ** - 20, 0.75 + 2 ** - 3 + 2 ** - 11, 0.375 ];
		const packings = [ THREE.RGBADepthPacking, THREE.RGBDepthPacking, THREE.RGDepthPacking, THREE.BasicDepthPacking ];

		const scene = new THREE.Scene();
		packings.forEach( ( depthPacking, i ) => {

			const z = 5 - ( 2 * depths[ i ] + 1 );
			scene.add( quad( new THREE.MeshDepthMaterial( { depthPacking } ), i % 2 ? 0.507 : - 0.493, i < 2 ? 0.507 : - 0.493, z, 0.9, 0.9 ) );

		} );

		const camera = new THREE.OrthographicCamera( - 1, 1, 1, - 1, 1, 3 );
		camera.position.set( 0, 0, 5 );

		return { scene, camera, clear: [ 0x000000, 1 ] };

	},

	// MeshDistanceMaterial: the distance to a point light, between its shadow camera's near and far. Upstream
	// reads the light from the renderer's material properties, set while rendering a point light's shadow map;
	// page.html sets it for the scene's `distance` light.
	distance() {

		const light = new THREE.PointLight( 0xffffff, 1 );
		light.position.set( 0.3, 0.8, 1.6 );
		light.shadow.camera.near = 0.8;
		light.shadow.camera.far = 3.5;

		const scene = new THREE.Scene();
		scene.add( light );
		scene.add( sphere( new THREE.MeshDistanceMaterial(), - 0.592, 0.0915, 0, 0.6 ) );
		scene.add( sphere( new THREE.MeshDistanceMaterial(), 0.703, - 0.201, - 0.8, 0.6 ) );

		return { scene, camera: front(), clear: [ 0x000000, 1 ], distance: light };

	},

	// Tangent-space normal maps on front-facing Phong quads under a point light: normalScale ( 1, 1 ) and
	// ( 2, -1 ), the same map read through a tangent attribute (USE_TANGENT), and on Lambert.
	normal_map_tangent() {

		const map = normals( 16 );
		const scene = new THREE.Scene();
		scene.add( new THREE.AmbientLight( 0xffffff, 0.4 ) );

		const light = new THREE.PointLight( 0xffffff, 2.5, 0, 1 );
		light.position.set( 0.2, 0.6, 1 );
		scene.add( light );

		const material = { color: 0xaabbcc, specular: 0x555555, shininess: 30, normalMap: map };
		scene.add( quad( new THREE.MeshPhongMaterial( material ), - 0.547, 0.513, 0, 1.031, 0.97 ) );
		scene.add( quad( new THREE.MeshPhongMaterial( { ...material, normalScale: new THREE.Vector2( 2, - 1 ) } ), 0.553, 0.513, 0, 1.031, 0.97 ) );

		// Tangents turned 40 degrees from the uv directions, with a flipped bitangent (w = -1): the attribute
		// is used as given, so the frame differs from the derivatives' one.
		const tangents = plain( new THREE.PlaneGeometry( 1.031, 0.97 ) );
		tangents.setAttribute( 'tangent', new THREE.Float32BufferAttribute( new Array( 4 ).fill( [ Math.cos( 0.7 ), Math.sin( 0.7 ), 0, - 1 ] ).flat(), 4 ) );
		const mesh = new THREE.Mesh( tangents, new THREE.MeshPhongMaterial( material ) );
		mesh.position.set( - 0.547, - 0.487, 0 );
		scene.add( mesh );

		scene.add( quad( new THREE.MeshLambertMaterial( { color: 0xccbbaa, normalMap: map, normalScale: new THREE.Vector2( 1.5, 1.5 ) } ), 0.553, - 0.487, 0, 1.031, 0.97 ) );

		return { scene, camera: front(), clear: [ 0x202020, 1 ] };

	},

	// An object-space normal map on a sphere (the sphere's own normals, wobbled), and on the back of a BackSide
	// quad (FLIP_SIDED).
	normal_map_object() {

		const map = field( 32, ( u, v ) => {

			const phi = u * 2 * Math.PI, theta = ( 1 - v ) * Math.PI;
			const n = new THREE.Vector3( - Math.cos( phi ) * Math.sin( theta ), Math.cos( theta ), Math.sin( phi ) * Math.sin( theta ) );
			n.x += 0.15 * Math.sin( 6 * phi );
			n.y += 0.15 * Math.sin( 5 * theta );
			n.normalize();

			return [ n.x * 127.5 + 127.5, n.y * 127.5 + 127.5, n.z * 127.5 + 127.5, 255 ];

		}, { wrapT: THREE.ClampToEdgeWrapping } );

		const scene = stage( new THREE.Scene(), 0.8, 2 );
		const front = sphere( new THREE.MeshLambertMaterial( { color: 0xddccaa, normalMap: map, normalMapType: THREE.ObjectSpaceNormalMap } ), - 0.6035, 0.0065, 0, 0.55 );
		front.rotation.y = 0.5;
		scene.add( front );

		const back = new THREE.Mesh( new THREE.PlaneGeometry( 1.031, 1.231 ), new THREE.MeshPhongMaterial( { color: 0xaaccdd, normalMap: map, normalMapType: THREE.ObjectSpaceNormalMap, side: THREE.BackSide } ) );
		back.position.set( 0.653, 0.013, 0 );
		back.rotation.y = Math.PI;
		scene.add( back );

		return { scene, camera: camera( 50, [ 0, 0.3, 3 ] ), clear: [ 0x202020, 1 ] };

	},

	// bumpMap on lit quads: bumpScale positive and negative facing the camera, a DoubleSide quad and a BackSide
	// Lambert quad (bumpScale negated, FLIP_SIDED) seen from behind.
	bump_map() {

		const bump = field( 16, ( u, v ) => [ 40 + 175 * height( u, v ), 128, 128, 255 ] );

		const scene = new THREE.Scene();
		scene.add( new THREE.AmbientLight( 0xffffff, 0.4 ) );

		const light = new THREE.PointLight( 0xffffff, 2.5, 0, 1 );
		light.position.set( - 0.3, 0.5, 1 );
		scene.add( light );

		scene.add( quad( new THREE.MeshLambertMaterial( { color: 0xddccbb, bumpMap: bump, bumpScale: 4 } ), - 0.547, 0.513, 0, 1.031, 0.97 ) );
		scene.add( quad( new THREE.MeshPhongMaterial( { color: 0xbbccdd, bumpMap: bump, bumpScale: - 3, shininess: 40 } ), 0.553, 0.513, 0, 1.031, 0.97 ) );

		const turned = quad( new THREE.MeshPhongMaterial( { color: 0xccddbb, bumpMap: bump, bumpScale: 4, side: THREE.DoubleSide } ), - 0.547, - 0.487, 0, 1.031, 0.97 );
		turned.rotation.y = Math.PI;
		scene.add( turned );

		const back = quad( new THREE.MeshLambertMaterial( { color: 0xddbbcc, bumpMap: bump, bumpScale: 4, side: THREE.BackSide } ), 0.553, - 0.487, 0, 1.031, 0.97 );
		back.rotation.y = Math.PI;
		scene.add( back );

		return { scene, camera: front(), clear: [ 0x202020, 1 ] };

	},

	// displacementMap (vertex stage: scale and bias along the normal) on a subdivided Lambert plane and a
	// Phong sphere.
	displacement_map() {

		const displacement = field( 16, ( u, v ) => [ 255 * height( u, v ), 128, 128, 255 ] );

		const scene = stage( new THREE.Scene(), 0.5, 2.2 );
		const plane = new THREE.Mesh( new THREE.PlaneGeometry( 2, 1.6, 40, 32 ), new THREE.MeshLambertMaterial( { color: 0xccbb99, displacementMap: displacement, displacementScale: 0.4, displacementBias: - 0.1 } ) );
		plane.rotation.x = - 1.1;
		plane.position.set( 0, - 0.35, 0 );
		scene.add( plane );

		const ball = sphere( new THREE.MeshPhongMaterial( { color: 0x6699cc, displacementMap: displacement, displacementScale: 0.15 } ), 0.01, 0.55, 0, 0.35 );
		scene.add( ball );

		return { scene, camera: camera(), clear: [ 0x202020, 1 ] };

	},

	// MeshNormalMaterial with a tangent-space normal map, a bump map, a normal map on a DoubleSide quad seen from
	// behind, and an object-space normal map. Displacement runs in the vertex stage every kind shares
	// (displacement_map).
	normal_material_maps() {

		const map = normals( 16 );
		const bump = field( 16, ( u, v ) => [ 40 + 175 * height( u, v ), 128, 128, 255 ] );

		const scene = new THREE.Scene();
		scene.add( quad( new THREE.MeshNormalMaterial( { normalMap: map, normalScale: new THREE.Vector2( 1.5, 1.5 ) } ), - 0.547, 0.513, 0, 1.031, 0.97 ) );
		scene.add( quad( new THREE.MeshNormalMaterial( { bumpMap: bump, bumpScale: 4 } ), 0.553, 0.513, 0, 1.031, 0.97 ) );

		const turned = quad( new THREE.MeshNormalMaterial( { normalMap: map, side: THREE.DoubleSide } ), - 0.547, - 0.487, 0, 1.031, 0.97 );
		turned.rotation.y = Math.PI;
		scene.add( turned );

		scene.add( quad( new THREE.MeshNormalMaterial( { normalMap: map, normalMapType: THREE.ObjectSpaceNormalMap } ), 0.553, - 0.487, 0, 1.031, 0.97 ) );

		return { scene, camera: front(), clear: [ 0x202020, 1 ] };

	},


	// MeshStandardMaterial: a roughness × metalness grid under ambient, directional and point light (the GGX
	// BRDF, the DFG term and multiple-scattering compensation).
	standard_grid_light() {

		const scene = stage( new THREE.Scene(), 0.5, 2.6 );
		const point = new THREE.PointLight( 0xaaccff, 3, 0, 2 );
		point.position.set( 1.2, - 0.6, 1.2 );
		scene.add( point );
		grid( scene, ( roughness, metalness ) => new THREE.MeshStandardMaterial( { color: 0xd09060, roughness, metalness } ) );

		return { scene, camera: front(), clear: [ 0x181818, 1 ] };

	},

	// The same grid lit by scene.environment only (an HDR equirectangular map through the PMREM), tone mapped.
	standard_grid_environment() {

		const scene = new THREE.Scene();
		scene.environment = sky();
		grid( scene, ( roughness, metalness ) => new THREE.MeshStandardMaterial( { color: 0xd09060, roughness, metalness } ) );

		return { scene, camera: front(), clear: [ 0x181818, 1 ], renderer: { toneMapping: THREE.ACESFilmicToneMapping } };

	},



	// MeshStandardMaterial's maps on front-facing quads under ambient, directional and point light: roughnessMap,
	// metalnessMap and aoMap from one texture (G, B and R); normalMap with emissiveMap; bumpMap with vertex
	// colors; map with alphaMap, alphaTest and lightMap.
	standard_maps() {

		const scene = stage( new THREE.Scene(), 0.5, 2.4 );
		const point = new THREE.PointLight( 0xffddaa, 2.5, 0, 2 );
		point.position.set( 0.6, - 0.3, 1.1 );
		scene.add( point );

		const orm = field( 16, ( u, v ) => [ 160 + 90 * height( u, v ), 60 + 180 * height( v, u ), 255 * height( u, v ), 255 ] );
		const glow = field( 8, ( u, v ) => [ 255 * u, 128, 255 * v, 255 ] );
		const colored = plain( new THREE.PlaneGeometry( 1.031, 0.97 ) );
		colored.setAttribute( 'color', new THREE.Float32BufferAttribute( [ 0.9, 0.4, 0.3, 0.3, 0.8, 0.4, 0.4, 0.5, 0.9, 0.8, 0.8, 0.3 ], 3 ) );
		const bumped = new THREE.Mesh( colored, new THREE.MeshStandardMaterial( { vertexColors: true, roughness: 0.5, metalness: 0.3, bumpMap: field( 16, ( u, v ) => [ 40 + 175 * height( u, v ), 128, 128, 255 ] ), bumpScale: 3 } ) );
		// The alpha map is 0 or 1 per texel, sampled nearest: alphaTest then never meets a value near 0.5. A filtered
		// gradient crossed 0.5 at some pixel, and there GPUs that round texture filtering differently by 1/255 (Mali
		// against Apple) disagreed on whether to discard it.
		const ring = field( 8, ( u, v ) => [ 128, Math.hypot( u - 0.5, v - 0.5 ) * 2.2 < 0.5 ? 0 : 255, 128, 255 ], { magFilter: THREE.NearestFilter, minFilter: THREE.NearestFilter, wrapS: THREE.ClampToEdgeWrapping, wrapT: THREE.ClampToEdgeWrapping } );

		quads( scene, [
			new THREE.MeshStandardMaterial( { color: 0xd8b070, roughness: 1, metalness: 1, roughnessMap: orm, metalnessMap: orm, aoMap: orm, aoMapIntensity: 0.8 } ),
			new THREE.MeshStandardMaterial( { color: 0x8899aa, roughness: 0.45, metalness: 0.2, normalMap: normals( 16 ), emissive: 0xffffff, emissiveMap: glow, emissiveIntensity: 0.3 } ),
			bumped,
			new THREE.MeshStandardMaterial( { map: palette( { magFilter: THREE.LinearFilter }, 48 ), roughness: 0.6, alphaMap: ring, alphaTest: 0.5, lightMap: field( 8, ( u, v ) => [ 80 + 100 * u, 60, 80 + 100 * v, 255 ] ), lightMapIntensity: 1.5 } ),
		] );

		return { scene, camera: front(), clear: [ 0x202020, 1 ] };

	},

	// MeshStandardMaterial with flatShading (normals from derivatives) on tilted quads with vertex colors, a quad
	// without a normal attribute (flat shading by WebGLPrograms' rule), and linear fog over their depths.
	standard_flat_fog() {

		const scene = stage( new THREE.Scene(), 0.4, 2.4 );
		scene.fog = new THREE.Fog( 0x8899aa, 2.4, 6 );

		const colored = plain( new THREE.PlaneGeometry( 1.031, 0.97 ) );
		colored.setAttribute( 'color', new THREE.Float32BufferAttribute( [ 0.9, 0.4, 0.3, 0.3, 0.8, 0.4, 0.4, 0.5, 0.9, 0.8, 0.8, 0.3 ], 3 ) );

		const tilted = new THREE.Mesh( colored, new THREE.MeshStandardMaterial( { vertexColors: true, flatShading: true, roughness: 0.4, metalness: 0.1 } ) );
		tilted.position.set( - 0.547, 0.513, 0 );
		tilted.rotation.set( 0.4, 0.6, 0 );
		tilted.name = 'tilted';

		const far = quad( new THREE.MeshStandardMaterial( { color: 0xcc8844, flatShading: true, roughness: 0.7 } ), 0.553, 0.513, - 2, 1.4, 1.3 );
		far.rotation.y = - 0.5;
		far.name = 'far';

		const bare = plain( new THREE.PlaneGeometry( 1.031, 0.97 ) );
		bare.deleteAttribute( 'normal' );
		const unlit = new THREE.Mesh( bare, new THREE.MeshStandardMaterial( { color: 0x66aa88, roughness: 0.5, metalness: 0.5 } ) );
		unlit.position.set( - 0.547, - 0.487, 0.5 );
		unlit.rotation.x = - 0.3;
		unlit.name = 'unlit';

		const fogless = quad( new THREE.MeshStandardMaterial( { color: 0xaa66cc, fog: false, roughness: 0.3 } ), 0.553, - 0.487, - 1.5, 1.3, 1.2 );

		scene.add( tilted, far, unlit, fogless );

		return { scene, camera: front(), clear: [ 0x8899aa, 1 ] };

	},

	// MeshPhysicalMaterial clearcoat under lights and scene.environment: over a base normal map, with a clearcoat
	// normal map (clearcoatNormalScale), with clearcoat and clearcoatRoughness maps, and on a BackSide quad
	// (clearcoatNormalScale negated).
	physical_clearcoat() {

		const scene = stage( new THREE.Scene(), 0.3, 2 );
		scene.environment = sky();

		const back = quad( new THREE.MeshPhysicalMaterial( { color: 0x336699, roughness: 0.8, clearcoat: 0.8, clearcoatRoughness: 0.3, clearcoatNormalMap: normals( 16 ), side: THREE.BackSide } ) );
		back.rotation.y = Math.PI;

		quads( scene, [
			new THREE.MeshPhysicalMaterial( { color: 0xaa3322, roughness: 0.7, normalMap: normals( 16 ), clearcoat: 1, clearcoatRoughness: 0.15 } ),
			new THREE.MeshPhysicalMaterial( { color: 0x228844, roughness: 0.6, metalness: 0.3, clearcoat: 1, clearcoatRoughness: 0.35, clearcoatNormalMap: normals( 16 ), clearcoatNormalScale: new THREE.Vector2( 1.2, - 0.8 ) } ),
			new THREE.MeshPhysicalMaterial( { color: 0x887766, roughness: 0.5, clearcoat: 1, clearcoatMap: field( 16, ( u, v ) => [ 255 * height( u, v ), 128, 128, 255 ] ), clearcoatRoughness: 0.9, clearcoatRoughnessMap: field( 8, ( u, v ) => [ 128, 40 + 200 * u, 128, 255 ] ) } ),
			back,
		] );

		return { scene, camera: front(), clear: [ 0x181818, 1 ], renderer: { toneMapping: THREE.ACESFilmicToneMapping } };

	},

	// MeshPhysicalMaterial ior, specularIntensity and specularColor with their maps, under lights and
	// scene.environment.
	physical_specular() {

		const scene = stage( new THREE.Scene(), 0.3, 2.2 );
		scene.environment = sky();

		quads( scene, [
			new THREE.MeshPhysicalMaterial( { color: 0x445566, roughness: 0.35, ior: 2.2 } ),
			new THREE.MeshPhysicalMaterial( { color: 0x445566, roughness: 0.35, ior: 1.2, specularIntensity: 0.6, specularColor: 0xffaa66 } ),
			new THREE.MeshPhysicalMaterial( { color: 0x554433, roughness: 0.4, metalness: 0.4, specularIntensityMap: field( 16, ( u, v ) => [ 128, 128, 128, 40 + 215 * height( u, v ) ] ) } ),
			new THREE.MeshPhysicalMaterial( { color: 0x334455, roughness: 0.3, ior: 1.7, specularColor: 0xffffff, specularColorMap: palette( { magFilter: THREE.LinearFilter }, 64 ) } ),
		] );

		return { scene, camera: front(), clear: [ 0x181818, 1 ], renderer: { toneMapping: THREE.ACESFilmicToneMapping } };

	},

	// MeshPhysicalMaterial sheen (with sheenColorMap and sheenRoughnessMap) on a gently waved cloth and on quads,
	// under lights and scene.environment.
	physical_sheen() {

		const scene = stage( new THREE.Scene(), 0.3, 2.4 );
		scene.environment = sky();

		const cloth = new THREE.PlaneGeometry( 2.1, 0.95, 24, 12 );
		const position = cloth.getAttribute( 'position' );

		for ( let i = 0; i < position.count; i ++ ) {

			position.setZ( i, 0.06 * Math.sin( position.getX( i ) * 5 ) * Math.cos( position.getY( i ) * 4 ) );

		}

		cloth.computeVertexNormals();

		const draped = new THREE.Mesh( plain( cloth ), new THREE.MeshPhysicalMaterial( { color: 0x552233, roughness: 0.8, sheen: 1, sheenColor: 0xffaacc, sheenRoughness: 0.4 } ) );
		draped.position.set( 0.013, 0.513, 0 );
		draped.name = 'cloth';
		scene.add( draped );

		quads( scene, [
			null,
			null,
			new THREE.MeshPhysicalMaterial( { color: 0x223355, roughness: 0.9, sheen: 0.8, sheenColor: 0xffffff, sheenColorMap: palette( { magFilter: THREE.LinearFilter }, 64 ), sheenRoughness: 0.6 } ),
			new THREE.MeshPhysicalMaterial( { color: 0x335522, roughness: 0.7, sheen: 1, sheenColor: 0xccffcc, sheenRoughness: 1, sheenRoughnessMap: field( 16, ( u, v ) => [ 128, 128, 128, 60 + 195 * height( u, v ) ] ) } ),
		].map( ( material ) => material ?? new THREE.MeshBasicMaterial( { visible: false } ) ) );

		return { scene, camera: front(), clear: [ 0x181818, 1 ] };

	},

	// MeshPhysicalMaterial iridescence (iridescenceIOR, the thickness range, iridescenceMap and
	// iridescenceThicknessMap) on dielectric and metallic quads under scene.environment and a light.
	physical_iridescence() {

		const scene = stage( new THREE.Scene(), 0.2, 1.8 );
		scene.environment = sky();

		quads( scene, [
			new THREE.MeshPhysicalMaterial( { color: 0x202020, roughness: 0.3, iridescence: 1, iridescenceIOR: 1.3, iridescenceThicknessMinimum: 100, iridescenceThicknessMaximum: 400 } ),
			new THREE.MeshPhysicalMaterial( { color: 0xccaa88, roughness: 0.35, metalness: 1, iridescence: 1, iridescenceIOR: 1.8, iridescenceThicknessMinimum: 200, iridescenceThicknessMaximum: 700 } ),
			new THREE.MeshPhysicalMaterial( { color: 0x303040, roughness: 0.4, iridescence: 1, iridescenceThicknessMinimum: 100, iridescenceThicknessMaximum: 800, iridescenceThicknessMap: field( 16, ( u, v ) => [ 128, 255 * height( u, v ), 128, 255 ] ) } ),
			new THREE.MeshPhysicalMaterial( { color: 0x403030, roughness: 0.3, iridescence: 0.9, iridescenceMap: field( 8, ( u, v ) => [ 60 + 195 * u, 128, 128, 255 ] ) } ),
		] );

		return { scene, camera: front(), clear: [ 0x181818, 1 ], renderer: { toneMapping: THREE.ACESFilmicToneMapping } };

	},

	// MeshPhysicalMaterial anisotropy (anisotropyRotation, anisotropyMap) with derivative and geometry tangents,
	// under a point light and scene.environment.
	physical_anisotropy() {

		const scene = stage( new THREE.Scene(), 0.2, 1.2 );
		scene.environment = sky();

		const point = new THREE.PointLight( 0xffffff, 3, 0, 2 );
		point.position.set( 0.2, 0.1, 0.9 );
		scene.add( point );

		const polar = field( 16, ( u, v ) => {

			const angle = 2 * Math.PI * height( u, v );

			return [ 127.5 + 127.5 * Math.cos( angle ), 127.5 + 127.5 * Math.sin( angle ), 255 * ( 0.4 + 0.6 * u ), 255 ];

		} );

		quads( scene, [
			new THREE.MeshPhysicalMaterial( { color: 0x888888, roughness: 0.35, metalness: 1, anisotropy: 0.8 } ),
			new THREE.MeshPhysicalMaterial( { color: 0x998877, roughness: 0.4, metalness: 0.8, anisotropy: 0.9, anisotropyRotation: 0.7 } ),
			tangentQuad( new THREE.MeshPhysicalMaterial( { color: 0x778899, roughness: 0.35, metalness: 1, anisotropy: 0.7, anisotropyRotation: - 0.4 } ) ),
			new THREE.MeshPhysicalMaterial( { color: 0x887766, roughness: 0.45, metalness: 0.9, anisotropy: 1, anisotropyMap: polar } ),
		] );

		return { scene, camera: front(), clear: [ 0x181818, 1 ], renderer: { toneMapping: THREE.ACESFilmicToneMapping } };

	},

	// MeshPhysicalMaterial diffuseRoughness (EON, with diffuseRoughnessMap) and retroreflectivity, under lights
	// and scene.environment.
	physical_diffuse_roughness() {

		const scene = stage( new THREE.Scene(), 0.3, 2.4 );
		scene.environment = sky();

		quads( scene, [
			new THREE.MeshPhysicalMaterial( { color: 0xcc8855, roughness: 0.8, diffuseRoughness: 1 } ),
			new THREE.MeshPhysicalMaterial( { color: 0x5588cc, roughness: 0.7, diffuseRoughness: 1, diffuseRoughnessMap: field( 8, ( u, v ) => [ 40 + 215 * u, 128, 128, 255 ] ) } ),
			new THREE.MeshPhysicalMaterial( { color: 0x88aa55, roughness: 0.5, retroreflectivity: 0.8 } ),
			new THREE.MeshPhysicalMaterial( { color: 0xaa8866, roughness: 0.4, metalness: 0.6, retroreflectivity: 1, diffuseRoughness: 0.5 } ),
		] );

		return { scene, camera: front(), clear: [ 0x181818, 1 ], renderer: { toneMapping: THREE.ACESFilmicToneMapping } };

	},


	// envMap on MeshBasicMaterial (ENVMAP_TYPE_CUBE, reflected in the vertex stage): a reflecting sphere
	// (MultiplyOperation), a refracting one (CubeRefractionMapping, MixOperation), a quad with a specularMap
	// (AddOperation), and a quad with an equirectangular HDR map converted to a cube render target
	// (MixOperation). The reflecting sphere's map has no mipmaps: minified, its levels of detail differ between
	// the paths (docs/flutter-gpu.md); 12 segments keep its rim normals off grazing angles.
	envmap_basic() {

		const scene = new THREE.Scene();
		const add = ( material, x, y, name ) => {

			const mesh = sphere( material, x, y, 0, 0.45, 12 );
			mesh.name = name;
			scene.add( mesh );

		};

		add( new THREE.MeshBasicMaterial( { color: 0xffeecc, envMap: Object.assign( smoothCube(), { minFilter: THREE.LinearFilter } ) } ), - 0.5285, 0.4865, 'reflect' );
		add( new THREE.MeshBasicMaterial( { color: 0xccddff, envMap: smoothCube( THREE.CubeRefractionMapping ), combine: THREE.MixOperation, reflectivity: 0.8, refractionRatio: 0.9 } ), 0.55, 0.4985, 'refract' );
		scene.add( quad( new THREE.MeshBasicMaterial( { color: 0x445566, envMap: skybox(), combine: THREE.AddOperation, reflectivity: 0.6, specularMap: field( 8, ( u, v ) => [ 40 + 215 * u, 128, 128, 255 ] ) } ), - 0.547, - 0.487, 0, 1.031, 0.97 ) );
		scene.add( quad( new THREE.MeshBasicMaterial( { color: 0x886644, envMap: sky(), combine: THREE.MixOperation, reflectivity: 0.5 } ), 0.553, - 0.487, 0, 1.031, 0.97 ) );

		return { scene, camera: front(), clear: [ 0x202020, 1 ] };

	},

	// envMap on MeshLambertMaterial and MeshPhongMaterial: their own cube maps (MixOperation, MultiplyOperation,
	// reflected per fragment: ENV_WORLDPOS), and scene.environment through the PMREM (irradiance only) with
	// environmentIntensity.
	envmap_lambert_phong() {

		const scene = stage( new THREE.Scene(), 0.2, 1.6 );
		scene.environment = sky();
		scene.environmentIntensity = 0.7;

		quads( scene, [
			new THREE.MeshLambertMaterial( { color: 0xcc8866, envMap: skybox(), combine: THREE.MixOperation, reflectivity: 0.6 } ),
			new THREE.MeshPhongMaterial( { color: 0x88aacc, shininess: 40, envMap: skybox(), reflectivity: 0.9 } ),
			new THREE.MeshLambertMaterial( { color: 0xaacc88 } ),
			new THREE.MeshPhongMaterial( { color: 0xccaa88, specular: 0x444444, normalMap: normals( 16 ) } ),
		] );

		return { scene, camera: front(), clear: [ 0x202020, 1 ] };

	},

	// envMapRotation and envMapIntensity of a material's own environment (a CubeTexture through the PMREM,
	// mirrored in x) against scene.environment's environmentRotation and environmentIntensity, on MeshStandardMaterial
	// and MeshPhongMaterial quads; an aoMap under the environment (specular occlusion).
	envmap_rotation_intensity() {

		const scene = new THREE.Scene();
		scene.environment = sky();
		scene.environmentRotation.set( 0.3, 1.2, 0 );
		scene.environmentIntensity = 1.4;

		quads( scene, [
			new THREE.MeshStandardMaterial( { color: 0xddccbb, roughness: 0.3, metalness: 1, envMap: skybox(), envMapIntensity: 0.8, envMapRotation: new THREE.Euler( 0, 0.9, 0.2 ) } ),
			new THREE.MeshStandardMaterial( { color: 0xddccbb, roughness: 0.3, metalness: 1 } ),
			new THREE.MeshStandardMaterial( { color: 0x996644, roughness: 0.75, metalness: 0.2, aoMap: field( 16, ( u, v ) => [ 60 + 195 * height( u, v ), 128, 128, 255 ] ) } ),
			new THREE.MeshPhongMaterial( { color: 0x6688aa, envMap: sky(), envMapRotation: new THREE.Euler( 0, - 0.8, 0 ), combine: THREE.MixOperation, reflectivity: 0.5 } ),
		] );

		return { scene, camera: front(), clear: [ 0x202020, 1 ], renderer: { toneMapping: THREE.ACESFilmicToneMapping } };

	},

	// A texture background (WebGLBackground's plane): an sRGB canvas with a uv transform and backgroundIntensity,
	// behind a lit box.
	background_texture() {

		const scene = stage( new THREE.Scene(), 0.5, 2 );
		scene.background = canvas( 32, 32, ( context ) => {

			const gradient = context.createLinearGradient( 0, 0, 32, 32 );
			gradient.addColorStop( 0, '#ff9966' );
			gradient.addColorStop( 0.5, '#66aaff' );
			gradient.addColorStop( 1, '#99ff99' );
			context.fillStyle = gradient;
			context.fillRect( 0, 0, 32, 32 );

		}, { offset: new THREE.Vector2( 0.1, - 0.05 ), repeat: new THREE.Vector2( 0.8, 0.9 ) } );
		scene.backgroundIntensity = 0.7;
		scene.add( quad( new THREE.MeshLambertMaterial( { color: 0xeeeeee } ), 0.013, 0.007, 0, 1.21, 1.11 ) );

		return { scene, camera: front(), clear: [ 0x000000, 1 ] };

	},

	// A CubeTexture background (WebGLBackground's box, mirrored in x) with backgroundRotation and
	// backgroundIntensity, from a tilted camera.
	background_cube() {

		const scene = new THREE.Scene();
		scene.background = skybox( THREE.CubeReflectionMapping, 0.8 );
		scene.backgroundRotation.set( 0.2, 0.7, 0 );
		scene.backgroundIntensity = 0.85;

		return { scene, camera: camera( 70, [ 0.5, 0.3, 1 ] ), clear: [ 0x000000, 1 ] };

	},

	// An HDR equirectangular background, converted to a cube render target (fromEquirectangularTexture), tone
	// mapped.
	background_equirect() {

		const scene = new THREE.Scene();
		scene.background = sky();

		return { scene, camera: camera( 75, [ - 0.6, - 0.1, 1 ] ), clear: [ 0x000000, 1 ], renderer: { toneMapping: THREE.ACESFilmicToneMapping } };

	},

	// fixtures/hdr/sky.hdr (tool/reference/js/hdr_files.mjs), loaded by page.html with r187's
	// HDRLoader as HalfFloatType: scene.environment (through the PMREM) and scene.background (converted to a cube
	// render target) of MeshStandardMaterial quads lit by nothing else: a mirror, a rough copper, a glossy metal and
	// a rough dielectric. Spheres: hdr_environment_sphere and hdr_environment_mirror.
	hdr_environment() {

		const scene = new THREE.Scene();
		quads( scene, [
			new THREE.MeshStandardMaterial( { color: 0xffffff, roughness: 0, metalness: 1 } ),
			new THREE.MeshStandardMaterial( { color: 0xd09060, roughness: 0.5, metalness: 0.2 } ),
			new THREE.MeshStandardMaterial( { color: 0xbbbbbb, roughness: 0.2, metalness: 1 } ),
			new THREE.MeshStandardMaterial( { color: 0x8899aa, roughness: 1, metalness: 0 } ),
		] );

		return { scene, camera: front(), clear: [ 0x000000, 1 ], hdr: { url: '/fixtures/hdr/sky.hdr' } };

	},

	// The same file as FloatType, tone mapped (ACES Filmic, exposure 0.7), on the same kinds of quads.
	hdr_environment_aces() {

		const scene = new THREE.Scene();
		quads( scene, [
			new THREE.MeshStandardMaterial( { color: 0xbbbbbb, roughness: 0.25, metalness: 1 } ),
			new THREE.MeshStandardMaterial( { color: 0xffffff, roughness: 0, metalness: 0 } ),
			new THREE.MeshStandardMaterial( { color: 0xd0a070, roughness: 0.6, metalness: 1 } ),
			new THREE.MeshStandardMaterial( { color: 0x77aa66, roughness: 0.8, metalness: 0 } ),
		] );

		return {
			scene,
			camera: front(),
			clear: [ 0x000000, 1 ],
			renderer: { toneMapping: THREE.ACESFilmicToneMapping, toneMappingExposure: 0.7 },
			hdr: { url: '/fixtures/hdr/sky.hdr', type: THREE.FloatType },
		};

	},

	// The same HDR environment and background on grid() spheres (roughness 0.45 to 0.95, metal on top). Lit spheres
	// first failed on silhouette pixels by up to 114/255 (E6); that was flutter_tester alone: its SwiftShader covers
	// pixel centres within about 0.007 pixel of a silhouette differently, and grid()'s offsets keep them away.
	hdr_environment_sphere() {

		const scene = new THREE.Scene();
		grid( scene, ( roughness, metalness ) => new THREE.MeshStandardMaterial( { color: 0xd09060, roughness, metalness } ) );

		return { scene, camera: front(), clear: [ 0x000000, 1 ], hdr: { url: '/fixtures/hdr/sky.hdr' } };

	},

	// Nearly mirrors: grid() spheres of roughness 0, 0.125 and 0.25, metal on top, dielectric below. Equal to r187
	// on Metal; SwiftShader's rims differ by up to 11/255 (parity.dart `swiftShader`).
	hdr_environment_mirror() {

		const scene = new THREE.Scene();
		grid( scene, ( roughness, metalness ) => new THREE.MeshStandardMaterial( { color: metalness ? 0xffffff : 0x8899aa, roughness: ( roughness - 0.45 ) / 2, metalness } ) );

		return { scene, camera: front(), clear: [ 0x000000, 1 ], hdr: { url: '/fixtures/hdr/sky.hdr' } };

	},

	// backgroundBlurriness: the background drawn from a PMREM level (here of a CubeTexture), with rotation and
	// intensity.
	background_blurriness() {

		const scene = new THREE.Scene();
		scene.background = skybox();
		scene.backgroundBlurriness = 0.35;
		scene.backgroundIntensity = 1.2;
		scene.backgroundRotation.set( 0, - 0.5, 0.1 );

		return { scene, camera: camera( 70, [ 0.5, 0.3, 1 ] ), clear: [ 0x000000, 1 ] };

	},

	// backgroundBlurriness on an HDR equirectangular background (its PMREM), behind a MeshStandardMaterial quad lit
	// by the same map as scene.environment.
	background_blurriness_equirect() {

		const scene = new THREE.Scene();
		scene.background = scene.environment = sky();
		scene.backgroundBlurriness = 0.6;
		scene.add( quad( new THREE.MeshStandardMaterial( { color: 0xbbbbbb, roughness: 0.15, metalness: 1 } ), 0.013, 0.007, 0, 1.1, 1 ) );

		return { scene, camera: camera( 60, [ 0.3, - 0.2, 2.5 ] ), clear: [ 0x000000, 1 ], renderer: { toneMapping: THREE.ACESFilmicToneMapping } };

	},

	// MeshPhysicalMaterial transmission over opaque quads (the transmission render target): thickness with ior,
	// attenuation, transmission roughness (the target's mip levels), and dispersion.
	physical_transmission() {

		const scene = stage( new THREE.Scene(), 0.6, 1.5 );

		// Stripes at z = -1 whose edges fall midway between the transmission target's 4× multisample positions
		// (x offsets 0.125, 0.375, 0.625, 0.875 in a pixel): samples within about 0.03 pixel of an edge are
		// covered differently on the two paths, like pixel centres in the frame.
		const scale = size / 2 / ( 4 * Math.tan( THREE.MathUtils.degToRad( 25 ) ) );
		const stripes = [ [ 0xff5533, 16.25, 36.75 ], [ 0x33cc66, 41, 61.75 ], [ 0x3366ff, 66.25, 86.75 ], [ 0xffcc33, 91, 111.75 ] ];

		for ( const [ color, left, right ] of stripes ) {

			const x = ( ( left + right ) / 2 - size / 2 ) / scale;
			scene.add( quad( new THREE.MeshBasicMaterial( { color } ), x, 0, - 1, ( right - left ) / scale, 5 ) );

		}

		quads( scene, [
			new THREE.MeshPhysicalMaterial( { color: 0xffffff, roughness: 0.1, transmission: 1, thickness: 0.6, ior: 1.5 } ),
			new THREE.MeshPhysicalMaterial( { color: 0xffffff, roughness: 0.2, transmission: 1, thickness: 0.8, attenuationColor: 0x66aaff, attenuationDistance: 0.7 } ),
			new THREE.MeshPhysicalMaterial( { color: 0xeeeeff, roughness: 0.45, transmission: 0.9, thickness: 0.3, ior: 1.4 } ),
			new THREE.MeshPhysicalMaterial( { color: 0xffffff, roughness: 0.1, transmission: 1, thickness: 1, ior: 1.6, dispersion: 4 } ),
		] );

		return { scene, camera: front(), clear: [ 0x101010, 1 ] };

	},


	// A DoubleSide transmissive pane turned away from the camera: without WEBGL_multisampled_render_to_texture
	// (Chrome on macOS) its back face is drawn into the transmission target as well, sampling the opaque objects
	// behind, before the frame draws it.
	physical_transmission_double_side() {

		const scene = stage( new THREE.Scene(), 0.6, 1.5 );
		const scale = size / 2 / ( 4 * Math.tan( THREE.MathUtils.degToRad( 25 ) ) );
		const stripes = [ [ 0xff5533, 16.25, 36.75 ], [ 0x33cc66, 41, 61.75 ], [ 0x3366ff, 66.25, 86.75 ], [ 0xffcc33, 91, 111.75 ] ];

		for ( const [ color, left, right ] of stripes ) {

			const x = ( ( left + right ) / 2 - size / 2 ) / scale;
			scene.add( quad( new THREE.MeshBasicMaterial( { color } ), x, 0, - 1, ( right - left ) / scale, 5 ) );

		}

		// Seen from behind; its vertical edges project between multisample positions too (x 37.80 and 95.98).
		const pane = new THREE.Mesh( new THREE.PlaneGeometry( 1.3, 5 ), new THREE.MeshPhysicalMaterial( { color: 0xeeffee, roughness: 0.15, transmission: 1, thickness: 0.5, side: THREE.DoubleSide } ) );
		pane.position.set( 0, 0, 0.2 );
		pane.rotation.y = 2.7;
		scene.add( pane );

		return { scene, camera: front(), clear: [ 0x101010, 1 ] };

	},

	// BasicShadowMap: hard shadows of both boxes on the floor and of the floating box on the standing one,
	// nearest texels of the depth map.
	shadow_basic() {

		const { scene, camera } = shadowed( new THREE.MeshLambertMaterial( { color: 0xcccccc } ), new THREE.MeshLambertMaterial( { color: 0xdd8855 } ) );

		return { scene, camera, clear: [ 0x000000, 1 ], renderer: { shadowMap: { enabled: true, type: THREE.BasicShadowMap } } };

	},

	// PCFShadowMap (the default) on Phong and Standard materials: five filtered samples on a Vogel disk of
	// radius 2 texels, rotated per pixel, and a shadow intensity below 1.
	shadow_pcf() {

		const { scene, light, camera } = shadowed( new THREE.MeshStandardMaterial( { color: 0xcccccc, roughness: 0.8 } ), new THREE.MeshPhongMaterial( { color: 0x6699dd, specular: 0x222222 } ) );
		light.shadow.radius = 2;
		light.shadow.intensity = 0.8;

		return { scene, camera, clear: [ 0x000000, 1 ], renderer: { shadowMap: { enabled: true } } };

	},

	// bias and normalBias move the shadow: a negative bias lifts it off near the standing box's base, the normal
	// bias moves the lookup along the floor's normal (a Toon floor, PCF).
	shadow_bias() {

		const { scene, light, camera } = shadowed( new THREE.MeshToonMaterial( { color: 0xbbccbb } ), new THREE.MeshLambertMaterial( { color: 0xcc7799 } ) );
		light.shadow.bias = - 0.012;
		light.shadow.normalBias = 0.08;

		return { scene, camera, clear: [ 0x000000, 1 ], renderer: { shadowMap: { enabled: true } } };

	},

	// Two shadow-casting directional lights and one without shadows (PCFSoftShadowMap, which r187 maps to
	// PCFShadowMap). The standing box (moved into the floating box's shadow from the second light) neither casts
	// nor receives; of two quads facing up, which receive nothing, only the one with shadowSide DoubleSide casts a
	// shadow (the default draws a FrontSide caster's back faces into the map).
	shadow_lights() {

		const { scene, light, standing, camera } = shadowed( new THREE.MeshPhysicalMaterial( { color: 0xcccccc, roughness: 0.7, clearcoat: 0.3 } ), new THREE.MeshLambertMaterial( { color: 0xddcc66 } ) );
		light.intensity = 1.4;

		// Edges in this map: the floating box u 50 and 70, v 86.34 and 127.94; the standing box u 56 and 72; the
		// quads u 80 and 92, 28 and 40, v 59.39 and 74.37 (in the first map u 72 and 96, 176 and 200, v 191.88
		// and 214.16; the standing box u 112 and 144).
		const second = new THREE.DirectionalLight( 0x99bbff, 1.2 );
		second.position.set( 1.6, 2.4, 0 );
		second.castShadow = true;
		second.shadow.mapSize.set( 128, 192 );
		Object.assign( second.shadow.camera, { left: - 1.6, right: 1.6, top: 1.6, bottom: - 1.6, near: 0.5, far: 8 } );

		const third = new THREE.DirectionalLight( 0xffffff, 0.4 );
		third.position.set( 0, 1, 2 );

		standing.position.z = 0;
		standing.castShadow = false;
		standing.receiveShadow = false;

		for ( const [ z, shadowSide ] of [ [ - 0.55, null ], [ 0.75, THREE.DoubleSide ] ] ) {

			const quad = new THREE.Mesh( new THREE.PlaneGeometry( 0.3, 0.3 ), new THREE.MeshLambertMaterial( { color: 0x66ccaa, shadowSide } ) );
			quad.rotation.x = - Math.PI / 2;
			quad.position.set( 0.85, 0.4, z );
			quad.castShadow = true;
			scene.add( quad );

		}

		scene.add( second, third );

		return { scene, camera, clear: [ 0x000000, 1 ], renderer: { shadowMap: { enabled: true, type: THREE.PCFSoftShadowMap } } };

	},

	// ShadowMaterial: the floor shows only the boxes' shadows, its color at opacity 0.5 over a blue clear color
	// (PCF, radius 1.5), faded by Fog with the Lambert boxes.
	shadow_material_directional() {

		const { scene, light, camera } = shadowed( new THREE.ShadowMaterial( { color: 0x221133, opacity: 0.5 } ), new THREE.MeshLambertMaterial( { color: 0xdd8855 } ) );
		light.shadow.radius = 1.5;
		scene.fog = new THREE.Fog( 0x6688aa, 2, 7 );

		return { scene, camera, clear: [ 0x6688aa, 1 ], renderer: { shadowMap: { enabled: true } } };

	},

	// ShadowMaterial under a spot light (BasicShadowMap), opacity 0.7 over a green clear color; the shadow's color
	// does not depend on the light's cone.
	shadow_material_spot() {

		const { scene, camera } = spotted( new THREE.ShadowMaterial( { color: 0x102030, opacity: 0.7 } ), new THREE.MeshLambertMaterial( { color: 0xcccccc } ) );

		return { scene, camera, clear: [ 0x88aa66, 1 ], renderer: { shadowMap: { enabled: true, type: THREE.BasicShadowMap } } };

	},

	// VSMShadowMap under a directional light: the receivers are drawn into the map too, with their own side; the
	// depth is blurred over ± 4 texels (8 samples, the default) vertically, then horizontally, and the floor reads
	// the mean and deviation through Chebyshev's bound with r187's light-bleeding clamp.
	shadow_vsm_directional() {

		const { scene, light, camera } = shadowed( new THREE.MeshLambertMaterial( { color: 0xcccccc } ), new THREE.MeshLambertMaterial( { color: 0xdd8855 } ) );
		light.shadow.radius = 4;
		light.shadow.bias = - 0.001;

		return { scene, camera, clear: [ 0x000000, 1 ], renderer: { shadowMap: { enabled: true, type: THREE.VSMShadowMap } } };

	},

	// VSMShadowMap under a spot light: radius 3 over 6 samples per pass (offsets ± 0.6, 1.8 and 3 texels: none
	// falls on a texel edge, where the vertical pass's nearest reads would tie), shadow intensity 0.85.
	shadow_vsm_spot() {

		const { scene, light, camera } = spotted( new THREE.MeshStandardMaterial( { color: 0xcccccc, roughness: 0.8 } ), new THREE.MeshPhongMaterial( { color: 0x6699dd, specular: 0x222222 } ) );
		Object.assign( light.shadow, { radius: 3, blurSamples: 6, intensity: 0.85, bias: - 0.001 } );

		return { scene, camera, clear: [ 0x000000, 1 ], renderer: { shadowMap: { enabled: true, type: THREE.VSMShadowMap } } };

	},

	// A spot light's shadows with BasicShadowMap: the shadow camera is perspective, its projection rebuilt from the
	// light's angle (r187 updates it in SpotLightShadow.updateMatrices).
	spot_shadow_basic() {

		const { scene, camera } = spotted( new THREE.MeshLambertMaterial( { color: 0xcccccc } ), new THREE.MeshLambertMaterial( { color: 0xdd8855 } ) );

		return { scene, camera, clear: [ 0x000000, 1 ], renderer: { shadowMap: { enabled: true, type: THREE.BasicShadowMap } } };

	},

	// PCF under a spot light with a wide penumbra: radius 2 texels, intensity 0.8, focus 0.7 (a narrower shadow
	// camera, finer texels), a cutoff distance (the shadow camera's far), bias and normalBias.
	spot_shadow_pcf() {

		const { scene, light, camera } = spotted( new THREE.MeshStandardMaterial( { color: 0xcccccc, roughness: 0.8 } ), new THREE.MeshPhongMaterial( { color: 0x6699dd, specular: 0x222222 } ) );
		light.penumbra = 0.6;
		light.distance = 7;
		light.shadow.radius = 2;
		light.shadow.intensity = 0.8;
		light.shadow.focus = 0.7;
		light.shadow.bias = - 0.0005;
		light.shadow.normalBias = 0.03;

		return { scene, camera, clear: [ 0x000000, 1 ], renderer: { shadowMap: { enabled: true } } };

	},

	// Two shadow-casting spot lights (the second with a 128 × 192 map) and one without shadows, on a Physical
	// floor; the standing box casts but does not receive. BasicShadowMap here and in spot_map: the boxes' edges
	// along x and y are slanted in a perspective map and cross texel centres, and PCF (radius 1 or 2) differed
	// there by 3 to 12/255 in 3 to 7 pixels at the floating box's shadow corners.
	spot_shadow_lights() {

		const { scene, light, standing, camera } = spotted( new THREE.MeshPhysicalMaterial( { color: 0xcccccc, roughness: 0.7, sheen: 0.3 } ), new THREE.MeshLambertMaterial( { color: 0xddcc66 } ) );
		light.intensity = 14;

		const second = new THREE.SpotLight( 0x99bbff, 12, 0, 0.5, 0.3, 2 );
		second.position.set( 1.63, 2.35, 0 );
		second.castShadow = true;
		second.shadow.mapSize.set( 128, 192 );

		const third = new THREE.SpotLight( 0xffffff, 6, 0, 0.4, 0.5, 2 );
		third.position.set( 0, 1.5, 2.2 );

		standing.receiveShadow = false;
		scene.add( second, third );

		return { scene, camera, clear: [ 0x000000, 1 ], renderer: { shadowMap: { enabled: true, type: THREE.BasicShadowMap } } };

	},

	// SpotLight.map: a smooth texture projected through the shadow camera, by a light that also casts shadows and
	// by one that does not (no normalBias for its coordinates); white outside the camera's frustum. One box.
	spot_map() {

		const { scene, light, floating, standing, camera } = spotted( new THREE.MeshLambertMaterial( { color: 0xdddddd } ), new THREE.MeshLambertMaterial( { color: 0xcccccc } ) );

		// At z 0.1 one texel of the floating box's slanted edge was covered differently by the paths (63/255).
		floating.position.z = 0.13;
		const clamp = { wrapS: THREE.ClampToEdgeWrapping, wrapT: THREE.ClampToEdgeWrapping };
		light.map = field( 8, ( u, v ) => [ 255 - 120 * u, 140 + 100 * v, 120 + 120 * u * v, 255 ], clamp );
		light.shadow.normalBias = 0.02;

		const second = new THREE.SpotLight( 0xffffff, 10, 0, 0.35, 0.3, 2 );
		second.position.set( 1.4, 2.4, 0.8 );
		second.map = field( 4, ( u, v ) => [ 120 + 120 * v, 200, 255 - 100 * u, 255 ], clamp );
		scene.add( second );

		// The standing box's top face showed one corner pixel unlit here (79) and lit in the reference (205),
		// with or without either map, normalBias or receiveShadow; not explained yet, so it is left out.
		scene.remove( standing );

		return { scene, camera, clear: [ 0x000000, 1 ], renderer: { shadowMap: { enabled: true, type: THREE.BasicShadowMap } } };

	},

	// A point light's shadows with BasicShadowMap: the casters drawn into the six faces of a cube map, each storing
	// the perspective depth along its axis; the light above the boxes, so both boxes and their shadows are seen
	// through the -Y face only, away from the faces' seams.
	point_shadow_basic() {

		const { scene, camera } = pointed( new THREE.MeshLambertMaterial( { color: 0xcccccc } ), new THREE.MeshLambertMaterial( { color: 0xdd8855 } ) );

		return { scene, camera, clear: [ 0x000000, 1 ], renderer: { shadowMap: { enabled: true, type: THREE.BasicShadowMap } } };

	},

	point_shadow_pcf() {

		const { scene, camera } = walled();

		return { scene, camera, clear: [ 0x000000, 1 ], renderer: { shadowMap: { enabled: true } } };

	},

	point_shadow_pcf_radius() {

		const { scene, light, camera } = walled();
		light.shadow.radius = 3;
		light.shadow.intensity = 0.85;
		light.shadow.bias = - 0.0005;
		light.shadow.normalBias = 0.02;

		return { scene, camera, clear: [ 0x000000, 1 ], renderer: { shadowMap: { enabled: true, type: THREE.PCFShadowMap } } };

	},


	// Line, LineSegments and LineLoop with LineBasicMaterial, one pixel wide (WebGL on ANGLE draws no wider), over
	// a quad, so the primitive type switches between draws: a strip with vertex colors, indexed segments, a closed
	// loop, a transparent strip across the quad. Every vertex lies outside its pixel's diamond (most 0.15 pixel
	// from a corner): GL leaves out the pixel of a line's last point inside its diamond (the diamond-exit rule),
	// which the Flutter GPU fragment stage cannot tell without the endpoint. Pixel centres where a line passes the
	// diamond's boundary are ties that go either way; over the gradient below, two loop vertices were moved
	// by a search to keep pixel centres off them; elsewhere they count as edge pixels.
	line_basic() {

		const strip = new THREE.BufferGeometry();
		strip.setAttribute( 'position', new THREE.Float32BufferAttribute( [ - 1.1333, 0.9213, 0, - 0.3683, 0.6088, 0, 0.3027, 1.0678, 0, 1.0962, 0.7246, 0 ], 3 ) );
		strip.setAttribute( 'color', new THREE.Float32BufferAttribute( [ 0.9, 0.3, 0.2, 0.3, 0.8, 0.4, 0.2, 0.4, 0.9, 0.9, 0.8, 0.3 ], 3 ) );

		const segments = new THREE.BufferGeometry();
		segments.setAttribute( 'position', new THREE.Float32BufferAttribute( [ - 1.1618, 0.2809, 0, - 0.2153, 0.4186, 0, 0.4776, 0.1279, 0, 1.1836, 0.3749, 0 ], 3 ) );
		segments.setIndex( [ 0, 1, 1, 2, 2, 3 ] );

		const loop = new THREE.BufferGeometry();
		loop.setAttribute( 'position', new THREE.Float32BufferAttribute( [ - 0.9202, - 0.2678, 0, - 0.3093, - 0.412, 0, - 0.4776, - 1.0306, 0, - 1.0732, - 0.8787, 0 ], 3 ) );

		const across = new THREE.BufferGeometry();
		across.setAttribute( 'position', new THREE.Float32BufferAttribute( [ - 0.0666, - 0.6307, 0.1, 1.2076, - 0.3772, 0.1, 0.1299, - 1.1019, 0.1 ], 3 ) );

		// Behind the loop's closing segment, a steep gradient (red along x, green along y, more than 2/255 per pixel):
		// a missing line pixel there finds no neighbour of its color in the reference, so it counts as wrong, not
		// as an edge pixel.
		const gradient = new THREE.BufferGeometry();
		gradient.setAttribute( 'position', new THREE.Float32BufferAttribute( [ - 1.214, - 0.2089, - 0.1, - 0.8527, - 0.2089, - 0.1, - 1.214, - 1.0221, - 0.1, - 0.8527, - 1.0221, - 0.1 ], 3 ) );
		gradient.setAttribute( 'color', new THREE.Float32BufferAttribute( [ 0.03, 0.03, 0.2, 0.6, 0.03, 0.2, 0.03, 0.35, 0.2, 0.6, 0.35, 0.2 ], 3 ) );
		gradient.setIndex( [ 0, 2, 1, 2, 3, 1 ] );

		const scene = new THREE.Scene();
		scene.add( quad( new THREE.MeshBasicMaterial( { color: 0x3366aa } ), 0.53, - 0.71, 0, 0.8, 0.6 ) );
		scene.add( new THREE.Mesh( gradient, new THREE.MeshBasicMaterial( { vertexColors: true } ) ) );
		scene.add( new THREE.Line( strip, new THREE.LineBasicMaterial( { vertexColors: true } ) ) );
		scene.add( new THREE.LineSegments( segments, new THREE.LineBasicMaterial( { color: 0x33cc66 } ) ) );
		scene.add( new THREE.LineLoop( loop, new THREE.LineBasicMaterial( { color: 0xff8844 } ) ) );
		scene.add( new THREE.Line( across, new THREE.LineBasicMaterial( { color: 0xffff88, transparent: true, opacity: 0.5 } ) ) );

		return { scene, camera: front(), clear: [ 0x202020, 1 ], edges: 4 };

	},

	// Lines in fog: an indexed LineLoop (closed back to its first index), segments receding in depth, a strip with
	// fog off. A draw range would not reach the Dart side (toJSON does not keep it).
	line_fog() {

		const loop = new THREE.BufferGeometry();
		loop.setAttribute( 'position', new THREE.Float32BufferAttribute( [ - 0.87, 0.97, 0, - 0.13, 1.09, 0, 0.71, 0.83, 0, 0.93, 0.21, 0, - 0.21, 0.37, 0, - 1.03, 0.29, 0 ], 3 ) );
		loop.setIndex( [ 5, 0, 1, 2, 3, 4 ] );

		const receding = [];

		for ( let i = 0; i < 6; i ++ ) {

			receding.push( - 1.17 + 0.41 * i, - 0.23, - 1 - 1.7 * i, - 0.93 + 0.41 * i, - 0.97, - 1 - 1.7 * i );

		}

		const segments = new THREE.BufferGeometry();
		segments.setAttribute( 'position', new THREE.Float32BufferAttribute( receding, 3 ) );

		const strip = new THREE.BufferGeometry();
		strip.setAttribute( 'position', new THREE.Float32BufferAttribute( [ - 1.11, - 1.13, - 6, 1.13, - 0.83, - 6 ], 3 ) );

		const scene = new THREE.Scene();
		scene.fog = new THREE.Fog( 0x8899aa, 2, 12 );
		scene.add( new THREE.LineLoop( loop, new THREE.LineBasicMaterial( { color: 0xffcc33 } ) ) );
		scene.add( new THREE.LineSegments( segments, new THREE.LineBasicMaterial( { color: 0xee4422 } ) ) );
		scene.add( new THREE.Line( strip, new THREE.LineBasicMaterial( { color: 0x22ee66, fog: false } ) ) );

		return { scene, camera: front(), clear: [ 0x8899aa, 1 ], edges: 5 };

	},

	// LineDashedMaterial on Line, LineSegments (distances running on across the pairs) and a Line without
	// computeLineDistances (lineDistance reads 0: all dash). Lines run along rows or columns 0.2 pixel from the
	// pixel centres and start on pixel edges, with dash and gap lengths in whole pixels, so every dash ends half a
	// pixel from a pixel centre.
	line_dashed_basic() {

		const px = Math.tan( THREE.MathUtils.degToRad( 25 ) ) * 3 / 64;
		const line = ( pixels ) => {

			const geometry = new THREE.BufferGeometry();
			geometry.setAttribute( 'position', new THREE.Float32BufferAttribute( at( pixels, 3 ), 3 ) );

			return geometry;

		};

		const strip = new THREE.Line( line( [ [ 8, 12.3 ], [ 64, 12.3 ], [ 120, 12.3 ] ] ), new THREE.LineDashedMaterial( { color: 0xff8844, dashSize: 4 * px, gapSize: 2 * px } ) );
		const column = new THREE.Line( line( [ [ 30.3, 24 ], [ 30.3, 120 ] ] ), new THREE.LineDashedMaterial( { color: 0x33cc66, dashSize: 6 * px, gapSize: 4 * px } ) );
		const pairs = new THREE.LineSegments( line( [ [ 40, 30.3 ], [ 110, 30.3 ], [ 40, 40.7 ], [ 110, 40.7 ] ] ), new THREE.LineDashedMaterial( { color: 0x88aaff, dashSize: 3 * px, gapSize: 5 * px } ) );
		const plain = new THREE.Line( line( [ [ 40, 60.3 ], [ 110, 60.3 ] ] ), new THREE.LineDashedMaterial( { color: 0xffff88, dashSize: 2 * px, gapSize: 2 * px } ) );

		strip.computeLineDistances();
		column.computeLineDistances();
		pairs.computeLineDistances();

		const scene = new THREE.Scene();
		scene.add( strip, column, pairs, plain );

		return { scene, camera: front(), clear: [ 0x202020, 1 ], edges: 0 };

	},

	// LineDashedMaterial's scale: a LineLoop with vertex colors (scale 2; its closing segment runs from the last
	// distance back to 0), its sides 0.3 pixel from the pixel centres, each segment starting before its first pixel
	// centre (Metal draws no pixel behind a line's start). A search sized it so that each corner pixel takes the
	// same dash or gap from both its segments (or a gap from the one GL leaves it out of) and dash ends stay 0.1
	// pixel or more from pixel centres. Then a translucent Line (scale 0.5, opacity 0.5) across a quad.
	line_dashed_scale() {

		const px = Math.tan( THREE.MathUtils.degToRad( 25 ) ) * 3 / 64;

		const loop = new THREE.BufferGeometry();
		loop.setAttribute( 'position', new THREE.Float32BufferAttribute( at( [ [ 16.2, 16.2 ], [ 76.8, 16.2 ], [ 76.8, 56.8 ], [ 16.2, 56.8 ] ], 3 ), 3 ) );
		loop.setAttribute( 'color', new THREE.Float32BufferAttribute( [ 0.9, 0.3, 0.2, 0.3, 0.8, 0.4, 0.2, 0.4, 0.9, 0.9, 0.8, 0.3 ], 3 ) );

		const across = new THREE.BufferGeometry();
		across.setAttribute( 'position', new THREE.Float32BufferAttribute( at( [ [ 56, 96.3 ], [ 120, 96.3 ] ], 2.9 ), 3 ) );

		const closed = new THREE.LineLoop( loop, new THREE.LineDashedMaterial( { vertexColors: true, scale: 2, dashSize: 8 * px, gapSize: 4 * px } ) );
		const translucent = new THREE.Line( across, new THREE.LineDashedMaterial( { color: 0xffff88, scale: 0.5, dashSize: 4 * px, gapSize: 2 * px, transparent: true, opacity: 0.5 } ) );

		closed.computeLineDistances();
		translucent.computeLineDistances();

		const scene = new THREE.Scene();
		scene.add( quad( new THREE.MeshBasicMaterial( { color: 0x3366aa } ), 0.53, - 0.71, 0, 0.8, 0.6 ) );
		scene.add( closed, translucent );

		return { scene, camera: front(), clear: [ 0x202020, 1 ], edges: 0 };

	},

	// Points: a fixed size (sizeAttenuation off, fog off), vertex colors with sizes attenuated by depth (8 pixels at
	// depth 2, 4 at depth 4, in fog), translucent odd-sized points over a quad.
	points_basic() {

		const fixed = new THREE.BufferGeometry();
		fixed.setAttribute( 'position', new THREE.Float32BufferAttribute( at( [ [ 20.15, 20.1 ], [ 40.1, 24.15 ], [ 60.2, 18.1 ] ], 3 ), 3 ) );

		const depths = new THREE.BufferGeometry();
		depths.setAttribute( 'position', new THREE.Float32BufferAttribute( [
			...at( [ [ 24.1, 56.15 ], [ 48.15, 60.1 ] ], 2 ),
			...at( [ [ 72.1, 56.2 ], [ 96.15, 52.1 ] ], 4 ),
		], 3 ) );
		depths.setAttribute( 'color', new THREE.Float32BufferAttribute( [ 0.9, 0.3, 0.2, 0.3, 0.8, 0.4, 0.2, 0.4, 0.9, 0.9, 0.8, 0.3 ], 3 ) );

		const translucent = new THREE.BufferGeometry();
		translucent.setAttribute( 'position', new THREE.Float32BufferAttribute( at( [ [ 80.6, 92.65 ], [ 84.65, 96.6 ], [ 104.6, 100.7 ] ], 2.5 ), 3 ) );

		const scene = new THREE.Scene();
		scene.fog = new THREE.Fog( 0x8899aa, 1.5, 6 );
		scene.add( quad( new THREE.MeshBasicMaterial( { color: 0x3366aa, fog: false } ), 0.525, - 0.71, 0, 0.79, 0.6 ) );
		scene.add( new THREE.Points( fixed, new THREE.PointsMaterial( { color: 0xff8844, size: 6, sizeAttenuation: false, fog: false } ) ) );
		scene.add( new THREE.Points( depths, new THREE.PointsMaterial( { vertexColors: true, size: 0.25 } ) ) );
		scene.add( new THREE.Points( translucent, new THREE.PointsMaterial( { color: 0xffff88, size: 7, sizeAttenuation: false, transparent: true, opacity: 0.5, fog: false } ) ) );

		return { scene, camera: front(), clear: [ 0x202020, 1 ], edges: 0 };

	},

	// Point sprites: a map at gl_PointCoord (orientation), through the map's uvTransform, with vertex colors; an
	// alphaMap with alphaTest (its own transform is not read: points read the map's uvTransform only); the uv
	// attribute in place of gl_PointCoord (USE_POINTS_UV), one texel per point.
	points_map() {

		const options = { magFilter: THREE.NearestFilter, minFilter: THREE.NearestFilter, generateMipmaps: false };
		const shifted = palette( { ...options, wrapS: THREE.RepeatWrapping, wrapT: THREE.RepeatWrapping } );
		shifted.repeat.set( 0.5, 0.5 );
		shifted.offset.set( 0.25, 0.5 );

		const holes = new THREE.DataTexture( new Uint8Array( checker( 4, 4, 1, [ 0, 255, 0, 255 ], [ 0, 64, 0, 255 ] ) ), 4, 4 );
		Object.assign( holes, options );
		holes.offset.set( 0.5, 0.5 );
		holes.needsUpdate = true;

		const sprites = new THREE.BufferGeometry();
		sprites.setAttribute( 'position', new THREE.Float32BufferAttribute( at( [ [ 24.1, 24.15 ], [ 64.15, 28.1 ] ], 3 ), 3 ) );

		const tinted = new THREE.BufferGeometry();
		tinted.setAttribute( 'position', new THREE.Float32BufferAttribute( at( [ [ 96.1, 24.2 ], [ 104.15, 48.1 ] ], 3 ), 3 ) );
		tinted.setAttribute( 'color', new THREE.Float32BufferAttribute( [ 1, 0.5, 0.5, 0.5, 1, 1 ], 3 ) );

		const masked = new THREE.BufferGeometry();
		masked.setAttribute( 'position', new THREE.Float32BufferAttribute( at( [ [ 24.15, 72.1 ], [ 56.1, 76.15 ] ], 3 ), 3 ) );

		const uvs = new THREE.BufferGeometry();
		uvs.setAttribute( 'position', new THREE.Float32BufferAttribute( at( [ [ 80.6, 80.65 ], [ 92.65, 84.6 ], [ 104.6, 96.7 ], [ 84.7, 104.6 ] ], 3 ), 3 ) );
		uvs.setAttribute( 'uv', new THREE.Float32BufferAttribute( [ 0.125, 0.125, 0.625, 0.375, 0.375, 0.875, 0.875, 0.625 ], 2 ) );

		const scene = new THREE.Scene();
		scene.add( new THREE.Points( sprites, new THREE.PointsMaterial( { map: palette( options ), size: 16, sizeAttenuation: false } ) ) );
		scene.add( new THREE.Points( tinted, new THREE.PointsMaterial( { map: shifted, vertexColors: true, size: 12, sizeAttenuation: false } ) ) );
		scene.add( new THREE.Points( masked, new THREE.PointsMaterial( { color: 0x88ccff, alphaMap: holes, alphaTest: 0.5, size: 16, sizeAttenuation: false } ) ) );
		scene.add( new THREE.Points( uvs, new THREE.PointsMaterial( { map: palette( options ), size: 7, sizeAttenuation: false } ) ) );

		return { scene, camera: front(), clear: [ 0x202020, 1 ], edges: 0 };

	},

	// Sprites: attenuated sizes at two depths (one in fog), a fixed size (sizeAttenuation off) with a negative x
	// scale (still drawn: only a mesh's winding flips), a rotated sprite anchored at its top-left corner (center),
	// translucent sprites sorted by their own depth with a translucent quad, a sprite with depthTest off behind an
	// opaque quad and an opaque sprite (transparent false).
	sprite_basic() {

		const scene = new THREE.Scene();
		scene.fog = new THREE.Fog( 0x8899aa, 1.5, 6 );
		scene.add( quad( new THREE.MeshBasicMaterial( { color: 0x3366aa, fog: false } ), 0.525, - 0.71, 0, 0.79, 0.6 ) );
		scene.add( sprite( new THREE.SpriteMaterial( { color: 0xff8844, fog: false } ), [ 24.25, 20.25 ], 3, 20, 12 ) );
		scene.add( sprite( new THREE.SpriteMaterial( { color: 0x44ff88 } ), [ 64.25, 18.25 ], 4.5, 16, 14 ) );

		const fixed = sprite( new THREE.SpriteMaterial( { color: 0xffff88, sizeAttenuation: false, fog: false } ), [ 104.25, 22.25 ], 2, 1, 1 );
		fixed.scale.set( - 14 * Math.tan( THREE.MathUtils.degToRad( 25 ) ) / 64, 10 * Math.tan( THREE.MathUtils.degToRad( 25 ) ) / 64, 1 );
		scene.add( fixed );

		const anchored = sprite( new THREE.SpriteMaterial( { color: 0xff3366, rotation: 0.43, opacity: 0.5, fog: false } ), [ 72.25, 80.25 ], 2.5, 30, 18 );
		anchored.center.set( 0, 1 );
		scene.add( anchored );
		scene.add( sprite( new THREE.SpriteMaterial( { color: 0x33ccff, opacity: 0.6, fog: false } ), [ 92.25, 98.25 ], 2.7, 28, 24 ) );
		scene.add( quad( new THREE.MeshBasicMaterial( { color: 0xffcc00, transparent: true, opacity: 0.5, fog: false } ), 0.3, - 0.95, 0.2, 0.5, 0.3 ) );
		scene.add( sprite( new THREE.SpriteMaterial( { color: 0xcc66ff, depthTest: false, fog: false } ), [ 80.25, 112.25 ], 3.6, 12, 10 ) );
		scene.add( sprite( new THREE.SpriteMaterial( { color: 0x88ff44, transparent: false } ), [ 24.25, 64.25 ], 2, 18, 22 ) );

		return { scene, camera: front(), clear: [ 0x202020, 1 ], edges: 0 };

	},

	// Sprite maps: the map with its uvTransform (repeat, offset), the alphaMap through its own transform with
	// alphaTest, a color tint, and a map in fog.
	sprite_map() {

		const options = { magFilter: THREE.NearestFilter, minFilter: THREE.NearestFilter, generateMipmaps: false };
		const shifted = palette( { ...options, wrapS: THREE.RepeatWrapping, wrapT: THREE.RepeatWrapping } );
		shifted.repeat.set( 0.5, 0.5 );
		shifted.offset.set( 0.25, 0.5 );

		const holes = new THREE.DataTexture( new Uint8Array( checker( 4, 4, 1, [ 0, 255, 0, 255 ], [ 0, 64, 0, 255 ] ) ), 4, 4 );
		Object.assign( holes, options, { wrapS: THREE.RepeatWrapping, wrapT: THREE.RepeatWrapping } );
		holes.offset.set( 0.25, 0 );
		holes.needsUpdate = true;

		const scene = new THREE.Scene();
		scene.fog = new THREE.Fog( 0x8899aa, 1.5, 6 );
		scene.add( sprite( new THREE.SpriteMaterial( { map: palette( options ), fog: false } ), [ 32.25, 32.25 ], 3, 32, 32 ) );
		scene.add( sprite( new THREE.SpriteMaterial( { map: shifted, color: 0xffcc88, fog: false } ), [ 96.25, 32.25 ], 3, 32, 24 ) );
		scene.add( sprite( new THREE.SpriteMaterial( { color: 0x88ccff, alphaMap: holes, alphaTest: 0.5, fog: false } ), [ 32.25, 96.25 ], 3, 32, 32 ) );
		scene.add( sprite( new THREE.SpriteMaterial( { map: palette( options ) } ), [ 96.25, 96.25 ], 4.5, 32, 32 ) );

		return { scene, camera: front(), clear: [ 0x202020, 1 ], edges: 0 };

	},

	// Skinning: an unlit bar bent sideways and toward the camera (attached bones, children of the mesh), a bar with
	// MeshNormalMaterial whose bones live outside it (DetachedBindMode, bound at its world matrix), bent away.
	skin_basic() {

		const scene = new THREE.Scene();
		scene.add( skinned( new THREE.MeshBasicMaterial( { color: 0xff8844 } ), [ - 0.5, - 0.05 ], [ 0.5, 0, 0.6 ] ) );
		scene.add( skinned( new THREE.MeshNormalMaterial(), [ 0.55, 0.03 ], [ - 0.7, 0.3, - 0.4 ], scene ) );

		return { scene, camera: front(), clear: [ 0x202020, 1 ], edges: 1 };

	},

	// Skinned normals under a directional light: Lambert and standard bars bent toward and away from the light,
	// casting their skinned shadows on a wall behind them.
	skin_lit() {

		const scene = stage( new THREE.Scene(), 0.4, 2.5 );
		const light = scene.children[ 1 ];
		light.castShadow = true;
		light.shadow.mapSize.set( 256, 256 );
		Object.assign( light.shadow.camera, { left: - 1.6, right: 1.6, top: 1.6, bottom: - 1.6, near: 0.5, far: 8 } );

		const wall = quad( new THREE.MeshLambertMaterial( { color: 0xbbbbbb } ), 0, 0, - 0.5, 4, 4 );
		wall.receiveShadow = true;
		scene.add( wall );

		// The bars are open sheets: shadowSide FrontSide, since the default (BackSide for FrontSide) casts nothing.
		const lambert = skinned( new THREE.MeshLambertMaterial( { color: 0x88aaff, shadowSide: THREE.FrontSide } ), [ - 0.5, - 0.05 ], [ 0.6, 0, 0.5 ] );
		const standard = skinned( new THREE.MeshStandardMaterial( { color: 0xffaa66, roughness: 0.7, shadowSide: THREE.FrontSide } ), [ 0.55, 0.03 ], [ - 0.6, 0.4, - 0.3 ] );
		lambert.castShadow = standard.castShadow = true;
		scene.add( lambert, standard );

		return { scene, camera: front(), clear: [ 0x202020, 1 ], renderer: { shadowMap: { enabled: true, type: THREE.BasicShadowMap } }, edges: 2 };

	},

	// Skinning past r187's old uniform limit: 120 bones in the bone texture (24 × 24 texels), the bars skinned to
	// bones 118 and 119, the bones before them turned so a wrong texel row or column shows.
	skin_bones() {

		const scene = new THREE.Scene();
		scene.add( skinned( new THREE.MeshBasicMaterial( { color: 0xff8844 } ), [ - 0.5, - 0.05 ], [ 0.5, 0, 0.6 ], null, { bones: 120 } ) );
		scene.add( skinned( new THREE.MeshNormalMaterial(), [ 0.55, 0.03 ], [ - 0.7, 0.3, - 0.4 ], scene, { bones: 120 } ) );

		return { scene, camera: front(), clear: [ 0x202020, 1 ], edges: 1 };

	},

	// Skinning and morph targets on one mesh: morphed() bars (relative targets with morphed vertex colors on
	// MeshBasicMaterial; absolute targets with morphed normals on MeshNormalMaterial) skinned as skinned()'s,
	// the targets applied before the bones.
	skin_morph() {

		const scene = new THREE.Scene();
		const colors = morphed( null, [ 0, 0 ], [], { relative: true, colors: true } ).geometry;
		const normals = morphed( null, [ 0, 0 ], [], { normals: true, bend: 'z' } ).geometry;
		const basic = skinned( new THREE.MeshBasicMaterial( { vertexColors: true } ), [ - 0.5, - 0.05 ], [ 0.5, 0, 0.6 ], null, { geometry: colors } );
		const normal = skinned( new THREE.MeshNormalMaterial(), [ 0.55, 0.03 ], [ - 0.7, 0.3, - 0.4 ], scene, { geometry: normals } );
		basic.morphTargetInfluences = [ 0.7, 0.4 ];
		normal.morphTargetInfluences = [ 0.8, - 0.5 ];
		scene.add( basic, normal );

		return { scene, camera: front(), clear: [ 0x202020, 1 ], edges: 3 };

	},

	// Morph targets (WebGLMorphtargets): absolute targets with morphed vertex colors on MeshBasicMaterial, and
	// relative targets with morphed normals on MeshNormalMaterial, non-indexed from the second quad.
	morph_basic() {

		const scene = new THREE.Scene();
		scene.add( morphed( new THREE.MeshBasicMaterial( { vertexColors: true } ), [ - 0.6, 0.03 ], [ 0.7, 0.4 ], { colors: true } ) );
		scene.add( morphed( new THREE.MeshNormalMaterial(), [ 0.45, - 0.05 ], [ 0.8, - 0.5 ], { relative: true, normals: true, flat: true } ) );

		return { scene, camera: front(), clear: [ 0x202020, 1 ], edges: 2 };

	},

	// Morphed normals under a directional light: Lambert (relative) and standard (absolute) bars bent toward the
	// light, casting their morphed shadows on a wall behind them.
	morph_lit() {

		const scene = stage( new THREE.Scene(), 0.4, 2.5 );
		const light = scene.children[ 1 ];
		light.castShadow = true;
		light.shadow.mapSize.set( 256, 256 );
		Object.assign( light.shadow.camera, { left: - 1.6, right: 1.6, top: 1.6, bottom: - 1.6, near: 0.5, far: 8 } );

		const wall = quad( new THREE.MeshLambertMaterial( { color: 0xbbbbbb } ), 0, 0, - 0.5, 4, 4 );
		wall.receiveShadow = true;
		scene.add( wall );

		const options = { normals: true, bend: 'z' };
		const lambert = morphed( new THREE.MeshLambertMaterial( { color: 0x88aaff, shadowSide: THREE.FrontSide } ), [ - 0.5, - 0.05 ], [ 0.9, 0.6 ], { ...options, relative: true } );
		const standard = morphed( new THREE.MeshStandardMaterial( { color: 0xffaa66, roughness: 0.7, shadowSide: THREE.FrontSide } ), [ 0.55, 0.03 ], [ 0.6, 0.3 ], options );
		lambert.castShadow = standard.castShadow = true;
		scene.add( lambert, standard );

		return { scene, camera: front(), clear: [ 0x202020, 1 ], renderer: { shadowMap: { enabled: true, type: THREE.BasicShadowMap } }, edges: 7 };

	},

	// InstancedMesh (instanceMatrix, instanceColor, count): white quads tinted per instance, turned and scaled
	// unevenly, the sixth past `count`, the mesh itself off screen (culled only by the instanced bounding sphere);
	// morphed() bars with morphed vertex colors times the instance colors; MeshNormalMaterial boxes whose normals
	// turn with each instance's matrix.
	instanced_basic() {

		const scene = new THREE.Scene();
		const quads = [
			[ - 1.0, 0.9, 0, 0, 0, 0.3, 1, 1 ],
			[ - 0.5, 0.9, 0, 0, 0, - 0.5, 1.4, 0.7 ],
			[ 0.02, 0.88, 0, 0, 0, 0.9, 0.8, 1.2 ],
			[ 0.53, 0.91, 0, 0, 0, 0, 1.1, 1.1 ],
			[ 1.02, 0.89, 0, 0, 0, 0.6, 0.6, 1.3 ],
			[ 0.01, 0, 0.5, 0, 0, 0, 3, 3 ]
		];
		const tints = [ 0xff4444, 0x44ff44, 0x4466ff, 0xffcc33, 0xcc55ff, 0xffffff ];
		scene.add( instanced( new THREE.PlaneGeometry( 0.3, 0.3 ), new THREE.MeshBasicMaterial(), quads, { colors: tints, offset: [ 6, 0, 0 ], count: 5 } ) );

		const bars = morphed( null, [ 0, 0 ], [], { relative: true, colors: true } ).geometry;
		const bar = instanced( bars, new THREE.MeshBasicMaterial( { vertexColors: true } ), [
			[ - 0.9, - 0.55, 0, 0, 0, 0.2, 0.8, 0.6 ],
			[ - 0.4, - 0.6, 0, 0, 0, - 0.15, 1, 0.55 ]
		], { colors: [ 0xffffff, 0x88ffff ] } );
		bar.morphTargetInfluences = [ 0.7, 0.4 ];
		scene.add( bar );

		const box = new THREE.BoxGeometry( 0.3, 0.3, 0.3 );
		scene.add( instanced( box, new THREE.MeshNormalMaterial(), [
			[ 0.27, - 0.48, 0, 0.5, 0.7, 0.1, 1, 1 ],
			[ 0.83, - 0.52, 0, - 0.4, 0.9, 0.3, 1.5, 0.7 ],
			[ 0.56, 0.27, 0, 0.9, - 0.3, 0.6, 0.8, 1.2 ]
		] ) );

		return { scene, camera: front(), clear: [ 0x202020, 1 ], edges: 8 };

	},

	// Instanced lit quads turned toward and away from a directional light (Lambert tinted per instance, standard
	// untinted), casting their instanced shadows on a wall behind them.
	instanced_lit() {

		const scene = stage( new THREE.Scene(), 0.4, 2.5 );
		const light = scene.children[ 1 ];
		light.castShadow = true;
		light.shadow.mapSize.set( 256, 256 );
		Object.assign( light.shadow.camera, { left: - 1.6, right: 1.6, top: 1.6, bottom: - 1.6, near: 0.5, far: 8 } );

		const wall = quad( new THREE.MeshLambertMaterial( { color: 0xbbbbbb } ), 0, 0, - 0.5, 4, 4 );
		wall.receiveShadow = true;
		scene.add( wall );

		const plane = new THREE.PlaneGeometry( 0.4, 0.4 );
		const lambert = instanced( plane, new THREE.MeshLambertMaterial( { shadowSide: THREE.FrontSide } ), [
			[ - 0.7, 0.45, 0, 0, 0.6, 0.2, 1, 1 ],
			[ - 0.12, 0.47, 0, 0.5, - 0.5, 0, 1.3, 0.8 ],
			[ 0.6, 0.43, 0, - 0.4, 0.2, - 0.3, 0.9, 1.1 ]
		], { colors: [ 0x88aaff, 0xffaa66, 0x99ff99 ] } );
		const standard = instanced( plane, new THREE.MeshStandardMaterial( { color: 0xffaa66, roughness: 0.7, shadowSide: THREE.FrontSide } ), [
			[ - 0.5, - 0.5, 0, 0.3, 0.7, 0, 1.2, 0.9 ],
			[ 0.42, - 0.48, 0, - 0.6, - 0.4, 0.4, 1, 1 ]
		] );
		lambert.castShadow = standard.castShadow = true;
		scene.add( lambert, standard );

		return { scene, camera: front(), clear: [ 0x202020, 1 ], renderer: { shadowMap: { enabled: true, type: THREE.BasicShadowMap } }, edges: 5 };

	},

	// InstancedMesh.morphTexture (setMorphAt, USE_INSTANCING_MORPH): morphed() bars (relative targets, morphed
	// vertex colors) on MeshBasicMaterial and absolute stretched and twisted boxes on Lambert, each instance with
	// its own influences, the meshes' own influences zero.
	instanced_morph() {

		const scene = stage( new THREE.Scene(), 0.5, 2 );

		const bars = morphed( null, [ 0, 0 ], [], { relative: true, colors: true } ).geometry;
		scene.add( instanced( bars, new THREE.MeshBasicMaterial( { vertexColors: true } ), [
			[ - 0.95, 0.45, 0, 0, 0, 0, 0.8, 0.55 ],
			[ - 0.45, 0.47, 0, 0, 0, 0, 0.8, 0.55 ],
			[ 0.05, 0.44, 0, 0, 0, 0, 0.8, 0.55 ],
			[ 0.55, 0.46, 0, 0, 0, 0, 0.8, 0.55 ]
		], { morphs: [ [ 0, 0 ], [ 1, 0 ], [ 0.3, 1 ], [ 0.8, - 0.6 ] ] } ) );

		scene.add( instanced( twisted(), new THREE.MeshLambertMaterial( { color: 0x88aaff } ), [
			[ - 0.7, - 0.5, 0, 0.4, 0.3, 0, 1, 1 ],
			[ 0.03, - 0.52, 0, 0.4, 0.3, 0, 1, 1 ],
			[ 0.72, - 0.48, 0, 0.4, 0.3, 0, 1, 1 ]
		], { morphs: [ [ 0.2, 0 ], [ 0.9, 0.3 ], [ 0, 1 ] ] } ) );

		return { scene, camera: front(), clear: [ 0x202020, 1 ], edges: 4 };

	},

	// Per-instance morphed normals under a directional light: standard morphed() bars (absolute targets) bent
	// toward the light by their own influences, casting their per-instance morphed shadows on a wall.
	instanced_morph_lit() {

		const scene = stage( new THREE.Scene(), 0.4, 2.5 );
		const light = scene.children[ 1 ];
		light.castShadow = true;
		light.shadow.mapSize.set( 256, 256 );
		Object.assign( light.shadow.camera, { left: - 1.6, right: 1.6, top: 1.6, bottom: - 1.6, near: 0.5, far: 8 } );

		const wall = quad( new THREE.MeshLambertMaterial( { color: 0xbbbbbb } ), 0, 0, - 0.5, 4, 4 );
		wall.receiveShadow = true;
		scene.add( wall );

		const bars = morphed( null, [ 0, 0 ], [], { normals: true, bend: 'z' } ).geometry;
		const mesh = instanced( bars, new THREE.MeshStandardMaterial( { color: 0xffaa66, roughness: 0.7, shadowSide: THREE.FrontSide } ), [
			[ - 0.75, 0.03, 0, 0, 0, 0, 1, 1 ],
			[ - 0.02, - 0.04, 0, 0, 0, 0, 1, 1 ],
			[ 0.73, 0.02, 0, 0, 0, 0, 1, 1 ]
		], { morphs: [ [ 0, 0.5 ], [ 0.9, 0 ], [ 0.5, 0.8 ] ] } );
		mesh.castShadow = true;
		scene.add( mesh );

		return { scene, camera: front(), clear: [ 0x202020, 1 ], renderer: { shadowMap: { enabled: true, type: THREE.BasicShadowMap } }, edges: 9 };

	},

	// A HUD over the main scene, as r187 apps draw one: clearDepth between the two renders, so the overlay's quads
	// cover the near quad.
	frame_hud() {

		return overlaid( true );

	},

	// The same without clearDepth: the frame keeps the main scene's depth too, so the near quad hides the overlay's
	// quads where they overlap it.
	frame_overlay_depth() {

		return overlaid( false );

	},

	// Split screen as r187's webgl_multiple_views draws it: autoClear on, the scissor test on, per view a viewport, a
	// scissor and a clear color; the scissored clears leave the rest of the frame as it was. The left half shows the
	// main scene, the top right quarter the overlay scene, the bottom right the main scene again within a smaller
	// scissor, so its margin keeps the fresh frame's transparent black.
	frame_views() {

		return { ...overlaid( false ), views: { autoClear: true, list: [
			{ viewport: [ 0, 0, 64, 128 ], scissorTest: true, color: [ 0x203040, 1 ] },
			{ viewport: [ 64, 64, 64, 64 ], scissorTest: true, color: [ 0x402030, 1 ], overlay: true },
			{ viewport: [ 64, 0, 64, 64 ], scissor: [ 72, 8, 48, 40 ], scissorTest: true, color: [ 0x304020, 0.5 ] },
		] } };

	},

	// An inset as r187 apps draw a minimap: autoClear off, the main scene over the whole frame after clear(), then the
	// overlay scene in a small viewport low on the right after a clearDepth() inside its scissor, then the overlay
	// scene over the whole frame without a clear: outside the inset the main scene's depth still hides its quads
	// behind the near quad.
	frame_inset() {

		return { ...overlaid( false ), views: { autoClear: false, list: [
			{ viewport: [ 0, 0, 128, 128 ], clear: 'all' },
			{ viewport: [ 70, 12, 48, 40 ], scissorTest: true, clear: 'depth', overlay: true },
			{ viewport: [ 0, 0, 128, 128 ], overlay: true },
		] } };

	},

	// A 64 × 64 render target (default options: linear filtering, a depth buffer) holding Basic and Lambert
	// shapes in linear color, shown texel for pixel on a quad in the frame: its rows must come out upright.
	rt_basic() {

		const target = stage( new THREE.Scene(), 0.5, 2 );
		target.add( texels( new THREE.MeshBasicMaterial( { color: 0xff3020 } ), 5.2, 29.8, 36.2, 58.8 ) );
		target.add( texels( new THREE.MeshLambertMaterial( { color: 0x44cc66 } ), 34.2, 60.8, 6.2, 27.8 ) );

		const geometry = new THREE.BufferGeometry();
		geometry.setAttribute( 'position', new THREE.Float32BufferAttribute( [ 38.2, 36.3, 0, 60.7, 36.3, 0, 40.3, 58.6, 0 ].map( ( v, i ) => i % 3 === 2 ? 0 : v / 32 - 1 ), 3 ) );
		target.add( new THREE.Mesh( geometry, new THREE.MeshBasicMaterial( { color: 0xffcc33 } ) ) );

		const scene = new THREE.Scene();
		scene.add( quad( new THREE.MeshBasicMaterial( { userData: { renderTarget: true } } ) ) );

		return {
			scene,
			camera: flat(),
			clear: [ 0x000000, 1 ],
			target: { scene: target, camera: flat(), size: [ 64, 64 ], clear: [ 0x203040, 1 ], options: {} },
		};

	},

	// A target's own clear color and depth buffer: the far quad is drawn after the near one (renderOrder) and
	// must stay behind it. Nearest filtering, magnified twice onto the whole frame.
	rt_read() {

		const target = new THREE.Scene();
		const near = texels( new THREE.MeshBasicMaterial( { color: 0xff0000 } ), 10.3, 40.7, 12.2, 44.6, 0.2 );
		const far = texels( new THREE.MeshBasicMaterial( { color: 0x00ff00 } ), 24.3, 54.7, 22.4, 52.6, - 0.4 );
		far.renderOrder = 1;
		target.add( near, far );

		const scene = new THREE.Scene();
		scene.add( quad( new THREE.MeshBasicMaterial( { userData: { renderTarget: true } } ), 0, 0, 0, 2, 2 ) );

		return {
			scene,
			camera: flat(),
			clear: [ 0x000000, 1 ],
			target: {
				scene: target,
				camera: flat(),
				size: [ 64, 64 ],
				clear: [ 0x336699, 1 ],
				options: { minFilter: THREE.NearestFilter, magFilter: THREE.NearestFilter },
			},
		};

	},

	// A 128 × 128 target with a DepthTexture (UnsignedIntType, DepthFormat: DEPTH_COMPONENT24 in WebGL): a tilted
	// plane, a turned box and a sphere seen by a perspective camera whose near and far planes (1.5 and 5) spread
	// their depths, then the depth texture as the map of a MeshBasicMaterial on a quad filling the frame.
	depth_texture_view() {

		return depthView( {} );

	},

	// The same with a FloatType DepthTexture in DepthStencilFormat (DEPTH32F_STENCIL8 in WebGL).
	depth_texture_float() {

		return depthView( { type: THREE.FloatType, format: THREE.DepthStencilFormat } );

	},

	// CubeCamera.update into a 32 × 32 WebGLCubeRenderTarget (no mipmaps) at the sphere, which is hidden while
	// the faces are drawn; the sphere reflects the room and its quads through MeshBasicMaterial's envMap.
	cube_camera_basic() {

		const scene = room( new THREE.MeshBasicMaterial( { color: 0xffeecc } ) );

		return {
			scene,
			camera: front(),
			clear: [ 0x202020, 1 ],
			cube: { size: 32, options: {}, near: 0.1, far: 100, position: [ - 0.929, 0.5655, 0 ] },
		};

	},

	// The same through MeshStandardMaterial (metalness 1, roughness 0.4): the render target texture is
	// prefiltered into a PMREM (pmremVersion). The reflector is a quad facing the camera with its edges on pixel
	// boundaries and its normals turned toward +x (0.6, 0, 0.8), so it reflects mostly the +x face, without a rim
	// whose steep shading differs between the paths.
	cube_camera_standard() {

		const material = new THREE.MeshStandardMaterial( { color: 0xffffff, metalness: 1, roughness: 0.4 } );
		const [ a, b ] = [ at( [ [ 16, 20 ] ], 3 ), at( [ [ 80, 60 ] ], 3 ) ];
		const mirror = new THREE.Mesh( plain( new THREE.PlaneGeometry( b[ 0 ] - a[ 0 ], a[ 1 ] - b[ 1 ] ) ), material );
		mirror.position.set( ( a[ 0 ] + b[ 0 ] ) / 2, ( a[ 1 ] + b[ 1 ] ) / 2, 0 );
		mirror.geometry.setAttribute( 'normal', new THREE.Float32BufferAttribute( Array( 4 ).fill( [ 0.6, 0, 0.8 ] ).flat(), 3 ) );

		return {
			scene: room( material, mirror ),
			camera: front(),
			clear: [ 0x202020, 1 ],
			cube: { size: 32, options: {}, near: 0.1, far: 100, position: mirror.position.toArray() },
		};

	},

	// A transmissive pane drawn into a CubeCamera face: the cube pass runs its own transmission pass. The mirror is
	// cube_camera_standard's quad with MeshBasicMaterial, which shows the cube texture without prefiltering; it
	// reflects mostly the +x face, where a tinted pane facing it stands before four horizontal stripes, so a
	// transmission target read upside down shows them in the wrong order. The stripes run past both the mirror's
	// view and the main view (from z -2.4 to 4): a stripe's corner seen through the pane is covered differently by
	// the 4× multisample positions where a renderer draws the target's rows from the top (Flutter GPU, up to
	// 6/255 in the mirror) instead of from the bottom (WebGL). The main view sees the pane edge-on at its right.
	cube_camera_transmission() {

		const material = new THREE.MeshBasicMaterial( { color: 0xffffff } );
		const [ a, b ] = [ at( [ [ 16, 20 ] ], 3 ), at( [ [ 80, 60 ] ], 3 ) ];
		const mirror = new THREE.Mesh( plain( new THREE.PlaneGeometry( b[ 0 ] - a[ 0 ], a[ 1 ] - b[ 1 ] ) ), material );
		mirror.position.set( ( a[ 0 ] + b[ 0 ] ) / 2, ( a[ 1 ] + b[ 1 ] ) / 2, 0 );
		mirror.geometry.setAttribute( 'normal', new THREE.Float32BufferAttribute( Array( 4 ).fill( [ 0.6, 0, 0.8 ] ).flat(), 3 ) );

		const scene = room( material, mirror );

		for ( const [ color, y ] of [ [ 0xff5533, 1.35 ], [ 0x33cc66, 1.05 ], [ 0x3366ff, 0.75 ], [ 0xffcc33, 0.45 ] ] ) {

			const stripe = quad( new THREE.MeshBasicMaterial( { color } ), 2.6, y, 0.8, 6.4, 0.3 );
			stripe.rotation.y = - Math.PI / 2;
			scene.add( stripe );

		}

		const pane = quad( new THREE.MeshPhysicalMaterial( { color: 0xffffff, roughness: 0.05, transmission: 1, thickness: 0.3, attenuationColor: 0xccddff, attenuationDistance: 2 } ), 1.8, 0, 0, 3, 3 );
		pane.rotation.y = - Math.PI / 2;
		scene.add( pane );

		return {
			scene,
			camera: front(),
			clear: [ 0x202020, 1 ],
			cube: { size: 64, options: {}, near: 0.1, far: 100, position: mirror.position.toArray() },
		};

	},

	// BatchedMesh (addGeometry, addInstance, setMatrixAt): a box, a sphere and a cone batched into one geometry,
	// six instances turned and scaled unevenly, Lambert-lit (the normals turn with each instance's matrix), drawn
	// one multi-draw range per instance; the sphere's rims sit in ambient light.
	batched_basic() {

		const scene = stage( new THREE.Scene(), 0.5, 2 );
		const geometries = [ new THREE.BoxGeometry( 0.4, 0.4, 0.4 ), new THREE.SphereGeometry( 0.25, 16, 12 ), new THREE.ConeGeometry( 0.22, 0.45, 12 ) ];
		scene.add( batched( geometries, new THREE.MeshLambertMaterial( { color: 0xffaa66 } ), [
			[ 0, - 0.81, 0.52, 0, 0.5, 0.7, 0.1, 1, 1 ],
			[ 1, 0.02, 0.53, 0, 0, 0, 0, 1, 1 ],
			[ 2, 0.83, 0.51, 0, 0.3, 0, - 0.4, 1, 1 ],
			[ 2, - 0.79, - 0.48, 0, - 0.4, 0.6, 0.2, 1.3, 0.8 ],
			[ 0, 0.03, - 0.52, 0, - 0.3, 0.9, 0.3, 1.4, 0.7 ],
			[ 1, 0.81, - 0.49, 0, 0, 0, 0, 0.8, 1.2 ]
		] ) );

		return { scene, camera: front(), clear: [ 0x202020, 1 ], edges: 8 };

	},

	// BatchedMesh colors (setColorAt, batchingColorTexture) and visibility (setVisibleAt): quads and boxes tinted
	// per instance through MeshStandardMaterial under a directional light, the fourth instance hidden.
	batched_colors() {

		const scene = stage( new THREE.Scene(), 0.4, 2.5 );
		const geometries = [ new THREE.PlaneGeometry( 0.42, 0.42 ), new THREE.BoxGeometry( 0.35, 0.35, 0.35 ) ];
		scene.add( batched( geometries, new THREE.MeshStandardMaterial( { roughness: 0.7 } ), [
			[ 0, - 0.71, 0.47, 0, 0, 0.5, 0.2, 1, 1 ],
			[ 1, 0.02, 0.48, 0, 0.6, 0.5, 0, 1, 1 ],
			[ 0, 0.73, 0.46, 0, - 0.4, - 0.3, 0.3, 1.2, 0.8 ],
			[ 0, - 0.68, - 0.52, 0, 0, 0, 0, 1, 1 ],
			[ 1, 0.01, - 0.49, 0, - 0.5, 0.8, 0.2, 1.3, 0.8 ],
			[ 0, 0.72, - 0.51, 0, 0.3, 0.4, - 0.2, 0.9, 1.2 ]
		], { colors: [ 0x88aaff, 0xffaa66, 0x99ff99, 0xff4444, 0xffee88, 0xcc88ff ], hidden: [ 3 ] } ) );

		return { scene, camera: front(), clear: [ 0x202020, 1 ], edges: 10 };

	},

	// A BatchedMesh casting and receiving shadows (onBeforeShadow: its ranges culled and sorted for the shadow
	// camera, drawn with the depth material's batching variant): shadowed()'s two boxes as instances of two
	// geometries in their places, a third, a squat box under the floating one, in its shadow on the ground, and a
	// fourth high up out of the camera's view (culled in the main pass, not in the shadow pass) whose shadow falls
	// left of the boxes, under a directional light with PCFShadowMap.
	batched_shadow() {

		const material = new THREE.MeshLambertMaterial( { color: 0xdd8855 } );
		const { scene, camera, floating, standing } = shadowed( new THREE.MeshLambertMaterial( { color: 0xcccccc } ), material );
		scene.remove( floating, standing );

		const mesh = batched( [ new THREE.BoxGeometry( 0.5, 0.5, 0.5 ), new THREE.BoxGeometry( 0.4, 0.7, 0.4 ) ], material, [
			[ 0, 0.1435, 0.55, 0.1, 0, 0, 0, 1, 1 ],
			[ 1, - 0.6, 0.353, - 0.4, 0, 0, 0, 1, 1 ],
			[ 1, 0.4615, 0.1385, 0.13, 0, 0, 0, 0.6, 0.4 ],
			[ 1, - 1.85, 2.1, 0.15, 0, 0, 0, 1, 0.5 ]
		] );
		mesh.castShadow = true;
		mesh.receiveShadow = true;
		scene.add( mesh );

		return { scene, camera, clear: [ 0x000000, 1 ], renderer: { shadowMap: { enabled: true } }, edges: 14 };

	},

	// batched_shadow's BatchedMesh under pointed()'s point light with BasicShadowMap: onBeforeShadow runs once per
	// cube face, each face's ranges culled against that face's camera, and an instance beside the light, above the
	// others, casts into the - X and - Y faces.
	batched_shadow_point() {

		const material = new THREE.MeshLambertMaterial( { color: 0xdd8855 } );
		const { scene, camera, floating, standing } = pointed( new THREE.MeshLambertMaterial( { color: 0xcccccc } ), material );
		scene.remove( floating, standing );

		const mesh = batched( [ new THREE.BoxGeometry( 0.5, 0.5, 0.5 ), new THREE.BoxGeometry( 0.4, 0.7, 0.4 ) ], material, [
			[ 0, 0.1435, 0.55, 0.1, 0, 0, 0, 1, 1 ],
			[ 1, - 0.6, 0.353, - 0.4, 0, 0, 0, 1, 1 ],
			[ 0, - 0.69, 1.43, 0.27, 0, 0, 0, 0.4, 0.4 ]
		] );
		mesh.castShadow = true;
		mesh.receiveShadow = true;
		scene.add( mesh );

		return { scene, camera, clear: [ 0x000000, 1 ], renderer: { shadowMap: { enabled: true, type: THREE.BasicShadowMap } }, edges: 14 };

	},

	// A RectAreaLight (r187 apps call RectAreaLightUniformsLib.init(); page.html does) over a floor, a quad and a
	// box of MeshStandardMaterial with three roughness values, plus a little ambient light.
	rect_area_standard() {

		const scene = new THREE.Scene();
		scene.add( new THREE.AmbientLight( 0xffffff, 0.15 ) );

		const light = new THREE.RectAreaLight( 0xffeedd, 14, 1.6, 0.5 );
		light.position.set( 0, 0.5, 1.4 );
		light.lookAt( 0, - 0.2, 0 );
		scene.add( light );

		const floor = new THREE.Mesh( new THREE.PlaneGeometry( 4, 4 ), new THREE.MeshStandardMaterial( { color: 0x888888, roughness: 0.4 } ) );
		floor.rotation.x = - Math.PI / 2;
		floor.position.y = - 0.7013;
		scene.add( floor );

		const quad = new THREE.Mesh( new THREE.PlaneGeometry( 0.8013, 0.8013 ), new THREE.MeshStandardMaterial( { color: 0xd09060, roughness: 0.25, metalness: 0.2 } ) );
		quad.position.set( - 0.5017, 0.0021, 0 );
		scene.add( quad );

		const box = new THREE.Mesh( new THREE.BoxGeometry( 0.6, 0.6, 0.6 ), new THREE.MeshStandardMaterial( { color: 0x6688cc, roughness: 0.7 } ) );
		box.position.set( 0.55, - 0.3687, 0.1 );
		box.rotation.y = 0.5;
		scene.add( box );

		return { scene, camera: front(), clear: [ 0x181818, 1 ], edges: 12 };

	},

	// A rotated RectAreaLight over MeshPhysicalMaterial with clearcoat (RE_Direct_RectArea_Physical lights the
	// clearcoat layer too) and a MeshLambertMaterial quad, which r187 does not light with rect area lights.
	rect_area_physical() {

		const scene = new THREE.Scene();
		scene.add( new THREE.AmbientLight( 0xffffff, 0.25 ) );

		const light = new THREE.RectAreaLight( 0xaaccff, 16, 1.2, 0.4 );
		light.position.set( - 0.6, 0.4, 1.2 );
		light.lookAt( 0, 0, 0 );
		light.rotateZ( 0.6 );
		scene.add( light );

		const floor = new THREE.Mesh( new THREE.PlaneGeometry( 4, 4 ), new THREE.MeshPhysicalMaterial( { color: 0x556677, roughness: 0.8, clearcoat: 1, clearcoatRoughness: 0.1 } ) );
		floor.rotation.x = - Math.PI / 2;
		floor.position.y = - 0.7013;
		scene.add( floor );

		const coated = new THREE.Mesh( new THREE.PlaneGeometry( 0.8013, 0.8013 ), new THREE.MeshPhysicalMaterial( { color: 0xaa3322, roughness: 0.5, clearcoat: 1, clearcoatRoughness: 0.2 } ) );
		coated.position.set( - 0.4517, 0.0021, 0 );
		scene.add( coated );

		const lambert = new THREE.Mesh( new THREE.PlaneGeometry( 0.8013, 0.8013 ), new THREE.MeshLambertMaterial( { color: 0xcccccc } ) );
		lambert.position.set( 0.5017, 0.0021, 0 );
		scene.add( lambert );

		return { scene, camera: front(), clear: [ 0x181818, 1 ] };

	},

	// AnimationMixer at fixed times (`animate`; page.html): skinned() bars driven by clips on their bones, which
	// toJSON keeps in the mesh's `animations`. The left bar (attached) plays `bend` (the middle bone's quaternion,
	// three keys) at weight 0.7 and `lift` (the root bone's position) at 0.6; the right one (detached,
	// MeshNormalMaterial) fades `sway` out and `twist` in over 0.8 s, `twist` ping-ponging. Times: rest, between
	// keys, mid-fade, and past the clips' ends (LoopRepeat wraps).
	anim_skinned() {

		const scene = new THREE.Scene();
		const left = skinned( new THREE.MeshBasicMaterial( { color: 0xff8844 } ), [ - 0.5, - 0.05 ], [ 0, 0, 0 ] );
		const right = skinned( new THREE.MeshNormalMaterial(), [ 0.55, 0.03 ], [ 0, 0, 0 ], scene );
		const turn = ( x, y, z ) => new THREE.Quaternion().setFromEuler( new THREE.Euler( x, y, z ) ).toArray();

		for ( const mesh of [ left, right ] ) {

			const [ root, middle ] = mesh.skeleton.bones;
			root.name = 'root';
			middle.name = 'middle';

		}

		const foot = left.skeleton.bones[ 0 ].position.toArray();
		left.animations = [
			new THREE.AnimationClip( 'bend', - 1, [
				new THREE.QuaternionKeyframeTrack( 'middle.quaternion', [ 0, 0.5, 1 ], [ ...turn( 0, 0, 0 ), ...turn( 0.5, 0, 0.7 ), ...turn( 0, 0, 0 ) ] )
			] ),
			new THREE.AnimationClip( 'lift', - 1, [
				new THREE.VectorKeyframeTrack( 'root.position', [ 0, 0.8 ], [ ...foot, foot[ 0 ] + 0.15, foot[ 1 ] + 0.23, foot[ 2 ] ] )
			] )
		];
		right.animations = [
			new THREE.AnimationClip( 'sway', - 1, [
				new THREE.QuaternionKeyframeTrack( 'middle.quaternion', [ 0, 0.6 ], [ ...turn( 0, 0, 0 ), ...turn( - 0.7, 0.3, - 0.4 ) ] )
			] ),
			new THREE.AnimationClip( 'twist', - 1, [
				new THREE.QuaternionKeyframeTrack( 'middle.quaternion', [ 0, 0.5 ], [ ...turn( 0, 0, 0 ), ...turn( 0.4, 0.5, 0.6 ) ] )
			] )
		];
		scene.add( left, right );

		const animate = {
			times: [ 0, 0.37, 1.25, 2.6 ],
			actions: {
				bend: { weight: 0.7 },
				lift: { weight: 0.6 },
				sway: { fadeOut: 0.8 },
				twist: { fadeIn: 0.8, loop: THREE.LoopPingPong }
			}
		};

		return { scene, camera: front(), clear: [ 0x202020, 1 ], animate, edges: 5 };

	},

	// AnimationMixer on morph targets, a material and object positions: a morphed() bar (MeshBasicMaterial,
	// transparent over a grey quad) whose `shape` clip moves both influences (`.morphTargetInfluences[0]`
	// linear, `[1]` smooth), its material's color and opacity through PropertyBinding; and three quads whose
	// `.position` clips interpolate linearly, discretely and smoothly (CubicInterpolant) through the same keys.
	anim_morph() {

		const scene = new THREE.Scene();
		scene.add( quad( new THREE.MeshBasicMaterial( { color: 0x777777 } ), - 0.55, 0.02, - 0.3, 0.83, 1.03 ) );

		const bar = morphed( new THREE.MeshBasicMaterial( { color: 0x66ccff, transparent: true } ), [ - 0.55, 0.01 ], [ 0, 0 ] );
		bar.animations = [
			new THREE.AnimationClip( 'shape', - 1, [
				new THREE.NumberKeyframeTrack( '.morphTargetInfluences[0]', [ 0, 0.5, 1.2 ], [ 0, 1, 0.3 ] ),
				new THREE.NumberKeyframeTrack( '.morphTargetInfluences[1]', [ 0, 0.4, 0.9, 1.2 ], [ 0, 0.8, - 0.4, 0 ], THREE.InterpolateSmooth ),
				new THREE.ColorKeyframeTrack( '.material.color', [ 0, 0.6, 1.2 ], [ 0.4, 0.8, 1, 1, 0.3, 0.1, 0.2, 0.9, 0.3 ] ),
				new THREE.NumberKeyframeTrack( '.material.opacity', [ 0, 1.2 ], [ 1, 0.35 ] )
			] )
		];
		scene.add( bar );

		const interpolations = { linear: THREE.InterpolateLinear, discrete: THREE.InterpolateDiscrete, smooth: THREE.InterpolateSmooth };
		const colors = [ 0xff5544, 0x55ee66, 0x5577ff ];

		Object.entries( interpolations ).forEach( ( [ name, interpolation ], i ) => {

			const y = 0.62 - 0.6 * i + 0.033;
			const box = quad( new THREE.MeshBasicMaterial( { color: colors[ i ] } ), 0.31, y, 0, 0.27, 0.27 );

			// The smooth quad swings wider, so smooth taken as linear moves its edges 2 to 4 pixels (0.825 and 1.62 s).
			box.animations = [
				new THREE.AnimationClip( name, - 1, [
					new THREE.VectorKeyframeTrack( '.position', [ 0, 0.4, 0.7, 1 ], name === 'smooth' ? [ 0.31, y, 0, 0.99, y + 0.25, 0, 0.4, y - 0.25, 0, 0.94, y, 0 ] : [ 0.31, y, 0, 0.74, y + 0.1, 0, 0.55, y - 0.15, 0, 0.88, y, 0 ], interpolation )
				] )
			];
			scene.add( box );

		} );

		return { scene, camera: front(), clear: [ 0x202020, 1 ], animate: { times: [ 0, 0.37, 0.825, 1.62 ] }, edges: 3 };

	},

	// antialias: true (exception E-ANTIALIAS): rotated MeshBasic quads and a triangle with sharp silhouettes over
	// each other and the clear color, and thin lines, drawn with 4× MSAA on both sides.
	aa_basic() {

		const scene = new THREE.Scene();
		const tilted = quad( new THREE.MeshBasicMaterial( { color: 0xe8d040 } ), - 0.45, 0.35, 0, 0.9, 0.7 );
		tilted.rotation.z = 0.37;
		const turned = quad( new THREE.MeshBasicMaterial( { color: 0x3366cc } ), 0.4, 0.2, 0.1, 0.8, 0.8 );
		turned.rotation.z = - 0.61;
		const thin = triangle( new THREE.MeshBasicMaterial( { color: 0xcc4433 } ), - 0.2 );
		thin.scale.set( 0.5, 0.35, 1 );
		thin.position.set( 0.15, - 0.62, - 0.2 );
		thin.rotation.z = 0.23;

		const lines = new THREE.BufferGeometry();
		lines.setAttribute( 'position', new THREE.Float32BufferAttribute( [ - 1.15, - 0.35, 0.2, 1.1, - 0.1, 0.2, - 1.0, - 1.05, 0.2, - 0.2, 1.05, 0.2 ], 3 ) );

		scene.add( tilted, turned, thin );
		scene.add( new THREE.LineSegments( lines, new THREE.LineBasicMaterial( { color: 0xffffff } ) ) );

		return { scene, camera: front(), clear: [ 0x101018, 1 ], antialias: true };

	},

	// antialias: true with lighting and a shadow: the boxes of shadowed() in MeshStandardMaterial, the floating one
	// turned so none of its silhouette edges is a row or column. It casts no shadow: turned, its silhouette in the
	// shadow map moved the PCF shadow's edge by up to 32/255 at 5 floor pixels against r187 with antialias off too
	// (a texel tie, not MSAA), so only the standing box casts one.
	aa_standard() {

		const { scene, floating, camera } = shadowed( new THREE.MeshStandardMaterial( { color: 0xcccccc, roughness: 0.8 } ), new THREE.MeshStandardMaterial( { color: 0x6699dd, roughness: 0.4, metalness: 0.2 } ) );
		floating.rotation.set( 0.3, 0.71, 0.13 );
		floating.castShadow = false;

		return { scene, camera, clear: [ 0x000000, 1 ], renderer: { shadowMap: { enabled: true } }, antialias: true };

	},

	// An FXAAPass (r187's FXAAShader) on a known frame: a full-frame quad showing a 128 × 128 nearest-filtered
	// DataTexture texel for pixel (no rasterized silhouette, so the input to FXAA is the same on both sides), with
	// stair-stepped hard edges at several slopes, a one-texel line and a one-texel near-vertical line; a RenderPass
	// into the HalfFloatType target, the FXAAPass, an OutputPass with the sRGB transfer.
	composer_fxaa() {

		const scene = new THREE.Scene();
		const map = field( size, ( u, v ) => {

			if ( Math.abs( v - 0.3 - 0.21 * u ) < 0.5 / size ) {

				return [ 255, 255, 255, 255 ];

			}

			if ( Math.abs( u - 0.82 - 0.08 * v ) < 0.5 / size ) {

				return [ 255, 64, 32, 255 ];

			}

			if ( v > 0.55 + 0.37 * u && u < 0.7 ) {

				return [ 232, 208, 64, 255 ];

			}

			if ( u > 0.45 + 0.6 * v && v > 0.08 ) {

				return [ 51, 102, 204, 255 ];

			}

			return [ 0, 0, 0, 255 ];

		}, { magFilter: THREE.NearestFilter, minFilter: THREE.NearestFilter, generateMipmaps: false } );
		scene.add( quad( new THREE.MeshBasicMaterial( { map } ), 0, 0, 0, 2, 2 ) );

		return { scene, camera: flat(), clear: [ 0x000000, 1 ], composer: { fxaa: true } };

	},

	// A render target with samples: 4 (exception E-ANTIALIAS) holding aa_basic's scene, 128 × 128 with nearest
	// filtering, shown texel for pixel on a quad over the whole frame, which is drawn without antialias: every
	// blended pixel comes from the target's resolve.
	rt_samples() {

		const { scene: target, camera, clear } = this.aa_basic();

		const scene = new THREE.Scene();
		scene.add( quad( new THREE.MeshBasicMaterial( { userData: { renderTarget: true } } ), 0, 0, 0, 2, 2 ) );

		return {
			scene,
			camera: flat(),
			clear: [ 0x000000, 1 ],
			target: {
				scene: target,
				camera,
				size: [ size, size ],
				clear,
				options: { samples: 4, minFilter: THREE.NearestFilter, magFilter: THREE.NearestFilter },
			},
		};

	},

	// aa_basic's scene through an EffectComposer whose HalfFloatType targets have samples: 4 (exception
	// E-ANTIALIAS): the RenderPass draws it multisampled, the OutputPass applies the sRGB transfer; the renderer
	// itself has no antialias. The clear color is black: RenderPass's renderer.clear() into a target uses the clear
	// value WebGLBackground last set, in sRGB when setClearColor ran without a target, which the port does not
	// mimic (it clears a target in linear color).
	composer_samples() {

		return { ...this.aa_basic(), clear: [ 0x000000, 1 ], antialias: false, composer: { samples: 4 } };

	},

};

export { size };;
