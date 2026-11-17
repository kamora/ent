// Runs animation scenarios against the pinned three.js r187 source and writes the sampled scene state to
// fixtures/values/animation_scenarios.json, which packages/ent/test/animation/animation_scenarios_test.dart
// replays operation by operation.
//
// Usage: node tool/reference/js/animation_scenarios.mjs
//
// A scenario is data: tracks, clips and a list of operations. Every mixer operation is followed by a
// snapshot of the scene (three objects: root > child > leaf), each action's state and the events fired.

import { writeFileSync, mkdirSync } from 'node:fs';
import { execSync } from 'node:child_process';

const src = '../../../third_party/three.js/src/';
const here = new URL( '.', import.meta.url );
const git = ( args ) => execSync( 'git ' + args, { cwd: new URL( '../../../third_party/three.js/', here ) } ).toString().trim();
const pin = { tag: git( 'describe --tags --exact-match' ), commit: git( 'rev-parse HEAD' ) };

if ( pin.tag !== 'r187' ) {

	throw new Error( 'three.js checkout is ' + pin.tag + ', fixtures require r187' );

}

const { Object3D } = await import( src + 'core/Object3D.js' );
const { AnimationMixer } = await import( src + 'animation/AnimationMixer.js' );
const { AnimationClip } = await import( src + 'animation/AnimationClip.js' );
const { AnimationUtils } = await import( src + 'animation/AnimationUtils.js' );
const { AnimationObjectGroup } = await import( src + 'animation/AnimationObjectGroup.js' );
const { KeyframeTrack } = await import( src + 'animation/KeyframeTrack.js' );
const { VectorKeyframeTrack } = await import( src + 'animation/tracks/VectorKeyframeTrack.js' );
const { QuaternionKeyframeTrack } = await import( src + 'animation/tracks/QuaternionKeyframeTrack.js' );
const { NumberKeyframeTrack } = await import( src + 'animation/tracks/NumberKeyframeTrack.js' );
const { BooleanKeyframeTrack } = await import( src + 'animation/tracks/BooleanKeyframeTrack.js' );
const { StringKeyframeTrack } = await import( src + 'animation/tracks/StringKeyframeTrack.js' );
const { ColorKeyframeTrack } = await import( src + 'animation/tracks/ColorKeyframeTrack.js' );
const { Quaternion } = await import( src + 'math/Quaternion.js' );
const { Vector3 } = await import( src + 'math/Vector3.js' );
const { setConsoleFunction } = await import( src + 'utils.js' );

const warnings = [];
setConsoleFunction( ( type, message ) => warnings.push( type + ': ' + message.replaceAll( 'THREE.', 'ENT.' ) ) );

const C = {
	LoopOnce: 2200, LoopRepeat: 2201, LoopPingPong: 2202,
	Discrete: 2300, Linear: 2301, Smooth: 2302, Bezier: 2303,
	Normal: 2500, Additive: 2501
};

const TRACKS = { Vector: VectorKeyframeTrack, Quaternion: QuaternionKeyframeTrack, Number: NumberKeyframeTrack, Boolean: BooleanKeyframeTrack, String: StringKeyframeTrack, Color: ColorKeyframeTrack };

function number( v ) {

	if ( typeof v !== 'number' ) return v;
	if ( Number.isNaN( v ) ) return 'NaN';
	if ( v === Infinity ) return 'Infinity';
	if ( v === - Infinity ) return '-Infinity';
	return Object.is( v, - 0 ) ? '-0' : v;

}

const q = ( x, y, z, angle ) => new Quaternion().setFromAxisAngle( new Vector3( x, y, z ).normalize(), angle ).toArray();

function makeTrack( t ) {

	const Track = TRACKS[ t.type ];
	const track = t.type === 'Boolean' || t.type === 'String' ? new Track( t.name, t.times, t.values ) : new Track( t.name, t.times, t.values, t.interpolation );

	if ( t.settings ) {

		track.settings = { inTangents: new Float32Array( t.settings.inTangents ), outTangents: new Float32Array( t.settings.outTangents ) };

	}

	return track;

}

function objectState( o ) {

	return {
		position: o.position.toArray().map( number ),
		quaternion: o.quaternion.toArray().map( number ),
		rotation: [ o.rotation.x, o.rotation.y, o.rotation.z ].map( number ),
		scale: o.scale.toArray().map( number ),
		visible: o.visible,
		type: o.type
	};

}

