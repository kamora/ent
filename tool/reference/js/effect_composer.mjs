// Runs EffectComposer scenarios against the pinned three.js r187 source in Node with a recording renderer and
// writes what each scenario did to fixtures/values/effect_composer.json, which
// packages/ent/test/postprocessing/effect_composer_test.dart replays with the Dart composer and the same renderer.
//
// Usage: node tool/reference/js/effect_composer.mjs
//
// The renderer draws nothing: it logs every call the passes make (render targets by first use, T0, T1, …; the
// quad's material, its tDiffuse target, defines and uniforms (a Vector2 as x,y); the clear state at each render).

import { writeFileSync } from 'node:fs';
import { execSync } from 'node:child_process';
import { register } from 'node:module';

const here = new URL( '.', import.meta.url );
const core = new URL( '../../../third_party/three.js/src/Three.js', here ).href;
const git = ( args ) => execSync( 'git ' + args, { cwd: new URL( '../../../third_party/three.js/', here ) } ).toString().trim();
const pin = { tag: git( 'describe --tags --exact-match' ), commit: git( 'rev-parse HEAD' ) };

if ( pin.tag !== 'r187' ) {

	throw new Error( 'three.js checkout is ' + pin.tag + ', fixtures require r187' );

}

// The addons import the bare specifier 'three'; resolve it to the full build of the pinned source (UniformsUtils is not in the core one).
const hook = `export async function resolve( specifier, context, next ) {
	if ( specifier === 'three' ) {
		return { url: ${JSON.stringify( core )}, shortCircuit: true };
	}
	return next( specifier, context );
}`;
register( 'data:text/javascript,' + encodeURIComponent( hook ) );

const THREE = await import( 'three' );
const jsm = '../../../third_party/three.js/examples/jsm/';
const { EffectComposer } = await import( jsm + 'postprocessing/EffectComposer.js' );
const { RenderPass } = await import( jsm + 'postprocessing/RenderPass.js' );
const { ShaderPass } = await import( jsm + 'postprocessing/ShaderPass.js' );
const { OutputPass } = await import( jsm + 'postprocessing/OutputPass.js' );
const { FXAAPass } = await import( jsm + 'postprocessing/FXAAPass.js' );
const { UnrealBloomPass } = await import( jsm + 'postprocessing/UnrealBloomPass.js' );
const { Pass } = await import( jsm + 'postprocessing/Pass.js' );
const { CopyShader } = await import( jsm + 'shaders/CopyShader.js' );
const { VignetteShader } = await import( jsm + 'shaders/VignetteShader.js' );

