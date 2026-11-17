// Runs OrbitControls and MapControls scenarios against the pinned three.js r187 source in Node and writes the
// camera and target after every operation to fixtures/values/orbit_controls.json, which
// packages/ent/test/controls/orbit_controls_test.dart replays operation by operation.
//
// Usage: node tool/reference/js/orbit_controls.mjs
//
// There is no DOM: the controls get a fake element (clientWidth, clientHeight, getBoundingClientRect,
// listener stubs that remember what is attached) and the scenarios dispatch plain event objects to the listeners
// upstream attached at that moment: pointerdown, wheel and keydown on the element, pointermove, pointerup and
// keydown on its document.

import { writeFileSync } from 'node:fs';
import { execSync } from 'node:child_process';
import { register } from 'node:module';

const here = new URL( '.', import.meta.url );
const core = new URL( '../../../third_party/three.js/src/Three.Core.js', here ).href;
const git = ( args ) => execSync( 'git ' + args, { cwd: new URL( '../../../third_party/three.js/', here ) } ).toString().trim();
const pin = { tag: git( 'describe --tags --exact-match' ), commit: git( 'rev-parse HEAD' ) };

if ( pin.tag !== 'r187' ) {

	throw new Error( 'three.js checkout is ' + pin.tag + ', fixtures require r187' );

}

// The addons import the bare specifier 'three'; resolve it to the core build of the pinned source.
const hook = `export async function resolve( specifier, context, next ) {
	if ( specifier === 'three' ) {
		return { url: ${JSON.stringify( core )}, shortCircuit: true };
	}
	return next( specifier, context );
}`;
register( 'data:text/javascript,' + encodeURIComponent( hook ) );

const THREE = await import( 'three' );
const { OrbitControls } = await import( '../../../third_party/three.js/examples/jsm/controls/OrbitControls.js' );
const { MapControls } = await import( '../../../third_party/three.js/examples/jsm/controls/MapControls.js' );

const width = 800;
const height = 600;

// A target that keeps its listeners, so an event reaches a handler only while upstream has it attached.
function target() {

	const listeners = {};

	return {
		listeners,
		addEventListener( type, listener ) {

			( listeners[ type ] ??= new Set() ).add( listener );

		},
		removeEventListener( type, listener ) {

			listeners[ type ]?.delete( listener );

		},
		dispatch( type, event ) {

			for ( const listener of [ ...( listeners[ type ] ?? [] ) ] ) {

				listener( event );

			}

		}
	};

}

function element() {

	return {
		clientWidth: width,
		clientHeight: height,
		style: {},
		ownerDocument: target(),
		getBoundingClientRect: () => ( { left: 0, top: 0, width, height } ),
		setPointerCapture() {},
		releasePointerCapture() {},
		...target()
	};

}

function camera( kind, up ) {

	const c = kind === 'ortho' ? new THREE.OrthographicCamera( - 4, 4, 3, - 3, 0.1, 100 ) : new THREE.PerspectiveCamera( 50, width / height, 0.1, 100 );
	if ( up ) {

		c.up.fromArray( up );

	}

	c.position.set( 1, 2, 5 );
	c.updateMatrixWorld();
	return c;

}

const pointer = ( op ) => ( {
	pointerId: op.id ?? 1,
	pointerType: op.type ?? 'mouse',
	button: op.button ?? 0,
	clientX: op.x,
	clientY: op.y,
	pageX: op.x,
	pageY: op.y,
	ctrlKey: op.ctrl ?? false,
	metaKey: false,
	shiftKey: op.shift ?? false,
	preventDefault() {}
} );

