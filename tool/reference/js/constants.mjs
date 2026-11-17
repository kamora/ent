// Writes fixtures/values/constants.json: every export of the pinned src/constants.js with its value, for
// packages/ent/test/constants_test.dart.
//
// Usage: node tool/reference/js/constants.mjs

import { writeFileSync } from 'node:fs';
import * as Constants from '../../../third_party/three.js/src/constants.js';

const values = Object.fromEntries( Object.keys( Constants ).sort().map( ( name ) => [ name, Constants[ name ] ] ) );

writeFileSync( new URL( '../../../fixtures/values/constants.json', import.meta.url ), JSON.stringify( { reference: 'r187', constants: values }, null, '\t' ) + '\n' );
console.log( Object.keys( values ).length + ' constants' );
