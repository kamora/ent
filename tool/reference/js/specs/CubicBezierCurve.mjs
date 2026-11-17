// Reference cases for src/extras/curves/CubicBezierCurve.js; the shared method list is in types/curves.mjs.
// computeFrenetFrames and toJSON return plain objects, which the fixture encoding cannot carry; the Dart unit
// tests cover them.

import { curveSpec } from '../types/curves.mjs';

export default curveSpec( 'CubicBezierCurve', 'Vector2' );