function actionState( a ) {

	return {
		time: number( a.time ),
		timeScale: number( a.timeScale ),
		weight: number( a.weight ),
		effectiveWeight: number( a.getEffectiveWeight() ),
		effectiveTimeScale: number( a.getEffectiveTimeScale() ),
		enabled: a.enabled,
		paused: a.paused,
		loopCount: number( a._loopCount ),
		running: a.isRunning(),
		scheduled: a.isScheduled()
	};

}

function run( scenario ) {

	const root = new Object3D(); root.name = 'root';
	const child = new Object3D(); child.name = 'child';
	const leaf = new Object3D(); leaf.name = 'leaf';
	root.add( child ); child.add( leaf );
	const extra = [ new Object3D(), new Object3D(), new Object3D() ];
	extra.forEach( ( o, i ) => o.name = 'extra' + i );

	const objects = { root, child, leaf, extra0: extra[ 0 ], extra1: extra[ 1 ], extra2: extra[ 2 ] };
	const group = scenario.group ? new AnimationObjectGroup( ...extra ) : null;
	const mixer = new AnimationMixer( group ?? root );
	const tracks = {};
	const clips = {};
	const actions = {};
	const events = [];
	const snapshots = [];
	const throwsLog = [];

	for ( const t of scenario.tracks ) tracks[ t.id ] = makeTrack( t );
	for ( const c of scenario.clips ) clips[ c.id ] = new AnimationClip( c.name, c.duration ?? - 1, c.tracks.map( ( id ) => tracks[ id ] ), c.blendMode );

	const actionId = ( action ) => Object.keys( actions ).find( ( k ) => actions[ k ] === action ) ?? null;

	mixer.addEventListener( 'finished', ( e ) => events.push( [ 'finished', actionId( e.action ), e.direction ] ) );
	mixer.addEventListener( 'loop', ( e ) => events.push( [ 'loop', actionId( e.action ), e.loopDelta ] ) );

	const arg = ( a ) => a !== null && typeof a === 'object' ? ( 'action' in a ? actions[ a.action ] : a.int ) : a;

	function snapshot() {

		const state = { mixerTime: number( mixer.time ), objects: {}, actions: {}, events: events.splice( 0 ), stats: [ mixer.stats.actions.total, mixer.stats.actions.inUse, mixer.stats.bindings.total, mixer.stats.bindings.inUse, mixer.stats.controlInterpolants.total, mixer.stats.controlInterpolants.inUse ] };
		for ( const [ k, o ] of Object.entries( objects ) ) state.objects[ k ] = objectState( o );
		for ( const [ k, a ] of Object.entries( actions ) ) state.actions[ k ] = actionState( a );
		snapshots.push( state );

	}

	for ( const op of scenario.ops ) {

		const [ kind, ...rest ] = op;

		switch ( kind ) {

			case 'action': {

				const [ id, clipId, rootName, blendMode ] = rest;
				actions[ id ] = mixer.clipAction( clips[ clipId ], rootName ? objects[ rootName ] : undefined, blendMode );
				break;

			}

			case 'call': {

				const [ id, method, ...args ] = rest;
				actions[ id ][ method ]( ...args.map( arg ) );
				break;

			}

			case 'throws': {

				// Records whether the call throws: some upstream paths fail, and the port must fail the same way.
				const [ id, method, ...args ] = rest;
				let threw = false;

				try {

					actions[ id ][ method ]( ...args.map( arg ) );

				} catch ( e ) {

					threw = true;

				}

				throwsLog.push( threw );
				break;

			}

			case 'set': {

				const [ id, property, value ] = rest;
				actions[ id ][ property ] = value;
				break;

			}

			case 'mixer': {

				const [ method, ...args ] = rest;
				const mapped = method.startsWith( 'uncache' ) ? args.map( ( a ) => clips[ a ] ?? objects[ a ] ) : args;
				mixer[ method ]( ...mapped );
				snapshot();
				break;

			}

			case 'mixerSet':
				mixer[ rest[ 0 ] ] = rest[ 1 ];
				break;

			case 'clip':
				clips[ rest[ 0 ] ][ rest[ 1 ] ]( ...rest.slice( 2 ) );
				break;

			case 'additive': {

				const [ id, referenceFrame, referenceClipId, fps ] = rest;
				AnimationUtils.makeClipAdditive( clips[ id ], referenceFrame, referenceClipId ? clips[ referenceClipId ] : undefined, fps );
				break;

			}

			case 'subclip': {

				const [ id, sourceId, name, start, end, fps ] = rest;
				clips[ id ] = AnimationUtils.subclip( clips[ sourceId ], name, start, end, fps );
				break;

			}

			case 'group': {

				const [ method, ...names ] = rest;
				group[ method ]( ...names.map( ( n ) => objects[ n ] ) );
				break;

			}

			default:
				throw new Error( 'unknown op ' + kind );

		}

	}

	const clipData = {};

	for ( const [ k, c ] of Object.entries( clips ) ) {

		clipData[ k ] = { duration: number( c.duration ), blendMode: c.blendMode, tracks: c.tracks.map( ( t ) => ( { name: t.name, times: Array.from( t.times, number ), values: Array.from( t.values, number ), interpolation: t.getInterpolation() ?? null } ) ) };

	}

	return { ...scenario, snapshots, clipData, throws: throwsLog };

}