// The recording renderer: logs into `log`, names render targets by first use.
function recorder( width, height, ratio ) {

	const log = [];
	const ids = new Map();
	const id = ( target ) => target === null ? 'screen' : ( ids.has( target ) ? ids.get( target ) : ( ids.set( target, 'T' + ids.size ), ids.get( target ) ) );
	const clearColor = new THREE.Color( 0x000000 );
	let clearAlpha = 1;
	let current = null;

	// A uniform's value: a texture by its target, a vector by its components, a color as hex, an array element by
	// element.
	const format = ( value ) => {

		if ( Array.isArray( value ) ) return '[' + value.map( format ).join( ';' ) + ']';
		if ( value && value.isTexture ) return id( value.renderTarget );
		if ( value && value.isVector2 ) return value.x + ',' + value.y;
		if ( value && value.isVector3 ) return value.x + ',' + value.y + ',' + value.z;
		if ( value && value.isColor ) return value.getHexString();
		return value;

	};

	const renderer = {
		log,
		id,
		autoClear: true,
		autoClearColor: true,
		autoClearDepth: true,
		autoClearStencil: true,
		toneMapping: THREE.NoToneMapping,
		toneMappingExposure: 1,
		outputColorSpace: THREE.SRGBColorSpace,
		getPixelRatio: () => ratio,
		getSize: ( target ) => target.set( width, height ),
		getRenderTarget: () => current,
		setRenderTarget: ( target ) => {

			current = target;
			log.push( 'setRenderTarget ' + id( target ) );

		},
		getClearColor: ( target ) => target.copy( clearColor ),
		setClearColor: ( color, alpha = 1 ) => {

			clearColor.set( color );
			clearAlpha = alpha;

		},
		getClearAlpha: () => clearAlpha,
		setClearAlpha: ( alpha ) => {

			clearAlpha = alpha;

		},
		clear: ( color = true, depth = true, stencil = true ) => log.push( `clear ${ color } ${ depth } ${ stencil }` ),
		clearDepth: () => log.push( 'clearDepth' ),
		render: ( scene, camera ) => {

			const state = `autoClear=${ renderer.autoClear } clear=${ clearColor.getHexString() }/${ clearAlpha } into=${ id( current ) }`;

			if ( scene.isScene ) {

				log.push( `render scene ${ scene.name } ${ camera.type } override=${ scene.overrideMaterial ? scene.overrideMaterial.name : '-' } ${ state }` );

			} else {

				const material = scene.material;
				const uniforms = Object.keys( material.uniforms ).sort().map( ( key ) => {

					return key + '=' + format( material.uniforms[ key ].value );

				} );
				log.push( `render quad ${ material.name } ${ camera.type } defines=${ Object.keys( material.defines ).sort().join( ',' ) } blending=${ material.blending } ${ uniforms.join( ' ' ) } ${ state }` );

			}

		},
	};

	return renderer;

}

// A pass that logs its setSize and render calls.
class Probe extends Pass {

	constructor( name, needsSwap = true ) {

		super();
		this.name = name;
		this.needsSwap = needsSwap;

	}

	setSize( width, height ) {

		this.log.push( `setSize ${ this.name } ${ width } ${ height }` );

	}

	render( renderer, writeBuffer, readBuffer, deltaTime, maskActive ) {

		this.log.push( `probe ${ this.name } write=${ renderer.id( writeBuffer ) } read=${ renderer.id( readBuffer ) } dt=${ deltaTime } mask=${ maskActive } screen=${ this.renderToScreen }` );

	}

}

function targets( composer, renderer ) {

	for ( const [ key, target ] of [ [ 'rt1', composer.renderTarget1 ], [ 'rt2', composer.renderTarget2 ], [ 'write', composer.writeBuffer ], [ 'read', composer.readBuffer ] ] ) {

		renderer.log.push( `${ key } ${ renderer.id( target ) } ${ target.width }x${ target.height } type=${ target.texture.type } name=${ target.texture.name }` );

	}

}

