// Runs the pinned three.js source in Node and writes reference fixtures for the Dart port.
//
// Usage: node tool/reference/js/generate.mjs [SpecName ...]
// Specs live in specs/<Name>.mjs, value types in types/*.mjs; output goes to fixtures/specs/<Name>.json.

import { readdirSync, writeFileSync } from 'node:fs';
import { execSync } from 'node:child_process';
import { createEncoder, unwrap } from './lib/codec.mjs';
import { createRng } from './lib/rng.mjs';

const here = new URL( '.', import.meta.url );
const upstream = new URL( '../../../third_party/three.js/', here );
const git = ( args ) => execSync( 'git ' + args, { cwd: upstream } ).toString().trim();
const pin = { tag: git( 'describe --tags --exact-match' ), commit: git( 'rev-parse HEAD' ) };

if ( pin.tag !== 'r187' ) {

	throw new Error( 'three.js checkout is ' + pin.tag + ', fixtures require r187' );

}

const types = {};

for ( const file of readdirSync( new URL( 'types/', here ) ).filter( ( f ) => f.endsWith( '.mjs' ) ).sort() ) {

	Object.assign( types, ( await import( new URL( 'types/' + file, here ) ) ).default );

}

const encode = createEncoder( types );

function hash( text ) {

	let h = 2166136261;

	for ( const c of text ) {

		h = Math.imul( h ^ c.charCodeAt( 0 ), 16777619 );

	}

	return h >>> 0;

}

function generate( spec, r ) {

	if ( typeof spec === 'function' ) {

		return spec( r );

	}

	switch ( spec ) {

		case 'num': return r.num();
		case 'unit': return r.unit();
		case 'bool': return r.bool();
		case 'int': return r.int( 0, 10 );

	}

	const type = types[ spec ];

	if ( ! type ) {

		throw new Error( 'fixture: unknown argument spec ' + spec );

	}

	return type.gen( r );

}

function returned( value, self, args ) {

	if ( value === undefined ) {

		return { undefined: true };

	}

	if ( value !== null && typeof value === 'object' ) {

		if ( value === self ) {

			return { this: true };

		}

		const index = args.indexOf( value );

		if ( index !== - 1 ) {

			return { arg: index };

		}

	}

	return encode( value );

}

function run( spec, method, input ) {

	const self = input.self;
	const args = input.args;
	const entry = { self: self === undefined ? null : encode( self ), args: args.map( encode ) };
	const values = args.map( unwrap );

	try {

		const target = spec.static ?? self;
		const result = target[ method.name ]( ...values );
		entry.out = { self: self === undefined ? null : encode( self ), args: args.map( encode ), return: returned( result, self, values ) };

	} catch ( e ) {

		entry.out = { throws: String( e.message ).replaceAll( 'THREE.', 'ENT.' ) };

	}

	return entry;

}

async function build( name ) {

	const spec = ( await import( new URL( 'specs/' + name + '.mjs', here ) ) ).default;
	const methods = spec.methods.map( ( method ) => {

		const r = createRng( hash( spec.name + '.' + method.name + '.' + ( method.label ?? '' ) ) );
		const count = method.cases ?? spec.cases ?? 10;
		const cases = [];

		for ( let i = 0; i < count; i ++ ) {

			const self = spec.static ? undefined : ( method.self ?? spec.self ?? ( ( rr ) => generate( spec.type, rr ) ) )( r );
			// `args` is a list of per-argument specs, or one function returning correlated arguments.
			const args = typeof method.args === 'function' ? method.args( r ) : ( method.args ?? [] ).map( ( a ) => generate( a, r ) );
			cases.push( run( spec, method, { self, args } ) );

		}

		for ( const edge of method.edge ?? [] ) {

			const input = edge();
			cases.push( run( spec, method, { self: spec.static ? undefined : input.self, args: input.args ?? [] } ) );

		}

		// `dart` names the Dart member when the language forces another name (docs/compatibility-exceptions.md).
		return { name: method.name, dart: method.dart ?? null, label: method.label ?? null, cases };

	} );

	const fixture = { reference: pin, name: spec.name, static: Boolean( spec.static ), methods };
	// `fixture` names the output file when one class has two specs (instance and static members).
	writeFileSync( new URL( '../../../fixtures/specs/' + ( spec.fixture ?? spec.name ) + '.json', here ), JSON.stringify( fixture, null, '\t' ) + '\n' );

	return [ spec.name, methods.length, methods.reduce( ( n, m ) => n + m.cases.length, 0 ) ];

}

const names = process.argv.length > 2 ? process.argv.slice( 2 ) : readdirSync( new URL( 'specs/', here ) ).filter( ( f ) => f.endsWith( '.mjs' ) ).map( ( f ) => f.slice( 0, - 4 ) ).sort();

for ( const name of names ) {

	const [ spec, methods, cases ] = await build( name );
	console.log( spec + ': ' + methods + ' methods, ' + cases + ' cases' );

}