const steps = ( dt, n ) => Array.from( { length: n }, () => [ 'mixer', 'update', dt ] );

const scenarios = [
	{
		name: 'vector linear repeat',
		tracks: [ { id: 'p', type: 'Vector', name: '.position', times: [ 0, 1, 2.5 ], values: [ 0, 0, 0, 1, 2, 3, - 1, 0.5, 4 ] } ],
		clips: [ { id: 'c', name: 'move', tracks: [ 'p' ] } ],
		ops: [ [ 'action', 'a', 'c' ], [ 'call', 'a', 'play' ], ...steps( 0.3, 12 ) ]
	},
	{
		name: 'quaternion slerp ping-pong',
		tracks: [ { id: 'q', type: 'Quaternion', name: 'child.quaternion', times: [ 0, 0.5, 1.5 ], values: [ ...q( 0, 1, 0, 0 ), ...q( 1, 1, 0, 1.2 ), ...q( 0.3, - 1, 2, - 2.5 ) ] } ],
		clips: [ { id: 'c', name: 'spin', tracks: [ 'q' ] } ],
		ops: [ [ 'action', 'a', 'c' ], [ 'call', 'a', 'setLoop', { int: C.LoopPingPong }, 3 ], [ 'call', 'a', 'play' ], ...steps( 0.35, 16 ) ]
	},
	{
		name: 'smooth once clamped',
		tracks: [
			{ id: 'p', type: 'Vector', name: 'child.position', times: [ 0, 0.4, 1, 1.6 ], values: [ 0, 0, 0, 2, 1, 0, - 1, 3, 1, 0.5, 0.5, 2 ], interpolation: C.Smooth },
			{ id: 's', type: 'Vector', name: 'leaf.scale', times: [ 0, 0.8, 1.6 ], values: [ 1, 1, 1, 2, 0.5, 3, 1, 1, 1 ], interpolation: C.Smooth }
		],
		clips: [ { id: 'c', name: 'smooth', tracks: [ 'p', 's' ] } ],
		ops: [ [ 'action', 'a', 'c' ], [ 'call', 'a', 'setLoop', { int: C.LoopOnce } ], [ 'set', 'a', 'clampWhenFinished', true ], [ 'call', 'a', 'play' ], ...steps( 0.25, 9 ) ]
	},
	{
		name: 'smooth repeat endings',
		tracks: [ { id: 'p', type: 'Vector', name: '.position', times: [ 0, 0.5, 1, 2 ], values: [ 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 0, 0 ], interpolation: C.Smooth } ],
		clips: [ { id: 'c', name: 'loop', tracks: [ 'p' ] } ],
		ops: [ [ 'action', 'a', 'c' ], [ 'call', 'a', 'setLoop', { int: C.LoopRepeat }, 2 ], [ 'set', 'a', 'zeroSlopeAtStart', false ], [ 'call', 'a', 'play' ], ...steps( 0.3, 9 ) ]
	},
	{
		name: 'discrete, boolean and string tracks',
		tracks: [
			{ id: 'v', type: 'Boolean', name: '.visible', times: [ 0, 0.5, 1 ], values: [ true, false, true ] },
			{ id: 't', type: 'String', name: 'child.type', times: [ 0, 0.3, 0.9 ], values: [ 'A', 'B', 'C' ] },
			{ id: 'r', type: 'Number', name: '.rotation[x]', times: [ 0, 0.6, 1.2 ], values: [ 0, 1.5, - 0.5 ], interpolation: C.Discrete },
			{ id: 'y', type: 'Number', name: 'leaf.scale[y]', times: [ 0, 1.2 ], values: [ 1, 4 ] }
		],
		clips: [ { id: 'c', name: 'mixed', tracks: [ 'v', 't', 'r', 'y' ] } ],
		ops: [ [ 'action', 'a', 'c' ], [ 'call', 'a', 'play' ], ...steps( 0.2, 8 ), [ 'call', 'a', 'stop' ], [ 'mixer', 'update', 0.1 ] ]
	},
	{
		name: 'cross-fade with warp',
		tracks: [
			{ id: 'p1', type: 'Vector', name: '.position', times: [ 0, 1 ], values: [ 0, 0, 0, 4, 0, 0 ] },
			{ id: 'p2', type: 'Vector', name: '.position', times: [ 0, 2 ], values: [ 0, 2, 0, 0, - 2, 1 ] },
			{ id: 's2', type: 'Vector', name: '.scale', times: [ 0, 2 ], values: [ 1, 1, 1, 2, 2, 2 ] }
		],
		clips: [ { id: 'c1', name: 'walk', tracks: [ 'p1' ] }, { id: 'c2', name: 'run', tracks: [ 'p2', 's2' ] } ],
		ops: [ [ 'action', 'a', 'c1' ], [ 'action', 'b', 'c2' ], [ 'call', 'a', 'play' ], [ 'call', 'b', 'play' ], [ 'mixer', 'update', 0.25 ], [ 'call', 'a', 'crossFadeTo', { action: 'b' }, 1, true ], ...steps( 0.2, 8 ) ]
	},
	{
		name: 'fades, weights, warps and halts',
		tracks: [ { id: 'p', type: 'Vector', name: 'child.position', times: [ 0, 1, 2 ], values: [ 0, 0, 0, 1, 1, 1, 0, 2, 0 ] }, { id: 'n', type: 'Number', name: 'child.scale[x]', times: [ 0, 2 ], values: [ 1, 3 ] } ],
		clips: [ { id: 'c', name: 'c', tracks: [ 'p', 'n' ] }, { id: 'd', name: 'd', tracks: [ 'n' ] } ],
		ops: [
			[ 'action', 'a', 'c' ], [ 'action', 'b', 'd' ], [ 'call', 'a', 'setEffectiveWeight', 0.6 ], [ 'call', 'a', 'play' ], [ 'call', 'b', 'play' ], [ 'call', 'b', 'fadeIn', 0.7 ],
			...steps( 0.2, 3 ), [ 'call', 'a', 'warp', 1, 3, 0.5 ], ...steps( 0.2, 4 ), [ 'call', 'a', 'halt', 0.4 ], ...steps( 0.2, 3 ),
			[ 'call', 'b', 'setDuration', 4 ], [ 'call', 'b', 'fadeOut', 0.3 ], ...steps( 0.15, 4 ), [ 'call', 'a', 'syncWith', { action: 'b' } ], [ 'call', 'a', 'setEffectiveTimeScale', - 0.5 ], ...steps( 0.2, 3 )
		]
	},
	{
		name: 'additive layering',
		tracks: [
			{ id: 'base', type: 'Vector', name: '.position', times: [ 0, 1 ], values: [ 0, 0, 0, 2, 0, 0 ] },
			{ id: 'addp', type: 'Vector', name: '.position', times: [ 0, 0.5, 1 ], values: [ 1, 1, 1, 1, 3, 1, 1, 1, 1 ] },
			{ id: 'addq', type: 'Quaternion', name: '.quaternion', times: [ 0, 1 ], values: [ ...q( 0, 0, 1, 0.3 ), ...q( 0, 0, 1, 1.3 ) ] },
			{ id: 'addn', type: 'Number', name: '.scale[z]', times: [ 0, 1 ], values: [ 2, 5 ] }
		],
		clips: [ { id: 'base', name: 'base', tracks: [ 'base' ] }, { id: 'add', name: 'add', tracks: [ 'addp', 'addq', 'addn' ] } ],
		ops: [
			[ 'additive', 'add', 0, null, 30 ],
			[ 'action', 'a', 'base' ], [ 'action', 'b', 'add', null, C.Additive ], [ 'call', 'b', 'setEffectiveWeight', 0.7 ], [ 'call', 'a', 'play' ], [ 'call', 'b', 'play' ], ...steps( 0.3, 6 )
		]
	},
	{
		name: 'additive with reference clip and frame',
		tracks: [
			{ id: 'r', type: 'Vector', name: 'child.position', times: [ 0, 1 ], values: [ 1, 0, 0, 3, 0, 0 ] },
			{ id: 't', type: 'Vector', name: 'child.position', times: [ 0, 2 ], values: [ 5, 5, 5, 7, 5, 3 ] },
			{ id: 'tq', type: 'Quaternion', name: 'child.quaternion', times: [ 0, 2 ], values: [ ...q( 1, 0, 0, 0.5 ), ...q( 0, 1, 0, - 0.8 ) ] },
			{ id: 'rq', type: 'Quaternion', name: 'child.quaternion', times: [ 0, 1 ], values: [ ...q( 1, 0, 0, 0.1 ), ...q( 1, 0, 0, 0.9 ) ] }
		],
		clips: [ { id: 'ref', name: 'ref', tracks: [ 'r', 'rq' ] }, { id: 'tgt', name: 'tgt', tracks: [ 't', 'tq' ] } ],
		ops: [ [ 'additive', 'tgt', 15, 'ref', 30 ], [ 'action', 'b', 'tgt', null, C.Additive ], [ 'call', 'b', 'play' ], ...steps( 0.4, 6 ) ]
	},
	{
		name: 'startAt and reversed mixer time',
		tracks: [ { id: 'p', type: 'Vector', name: '.position', times: [ 0, 1 ], values: [ 0, 0, 0, 0, 0, 10 ] } ],
		clips: [ { id: 'c', name: 'c', tracks: [ 'p' ] } ],
		ops: [ [ 'action', 'a', 'c' ], [ 'call', 'a', 'startAt', 0.5 ], [ 'call', 'a', 'play' ], ...steps( 0.2, 5 ), [ 'mixerSet', 'timeScale', - 1 ], ...steps( 0.3, 5 ), [ 'mixerSet', 'timeScale', 2 ], ...steps( 0.1, 3 ) ]
	},
	{
		name: 'setTime, stopAllAction and uncaching',
		tracks: [ { id: 'p', type: 'Vector', name: 'leaf.position', times: [ 0, 1 ], values: [ 0, 0, 0, 1, 2, 3 ] }, { id: 'v', type: 'Boolean', name: 'leaf.visible', times: [ 0, 0.5 ], values: [ true, false ] } ],
		clips: [ { id: 'c', name: 'c', tracks: [ 'p', 'v' ] }, { id: 'd', name: 'd', tracks: [ 'p' ] } ],
		ops: [
			[ 'action', 'a', 'c' ], [ 'action', 'b', 'd' ], [ 'call', 'a', 'play' ], [ 'call', 'b', 'play' ], [ 'mixer', 'setTime', 0.75 ], [ 'mixer', 'update', 0.1 ],
			[ 'mixer', 'stopAllAction' ], [ 'mixer', 'uncacheClip', 'd' ], [ 'call', 'a', 'play' ], [ 'mixer', 'update', 0.3 ], [ 'call', 'a', 'stop' ],

			// uncacheClip leaves the removed mixers' cache indices set, so replaying the action fails upstream.
			[ 'mixer', 'uncacheClip', 'c' ], [ 'throws', 'a', 'play' ]
		]
	},
	{
		name: 'uncacheAction and uncacheRoot, then new actions',
		tracks: [ { id: 'p', type: 'Vector', name: 'leaf.position', times: [ 0, 1 ], values: [ 0, 0, 0, 1, 2, 3 ] }, { id: 'v', type: 'Boolean', name: 'leaf.visible', times: [ 0, 0.5 ], values: [ true, false ] } ],
		clips: [ { id: 'c', name: 'c', tracks: [ 'p', 'v' ] }, { id: 'd', name: 'd', tracks: [ 'v' ] } ],
		ops: [
			[ 'action', 'a', 'c' ], [ 'action', 'b', 'd' ], [ 'call', 'a', 'play' ], [ 'call', 'b', 'play' ], [ 'mixer', 'update', 0.6 ],
			[ 'call', 'b', 'stop' ], [ 'mixer', 'uncacheAction', 'd' ], [ 'mixer', 'update', 0.1 ], [ 'mixer', 'stopAllAction' ], [ 'mixer', 'uncacheRoot', 'root' ],
			[ 'action', 'a2', 'c' ], [ 'action', 'b2', 'd' ], [ 'call', 'b2', 'play' ], [ 'call', 'a2', 'play' ], [ 'mixer', 'update', 0.7 ]
		]
	},
	{
		name: 'local root and bezier',
		tracks: [
			{ id: 'b', type: 'Number', name: '.position[x]', times: [ 0, 1, 2 ], values: [ 0, 1, 0 ], interpolation: C.Bezier, settings: { inTangents: [ - 0.3, 0, 0.6, 1.4, 1.7, 0.2 ], outTangents: [ 0.3, 0.5, 1.4, 0.6, 2.3, 0 ] } },
			{ id: 'c', type: 'Color', name: '.scale', times: [ 0, 2 ], values: [ 0.1, 0.2, 0.3, 0.9, 0.8, 0.7 ] }
		],
		clips: [ { id: 'c', name: 'c', tracks: [ 'b', 'c' ] } ],
		ops: [ [ 'action', 'a', 'c', 'child' ], [ 'action', 'r', 'c' ], [ 'call', 'a', 'play' ], [ 'call', 'r', 'play' ], [ 'call', 'r', 'setEffectiveWeight', 0.5 ], ...steps( 0.25, 9 ) ]
	},
	{
		name: 'subclip, optimize and trim',
		tracks: [ { id: 'p', type: 'Vector', name: '.position', times: [ 0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6 ], values: [ 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 2, 1, 0, 2, 1, 0, 0, 0, 0 ] } ],
		clips: [ { id: 'c', name: 'long', tracks: [ 'p' ] } ],
		ops: [ [ 'subclip', 's', 'c', 'short', 3, 15, 30 ], [ 'clip', 'c', 'optimize' ], [ 'clip', 'c', 'trim' ], [ 'action', 'a', 's' ], [ 'call', 'a', 'play' ], ...steps( 0.07, 6 ) ]
	},
	{
		name: 'animation object group',
		group: true,
		tracks: [ { id: 'p', type: 'Vector', name: '.position', times: [ 0, 1 ], values: [ 0, 0, 0, 1, 1, 1 ] }, { id: 'q', type: 'Quaternion', name: '.quaternion', times: [ 0, 1 ], values: [ ...q( 0, 1, 0, 0 ), ...q( 0, 1, 0, 2 ) ] } ],
		clips: [ { id: 'c', name: 'c', tracks: [ 'p', 'q' ] } ],
		ops: [ [ 'action', 'a', 'c' ], [ 'call', 'a', 'play' ], ...steps( 0.25, 2 ), [ 'group', 'remove', 'extra1' ], ...steps( 0.25, 2 ), [ 'group', 'add', 'extra1' ], [ 'mixer', 'update', 0.1 ] ]
	}
];

