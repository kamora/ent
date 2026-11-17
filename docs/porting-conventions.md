# Porting conventions

The rules every module port follows. Upstream is three.js **r187** (`docs/upstream.md`); its source in
`third_party/three.js/src/` is the specification. Deviations a user can observe go to
`docs/compatibility-exceptions.md`, with a test.

## Package shape

- `packages/ent` is one Dart library, `lib/ent.dart`, made of `part` files under `lib/src/`.
  Upstream `_members` (`Quaternion._onChange`, `Euler._order`, ...) are public by convention in JS and used
  across classes (`Object3D` calls `quaternion._onChange`). One library keeps them reachable inside the port
  with the same names; they stay private to users of the package (exception `E-PRIVATE`).
- File mapping: `src/math/Vector3.js` → `lib/src/math/vector3.dart`;
  `src/math/interpolants/CubicInterpolant.js` → `lib/src/math/interpolants/cubic_interpolant.dart`.
- No Flutter, no `dart:io`, no `dart:html`/`package:web` in this package. `dart:math` and `dart:typed_data` only.

## Formatting

- `tool/format.sh <paths>`: `dart format` at page width 120, keeping its two-space indentation (studio canon 006), then
  the empty line above multi-line comments (canon 003).
- Curly braces on every control-flow body, K&R, multi-line, even for one statement (canon 001/002).
  `switch` cases with a single `return` stay on one line, as upstream writes them.
- A multi-line comment (including two or more `///` lines) has an empty line above it (canon 003).
- Port the upstream JSDoc description as `///` doc comments: the prose, not the `@param {type}` tags; mention
  defaults and units where the JSDoc does.

## Names and members

- Same class, method, property and constant names as upstream, same parameter order.
- `this.prototype.isVector3 = true` → `bool get isVector3 => true;`. Subclasses inherit them as upstream does.
- Instance properties keep their names and mutability. JS getter/setter pairs stay getter/setter pairs.
- Module-level `const _v = new Vector3()` scratch objects become library-private top-level finals with a
  per-file prefix: `final _vector3V1 = Vector3();` (one library: names must not collide between files).
- Module-level helper functions: library-private, prefixed by the file's class (`_box3SatForAxes`).
- Static class fields/methods → Dart `static`.
- Object-literal namespaces (`MathUtils`, `ColorManagement`) → `abstract final class` with `static` members,
  or a class instance where upstream mutates the object at runtime (`ColorManagement.workingColorSpace`).

## Types and numbers

- JS `number` → `double` for values, `int` for indices, offsets, counts, hex colors and bit masks.
  Parameters typed `double` accept integer literals (`v.set(1, 2)`), not `int` variables (exception `E-NUM`).
- `Math.round(x)` → `_jsRound(x)` (JS rounds .5 toward +∞; Dart `round()` away from zero).
- `a % b` → `a.remainder(b)` (JS `%` keeps the dividend's sign; Dart `%` is always non-negative).
- `Math.floor/ceil/trunc` → `floorToDouble()/ceilToDouble()/truncateToDouble()` (keep `-0.0` and doubles).
- `Math.min/max` → `math.min/max` from `dart:math` (both propagate NaN and order ±0 like JS).
- `Math.sign` → `x.sign`. `Math.pow` → `math.pow(a, b).toDouble()`.
- Bit operations on JS numbers (`| 0`, `>>>`, `Math.imul`) → `_jsToInt32`, `_jsToUint32`, `_jsImul`
  (`lib/src/js.dart`); they behave the same on the VM and on the web.
- `===` on numbers → `==` (NaN unequal, `0 == -0`: identical to JS).
- `x || y` on numbers means "y when x is 0 or NaN": write it out (`x == 0 || x.isNaN ? y : x`); never `??`.
- `undefined` defaults: `function f( a, b = 1 )` → `f(double a, [double b = 1])`. An argument JS tests with
  `!== undefined` → nullable optional (`[double? z]`).
- Union parameters (`makeTranslation( x: Vector3|number, y, z )`) → `Object` and a type test, keeping the call
  shape; document the union in the doc comment.
- Plain JS arrays of numbers (`Matrix4.elements`) → `List<double>`, created as `Float64List` (fixed length,
  same values as a JS number array). Typed arrays map to the matching `dart:typed_data` list.
- `toArray( array = [], offset = 0 )` → `List<double> toArray([List<double>? array, int offset = 0])`; writes
  through `_jsArraySet`, which grows growable lists and ignores writes past the end of fixed-length lists
  like a JS typed array does. `fromArray( array, offset = 0 )` → `fromArray(List<num> array, [int offset = 0])`.
- `*[ Symbol.iterator ]()` → `Iterable<double> get iterable sync* { ... }` (exception `E-ITER`).
- `clone()` → `return Vector3(x, y, z);` typed as the class. JS `new this.constructor()` follows subclasses;
  a Dart subclass overrides `clone()` (exception `E-CLONE`).
- `throw new Error( msg )` → `throw EntError(msg)` (`lib/src/js.dart`), same message text.
- `warn(...)`, `error(...)`, `warnOnce(...)`, `log(...)` → the functions in `lib/src/utils.dart`, same text.
- Callbacks (`_onChangeCallback`) → `void Function()` fields.
- A method whose duck-typed parameters need a class that is not ported is left out until the class exists. Never
  stub it.

## No placeholders

No method that returns a default, throws `UnimplementedError`, or is missing without a `pending` row.

## Tests

Each module gets two kinds of tests in `packages/ent/test/`:

1. `math/<name>_test.dart`: the upstream QUnit tests in `third_party/three.js/test/unit/src/math/<Name>.tests.js`
   ported one-to-one (same test names; `QUnit.todo` stubs ported as nothing but listed), plus Dart-specific
   edge cases (exceptions log).
2. Reference fixtures: a spec in `tool/reference/js/specs/<Name>.mjs` drives the pinned three.js
   source in Node to write `fixtures/specs/<Name>.json`; the Dart test
   `test/fixtures_test.dart` replays every case through `dart:mirrors` (call by upstream method name) and
   compares receiver state, argument state and return value. See `tool/reference/js/README.md`.

Tolerance for fixture numbers: exact match first; otherwise `|a − b| ≤ 1e-9 · max(1, |a|, |b|)`. V8 and the
Dart VM use different `libm` implementations (`sin`, `acos`, `exp`, `pow` can differ in the last ulp), and
chained operations carry that difference. Exact and tolerance matches are counted separately in the report.

## Commands

```
tool/format.sh packages
(cd packages/ent && dart analyze --fatal-infos && dart test)
node tool/reference/js/generate.mjs [Name ...]
```