function apply( controls, op ) {

	const el = controls.domElement;
	const doc = el.ownerDocument;

	switch ( op.op ) {

		case 'down': return el.dispatch( 'pointerdown', pointer( op ) );
		case 'move': return doc.dispatch( 'pointermove', pointer( op ) );
		case 'up': return doc.dispatch( 'pointerup', pointer( op ) );
		case 'wheel': return el.dispatch( 'wheel', { clientX: op.x, clientY: op.y, deltaY: op.deltaY, deltaMode: op.mode ?? 0, ctrlKey: op.ctrl ?? false, preventDefault() {} } );
		case 'key': return el.dispatch( 'keydown', { code: op.code, key: op.code, ctrlKey: false, metaKey: false, shiftKey: op.shift ?? false, preventDefault() {} } );
		case 'controlDown': return doc.dispatch( 'keydown', { key: 'Control' } );
		case 'listenKeys': return controls.listenToKeyEvents( controls.domElement );
		case 'set': controls[ op.key ] = op.value; return;
		case 'target': controls.target.fromArray( op.value ); return;
		case 'update': return controls.update( op.dt ?? null );
		case 'saveState': return controls.saveState();
		case 'reset': return controls.reset();
		case 'rotateLeft': return controls.rotateLeft( op.value );
		case 'rotateUp': return controls.rotateUp( op.value );
		case 'pan': return controls.pan( op.value[ 0 ], op.value[ 1 ] );
		case 'dollyIn': return controls.dollyIn( op.value );
		case 'dollyOut': return controls.dollyOut( op.value );

	}

	throw new Error( 'unknown op ' + op.op );

}