const results = scenarios.map( ( s ) => { try { return run( s ); } catch ( e ) { console.error( "FAILED: " + s.name + ": " + e.message ); process.exit( 1 ); } } );

// Static helpers, checked as data.

const morph = [ 'Walk_001', 'Walk_002', 'Run_001', 'Run_002', 'Run_003', 'crdeath0059' ].map( ( name ) => ( { name } ) );
const clipToData = ( c ) => ( { name: c.name, duration: number( c.duration ), tracks: c.tracks.map( ( t ) => ( { name: t.name, type: t.ValueTypeName, times: Array.from( t.times, number ), values: Array.from( t.values, number ) } ) ) } );

const json = new AnimationClip( 'j', - 1, [
	new VectorKeyframeTrack( '.position', [ 0, 1 ], [ 1, 2, 3, 4, 5, 6 ], C.Smooth ),
	new StringKeyframeTrack( '.name', [ 0, 2 ], [ 'a', 'b' ] ),
	new NumberKeyframeTrack( '.opacity', [ 0, 3 ], [ 0, 1 ] )
] );
json.tracks[ 2 ].setInterpolation( C.Bezier );
json.tracks[ 2 ].settings = { inTangents: new Float32Array( [ - 1, 0, 2, 1 ] ), outTangents: new Float32Array( [ 1, 0, 4, 1 ] ) };
json.userData = { tag: 'x', n: 2.5 };
const jsonOut = AnimationClip.toJSON( json );
delete jsonOut.uuid;