const scenarios = {

	// Defaults: two HalfFloatType targets of the drawing-buffer size, the chain of a RenderPass, a CopyShader
	// pass, a disabled VignetteShader pass and an OutputPass under ACES.
	chain() {

		const renderer = recorder( 64, 32, 2 );
		renderer.toneMapping = THREE.ACESFilmicToneMapping;
		renderer.toneMappingExposure = 1.5;
		const composer = new EffectComposer( renderer );
		targets( composer, renderer );
		const scene = new THREE.Scene();
		scene.name = 'main';
		const copy = new ShaderPass( CopyShader );
		copy.uniforms.opacity.value = 0.5;
		const vignette = new ShaderPass( VignetteShader );
		vignette.enabled = false;
		composer.addPass( new RenderPass( scene, new THREE.PerspectiveCamera() ) );
		composer.addPass( copy );
		composer.addPass( vignette );
		composer.addPass( new OutputPass() );
		renderer.log.push( 'last ' + [ 0, 1, 2, 3 ].map( ( i ) => composer.isLastEnabledPass( i ) ).join( ',' ) );
		composer.render( 0.25 );
		composer.render( 0.25 );
		targets( composer, renderer );
		return renderer.log;

	},

	// renderToScreen false: the last pass writes into a target too; vignette enabled.
	offscreen() {

		const renderer = recorder( 10, 10, 1 );
		const composer = new EffectComposer( renderer );
		composer.renderToScreen = false;
		const vignette = new ShaderPass( VignetteShader );
		vignette.clear = true;
		composer.addPass( new RenderPass( new THREE.Scene(), new THREE.OrthographicCamera() ) );
		composer.addPass( vignette );
		composer.addPass( new OutputPass() );
		composer.render( 0 );
		targets( composer, renderer );
		return renderer.log;

	},

	// Sizes: addPass, insertPass, setPixelRatio, setSize, removePass, and probes for the swaps.
	sizes() {

		const renderer = recorder( 40, 20, 1 );
		const composer = new EffectComposer( renderer );
		const a = new Probe( 'a' );
		const b = new Probe( 'b', false );
		const c = new Probe( 'c' );

		for ( const probe of [ a, b, c ] ) {

			probe.log = renderer.log;

		}

		composer.addPass( a );
		composer.addPass( c );
		composer.insertPass( b, 1 );
		composer.setPixelRatio( 2 );
		composer.setSize( 30, 12 );
		targets( composer, renderer );
		composer.render( 1 );
		c.enabled = false;
		composer.render( 1 );
		composer.removePass( a );
		composer.removePass( a );
		composer.render( 1 );
		renderer.log.push( 'passes ' + composer.passes.map( ( p ) => p.name ).join( ',' ) );
		composer.swapBuffers();
		targets( composer, renderer );
		return renderer.log;

	},

	// reset() with and without a target, and a composer on a given target.
	reset() {

		const renderer = recorder( 16, 8, 1 );
		const composer = new EffectComposer( renderer );
		targets( composer, renderer );
		composer.reset();
		targets( composer, renderer );
		composer.reset( new THREE.WebGLRenderTarget( 5, 7 ) );
		targets( composer, renderer );
		const own = new EffectComposer( renderer, new THREE.WebGLRenderTarget( 9, 3 ) );
		targets( own, renderer );
		return renderer.log;

	},

	// RenderPass options: clear color and alpha, override material, clearDepth, clear off; restored after.
	render_pass() {

		const renderer = recorder( 8, 8, 1 );
		renderer.setClearColor( 0x112233, 0.75 );
		const composer = new EffectComposer( renderer );
		const scene = new THREE.Scene();
		scene.name = 'main';
		const override = new THREE.MeshBasicMaterial();
		override.name = 'override';
		const pass = new RenderPass( scene, new THREE.PerspectiveCamera(), override, 0xff8800, 0.5 );
		pass.clearDepth = true;
		const plain = new RenderPass( scene, new THREE.PerspectiveCamera() );
		plain.clear = false;
		composer.addPass( pass );
		composer.addPass( plain );
		renderer.autoClear = true;
		composer.render( 0 );
		renderer.log.push( `after autoClear=${ renderer.autoClear } clear=${ renderer.getClearColor( new THREE.Color() ).getHexString() }/${ renderer.getClearAlpha() } override=${ scene.overrideMaterial }` );
		return renderer.log;

	},

	// FXAAPass: its default resolution, then setSize through addPass, setPixelRatio and setSize (1 / width,
	// 1 / height of the drawing buffer), each followed by a render.
	fxaa() {

		const renderer = recorder( 64, 32, 2 );
		const composer = new EffectComposer( renderer );
		const fxaa = new FXAAPass();
		const resolution = () => renderer.log.push( `resolution ${ fxaa.uniforms.resolution.value.x } ${ fxaa.uniforms.resolution.value.y }` );
		resolution();
		composer.addPass( new RenderPass( new THREE.Scene(), new THREE.PerspectiveCamera() ) );
		composer.addPass( fxaa );
		composer.addPass( new OutputPass() );
		resolution();
		composer.render( 0 );
		composer.setPixelRatio( 1 );
		resolution();
		composer.setSize( 30, 12 );
		resolution();
		composer.render( 0 );
		return renderer.log;

	},

	// OutputPass defines for every tone mapping and both color spaces, rebuilt only when they change.
	output() {

		const renderer = recorder( 4, 4, 1 );
		const composer = new EffectComposer( renderer );
		const output = new OutputPass();
		composer.addPass( output );

		for ( const [ toneMapping, space ] of [
			[ THREE.NoToneMapping, THREE.SRGBColorSpace ], [ THREE.LinearToneMapping, THREE.SRGBColorSpace ],
			[ THREE.ReinhardToneMapping, THREE.LinearSRGBColorSpace ], [ THREE.CineonToneMapping, THREE.SRGBColorSpace ],
			[ THREE.ACESFilmicToneMapping, THREE.SRGBColorSpace ], [ THREE.AgXToneMapping, THREE.SRGBColorSpace ],
			[ THREE.NeutralToneMapping, THREE.LinearSRGBColorSpace ], [ THREE.CustomToneMapping, THREE.SRGBColorSpace ],
			[ THREE.CustomToneMapping, THREE.SRGBColorSpace ],
		] ) {

			renderer.toneMapping = toneMapping;
			renderer.outputColorSpace = space;
			composer.render( 0 );
			renderer.log.push( 'version ' + output.material.version );

		}

		return renderer.log;

	},

	// UnrealBloomPass between a RenderPass and an OutputPass at an odd size: its targets (half size, halved per mip,
	// rounded), the blur materials' kernels and coefficients, the composite's factors, every render (the blend
	// additive into the read buffer), then setSize through the composer and the second setting.
	bloom() {

		const renderer = recorder( 101, 61, 1 );
		const composer = new EffectComposer( renderer );
		const bloom = new UnrealBloomPass( new THREE.Vector2( 101, 61 ), 1.5, 0.4, 0.85 );
		const hash = ( source ) => source.length + ':' + [ ...source ].reduce( ( h, c ) => ( h * 33 + c.charCodeAt( 0 ) ) >>> 0, 5381 );
		const state = () => {

			for ( const target of [ bloom.renderTargetBright, ...bloom.renderTargetsHorizontal, ...bloom.renderTargetsVertical ] ) {

				renderer.log.push( `target ${ target.texture.name } ${ target.width }x${ target.height } type=${ target.texture.type } depth=${ target.depthBuffer } mipmaps=${ target.texture.generateMipmaps }` );

			}

			for ( const material of [ bloom.materialHighPassFilter, ...bloom.separableBlurMaterials, bloom.compositeMaterial, bloom.blendMaterial ] ) {

				renderer.log.push( `material defines=${ JSON.stringify( material.defines ) } vertex=${ hash( material.vertexShader ) } fragment=${ hash( material.fragmentShader ) } blending=${ material.blending } premultiplied=${ material.premultipliedAlpha } transparent=${ material.transparent } depth=${ material.depthTest },${ material.depthWrite }` );

			}

		};

		renderer.log.push( `swap=${ bloom.needsSwap } mips=${ bloom.nMips } resolution=${ bloom.resolution.x },${ bloom.resolution.y }` );
		state();
		composer.addPass( new RenderPass( new THREE.Scene(), new THREE.PerspectiveCamera() ) );
		composer.addPass( bloom );
		composer.addPass( new OutputPass() );
		state();
		composer.render( 0 );
		composer.setSize( 37, 22 );
		bloom.strength = 0.8;
		bloom.radius = 1;
		bloom.threshold = 0.2;
		bloom.bloomTintColors[ 2 ] = new THREE.Vector3( 1, 0.5, 0.25 );
		state();
		composer.render( 0 );
		return renderer.log;

	},

};

const result = { pin };

for ( const [ name, run ] of Object.entries( scenarios ) ) {

	result[ name ] = run();

}

// ent names UnrealBloomPass TuningPass, and so its targets.
writeFileSync(
	new URL( '../../../fixtures/values/effect_composer.json', here ),
	JSON.stringify( result, null, '\t' ).replaceAll( 'UnrealBloomPass.', 'TuningPass.' ) + '\n'
);