const scenarios = [
	{ name: 'rotate drag', ops: [
		{ op: 'down', x: 400, y: 300 }, { op: 'move', x: 430, y: 300 }, { op: 'move', x: 470, y: 260 }, { op: 'move', x: 380, y: 420 }, { op: 'up', x: 380, y: 420 }
	] },
	{ name: 'rotate speed', ops: [
		{ op: 'set', key: 'rotateSpeed', value: 0.5 }, { op: 'down', x: 100, y: 100 }, { op: 'move', x: 160, y: 130 }, { op: 'up', x: 160, y: 130 }
	] },
	{ name: 'wheel dolly', ops: [
		{ op: 'wheel', x: 400, y: 300, deltaY: - 100 }, { op: 'wheel', x: 400, y: 300, deltaY: 250 }, { op: 'wheel', x: 400, y: 300, deltaY: 3, mode: 1 },
		{ op: 'wheel', x: 400, y: 300, deltaY: - 1, mode: 2 }, { op: 'wheel', x: 400, y: 300, deltaY: - 4, ctrl: true },
		{ op: 'controlDown' }, { op: 'wheel', x: 400, y: 300, deltaY: - 4, ctrl: true }, { op: 'set', key: 'zoomSpeed', value: 2 }, { op: 'wheel', x: 10, y: 10, deltaY: 120 }
	] },
	{ name: 'middle drag dolly', ops: [
		{ op: 'down', button: 1, x: 300, y: 300 }, { op: 'move', x: 300, y: 340 }, { op: 'move', x: 300, y: 200 }, { op: 'up', x: 300, y: 200 }
	] },
	{ name: 'pan', ops: [
		{ op: 'down', button: 2, x: 300, y: 300 }, { op: 'move', x: 350, y: 280 }, { op: 'up', x: 350, y: 280 },
		{ op: 'down', button: 0, shift: true, x: 300, y: 300 }, { op: 'move', x: 250, y: 330 }, { op: 'up', x: 250, y: 330 },
		{ op: 'set', key: 'screenSpacePanning', value: false }, { op: 'set', key: 'panSpeed', value: 2 },
		{ op: 'down', button: 2, x: 300, y: 300 }, { op: 'move', x: 320, y: 360 }, { op: 'up', x: 320, y: 360 }
	] },
	{ name: 'damping', ops: [
		{ op: 'set', key: 'enableDamping', value: true }, { op: 'set', key: 'dampingFactor', value: 0.1 },
		{ op: 'down', x: 400, y: 300 }, { op: 'move', x: 450, y: 320 }, { op: 'up', x: 450, y: 320 },
		{ op: 'down', button: 2, x: 400, y: 300 }, { op: 'move', x: 380, y: 290 }, { op: 'up', x: 380, y: 290 },
		...Array.from( { length: 12 }, () => ( { op: 'update' } ) )
	] },
	{ name: 'clamps', ops: [
		{ op: 'set', key: 'minPolarAngle', value: 0.6 }, { op: 'set', key: 'maxPolarAngle', value: 1.2 },
		{ op: 'set', key: 'minAzimuthAngle', value: - 0.3 }, { op: 'set', key: 'maxAzimuthAngle', value: 0.5 },
		{ op: 'set', key: 'minDistance', value: 3 }, { op: 'set', key: 'maxDistance', value: 8 },
		{ op: 'update' }, { op: 'rotateUp', value: 2 }, { op: 'rotateUp', value: - 3 }, { op: 'rotateLeft', value: 2 }, { op: 'rotateLeft', value: - 4 },
		{ op: 'dollyIn', value: 0.1 }, { op: 'dollyOut', value: 0.05 },
		{ op: 'set', key: 'minAzimuthAngle', value: 2.5 }, { op: 'set', key: 'maxAzimuthAngle', value: - 2.5 },
		{ op: 'rotateLeft', value: 1 }, { op: 'rotateLeft', value: - 0.7 },
		{ op: 'set', key: 'minAzimuthAngle', value: - 4 }, { op: 'set', key: 'maxAzimuthAngle', value: 4 }, { op: 'rotateLeft', value: 0.2 }
	] },
	{ name: 'target radius', ops: [
		{ op: 'set', key: 'maxTargetRadius', value: 0.5 }, { op: 'pan', value: [ 200, - 100 ] }, { op: 'pan', value: [ - 30, 10 ] }
	] },
	{ name: 'save and reset', ops: [
		{ op: 'rotateLeft', value: 0.4 }, { op: 'saveState' }, { op: 'rotateUp', value: 0.3 }, { op: 'dollyIn', value: 0.7 }, { op: 'pan', value: [ 40, 40 ] },
		{ op: 'reset' }, { op: 'reset' }
	] },
	{ name: 'touch', ops: [
		{ op: 'down', type: 'touch', id: 1, x: 300, y: 300 }, { op: 'move', type: 'touch', id: 1, x: 340, y: 280 },
		{ op: 'down', type: 'touch', id: 2, x: 500, y: 300 }, { op: 'move', type: 'touch', id: 2, x: 560, y: 320 }, { op: 'move', type: 'touch', id: 1, x: 300, y: 290 },
		{ op: 'move', type: 'touch', id: 2, x: 480, y: 310 }, { op: 'up', type: 'touch', id: 1, x: 300, y: 290 },
		{ op: 'move', type: 'touch', id: 2, x: 450, y: 330 }, { op: 'up', type: 'touch', id: 2, x: 450, y: 330 }
	] },
	{ name: 'keys', ops: [
		{ op: 'key', code: 'ArrowUp' }, { op: 'listenKeys' }, { op: 'key', code: 'ArrowUp' }, { op: 'key', code: 'ArrowLeft' },
		{ op: 'key', code: 'ArrowRight', shift: true }, { op: 'key', code: 'ArrowDown', shift: true }, { op: 'key', code: 'KeyA' }
	] },
	{ name: 'auto rotate', ops: [
		{ op: 'set', key: 'autoRotate', value: true }, { op: 'update' }, { op: 'update', dt: 0.5 }, { op: 'set', key: 'autoRotateSpeed', value: - 3 }, { op: 'update', dt: 0.016 }
	] },
	{ name: 'zoom to cursor', ops: [
		{ op: 'set', key: 'zoomToCursor', value: true }, { op: 'wheel', x: 600, y: 150, deltaY: - 200 }, { op: 'wheel', x: 100, y: 500, deltaY: 300 },
		{ op: 'set', key: 'screenSpacePanning', value: false }, { op: 'wheel', x: 500, y: 450, deltaY: - 150 },
		{ op: 'down', button: 1, x: 200, y: 200 }, { op: 'move', x: 200, y: 160 }, { op: 'up', x: 200, y: 160 }
	] },
	{ name: 'ortho', camera: 'ortho', ops: [
		{ op: 'wheel', x: 400, y: 300, deltaY: - 100 }, { op: 'set', key: 'maxZoom', value: 1.3 }, { op: 'wheel', x: 400, y: 300, deltaY: - 300 },
		{ op: 'down', button: 2, x: 300, y: 300 }, { op: 'move', x: 360, y: 250 }, { op: 'up', x: 360, y: 250 },
		{ op: 'down', x: 300, y: 300 }, { op: 'move', x: 330, y: 330 }, { op: 'up', x: 330, y: 330 }, { op: 'saveState' },
		{ op: 'set', key: 'zoomToCursor', value: true }, { op: 'set', key: 'maxZoom', value: 10 }, { op: 'wheel', x: 600, y: 100, deltaY: - 200 }, { op: 'reset' }
	] },
	{ name: 'z up', up: [ 0, 0, 1 ], ops: [
		{ op: 'target', value: [ 0.5, 0, 0 ] }, { op: 'update' }, { op: 'down', x: 400, y: 300 }, { op: 'move', x: 450, y: 250 }, { op: 'up', x: 450, y: 250 },
		{ op: 'set', key: 'screenSpacePanning', value: false }, { op: 'pan', value: [ 20, 30 ] }
	] },
	{ name: 'map controls', controls: 'map', ops: [
		{ op: 'down', x: 400, y: 300 }, { op: 'move', x: 450, y: 340 }, { op: 'move', x: 300, y: 200 }, { op: 'up', x: 300, y: 200 },
		{ op: 'down', button: 2, x: 400, y: 300 }, { op: 'move', x: 420, y: 310 }, { op: 'up', x: 420, y: 310 },
		{ op: 'down', type: 'touch', id: 1, x: 300, y: 300 }, { op: 'move', type: 'touch', id: 1, x: 330, y: 290 },
		{ op: 'down', type: 'touch', id: 2, x: 500, y: 300 }, { op: 'move', type: 'touch', id: 2, x: 540, y: 340 }, { op: 'up', type: 'touch', id: 2, x: 540, y: 340 },
		{ op: 'up', type: 'touch', id: 1, x: 330, y: 290 },
		{ op: 'set', key: 'screenSpacePanning', value: true }, { op: 'down', x: 400, y: 300 }, { op: 'move', x: 380, y: 330 }, { op: 'up', x: 380, y: 330 }
	] },
	{ name: 'disabled', ops: [
		{ op: 'set', key: 'enabled', value: false }, { op: 'down', x: 400, y: 300 }, { op: 'move', x: 450, y: 300 }, { op: 'up', x: 450, y: 300 },
		{ op: 'set', key: 'enabled', value: true }, { op: 'set', key: 'enableRotate', value: false }, { op: 'down', x: 400, y: 300 }, { op: 'move', x: 450, y: 300 }, { op: 'up', x: 450, y: 300 },
		{ op: 'set', key: 'enableZoom', value: false }, { op: 'wheel', x: 400, y: 300, deltaY: - 100 }
	] }
];