const parsed = AnimationClip.parse( {
	name: 'p', fps: 10, uuid: 'fixed-uuid', userData: '{"a":1}',
	tracks: [
		{ name: '.position', type: 'vector3', times: [ 0, 10 ], values: [ 0, 0, 0, 1, 1, 1 ] },
		{ name: '.visible', type: 'boolean', keys: [ { time: 0, value: true }, { time: 5 }, { time: 10, value: false } ] },
		{ name: '.quaternion', type: 'quaternion', keys: [ { time: 0, value: [ 0, 0, 0, 1 ] }, { time: 20, value: [ 0, 1, 0, 0 ] } ], interpolation: C.Discrete },
		{ name: '.scale[x]', type: 'number', times: [ 0, 10 ], values: [ 1, 2 ], interpolation: C.Bezier, settings: { inTangents: [ 0, 1, 5, 2 ], outTangents: [ 5, 1, 10, 2 ] } }
	]
} );

const validation = [
	new NumberKeyframeTrack( 'a', [ 0, 1 ], [ 0, 1 ] ).validate(),
	new NumberKeyframeTrack( 'b', [ 1, 0 ], [ 0, 1 ] ).validate(),
	new NumberKeyframeTrack( 'c', [ 0, NaN ], [ 0, 1 ] ).validate(),
	new VectorKeyframeTrack( 'd', [ 0, 1 ], [ 0, 1, 2 ] ).validate(),
	new NumberKeyframeTrack( 'e', [ 0, 1 ], [ 0, NaN ] ).validate()
];

