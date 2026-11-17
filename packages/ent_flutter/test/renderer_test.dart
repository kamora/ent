// Pixel-level checks of FlutterGpuRenderer, rendered offscreen by Impeller under `flutter test --enable-impeller
// --enable-flutter-gpu`. Expected colors are derived from the reference's shaders (sRGB output encoding for
// MeshBasicMaterial, packNormalToRGB for MeshNormalMaterial); tolerance: 2/255 per channel.

// flutter_tester builds a Metal pipeline for each new material state in up to ~16 s (an app does it in a few
// hundred milliseconds; docs/flutter-gpu.md, Pipeline compile cost), so tests meeting several new states can
// take longer than package:test's default 30 s. The slowest set their own timeouts, 2.5 to 3 times their time
// alone (2026-11-07: all maps 94 s, skinned or morphed 125 s, compile 240 s), for the full suite runs them
// beside the parity scenes.
@Timeout(Duration(minutes: 2))
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:flutter_test/flutter_test.dart';
import 'package:ent_flutter/ent_flutter.dart';
import 'package:ent_flutter/src/gpu/bundles.dart';
import 'package:ent_flutter/src/gpu/programs.dart';

const int tolerance = 2;

class Frame {
  Frame(this.width, this.height, this.rgba);

  final int width;

  final int height;

  final ByteData rgba;

  List<int> pixel(int x, int y) {
    final i = (y * width + x) * 4;
    return [rgba.getUint8(i), rgba.getUint8(i + 1), rgba.getUint8(i + 2), rgba.getUint8(i + 3)];
  }
}

Future<Frame> frame(FlutterGpuRenderer renderer, Object3D scene, Camera camera) async {
  final image = renderer.render(scene, camera);
  final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return Frame(image.width, image.height, rgba!);
}

Matcher rgb(int r, int g, int b) {
  return predicate<List<int>>(
    (p) => (p[0] - r).abs() <= tolerance && (p[1] - g).abs() <= tolerance && (p[2] - b).abs() <= tolerance,
    'rgb($r, $g, $b) ± $tolerance',
  );
}

// A triangle in the z = 0 plane: (-0.5, -0.5), (0.5, -0.5), (0, 0.5); counter-clockwise unless [clockwise].
BufferGeometry triangle({bool clockwise = false}) {
  final positions = clockwise
      ? [-0.5, -0.5, 0.0, 0.0, 0.5, 0.0, 0.5, -0.5, 0.0]
      : [-0.5, -0.5, 0.0, 0.5, -0.5, 0.0, 0.0, 0.5, 0.0];
  return BufferGeometry()..setAttribute('position', Float32BufferAttribute(positions, 3));
}

// Looks down -z at the [-1, 1] square: pixel (x, y) of a 64×64 frame covers x/32 - 1, 1 - y/32.
OrthographicCamera ortho() => OrthographicCamera(-1, 1, 1, -1, 0.1, 10)..position.set(0, 0, 5);

// An sRGB CubeTexture of 4 × 4 DataTexture faces of one color, or with [perFace] one color per face (six rgb
// triples in [colors], +X first).
CubeTexture cube(List<int> colors, {bool perFace = false}) {
  DataTexture face(int i) {
    final rgb = perFace ? colors.sublist(i * 3, i * 3 + 3) : colors;
    return DataTexture(
      Uint8List.fromList([
        for (var t = 0; t < 16; t++) ...[...rgb, 255],
      ]),
      4,
      4,
    );
  }

  return CubeTexture([for (var i = 0; i < 6; i++) face(i)])
    ..colorSpace = SRGBColorSpace
    ..needsUpdate = true;
}