const round = ( v ) => Object.is( v, - 0 ) ? 0 : v;

function snapshot( controls, events, result ) {

	const c = controls.object;
	return {
		position: c.position.toArray().map( round ),
		quaternion: c.quaternion.toArray().map( round ),
		target: controls.target.toArray().map( round ),
		zoom: c.zoom,
		polar: controls.getPolarAngle(),
		azimuth: controls.getAzimuthalAngle(),
		distance: controls.getDistance(),
		state: controls.state,
		events: events.splice( 0 ),
		result: typeof result === 'boolean' ? result : null
	};

}

const results = scenarios.map( ( scenario ) => {

	const cam = camera( scenario.camera, scenario.up );
	const Type = scenario.controls === 'map' ? MapControls : OrbitControls;
	const controls = new Type( cam, element() );
	const events = [];

	for ( const type of [ 'change', 'start', 'end' ] ) {

		controls.addEventListener( type, () => events.push( type ) );

	}

	const initial = snapshot( controls, events, null );
	const steps = scenario.ops.map( ( op ) => ( { op, ...snapshot( controls, events, apply( controls, op ) ) } ) );
	return { ...scenario, ops: undefined, initial, steps };

} );

const json = JSON.stringify( { reference: pin, width, height, scenarios: results }, null, '\t' ) + '\n';
writeFileSync( new URL( '../../../fixtures/values/orbit_controls.json', here ), json );
console.log( 'orbit_controls: ' + results.length + ' scenarios, ' + results.reduce( ( n, s ) => n + s.steps.length, 0 ) + ' steps' );
