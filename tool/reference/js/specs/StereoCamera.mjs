// Reference cases for src/cameras/StereoCamera.js: update() from random perspective cameras, on stereo
// cameras that are fresh or already updated once. The cache-hit path reuses eye offsets held in
// module-level matrices shared by all stereo cameras, which a replayed case cannot reproduce; the Dart unit
// tests cover it with values printed from r187.

export default {
	name: 'StereoCamera',
	type: 'StereoCamera',
	cases: 30,
	methods: [
		{ name: 'update', args: [ 'PerspectiveCamera' ] }
	]
};