void main() {
  late FlutterGpuRenderer renderer;

  setUp(() async {
    renderer = await FlutterGpuRenderer.create()
      ..setSize(64, 64)
      ..setClearColor(0x336699);
  });

  tearDown(() => renderer.dispose());

  // A renderer of the test's own, set up as the shared one. The slow tests below use it: a test past its timeout
  // keeps running, and on the shared variable it would draw with the renderer of the tests after it.
  Future<FlutterGpuRenderer> own() async {
    final renderer = await FlutterGpuRenderer.create()
      ..setSize(64, 64)
      ..setClearColor(0x336699);
    addTearDown(renderer.dispose);
    return renderer;
  }

  test('a shader missing from the bundle is named, not reported as a missing bundle', () async {
    final library = (await gpu.ShaderLibrary.fromAsset('build/shaderbundles/ent.shaderbundle'))!;
    expect(shaderOf(library, 'FaceVertex'), isNotNull);
    expect(
      () => shaderOf(library, 'NoSuchVertex'),
      throwsA(isA<StateError>().having((e) => e.message, 'message', contains('has no NoSuchVertex'))),
    );
  });

  test('the hook keeps only the target backends, and a stripped bundle reads as the engine expects', () async {
    final bytes = File('build/shaderbundles/ent.shaderbundle').readAsBytesSync();
    final vulkan = (await gpu.ShaderLibrary.fromBytes(ByteData.sublistView(strip(bytes, {'vulkan'}))))!;

    // macOS keeps Metal and Vulkan: the bundle's OpenGL slots are empty, so keeping only them leaves the names.
    expect(strip(bytes, {'opengl_es', 'opengl_desktop'}).length, lessThan(64 << 10));
    expect(shaderOf(vulkan, 'FaceVertex'), isNotNull);

    // A bundle with another GPU's backend only (iOS Metal, which the macOS build already left out) has nothing for
    // this one, and the engine refuses it.
    await expectLater(gpu.ShaderLibrary.fromBytes(ByteData.sublistView(strip(bytes, {'metal_ios'}))), throwsException);
  });

  test('the bundle holds the variants the registry lists', () async {
    final library = (await gpu.ShaderLibrary.fromAsset('build/shaderbundles/ent.shaderbundle'))!;
    expect(shaderOf(library, 'basic'), isNotNull);
    expect(shaderOf(library, 'basic map polygon_offset'), isNotNull);
    expect(() => shaderOf(library, 'basic light_map'), throwsStateError);
  });

  test('setClearColor', () async {
    final f = await frame(renderer, Scene(), ortho());
    expect([f.width, f.height], [64, 64]);
    expect(f.pixel(0, 0), rgb(0x33, 0x66, 0x99));
    expect(f.pixel(63, 63), rgb(0x33, 0x66, 0x99));
    expect(f.pixel(0, 0)[3], 255);
  });

  test('triangle: MeshBasicMaterial color and orientation', () async {
    final scene = Scene()..add(Mesh(triangle(), MeshBasicMaterial({'color': 0xff8000})));
    final f = await frame(renderer, scene, ortho());

    // 0xff8000 is sRGB; stored linear, encoded back to sRGB on output.
    expect(f.pixel(32, 40), rgb(0xff, 0x80, 0x00));
    expect(f.pixel(32, 22), rgb(0xff, 0x80, 0x00), reason: 'near the apex, which points up');
    expect(f.pixel(32, 12), rgb(0x33, 0x66, 0x99), reason: 'above the apex');
    expect(f.pixel(32, 52), rgb(0x33, 0x66, 0x99), reason: 'below the base');
    expect(f.pixel(10, 46), rgb(0x33, 0x66, 0x99), reason: 'left of the base corner');
    expect(renderer.info.render.calls, 1);
    expect(renderer.info.render.triangles, 1);
  });

  test('side: back faces are culled for FrontSide, drawn for BackSide and DoubleSide', () async {
    Future<List<int>> centre(BufferGeometry geometry, int side) async {
      final scene = Scene()..add(Mesh(geometry, MeshBasicMaterial({'color': 0xff0000, 'side': side})));
      return (await frame(renderer, scene, ortho())).pixel(32, 40);
    }

    expect(await centre(triangle(), FrontSide), rgb(0xff, 0, 0));
    expect(await centre(triangle(clockwise: true), FrontSide), rgb(0x33, 0x66, 0x99));
    expect(await centre(triangle(clockwise: true), BackSide), rgb(0xff, 0, 0));
    expect(await centre(triangle(), BackSide), rgb(0x33, 0x66, 0x99));
    expect(await centre(triangle(clockwise: true), DoubleSide), rgb(0xff, 0, 0));
  });

  test('depth: the nearer plane wins whatever the draw order', () async {
    for (final nearFirst in [true, false]) {
      final near = Mesh(PlaneGeometry(1, 1), MeshBasicMaterial({'color': 0xff0000}))..renderOrder = nearFirst ? 0 : 1;
      final far = Mesh(PlaneGeometry(1.5, 1.5), MeshBasicMaterial({'color': 0x00ff00}))
        ..position.z = -1
        ..renderOrder = nearFirst ? 1 : 0;
      final f = await frame(
        renderer,
        Scene()
          ..add(near)
          ..add(far),
        ortho(),
      );
      expect(f.pixel(32, 32), rgb(0xff, 0, 0), reason: 'near plane drawn ${nearFirst ? 'first' : 'last'}');
      expect(f.pixel(32, 12), rgb(0, 0xff, 0), reason: 'far plane outside the near one');
    }
  });

  test('depthTest false: a later far plane draws over the near one', () async {
    final near = Mesh(PlaneGeometry(1, 1), MeshBasicMaterial({'color': 0xff0000}));
    final far = Mesh(PlaneGeometry(1.5, 1.5), MeshBasicMaterial({'color': 0x00ff00, 'depthTest': false}))
      ..position.z = -1
      ..renderOrder = 1;
    final f = await frame(
      renderer,
      Scene()
        ..add(near)
        ..add(far),
      ortho(),
    );
    expect(f.pixel(32, 32), rgb(0, 0xff, 0));
  });

  test('MeshNormalMaterial: view-space normals of a cube turned 45 degrees', () async {
    final camera = PerspectiveCamera(50, 1, 0.1, 100)..position.set(0, 0, 4);
    final cube = Mesh(BoxGeometry(1, 1, 1), MeshNormalMaterial())..rotation.y = math.pi / 4;
    final f = await frame(renderer, Scene()..add(cube), camera);

    // Faces +x and +z turn to view normals (±0.7071, 0, 0.7071); packNormalToRGB = n * 0.5 + 0.5.
    final left = [(0.5 - 0.3536) * 255, 0.5 * 255, (0.5 + 0.3536) * 255].map((v) => v.round()).toList();
    final right = [(0.5 + 0.3536) * 255, 0.5 * 255, (0.5 + 0.3536) * 255].map((v) => v.round()).toList();
    expect(f.pixel(26, 32), rgb(left[0], left[1], left[2]));
    expect(f.pixel(38, 32), rgb(right[0], right[1], right[2]));
    expect(renderer.info.render.triangles, 12);
  });

  test(
    'each variant kind draws through its own variants: an unregistered one is named, not drawn another way',
    () async {
      final camera = PerspectiveCamera(50, 1, 0.1, 100)..position.set(0, 0, 4);

      // No registry lists a light map with polygon offset, so each kind must ask for its own such variant.
      final lit = {
        'lightMap': DataTexture(Uint8List.fromList([255, 255, 255, 255]), 1, 1),
        'polygonOffset': true,
      };

      for (final (key, material) in [
        ('basic light_map polygon_offset', MeshBasicMaterial(lit)),
        ('lambert light_map polygon_offset', MeshLambertMaterial(lit)),
        ('phong light_map polygon_offset', MeshPhongMaterial(lit)),
        ('toon light_map polygon_offset', MeshToonMaterial(lit)),
        ('physical light_map polygon_offset', MeshStandardMaterial(lit)),
        ('physical clearcoat light_map polygon_offset', MeshPhysicalMaterial({...lit, 'clearcoat': 1.0})),

        // Matcap has no light map; no registry lists its alpha map with polygon offset either.
        ('matcap alpha_map polygon_offset', MeshMatcapMaterial({'alphaMap': lit['lightMap'], 'polygonOffset': true})),
      ]) {
        await expectLater(
          frame(renderer, Scene()..add(Mesh(BoxGeometry(1, 1, 1), material)), camera),
          throwsA(isA<StateError>().having((e) => e.message, 'message', contains('"$key"'))),
        );
      }

      // MeshNormalMaterial has no light map; an object-space normal map with polygon offset is not listed either.
      await expectLater(
        frame(
          renderer,
          Scene()..add(
            Mesh(
              BoxGeometry(1, 1, 1),
              MeshNormalMaterial({
                'normalMap': DataTexture(Uint8List.fromList([128, 128, 255, 255]), 1, 1),
                'normalMapType': ObjectSpaceNormalMap,
                'polygonOffset': true,
              }),
            ),
          ),
          camera,
        ),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', contains('"normal object_normal_map polygon_offset"')),
        ),
      );
    },
  );

  test('a frame or compile that throws on an unregistered variant leaves the next frames drawn right', () async {
    final renderer = await own();
    final red = Mesh(PlaneGeometry(1, 1), MeshBasicMaterial({'color': 0xff0000}));
    final missing = MeshLambertMaterial({
      'lightMap': DataTexture(Uint8List.fromList([255, 255, 255, 255]), 1, 1),
      'polygonOffset': true,
    });

    // The missing variant comes after a registered draw (nearer, and its material older), so the frame has started
    // when it throws.
    await expectLater(
      frame(
        renderer,
        Scene()
          ..add(red)
          ..add(Mesh(PlaneGeometry(2, 2), missing)..position.z = -1),
        ortho(),
      ),
      throwsA(isA<StateError>()),
    );

    // compile warms the same draws in a 1×1 frame of its own, which it must not leave behind either.
    expect(
      () => renderer.compile(Scene()..add(Mesh(PlaneGeometry(2, 2), missing)), ortho()),
      throwsA(isA<StateError>()),
    );

    for (var i = 0; i < 3; i++) {
      final shot = await frame(renderer, Scene()..add(red), ortho());
      expect(shot.pixel(32, 32), rgb(255, 0, 0), reason: 'frame $i, center');
      expect(shot.pixel(4, 4), rgb(0x33, 0x66, 0x99), reason: 'frame $i, corner');
    }

    // The viewport too, which a frame of compile's ignores: a full-view plane fills the bottom-left quarter only.
    renderer.setViewport(0, 0, 32, 32);
    final quarter = await frame(renderer, Scene()..add(Mesh(PlaneGeometry(2, 2), red.material as Material)), ortho());
    expect(quarter.pixel(16, 48), rgb(255, 0, 0), reason: 'inside the viewport');
    expect(quarter.pixel(48, 16), rgb(0x33, 0x66, 0x99), reason: 'outside the viewport');
  });

  test('a shadow pass that throws on an unregistered variant leaves the depth material drawing as before', () async {
    final renderer = await own();
    final fresh = await own();
    final light = DirectionalLight(0xffffff, 1)
      ..position.set(0, 0, 5)
      ..castShadow = true;

    // A caster with a map and nothing else asks for "depth map", which no registry lists.
    final caster = Mesh(
      PlaneGeometry(1, 1),
      MeshBasicMaterial({
        'map': DataTexture(Uint8List.fromList([255, 255, 255, 255]), 1, 1)..needsUpdate = true,
      }),
    )..castShadow = true;
    renderer.shadowMap.enabled = true;

    await expectLater(
      frame(
        renderer,
        Scene()
          ..add(light)
          ..add(caster),
        ortho(),
      ),
      throwsA(isA<StateError>().having((e) => e.message, 'message', contains('"depth map"'))),
    );

    // The near plane at z = 0.5 of a [0.1, 10] camera: packed depth, not the shadow pass's raw depth.
    Scene depth() =>
        Scene()
          ..add(Mesh(PlaneGeometry(2, 2), MeshDepthMaterial({'depthPacking': RGBADepthPacking}))..position.z = 0.5);
    final want = await frame(fresh, depth(), ortho());
    final got = await frame(renderer, depth(), ortho());
    expect(got.pixel(32, 32), want.pixel(32, 32));
  });

  test('a physical draw with more 2D textures than its slots throws, and the next frame draws right', () async {
    final renderer = await own();
    DataTexture texture() => DataTexture(Uint8List.fromList([255, 255, 255, 255]), 1, 1)..needsUpdate = true;
    final red = Mesh(PlaneGeometry(1, 1), MeshBasicMaterial({'color': 0xff0000}));

    // 14 maps with textures of their own fill the 15 slots with the DFG table.
    final full = Mesh(
      PlaneGeometry(2, 2),
      MeshPhysicalMaterial({
        for (final name in [
          'map',
          'alphaMap',
          'aoMap',
          'lightMap',
          'emissiveMap',
          'normalMap',
          'roughnessMap',
          'metalnessMap',
          'clearcoatMap',
          'clearcoatNormalMap',
          'clearcoatRoughnessMap',
          'sheenColorMap',
          'sheenRoughnessMap',
          'specularColorMap',
        ])
          name: texture(),
        'clearcoat': 1.0,
        'sheen': 1.0,
      }),
    )..receiveShadow = true;
    final lit = Scene()
      ..add(full)
      ..add(AmbientLight(0xffffff, 1));

    expect((await frame(renderer, lit, ortho())).pixel(32, 32), isNot(rgb(0x33, 0x66, 0x99)), reason: 'drawn');

    // A shadow-casting light takes a slot of its own, which leaves one map without.
    lit.add(
      DirectionalLight(0xffffff, 1)
        ..position.set(0, 0, 5)
        ..castShadow = true,
    );
    renderer.shadowMap.enabled = true;

    await expectLater(
      frame(renderer, lit, ortho()),
      throwsA(isA<StateError>().having((e) => e.message, 'message', contains('finds no free slot'))),
    );

    for (var i = 0; i < 2; i++) {
      final shot = await frame(renderer, Scene()..add(red), ortho());
      expect(shot.pixel(32, 32), rgb(255, 0, 0), reason: 'frame $i, center');
      expect(shot.pixel(4, 4), rgb(0x33, 0x66, 0x99), reason: 'frame $i, corner');
    }
  });

  test('maps with the same texture share a slot and draw as from copies, so every physical map fits', () async {
    final renderer = await own();
    final light = DirectionalLight(0xffffff, 2)..position.set(1, 2, 3);

    // Texels that differ per channel, so a map reading another slot shows.
    DataTexture texture() => DataTexture(
      Uint8List.fromList([40, 200, 90, 255, 220, 60, 160, 255, 120, 30, 250, 255, 250, 140, 20, 255]),
      2,
      2,
    )..needsUpdate = true;

    Future<Frame> draw(Material material) => frame(
      renderer,
      Scene()
        ..add(light)
        ..add(AmbientLight(0xffffff, 1))
        ..add(Mesh(PlaneGeometry(2, 2), material)),
      ortho(),
    );

    // The physical maps bind first: the white roughness map takes slot 0, so the shared texture's maps must read
    // their own slot.
    final white = DataTexture(Uint8List.fromList(List.filled(16, 255)), 2, 2)..needsUpdate = true;
    final flat = DataTexture(
      Uint8List.fromList([
        for (var i = 0; i < 4; i++) ...[128, 128, 255, 255],
      ]),
      2,
      2,
    )..needsUpdate = true;
    final one = texture();
    final base = {'roughnessMap': white, 'normalMap': flat, 'metalness': 0.5};
    final shared = await draw(MeshStandardMaterial({...base, 'aoMap': one, 'map': one, 'metalnessMap': one}));
    final copies = await draw(
      MeshStandardMaterial({...base, 'aoMap': texture(), 'map': texture(), 'metalnessMap': texture()}),
    );

    for (final (x, y) in [(16, 16), (48, 16), (16, 48), (48, 48)]) {
      expect(shared.pixel(x, y), copies.pixel(x, y), reason: '($x, $y)');
    }

    // Every map of the widest variant from one texture takes one slot.
    final widest = MeshPhysicalMaterial({
      for (final name in [
        'map',
        'alphaMap',
        'aoMap',
        'lightMap',
        'emissiveMap',
        'normalMap',
        'roughnessMap',
        'metalnessMap',
        'clearcoatMap',
        'clearcoatRoughnessMap',
        'clearcoatNormalMap',
        'sheenColorMap',
        'sheenRoughnessMap',
        'iridescenceMap',
        'iridescenceThicknessMap',
        'anisotropyMap',
        'specularIntensityMap',
        'specularColorMap',
        'diffuseRoughnessMap',
        'transmissionMap',
        'thicknessMap',
      ])
        name: one,
      for (final name in ['clearcoat', 'sheen', 'iridescence', 'anisotropy', 'diffuseRoughness', 'transmission'])
        name: 1.0,
      'dispersion': 1.0,
    });

    await draw(widest);
    expect(renderer.info.render.calls, 1);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('recording mode records every variant a frame or compile needs and skips the unregistered ones', () async {
    final renderer = await own();
    final camera = PerspectiveCamera(50, 1, 0.1, 100)..position.set(0, 0, 4);
    final lit = {
      'lightMap': DataTexture(Uint8List.fromList([255, 255, 255, 255]), 1, 1),
      'polygonOffset': true,
    };
    final missing = Mesh(BoxGeometry(1, 1, 1), MeshLambertMaterial(lit));
    renderer.recorded = {};

    // The registered plain box draws, the unregistered one does not, and neither throws.
    await frame(
      renderer,
      Scene()
        ..add(Mesh(BoxGeometry(1, 1, 1), MeshBasicMaterial()))
        ..add(missing),
      camera,
    );
    expect(renderer.recorded, {'basic', 'lambert light_map polygon_offset'});
    expect(renderer.info.render.calls, 1);

    renderer.recorded = {};
    renderer.compile(Scene()..add(Mesh(BoxGeometry(1, 1, 1), MeshPhongMaterial(lit))), camera);
    expect(renderer.recorded, {'phong light_map polygon_offset'});

    renderer.recorded = null;
    await expectLater(frame(renderer, Scene()..add(missing), camera), throwsStateError);
  });

  test('vertex colors apply only with vertexColors; instance colors without them (no fragment flag)', () async {
    BufferGeometry red() => triangle()..setAttribute('color', Float32BufferAttribute([1, 0, 0, 1, 0, 0, 1, 0, 0], 3));

    final plain = await frame(renderer, Scene()..add(Mesh(red(), MeshBasicMaterial())), ortho());
    final colored = await frame(
      renderer,
      Scene()..add(Mesh(red(), MeshBasicMaterial({'vertexColors': true}))),
      ortho(),
    );
    final instanced = InstancedMesh(red(), MeshBasicMaterial(), 1)
      ..setMatrixAt(0, Matrix4())
      ..setColorAt(0, Color(0x0000ff));
    final blue = await frame(renderer, Scene()..add(instanced), ortho());

    expect(plain.pixel(32, 40), rgb(0xff, 0xff, 0xff));
    expect(colored.pixel(32, 40), rgb(0xff, 0, 0));
    expect(blue.pixel(32, 40), rgb(0, 0, 0xff));
  });

  test('programs: a basic draw after a normal draw keeps its own bindings', () async {
    final small = Mesh(PlaneGeometry(0.2, 0.2), MeshNormalMaterial())..position.set(0.8, 0.8, 0);
    final basic = Mesh(triangle(), MeshBasicMaterial({'color': 0xff8000}))..renderOrder = 1;
    final f = await frame(
      renderer,
      Scene()
        ..add(small)
        ..add(basic),
      ortho(),
    );
    expect(f.pixel(32, 40), rgb(0xff, 0x80, 0x00));
    expect(renderer.info.render.calls, 2);
  });

  test('groups: a BoxGeometry with one material per face', () async {
    final colors = [0xff0000, 0x00ff00, 0x0000ff, 0xffff00, 0xff00ff, 0x00ffff];
    final cube = Mesh(BoxGeometry(1, 1, 1), [
      for (final c in colors) MeshBasicMaterial({'color': c}),
    ]);
    final f = await frame(renderer, Scene()..add(cube), ortho());

    // Group 4 is the +z face, the one facing the camera.
    expect(f.pixel(32, 32), rgb(0xff, 0x00, 0xff));
    expect(renderer.info.render.calls, 6);
  });

  test('drawRange: only the first triangle of an indexed plane', () async {
    final geometry = PlaneGeometry(1, 1)..setDrawRange(0, 3);
    final f = await frame(renderer, Scene()..add(Mesh(geometry, MeshBasicMaterial({'color': 0xffffff}))), ortho());

    // PlaneGeometry's first triangle covers the upper-left half of the square.
    expect(f.pixel(24, 24), rgb(0xff, 0xff, 0xff));
    expect(f.pixel(40, 40), rgb(0x33, 0x66, 0x99));
  });

  test('setSize and setPixelRatio size the drawing buffer; EntView updates the aspect', () async {
    renderer
      ..setPixelRatio(2)
      ..setSize(40, 20);
    final f = await frame(renderer, Scene(), ortho());
    expect([f.width, f.height], [80, 40]);
    expect(renderer.getDrawingBufferSize(Vector2()).toArray(), [80.0, 40.0]);
  });

  test('dispose: geometry buffers are released on the geometry dispose event', () async {
    final geometry = triangle();
    await frame(renderer, Scene()..add(Mesh(geometry, MeshBasicMaterial())), ortho());
    expect(renderer.info.memory.geometries, 1);
    geometry.dispose();
    expect(renderer.info.memory.geometries, 0);
  });

  test('attribute updates are re-uploaded when the version changes', () async {
    final geometry = triangle();
    final scene = Scene()..add(Mesh(geometry, MeshBasicMaterial({'color': 0xff0000})));
    expect((await frame(renderer, scene, ortho())).pixel(32, 40), rgb(0xff, 0, 0));
    final position = geometry.getAttribute('position')! as BufferAttribute;
    position
      ..setXYZ(0, -0.5, 0.5, 0)
      ..setXYZ(1, 0.5, 0.5, 0)
      ..setXYZ(2, 0, 0.9, 0)
      ..needsUpdate = true;
    expect((await frame(renderer, scene, ortho())).pixel(32, 40), rgb(0x33, 0x66, 0x99));
  });

  test('texture.mipmaps: user levels are sampled by level of detail, short of the 1x1 level', () async {
    // An 8×8 DataTexture whose levels are flat colors (8: red, 4: green, 2: blue, 1: yellow), on quads of 32, 4, 2 and
    // 1 pixels: levels of detail below 0, 1, 2 and 3. Flutter GPU allocates no 1×1 level (Texture.fullMipCount), so the
    // 1-pixel quad samples the 2×2 level where the reference samples the 1×1 one.
    DataImage level(int size, List<int> color) {
      return DataImage(
        data: Uint8List.fromList([
          for (var i = 0; i < size * size; i++) ...[...color, 255],
        ]),
        width: size,
        height: size,
      );
    }

    final colors = [
      [255, 0, 0],
      [0, 255, 0],
      [0, 0, 255],
      [255, 255, 0],
    ];
    final texture = DataTexture(level(8, colors[0]).data, 8, 8)
      ..mipmaps = [for (var i = 0; i < 4; i++) level(8 >> i, colors[i])]
      ..minFilter = NearestMipmapNearestFilter
      ..needsUpdate = true;
    final material = MeshBasicMaterial({'map': texture});
    final scene = Scene();

    for (final (x, width) in [(-0.5, 1.0), (0.3, 0.125), (0.6, 0.0625), (0.8, 0.03125)]) {
      scene.add(Mesh(PlaneGeometry(width, width), material)..position.set(x, 0.01, 0));
    }

    final f = await frame(renderer, scene, ortho());
    expect(f.pixel(16, 32), rgb(0xff, 0, 0), reason: 'magnified: level 0');
    expect(f.pixel(41, 32), rgb(0, 0xff, 0), reason: '4 pixels: level 1');
    expect(f.pixel(51, 32), rgb(0, 0, 0xff), reason: '2 pixels: level 2');
    expect(f.pixel(57, 31), rgb(0, 0, 0xff), reason: '1 pixel: level 2 here, the 1x1 level 3 in the reference');
    expect(renderer.info.memory.textures, 1);

    texture.dispose();
    expect(renderer.info.memory.textures, 0);
  });

  test('lights past the shaders\' maximum per type are ignored, with one warning (E-SHADERS)', () async {
    final messages = <String>[];
    setConsoleFunction((type, message, params) => messages.add('$type $message'));
    addTearDown(() => setConsoleFunction(null));

    // A Lambert quad lit by n identical point lights in front of it.
    Future<List<int>> lit(int n) async {
      final scene = Scene()..add(Mesh(PlaneGeometry(2, 2), MeshLambertMaterial({'color': 0xffffff})));

      for (var i = 0; i < n; i++) {
        scene.add(PointLight(0xffffff, 0.15, 0, 0)..position.set(0, 0, 1));
      }

      return (await frame(renderer, scene, ortho())).pixel(32, 32);
    }

    final seven = await lit(7);
    final eight = await lit(8);
    final nine = await lit(9);
    expect(eight[0], greaterThan(seven[0] + 2), reason: 'the eighth light adds');
    expect(nine, rgb(eight[0], eight[1], eight[2]), reason: 'the ninth is dropped');

    final warnings = messages.where((m) => m.contains('more than 8 PointLights')).toList();
    expect(warnings, hasLength(1));
  });

  test('every material kind draws with all of its maps (each bound sampler exists in its shader)', () async {
    final renderer = await own();

    Texture texture() {
      return DataTexture(Uint8List.fromList(List.filled(4 * 4 * 4, 200)), 4, 4)..needsUpdate = true;
    }

    final maps = {'map': texture(), 'alphaMap': texture(), 'displacementMap': texture()};
    final shading = {'normalMap': texture(), 'bumpMap': texture()};
    final lit = {...maps, ...shading, 'aoMap': texture(), 'lightMap': texture(), 'emissiveMap': texture()};
    final light = PointLight(0xffffff, 1)..position.set(0, 0, 2);
    final standard = {
      ...lit,
      'roughnessMap': texture(),
      'metalnessMap': texture(),
      'envMap': cube([200, 200, 200]),
    };
    final materials = <Material>[
      MeshBasicMaterial({
        'map': texture(),
        'alphaMap': texture(),
        'aoMap': texture(),
        'lightMap': texture(),
        'specularMap': texture(),
        'envMap': cube([200, 200, 200]),
      }),
      MeshNormalMaterial({...shading, 'displacementMap': texture()}),
      MeshLambertMaterial({
        ...lit,
        'specularMap': texture(),
        'envMap': cube([200, 200, 200]),
      }),
      MeshPhongMaterial({
        ...lit,
        'specularMap': texture(),
        'envMap': cube([200, 200, 200]),
      }),
      MeshStandardMaterial(standard),

      // The physical layers and transmission, their maps split over materials that fit the texture slots (14
      // maps, 13 with transmission); the standard maps come with each.
      MeshPhysicalMaterial({
        ...standard,
        for (final name in [
          'clearcoatMap',
          'clearcoatRoughnessMap',
          'clearcoatNormalMap',
          'sheenColorMap',
          'sheenRoughnessMap',
          'specularColorMap',
        ])
          name: texture(),
        'clearcoat': 1.0,
        'sheen': 1.0,
      }),
      MeshPhysicalMaterial({
        ...standard,
        for (final name in [
          'iridescenceMap',
          'iridescenceThicknessMap',
          'anisotropyMap',
          'specularIntensityMap',
          'diffuseRoughnessMap',
        ])
          name: texture(),
        'iridescence': 1.0,
        'anisotropy': 1.0,
        'diffuseRoughness': 1.0,
        'retroreflectivity': 1.0,
      }),
      MeshPhysicalMaterial({
        ...standard,
        'transmissionMap': texture(),
        'thicknessMap': texture(),
        'transmission': 1.0,
        'dispersion': 1.0,
      }),
      MeshToonMaterial({...lit, 'gradientMap': texture()}),
      MeshMatcapMaterial({...maps, ...shading, 'matcap': texture()}),
      MeshDepthMaterial(maps),
      MeshDistanceMaterial(maps),
    ];
    renderer.distanceLight = light;

    for (final material in materials) {
      final scene = Scene()
        ..add(light)
        ..add(Mesh(PlaneGeometry(1, 1, 4, 4), material));
      await frame(renderer, scene, ortho());
      expect(renderer.info.render.calls, 1, reason: material.type);
    }

    // Every physical map at once needs more slots than there are.
    final every = MeshPhysicalMaterial({
      ...standard,
      for (final name in [
        'clearcoatMap',
        'clearcoatRoughnessMap',
        'clearcoatNormalMap',
        'sheenColorMap',
        'sheenRoughnessMap',
        'iridescenceMap',
        'iridescenceThicknessMap',
        'anisotropyMap',
        'specularIntensityMap',
        'specularColorMap',
        'diffuseRoughnessMap',
        'transmissionMap',
        'thicknessMap',
      ])
        name: texture(),
      'clearcoat': 1.0,
      'sheen': 1.0,
      'iridescence': 1.0,
      'anisotropy': 1.0,
      'diffuseRoughness': 1.0,
      'transmission': 1.0,
      'dispersion': 1.0,
    });

    await expectLater(
      frame(renderer, Scene()..add(Mesh(PlaneGeometry(1, 1), every)), ortho()),
      throwsA(isA<StateError>().having((e) => e.message, 'message', contains('finds no free slot'))),
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('a skinned, morphed or instanced draw keeps its displacementMap and its vertex textures', () async {
    final renderer = await own();
    final messages = <String>[];
    setConsoleFunction((type, message, params) => messages.add('$type $message'));
    addTearDown(() => setConsoleFunction(null));

    final map = DataTexture(Uint8List.fromList(List.filled(4 * 4 * 4, 200)), 4, 4)..needsUpdate = true;
    final light = PointLight(0xffffff, 1)..position.set(0, 0, 2);

    // Morphed when [morph], skinned to one bone when [skin].
    Mesh mesh(Material material, {bool morph = false, bool skin = false}) {
      final geometry = PlaneGeometry(1, 1);

      if (morph) {
        geometry.morphAttributes['position'] = [Float32BufferAttribute(List.filled(12, 0.1), 3)];
      }

      if (!skin) {
        return Mesh(geometry, material)..morphTargetInfluences = [0.5];
      }

      geometry
        ..setAttribute('skinIndex', Uint16BufferAttribute(List.filled(16, 0), 4))
        ..setAttribute('skinWeight', Float32BufferAttribute(List.filled(16, 0.25), 4));
      final bone = Bone();
      return SkinnedMesh(geometry, material)
        ..morphTargetInfluences = morph ? [0.5] : []
        ..add(bone)
        ..bind(Skeleton([bone]));
    }

    // The widest variant: every map, every layer and transmission, its maps from one texture.
    MeshPhysicalMaterial widest() => MeshPhysicalMaterial({
      for (final name in [
        'map',
        'alphaMap',
        'aoMap',
        'lightMap',
        'emissiveMap',
        'normalMap',
        'roughnessMap',
        'metalnessMap',
        'clearcoatMap',
        'clearcoatRoughnessMap',
        'clearcoatNormalMap',
        'sheenColorMap',
        'sheenRoughnessMap',
        'iridescenceMap',
        'iridescenceThicknessMap',
        'anisotropyMap',
        'specularIntensityMap',
        'specularColorMap',
        'diffuseRoughnessMap',
        'transmissionMap',
        'thicknessMap',
        'displacementMap',
      ])
        name: map,
      for (final name in ['clearcoat', 'sheen', 'iridescence', 'anisotropy', 'diffuseRoughness', 'transmission'])
        name: 1.0,
      'dispersion': 1.0,
    });

    // Two instances, each with its own morph influences (InstancedMesh.morphTexture).
    final geometry = PlaneGeometry(1, 1)
      ..morphAttributes['position'] = [Float32BufferAttribute(List.filled(12, 0.1), 3)];
    final instanced = InstancedMesh(geometry, widest(), 2)..morphTargetInfluences = [0.5];

    for (var i = 0; i < 2; i++) {
      instanced.setMorphAt(i, Mesh()..morphTargetInfluences = [i * 0.5]);
    }

    instanced.morphTexture!.needsUpdate = true;

    final coated = {'displacementMap': map, 'clearcoat': 1.0, 'clearcoatMap': map};
    for (final object in [
      mesh(MeshStandardMaterial({'displacementMap': map}), morph: true),
      mesh(MeshPhysicalMaterial(coated), morph: true),
      mesh(MeshPhysicalMaterial(coated), skin: true),
      mesh(MeshPhysicalMaterial(coated), skin: true, morph: true),
      mesh(widest(), skin: true, morph: true),
      instanced,
    ]) {
      // Turned so that a displacement along the normal moves the quad across the frame.
      object.rotation.y = 0.8;
      final material = object.material as MeshStandardMaterial;
      Future<List<int>> draw(double scale) async {
        material.displacementScale = scale;
        final image = await frame(
          renderer,
          Scene()
            ..add(light)
            ..add(object),
          ortho(),
        );
        return image.rgba.buffer.asUint8List();
      }

      expect(await draw(0), isNot(await draw(1)), reason: '${object.runtimeType} ${material.type}');
    }

    // The instances read their own influences: giving the first the second's changes the frame.
    Future<List<int>> instances() async {
      final image = await frame(
        renderer,
        Scene()
          ..add(light)
          ..add(instanced),
        ortho(),
      );
      return image.rgba.buffer.asUint8List();
    }

    final first = await instances();
    instanced
      ..setMorphAt(0, Mesh()..morphTargetInfluences = [0.5])
      ..morphTexture!.needsUpdate = true;
    expect(first, isNot(await instances()));

    expect(messages.where((m) => m.contains('displacementMap') || m.contains('morph')), isEmpty);
    expect(renderer.info.render.calls, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 6)));

  test('cube textures: a reflecting quad facing the camera shows the +Z face (cube upload and orientation)', () async {
    final faces = [
      for (var i = 0; i < 6; i++) <int>[40 * i + 20, 255 - 40 * i, 128],
    ];
    final material = MeshBasicMaterial({'envMap': cube(faces.expand((c) => c).toList(), perFace: true)});
    final f = await frame(renderer, Scene()..add(Mesh(PlaneGeometry(1, 1), material)), ortho());

    // The view ray (0, 0, -1) reflects to +z; the face colors are sRGB bytes, so the output repeats them.
    expect(f.pixel(32, 32), rgb(faces[4][0], faces[4][1], faces[4][2]));
  });

  test('PMREM: a uniform environment stays uniform at every roughness (normalized GGX and integration sums)', () async {
    final scene = Scene()
      ..background = cube([180, 120, 60])
      ..backgroundBlurriness = 0.6;

    final camera = PerspectiveCamera(70, 1, 0.1, 10)..lookAt(Vector3(0.3, -0.2, -1));
    final f = await frame(renderer, scene, camera);

    for (final (x, y) in [(2, 2), (32, 32), (61, 7), (9, 58)]) {
      expect(f.pixel(x, y), rgb(180, 120, 60), reason: '($x, $y)');
    }
  });

  // Flutter GPU builds pipelines per process, so timing a first render cannot tell whether compile warmed it; the
  // renderer's debug set of draw states can: every state the frame draws must already be in it. Its many new
  // states take flutter_tester about two minutes when the test runs alone.
  test('compile and compileAsync prepare every draw state of the next frame and change nothing it shows', () async {
    final renderer = await own();
    final phong = MeshPhongMaterial({'color': 0xff8000});
    final back = MeshLambertMaterial({'color': 0x00ff80, 'side': BackSide});
    final glass = MeshStandardMaterial({'color': 0x8080ff, 'side': DoubleSide, 'transparent': true, 'opacity': 0.5});
    final transmissive = MeshPhysicalMaterial({'transmission': 0.5, 'side': DoubleSide});
    final coated = MeshPhysicalMaterial({'clearcoat': 1.0});
    final label = SpriteMaterial({'color': 0x44ccff});
    final faces = [
      MeshBasicMaterial({'color': 0xff0000}),
      MeshNormalMaterial(),
    ];
    final light = DirectionalLight(0xffffff, 2)
      ..position.set(1, 2, 3)
      ..castShadow = true;
    final hidden = Mesh(triangle(), MeshBasicMaterial({'colorWrite': false}))..position.set(50, 0, 0);

    // A SkinnedMesh draws and casts its shadow with the skinning variants of the Phong and depth programs.
    final plane = PlaneGeometry(1, 1)
      ..setAttribute('skinIndex', Uint16BufferAttribute(List.filled(16, 0), 4))
      ..setAttribute(
        'skinWeight',
        Float32BufferAttribute([
          for (var i = 0; i < 4; i++) ...[1, 0, 0, 0],
        ], 4),
      );
    final bone = Bone();
    final skinned = SkinnedMesh(plane, phong)
      ..position.z = -0.5
      ..castShadow = true
      ..add(bone)
      ..bind(Skeleton([bone]));

    // A geometry with morph targets draws and casts its shadow with the morph variants of the same programs.
    final targets = PlaneGeometry(1, 1)
      ..morphAttributes['position'] = [Float32BufferAttribute(List.filled(12, 0.1), 3)];
    final morphed = Mesh(targets, phong)
      ..position.set(-0.5, -0.5, -0.5)
      ..castShadow = true
      ..morphTargetInfluences = [0.5];

    // A SkinnedMesh with morph targets draws and casts its shadow with the combined vertex stage.
    final joint = Bone();
    final blended =
        SkinnedMesh(
            PlaneGeometry(1, 1)
              ..setAttribute('skinIndex', plane.getAttribute('skinIndex')!)
              ..setAttribute('skinWeight', plane.getAttribute('skinWeight')!)
              ..morphAttributes['position'] = [Float32BufferAttribute(List.filled(12, 0.1), 3)],
            phong,
          )
          ..position.set(0.5, 0.5, -0.5)
          ..castShadow = true
          ..morphTargetInfluences = [0.5]
          ..add(joint)
          ..bind(Skeleton([joint]));
    // An InstancedMesh (tinted, and with morph targets) draws and casts its shadow with the instancing variants.
    final instances = InstancedMesh(PlaneGeometry(1, 1), phong, 2)
      ..position.set(-0.5, 0.5, -0.5)
      ..castShadow = true
      ..setColorAt(1, Color(0x00ff00));
    final bent = InstancedMesh(targets, phong, 2)
      ..position.set(0.5, -0.5, -0.5)
      ..castShadow = true
      ..morphTargetInfluences = [0.5];
    final scene = Scene()
      ..add(light)
      ..add(Mesh(PlaneGeometry(1, 1), phong)..castShadow = true)
      ..add(Mesh(PlaneGeometry(1, 1), back)..position.x = 0.5)
      ..add(Mesh(PlaneGeometry(1, 1), glass)..position.y = 0.5)
      ..add(Mesh(PlaneGeometry(1, 1), transmissive)..position.y = -0.5)
      ..add(Mesh(PlaneGeometry(1, 1), coated)..position.set(0.5, -0.5, 0))
      ..add(Mesh(BoxGeometry(0.5, 0.5, 0.5), faces)..position.x = -0.5)
      ..add(Sprite(label)..position.set(0.5, 0.5, 0.5))
      ..add(skinned)
      ..add(morphed)
      ..add(blended)
      ..add(instances)
      ..add(bent)
      ..add(hidden);
    final camera = PerspectiveCamera(50, 1, 0.1, 20)..position.set(0, 0, 3);
    var callbacks = 0;
    hidden.onBeforeRender = (_, _, _, _, _, _) => callbacks += 1;
    renderer.shadowMap.enabled = true;

    await frame(renderer, Scene()..add(Mesh(triangle(), MeshBasicMaterial())), ortho());
    final texture = renderer.texture;
    final before = renderer.states.length;

    expect(renderer.compile(scene, camera), {
      phong,
      back,
      glass,
      transmissive,
      coated,
      label,
      ...faces,
      hidden.material,
    });
    expect(await renderer.compileAsync(scene, camera), same(scene));
    expect(renderer.states.length, greaterThan(before));
    expect([renderer.info.render.calls, renderer.info.render.triangles, renderer.info.render.frame], [1, 1, 1]);
    expect(renderer.texture, same(texture));
    expect(callbacks, 0, reason: 'compile calls no render callbacks');

    final warmed = renderer.states.length;
    final f = await frame(renderer, scene, camera);
    expect([f.width, f.height], [64, 64]);
    expect(renderer.states.length, warmed, reason: 'the frame met no state compile had not drawn');

    // An object about to join the scene, compiled with the scene's lights; without compile its state is new.
    final toon = MeshToonMaterial({'side': DoubleSide});
    final mesh = Mesh(PlaneGeometry(1, 1), toon);
    expect(renderer.compile(mesh, camera, scene), {toon});

    final count = renderer.states.length;
    expect(count, greaterThan(warmed));
    await frame(renderer, scene..add(mesh), camera);
    expect(renderer.states.length, count, reason: 'the joined object met no new state');

    final matcap = MeshMatcapMaterial({'side': BackSide});
    await frame(renderer, scene..add(Mesh(PlaneGeometry(1, 1), matcap)), camera);
    expect(renderer.states.length, greaterThan(count), reason: 'an uncompiled kind adds its state while rendering');
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('MeshDistanceMaterial is not drawn without a point light to measure from', () async {
    final messages = <String>[];
    setConsoleFunction((type, message, params) => messages.add('$type $message'));
    addTearDown(() => setConsoleFunction(null));

    final f = await frame(renderer, Scene()..add(Mesh(triangle(), MeshDistanceMaterial())), ortho());
    expect(f.pixel(32, 40), rgb(0x33, 0x66, 0x99));
    expect(renderer.info.render.calls, 0);
    expect(
      messages.where((m) => m.contains('MeshDistanceMaterial is drawn only into point light shadow maps')),
      hasLength(1),
    );
  });

  test('a skeleton of 200 bones reads its far bones from the bone texture', () async {
    final geometry = triangle()
      ..setAttribute('skinIndex', Uint16BufferAttribute(List.filled(12, 199), 4))
      ..setAttribute(
        'skinWeight',
        Float32BufferAttribute([
          for (var i = 0; i < 3; i++) ...[1, 0, 0, 0],
        ], 4),
      );
    final bones = [for (var i = 0; i < 200; i++) Bone()];
    final mesh = SkinnedMesh(geometry, MeshBasicMaterial({'color': 0xff0000}));
    bones.forEach(mesh.add);
    mesh.bind(Skeleton(bones));

    // Bone 199 (texels 796 to 799: row 24 of the 32 × 32 texture) lifts the triangle; its unused neighbour moves.
    bones[199].position.y = 0.5;
    bones[198].position.x = 0.5;

    final f = await frame(renderer, Scene()..add(mesh), ortho());
    expect(mesh.skeleton!.boneTexture!.image, isA<DataImage>().having((i) => i.width, 'width', 32));
    expect(f.pixel(32, 40), rgb(0x33, 0x66, 0x99), reason: 'the rest place is empty');
    expect(f.pixel(32, 20), rgb(0xff, 0x00, 0x00), reason: 'lifted by bone 199');
    expect(f.pixel(48, 20), rgb(0x33, 0x66, 0x99), reason: 'not moved by bone 198');
  });

  test('an InstancedMesh draws count instances, tinted, and an empty BatchedMesh draws nothing', () async {
    final messages = <String>[];
    setConsoleFunction((type, message, params) => messages.add('$type $message'));
    addTearDown(() => setConsoleFunction(null));

    // Three instances of a small triangle, the third past count; the mesh's own place is off the frame.
    final mesh = InstancedMesh(triangle(), MeshBasicMaterial({'color': 0xffffff}), 3)
      ..position.x = 5
      ..setColorAt(0, Color(0xff0000))
      ..setColorAt(1, Color(0x00ff00))
      ..setColorAt(2, Color(0x0000ff))
      ..count = 2;

    for (final (i, x) in [(0, -5.5), (1, -4.5), (2, -5.0)]) {
      mesh.setMatrixAt(i, Matrix4().makeTranslation(x, i == 2 ? -0.6 : 0.4, 0));
    }

    final batched = BatchedMesh(1, 3, 0, MeshBasicMaterial());
    final f = await frame(
      renderer,
      Scene()
        ..add(mesh)
        ..add(batched),
      ortho(),
    );
    expect(f.pixel(16, 20), rgb(0xff, 0x00, 0x00), reason: 'instance 0, tinted red');
    expect(f.pixel(48, 20), rgb(0x00, 0xff, 0x00), reason: 'instance 1, tinted green');
    expect(f.pixel(32, 52), rgb(0x33, 0x66, 0x99), reason: 'instance 2 is past count');
    expect([renderer.info.render.calls, renderer.info.render.triangles], [1, 2]);
    expect(messages.where((m) => m.contains('BatchedMesh')), isEmpty);

    mesh.count = 0;
    await frame(renderer, Scene()..add(mesh), ortho());
    expect(renderer.info.render.calls, 0, reason: 'no instances, no draw call, as in the reference');
  });

  test('render targets: clear color and depth, readRenderTargetPixels rows from the bottom, dispose', () async {
    final target = WebGLRenderTarget(64, 64);
    final near = Mesh(PlaneGeometry(1, 1), MeshBasicMaterial({'color': 0xff0000}));
    final far = Mesh(PlaneGeometry(1.5, 1.5), MeshBasicMaterial({'color': 0x00ff00}))
      ..position.set(0.5, 0.5, -1)
      ..renderOrder = 1;
    final textures = renderer.info.memory.textures;
    final pixel = Uint8List(4);

    Future<List<int>> read(int x, int y) async {
      await renderer.readRenderTargetPixels(target, x, y, 1, 1, pixel);
      return pixel.toList();
    }

    renderer
      ..setClearColor(0x0000ff)
      ..setRenderTarget(target)
      ..render(
        Scene()
          ..add(near)
          ..add(far),
        ortho(),
      );
    expect(renderer.getRenderTarget(), target);
    renderer.setRenderTarget(null);

    // Pixel (x, y) of the target, from the bottom left, covers x / 32 - 1, y / 32 - 1.
    expect(await read(4, 4), [0, 0, 255, 255], reason: 'the clear color');
    expect(await read(20, 20), [255, 0, 0, 255], reason: 'the near plane');
    expect(await read(40, 40), [255, 0, 0, 255], reason: 'the far plane, drawn last, behind the near one');
    expect(await read(56, 56), [0, 255, 0, 255], reason: 'the far plane alone, top right');
    expect(await read(56, 8), [0, 0, 255, 255], reason: 'bottom right: the clear color');

    final block = Uint8List(4 * 2 * 4);
    await renderer.readRenderTargetPixels(target, 46, 46, 4, 2, block);
    expect(block.sublist(0, 4), [255, 0, 0, 255], reason: '(46, 46): the near plane');
    expect(block.sublist(28, 32), [0, 255, 0, 255], reason: '(49, 47): the far plane, right of the near one');

    // The frame is drawn again once the target is unset, sampling the target's texture upright.
    final f = await frame(
      renderer,
      Scene()..add(Mesh(PlaneGeometry(2, 2), MeshBasicMaterial({'map': target.texture}))),
      ortho(),
    );
    expect(f.pixel(56, 8), rgb(0, 0xff, 0), reason: 'the far plane at the top right of the frame');
    expect(f.pixel(8, 56), rgb(0, 0, 0xff));
    expect(renderer.info.memory.textures, textures + 1);

    target.dispose();
    expect(renderer.info.memory.textures, textures, reason: 'the target\'s GPU textures are released on dispose');
  });

  test('render targets: a depthTexture reads the depth, cleared with it; color reads stay; dispose', () async {
    final target = WebGLRenderTarget(64, 64)..depthTexture = DepthTexture(64, 64);
    final near = Mesh(PlaneGeometry(1, 1), MeshBasicMaterial({'color': 0xff0000}));
    final far = Mesh(PlaneGeometry(1.5, 1.5), MeshBasicMaterial({'color': 0x00ff00}))
      ..position.set(0.5, 0.5, -1)
      ..renderOrder = 1;
    final textures = renderer.info.memory.textures;
    final pixel = Uint8List(4);
    final view = Scene()..add(Mesh(PlaneGeometry(2, 2), MeshBasicMaterial({'map': target.depthTexture})));

    renderer
      ..setClearColor(0x0000ff)
      ..setRenderTarget(target)
      ..render(
        Scene()
          ..add(near)
          ..add(far),
        ortho(),
      );
    expect(renderer.info.render.calls, 2, reason: 'the depth texture\'s pass is not counted');
    renderer.setRenderTarget(null);

    await renderer.readRenderTargetPixels(target, 20, 20, 1, 1, pixel);
    expect(pixel, [255, 0, 0, 255], reason: 'readRenderTargetPixels reads the color');

    // Depths (WebGL window z of ortho(): (5 - z - 0.1) / 9.9) in the red channel, shown in sRGB: the near plane
    // 0.495 (187), the far one 0.596 (203), the clear 1.
    var f = await frame(renderer, view, ortho());
    expect(f.pixel(20, 43), rgb(187, 0, 0), reason: 'the near plane');
    expect(f.pixel(40, 23), rgb(187, 0, 0), reason: 'the near plane, in front of the far one drawn after it');
    expect(f.pixel(56, 7), rgb(203, 0, 0), reason: 'the far plane alone, top right');
    expect(f.pixel(56, 55), rgb(255, 0, 0), reason: 'bottom right: cleared to 1');
    expect(renderer.info.memory.textures, textures + 2, reason: 'the target\'s texture and its depth texture');

    // A render of nothing clears the depth texture with the depth buffer.
    renderer
      ..setRenderTarget(target)
      ..render(Scene(), ortho())
      ..setRenderTarget(null);
    f = await frame(renderer, view, ortho());
    expect(f.pixel(20, 43), rgb(255, 0, 0), reason: 'no depth left from the previous render');

    target.dispose();
    expect(renderer.info.memory.textures, textures, reason: 'the depth texture is released with the target');
  });
  // The kinds of pixel of a 64 × 64 target: blue (the clear color), red, green, or (on an edge) a blend.
  Future<Map<String, int>> kinds(WebGLRenderTarget target) async {
    final pixels = Uint8List(64 * 64 * 4);
    final counts = <String, int>{};
    await renderer.readRenderTargetPixels(target, 0, 0, 64, 64, pixels);

    for (var i = 0; i < pixels.length; i += 4) {
      final kind = switch ((pixels[i], pixels[i + 1], pixels[i + 2])) {
        (0, 0, 255) => 'clear',
        (255, 0, 0) => 'red',
        (0, 255, 0) => 'green',
        _ => 'blend',
      };
      counts[kind] = (counts[kind] ?? 0) + 1;
    }

    return counts;
  }

  // A green plane over the bottom half of a target, behind a triangle at z = 0.
  Scene half() =>
      Scene()..add(Mesh(PlaneGeometry(2, 1), MeshBasicMaterial({'color': 0x00ff00}))..position.set(0, -0.5, -1));

  test('render targets with samples: multisampled, resolved into the texture at every render', () async {
    final target = WebGLRenderTarget(64, 64, {'samples': 4});
    final tilted = Mesh(triangle(), MeshBasicMaterial({'color': 0xff0000}))..rotation.z = 0.3;
    addTearDown(target.dispose);
    renderer
      ..setClearColor(0x0000ff)
      ..setRenderTarget(target)
      ..render(Scene()..add(tilted), ortho());
    final first = await kinds(target);
    expect(first['red'], greaterThan(400), reason: 'the triangle, resolved into the texture');
    expect(first['blend'], greaterThan(20), reason: 'its edges, multisampled');

    renderer
      ..render(half(), ortho())
      ..setRenderTarget(null);
    expect(await kinds(target), {'green': 2048, 'clear': 2048}, reason: 'the second render, resolved again');
  });

  // Flutter GPU 3.47.6 (Impeller, Metal) clears a color attachment whose load action is `load` (with its clear
  // value, transparent black by default), with or without samples, so a render without autoClear does not keep
  // what an earlier render drew into a target (docs/flutter-gpu.md, Render targets with samples).
  test('render targets with samples: a render without autoClear keeps the earlier one', () async {
    final target = WebGLRenderTarget(64, 64, {'samples': 4});
    final tilted = Mesh(triangle(), MeshBasicMaterial({'color': 0xff0000}))..rotation.z = 0.3;
    addTearDown(target.dispose);
    renderer
      ..setClearColor(0x0000ff)
      ..setRenderTarget(target)
      ..render(Scene()..add(tilted), ortho());
    final first = await kinds(target);

    // The samples and the multisampled depth of the first render are loaded: the triangle stays whole, in front.
    renderer
      ..autoClear = false
      ..render(half(), ortho())
      ..autoClear = true
      ..setRenderTarget(null);
    final second = await kinds(target);
    expect(second['red'], first['red'], reason: 'the first render is kept, in front of the plane');
    expect(second['green'], greaterThan(1000), reason: 'the plane');
  }, skip: 'flutter_tester clears on LoadAction.load (flutter/flutter#196199)');

  // The creation probe (a cleared texture loaded by an empty pass) agrees with a render: a red top half, then without
  // autoClear a green bottom half. flutter_tester clears the loaded color (flutter/flutter#196199), Metal keeps it.
  test('loadKeepsColor tells whether a render without autoClear keeps the earlier one', () async {
    final target = WebGLRenderTarget(64, 64);
    addTearDown(target.dispose);
    renderer
      ..setClearColor(0x0000ff)
      ..setRenderTarget(target)
      ..render(
        Scene()..add(Mesh(PlaneGeometry(2, 1), MeshBasicMaterial({'color': 0xff0000}))..position.y = 0.5),
        ortho(),
      )
      ..autoClear = false
      ..render(half(), ortho())
      ..autoClear = true
      ..setRenderTarget(null);
    expect((await kinds(target))['red'] == 2048, renderer.loadKeepsColor);
  });

  // The creation probe for 32-bit float filtering: SwiftShader filters RGBA32F linearly (the iPhone 11's A13 does not,
  // which the Metal parity run's hdr_environment_aces checks through the half-float fallback, E-FLOATFILTER).
  test('filtersFloat: flutter_tester filters 32-bit float textures', () {
    expect(renderer.filtersFloat, isTrue);
  });

  // The creation probe for sampling a depth buffer: SwiftShader reads a depth-stencil texture as black, so depth
  // textures take the replay here and the copy on Metal (the Metal parity run's depth_texture_* scenes,
  // E-DEPTHTEXTURE).
  test('readsDepth: flutter_tester cannot sample a depth buffer', () {
    expect(renderer.readsDepth, isFalse);
  });

  test('render targets: renders in a row, unawaited, each keep their own uniforms (host buffers in flight)', () async {
    final material = MeshBasicMaterial({'depthTest': false});
    final pixel = Uint8List(4);

    // 64 full-target quads, each a draw with its own uniforms, into a 1024² target: enough fill that the GPU is
    // still drawing one render when the next writes its uniforms, even with warm pipelines.
    final scene = Scene();

    for (var q = 0; q < 64; q++) {
      scene.add(Mesh(PlaneGeometry(2, 2), material));
    }

    // More renders than a Flutter GPU HostBuffer has frames (4), none awaited, each with its own color; the second
    // round draws with the host memory the first one returned to the pool.
    for (var round = 0; round < 2; round++) {
      final targets = [
        for (var i = 0; i < 16; i++)
          () {
            final target = WebGLRenderTarget(256, 256);
            material.color.setRGB(i / 15, 1 - i / 15, (i % 2).toDouble());
            renderer
              ..setRenderTarget(target)
              ..render(scene, ortho());
            return target;
          }(),
      ];
      renderer.setRenderTarget(null);

      final colors = <List<int>>[];

      for (final target in targets) {
        await renderer.readRenderTargetPixels(target, 128, 128, 1, 1, pixel);
        colors.add(pixel.sublist(0, 3));
        target.dispose();
      }

      expect(colors, [
        for (var i = 0; i < 16; i++) [(i / 15 * 255).round(), ((1 - i / 15) * 255).round(), i % 2 * 255],
      ], reason: 'round $round');
    }
  });

  test(
    'antialias: 4× MSAA resolved into the main frame, with compileAsync, transmission, targets and a composer',
    () async {
      final aa = await FlutterGpuRenderer.create(antialias: true);
      addTearDown(aa.dispose);
      aa.setSize(64, 64);
      final tilted = Mesh(triangle(), MeshBasicMaterial({'color': 0xff8000}))..rotation.z = 0.3;

      // A transmissive plane in the top right corner makes the frame draw the transmission pass first.
      final glass = Mesh(PlaneGeometry(0.4, 0.4), MeshPhysicalMaterial({'transmission': 1, 'roughness': 0}))
        ..position.set(0.75, 0.75, 1);
      final scene = Scene()
        ..background = Color(0x204060)
        ..add(tilted)
        ..add(glass);
      final camera = ortho();
      expect(await aa.compileAsync(scene, camera), same(scene));

      final f = await frame(aa, scene, camera);
      expect(f.pixel(1, 1), rgb(0x20, 0x40, 0x60), reason: 'background');
      expect(f.pixel(32, 32), rgb(255, 128, 0), reason: 'interior');

      // Below the plane, every pixel is the background, the triangle's orange or, on its edges, a blend of both.
      var blended = 0;

      for (var y = 24; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          final p = f.pixel(x, y);

          if (!rgb(0x20, 0x40, 0x60).matches(p, {}) && !rgb(255, 128, 0).matches(p, {})) {
            blended++;
          }
        }
      }

      expect(blended, greaterThan(20), reason: 'blended edge pixels');

      // A render target is not multisampled and reads back; the main frame after it is still antialiased.
      final target = WebGLRenderTarget(16, 16);
      final pixel = Uint8List(4);
      addTearDown(target.dispose);
      aa
        ..setRenderTarget(target)
        ..render(scene, camera)
        ..setRenderTarget(null);
      await aa.readRenderTargetPixels(target, 0, 15, 1, 1, pixel);
      expect(pixel[3], 255);
      expect((await frame(aa, scene, camera)).pixel(32, 32), rgb(255, 128, 0));

      // An EffectComposer: the RenderPass draws into its target, the OutputPass into the antialiased frame.
      final composer = EffectComposer(aa)
        ..addPass(RenderPass(scene, camera))
        ..addPass(OutputPass())
        ..render(0);
      addTearDown(composer.dispose);
      final image = aa.texture!.asImage();
      final composed = Frame(64, 64, (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!);
      expect(composed.pixel(1, 1), rgb(0x20, 0x40, 0x60));
      expect(composed.pixel(32, 32), rgb(255, 128, 0));
    },
  );
}
