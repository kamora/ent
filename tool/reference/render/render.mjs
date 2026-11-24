// Draws the reference scenes with the pinned three.js r187 in the installed headless Chrome (puppeteer-core
// from tool/) and writes, per scene, fixtures/rendering/reference/<name>.png (the drawing buffer's raw bytes) and
// <name>.json (scene, camera, clear color, size, renderer properties, a render target pass, a CubeCamera pass and
// the animation times), plus meta.json with the browser, GPU and three.js pin. An animated scene has one
// <name>@<time>.png per time in place of <name>.png.
//
// Usage: node tool/reference/render/render.mjs [name ...]
// Chrome: $CHROME, or /Applications/Google Chrome.app.
//
// Another device's Chrome, to compare GPUs: $REMOTE is the DevTools URL of a running Chrome (an Android phone's, by
// `adb forward tcp:9222 localabstract:chrome_devtools_remote`, then REMOTE=http://127.0.0.1:9222), which loads the
// page from $PORT on its own localhost (`adb reverse tcp:$PORT tcp:$PORT`); the frames go to $OUT, never to the
// references, and meta.json records that browser and GPU.

import { createServer } from 'node:http';
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { execSync } from 'node:child_process';
import { deflateSync } from 'node:zlib';
import { createRequire } from 'node:module';
import { extname, normalize, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = fileURLToPath( new URL( '../../../', import.meta.url ) );
const remote = process.env.REMOTE;
const out = process.env.OUT ?? join( root, 'fixtures/rendering/reference' );

if ( remote && ! process.env.OUT ) {

	throw new Error( 'REMOTE needs OUT: a remote device\'s frames are not the references.' );

}
const git = ( args ) => execSync( 'git ' + args, { cwd: join( root, 'third_party/three.js' ) } ).toString().trim();
const pin = { tag: git( 'describe --tags --exact-match' ), commit: git( 'rev-parse HEAD' ) };

if ( pin.tag !== 'r187' ) {

	throw new Error( 'three.js checkout is ' + pin.tag + ', reference frames require r187' );

}

// An 8-bit RGBA PNG of raw bytes (no color-space chunks): decoded as straight alpha, it returns the bytes
// unchanged, premultiplied or not.
function png( rgba, size ) {

	const crcTable = Array.from( { length: 256 }, ( _, n ) => {

		let c = n;

		for ( let k = 0; k < 8; k ++ ) {

			c = c & 1 ? 0xedb88320 ^ ( c >>> 1 ) : c >>> 1;

		}

		return c >>> 0;

	} );
	const crc = ( bytes ) => {

		let c = 0xffffffff;

		for ( const b of bytes ) {

			c = crcTable[ ( c ^ b ) & 255 ] ^ ( c >>> 8 );

		}

		return ( c ^ 0xffffffff ) >>> 0;

	};
	const chunk = ( type, data ) => {

		const body = Buffer.concat( [ Buffer.from( type, 'ascii' ), data ] );
		const length = Buffer.alloc( 4 );
		const check = Buffer.alloc( 4 );
		length.writeUInt32BE( data.length );
		check.writeUInt32BE( crc( body ) );

		return Buffer.concat( [ length, body, check ] );

	};
	const header = Buffer.alloc( 13 );
	header.writeUInt32BE( size, 0 );
	header.writeUInt32BE( size, 4 );
	header.set( [ 8, 6, 0, 0, 0 ], 8 );

	const rows = [];

	for ( let y = 0; y < size; y ++ ) {

		rows.push( Buffer.from( [ 0 ] ), rgba.subarray( y * size * 4, ( y + 1 ) * size * 4 ) );

	}

	return Buffer.concat( [
		Buffer.from( [ 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a ] ),
		chunk( 'IHDR', header ),
		chunk( 'IDAT', deflateSync( Buffer.concat( rows ) ) ),
		chunk( 'IEND', Buffer.alloc( 0 ) ),
	] );

}

const puppeteer = ( await import( pathToFileURL( createRequire( join( root, 'tool/package.json' ) ).resolve( 'puppeteer-core' ) ) ) ).default;
const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json' };

// Serves the repository read-only on localhost, so the page can import three.js's ES modules.
const server = createServer( ( request, response ) => {

	if ( request.url === '/favicon.ico' ) {

		response.writeHead( 204 ).end();
		return;

	}

	const path = normalize( join( root, decodeURIComponent( new URL( request.url, 'http://x' ).pathname ) ) );

	if ( ! path.startsWith( root ) || ! existsSync( path ) ) {

		response.writeHead( 404 ).end();
		return;

	}

	response.writeHead( 200, { 'content-type': types[ extname( path ) ] ?? 'application/octet-stream' } );
	response.end( readFileSync( path ) );

} );

await new Promise( ( resolve ) => server.listen( Number( process.env.PORT ?? 0 ), '127.0.0.1', resolve ) );

const browser = remote ? await puppeteer.connect( { browserURL: remote, defaultViewport: null } ) : await puppeteer.launch( {
	executablePath: process.env.CHROME ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
	headless: true,
	args: [ '--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist' ],
} );

try {

	const page = await browser.newPage();
	const errors = [];
	page.on( 'pageerror', ( error ) => errors.push( error.message ) );
	page.on( 'console', ( message ) => {

		if ( message.type() === 'error' || message.type() === 'warning' ) {

			errors.push( message.text() );

		}

	} );

	await page.goto( `http://127.0.0.1:${ server.address().port }/tool/reference/render/page.html` );
	await page.waitForFunction( 'window.ready === true || undefined', { timeout: 30000 } ).catch( () => {

		throw new Error( 'page did not load: ' + errors.join( '; ' ) );

	} );

	const all = await page.evaluate( () => window.sceneNames );
	const names = process.argv.length > 2 ? process.argv.slice( 2 ) : all;
	let gpu;
	mkdirSync( out, { recursive: true } );

	for ( const name of names ) {

		if ( ! all.includes( name ) ) {

			throw new Error( 'unknown scene ' + name );

		}

		const result = await page.evaluate( ( n ) => window.renderScene( n ), name );

		if ( errors.length > 0 ) {

			throw new Error( name + ': ' + errors.join( '; ' ) );

		}

		gpu = result.gpu;

		// An animated scene has a frame per time, <name>@<time>.png, and no <name>.png.
		if ( result.frames ) {

			result.frames.forEach( ( frame, i ) => {

				writeFileSync( join( out, name + '@' + result.animate.times[ i ] + '.png' ), png( Buffer.from( frame, 'base64' ), result.size ) );

			} );

		} else {

			writeFileSync( join( out, name + '.png' ), png( Buffer.from( result.pixels, 'base64' ), result.size ) );

		}

		writeFileSync(
			join( out, name + '.json' ),
			JSON.stringify( { scene: result.scene, camera: result.camera, clear: result.clear, size: result.size, renderer: result.renderer, distance: result.distance, edges: result.edges, target: result.target, cube: result.cube, animate: result.animate, gltf: result.gltf, hdr: result.hdr, composer: result.composer, overlay: result.overlay, views: result.views, antialias: result.antialias || undefined }, null, '\t' ) + '\n'
		);
		console.log( name );

	}

	if ( remote ) {

		await page.close();

	}

	const meta = {
		three: pin,
		browser: await browser.version(),
		gpu,
		renderer: 'WebGLRenderer, antialias false unless the scene sets it, pixel ratio 1, preserveDrawingBuffer true; PNG of readPixels bytes',
		os: remote ? await browser.userAgent() : execSync( 'sw_vers -productVersion' ).toString().trim(),
	};
	writeFileSync( join( out, 'meta.json' ), JSON.stringify( meta, null, '\t' ) + '\n' );
	console.log( JSON.stringify( meta ) );

} finally {

	if ( remote ) {

		await browser.disconnect();

	} else {

		await browser.close();

	}

	server.close();

}