const interpolations = [
	new NumberKeyframeTrack( 'a', [ 0 ], [ 0 ] ).getInterpolation(),
	new QuaternionKeyframeTrack( 'b', [ 0 ], [ 0, 0, 0, 1 ], C.Smooth ).getInterpolation(),
	new StringKeyframeTrack( 'c', [ 0 ], [ 'x' ] ).setInterpolation( C.Linear ).getInterpolation(),
	new BooleanKeyframeTrack( 'd', [ 0 ], [ true ] ).setInterpolation( C.Bezier ).getInterpolation(),
	new NumberKeyframeTrack( 'e', [ 0 ], [ 0 ] ).setInterpolation( 9999 ).getInterpolation()
];

const trimmed = [ [ 0.5, 2.5 ], [ 3, 4 ], [ - 2, - 1 ], [ 1, 1 ] ].map( ( [ a, b ] ) => {

	const t = new VectorKeyframeTrack( 't', [ 0, 1, 2, 3 ], [ 0, 0, 1, 1, 2, 2, 3, 3 ] ).trim( a, b );
	return [ Array.from( t.times, number ), Array.from( t.values, number ) ];

} );

const flatTimes = [], flatValues = [];
AnimationUtils.flattenJSON( [ { time: 0 }, { time: 1, value: new Vector3( 1, 2, 3 ) }, { time: 2 }, { time: 3, value: new Vector3( 4, 5, 6 ) } ], flatTimes, flatValues, 'value' );

