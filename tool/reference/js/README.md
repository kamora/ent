# Reference fixtures

Expected values for the Dart port come from the pinned three.js r187 source running in Node, never from the
Dart code itself.

```
tool/fetch_upstream.sh                              # once: the pinned checkout in third_party/three.js
node tool/reference/js/generate.mjs        # all specs
node tool/reference/js/generate.mjs Box3   # one spec
(cd packages/ent && dart test test/fixtures_test.dart)
```

`generate.mjs` refuses to run unless `third_party/three.js` is at tag `r187`; every fixture records the tag
and commit.

## Layout

- `specs/<Name>.mjs`: which methods to call and how to generate their inputs.
- `types/*.mjs`: value types (`Vector3`, `Box3`, …): how to generate one and the state list recorded for it.
  The Dart codecs in `packages/ent/test/support/codecs/` read the same layouts.
- `lib/rng.mjs`: a seeded generator independent of three.js; each method is seeded from
  `"<spec>.<method>.<label>"`, so adding a method does not change the others' cases.
- `lib/codec.mjs`: the JSON encoding.
- `fixtures/specs/<Name>.json`: output, prettified with tabs.
- `gltf_files.mjs`: writes the hand-built glTF test assets in `fixtures/gltf/` (`scene.gltf`, the same asset
  as `scene.glb`, `external.gltf` with `external.bin`, `render.gltf`); deterministic, no downloads.
  `gltf_loader.mjs` loads them with r187's `GLTFLoader` in Node and writes `fixtures/values/gltf_loader.json`, which
  `packages/ent/test/loaders/gltf_loader_test.dart` compares with the Dart port.
- `effect_composer.mjs`: runs r187's `EffectComposer`, `RenderPass`, `ShaderPass`, `OutputPass`, `FXAAPass` and
  `UnrealBloomPass` with a recording renderer and writes each scenario's call log to
  `fixtures/values/effect_composer.json`, which `packages/ent/test/postprocessing/effect_composer_test.dart`
  compares line for line (numbers within 1e-12; `bloom` logs the pass's targets, its materials' defines and a hash of
  their GLSL, and every uniform; the test writes each effect material as the reference's shader material and leaves
  out the hashes, and the port's final blend is substituted for r187's, exception E-POSTPROCESSING).
- `hdr_files.mjs`: writes the RGBE test images in `fixtures/hdr/` (`sky.hdr`, run-length encoded, and
  `flat.hdr`); deterministic, no downloads, no three.js. `hdr_loader.mjs` parses them with r187's `HDRLoader` in
  Node (HalfFloatType and FloatType) and writes `fixtures/values/hdr_loader.json`, which
  `packages/ent/test/loaders/hdr_loader_test.dart` compares exactly.
- `worm_glb.mjs`: writes `examples/worm/assets/worm.glb`, the example viewer's model (a textured tube skinned
  to 5 bones with a looping `wiggle` clip); deterministic, no downloads, no three.js.

## Spec format

```js
export default {
	name: 'Vector3',        // fixture file and Dart class name
	type: 'Vector3',        // receiver type from types/ (instance methods)
	// static: MathUtils,   // or: call methods on this object; Dart calls static members of class `name`
	// fixture: 'QuaternionStatic', // output file name when a class has a second (static) spec
	cases: 10,              // random cases per method (default 10)
	methods: [
		{ name: 'add', args: [ 'Vector3' ] },
		{ name: 'setComponent', args: [ ( r ) => r.int( 0, 2 ), 'num' ] },
		{ name: 'clampLength', args: [ 'num', 'num' ], edge: [ () => ( { self: new Vector3(), args: [ 1, 2 ] } ) ] },
		{ name: 'pingpong', label: 'default length', args: [ 'num' ] },
		{ name: 'getNormal', dart: 'getNormalStatic', args: [ 'Vector3', 'Vector3', 'Vector3', 'Vector3' ] } // exception E-STATIC
	]
};
```

`args` may also be one function `( r ) => [ ... ]` returning the whole argument list, for arguments that
depend on each other (a point in a triangle's plane). `dart` names the Dart member when the language forces
another name (E-STATIC).

Argument specs: a type name from `types/`, `'num'` (mostly [-10, 10), sometimes 0, ±1, 0.5, 2), `'unit'`
([0, 1)), `'bool'`, `'int'` ([0, 10]), or `( r ) => value`. Use `r.int( min, max )` for arguments that are
integers in Dart (indices, offsets, hex colors): plain JS numbers arrive in Dart as `double`.

## Case format

Each case records the receiver and arguments before the call (`self`, `args`) and after it (`out.self`,
`out.args`), and the return value: `{ "this": true }` when the method returned its receiver,
`{ "arg": i }` when it returned argument `i` (the `target` pattern), `{ "undefined": true }`, or an encoded
value. A call that throws records `{ "throws": message }`; Dart must throw too.

Numbers: JSON numbers, or `"NaN"`, `"Infinity"`, `"-Infinity"`, `"-0"`. Integers passed as `int`:
`{ "int": n }`. Arrays: `{ "array": [...] }`; typed arrays: `{ "typed": "Float32Array", "values": [...] }`;
value types: `{ "type": "Vector3", "value": [...] }`.

## Comparison

The Dart side (`test/support/fixtures.dart`) calls each method by its upstream name through `dart:mirrors`,
so a renamed or missing member fails like a wrong result. Numbers must match exactly or within
`1e-9 · max(1, |a|, |b|)`; the run prints how many matched each way. Identity is checked for `this` and
`arg` returns, which also verifies chaining.