const order = AnimationUtils.getKeyframeOrder( [ 3, 1, 2, 1, 0 ] );

const data = {
	morphSequence: clipToData( AnimationClip.CreateFromMorphTargetSequence( 'seq', morph.slice( 0, 3 ), 10 ) ),
	morphSequenceNoLoop: clipToData( AnimationClip.CreateFromMorphTargetSequence( 'seq', morph.slice( 0, 3 ), 10, true ) ),
	morphClips: AnimationClip.CreateClipsFromMorphTargetSequences( morph, 24 ).map( clipToData ),
	clipJSON: jsonOut,
	parsed: { ...clipToData( parsed ), uuid: parsed.uuid, userData: parsed.userData, interpolations: parsed.tracks.map( ( t ) => t.getInterpolation() ), tangents: Array.from( parsed.tracks[ 3 ].settings.inTangents, number ) },
	validation,
	interpolations,
	trimmed,
	flatten: [ flatTimes, flatValues ],
	order,
	sorted: Array.from( AnimationUtils.sortedArray( new Float32Array( [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ] ), 2, order ), number ),
	warnings: warnings.splice( 0 )
};

mkdirSync( new URL( '../../../fixtures/values/', here ), { recursive: true } );
writeFileSync( new URL( '../../../fixtures/values/animation_scenarios.json', here ), JSON.stringify( { reference: pin, scenarios: results, data }, null, '\t' ) + '\n' );
console.log( results.length + ' scenarios, ' + results.reduce( ( n, r ) => n + r.snapshots.length, 0 ) + ' snapshots' );
