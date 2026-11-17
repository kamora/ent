// Renderer parity with the reference frames in a macOS app, on Metal: the scenes and the comparison of
// packages/ent_flutter/test/parity_test.dart (flutter_tester runs Impeller on Vulkan through SwiftShader), shared
// through its test/parity.dart. The references reach the app as assets: integration_test/fixtures links to the
// repository's fixtures directory. The skipped scenes run too, to measure them on Metal: one that fails is reported as
// skipped, with its numbers, rather than failing the run. A failing frame is saved to parity_failures in the app's
// temporary directory.
//
// flutter test integration_test/parity_metal_test.dart -d macos --enable-flutter-gpu
// One scene or a few: add --dart-define=PARITY_ONLY=name,name.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ent_flutter/ent_flutter.dart';

import '../../../packages/ent_flutter/test/parity.dart';

const only = String.fromEnvironment('PARITY_ONLY');

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final assets = (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets();
  const prefix = 'integration_test/fixtures/rendering/reference/';

  declare(
    [
      for (final a in assets)
        if (a.startsWith(prefix) && a.endsWith('.json') && !a.endsWith('meta.json'))
          a.substring(prefix.length).replaceAll('.json', ''),
    ].where((name) => only.isEmpty || only.split(',').contains(name)),
    (path) async => Uint8List.fromList((await rootBundle.load('integration_test/$path')).buffer.asUint8List()),
    measure: skipped,
    failures: Directory('${Directory.systemTemp.path}/parity_failures'),
  );

  // flutter/flutter#196199: a color attachment loaded with LoadAction.load keeps what an earlier render drew on Metal,
  // unlike flutter_tester. Measured here through the renderer: a red top half, then without autoClear a green bottom
  // half, into a render target (without and with samples) and into the frame (E-FRAME, with and without antialias).
  test('LoadAction.load: a render without autoClear keeps the earlier one', () async {
    final renderer = await FlutterGpuRenderer.create();
    final camera = OrthographicCamera(-1, 1, 1, -1, 0.1, 10)..position.set(0, 0, 5);
    addTearDown(renderer.dispose);
    renderer
      ..setSize(64, 64)
      ..setClearColor(0x0000ff);

    Scene half(int color, double y) =>
        Scene()..add(Mesh(PlaneGeometry(2, 1), MeshBasicMaterial({'color': color}))..position.set(0, y, 0));

    Map<String, int> kinds(Uint8List pixels) {
      final counts = <String, int>{};

      for (var i = 0; i < pixels.length; i += 4) {
        final kind = switch ((pixels[i], pixels[i + 1], pixels[i + 2])) {
          (0, 0, 255) => 'clear',
          (255, 0, 0) => 'red',
          (0, 255, 0) => 'green',
          _ => 'other',
        };
        counts[kind] = (counts[kind] ?? 0) + 1;
      }

      return counts;
    }

    final results = <String, Map<String, int>>{};

    for (final samples in [0, 4]) {
      final target = WebGLRenderTarget(64, 64, {'samples': samples});
      final pixels = Uint8List(64 * 64 * 4);
      addTearDown(target.dispose);
      renderer
        ..setRenderTarget(target)
        ..render(half(0xff0000, 0.5), camera)
        ..autoClear = false
        ..render(half(0x00ff00, -0.5), camera)
        ..autoClear = true;
      await renderer.readRenderTargetPixels(target, 0, 0, 64, 64, pixels);
      renderer.setRenderTarget(null);
      results['target, samples $samples'] = kinds(pixels);
    }

    // The frame keeps it by copying the previous render's texture (E-FRAME), with and without antialias.
    for (final antialias in [false, true]) {
      final own = antialias ? await FlutterGpuRenderer.create(antialias: true) : renderer;
      addTearDown(own.dispose);
      own
        ..setSize(64, 64)
        ..setClearColor(0x0000ff)
        ..render(half(0xff0000, 0.5), camera)
        ..autoClear = false;
      final frame = await own.render(half(0x00ff00, -0.5), camera).toByteData(format: ui.ImageByteFormat.rawRgba);
      own.autoClear = true;
      results['frame${antialias ? ', antialias' : ''}'] = kinds(frame!.buffer.asUint8List());
    }

    // Evidence for the report.
    // ignore: avoid_print
    print('LoadAction.load: $results');
    expect(results['target, samples 0']!['red'], 2048, reason: 'the first render kept in a render target');
    expect(renderer.loadKeepsColor, isTrue, reason: 'the creation probe agrees');
    expect(results['target, samples 4']!['red'], 2048, reason: 'the first render kept in a multisampled target');
    expect(results['frame']!['red'], 2048, reason: 'the first render kept in the frame');
    expect(results['frame']!['green'], 2048, reason: 'the second render drawn into the frame');
    expect(results['frame, antialias']!['red'], 2048, reason: 'the first render kept in the antialiased frame');

    // The depth texture's creation probe: Metal samples a depth buffer, so the depth_texture_* scenes above checked
    // the copy, not the replay flutter_tester takes (E-DEPTHTEXTURE).
    expect(renderer.readsDepth, isTrue, reason: 'Metal samples depth buffers');
  });

  // The widest physical variant binds the most textures of any draw (every physical map, every layer, transmission
  // with dispersion, the env map), more sampler units than WebGL gives, so no reference frame can show it. Here it is
  // only drawn: its own variant, without a Metal fault, and covering the quad; the quadrants' mean colors are printed
  // to compare GPUs.
  test('the widest physical variant draws', () async {
    const widest =
        'physical alpha_map anisotropy anisotropy_map ao_map clearcoat clearcoat_map clearcoat_normal_map '
        'clearcoat_roughness_map diffuse_roughness diffuse_roughness_map dispersion emissive_map iridescence '
        'iridescence_map iridescence_thickness_map light_map map metalness_map normal_map roughness_map sheen '
        'sheen_color_map sheen_roughness_map specular_color_map specular_intensity_map thickness_map transmission '
        'transmission_map';
    final renderer = await FlutterGpuRenderer.create();
    final camera = OrthographicCamera(-1, 1, 1, -1, 0.1, 10)..position.set(0, 0, 5);
    addTearDown(renderer.dispose);
    renderer
      ..setSize(64, 64)
      ..setClearColor(0x101010);

    // A 2×2 texture with these texels.
    DataTexture texture(List<int> texels) => DataTexture(Uint8List.fromList(texels), 2, 2)..needsUpdate = true;

    final ramp = texture([40, 40, 128, 255, 255, 40, 128, 255, 40, 255, 128, 255, 255, 255, 128, 255]);
    final flat = texture([128, 128, 255, 255, 140, 120, 250, 255, 120, 140, 250, 255, 128, 128, 255, 255]);
    final gray = texture([90, 140, 190, 255, 140, 190, 240, 255, 190, 240, 90, 255, 240, 90, 140, 255]);
    final sky =
        DataTexture(
            Uint8List.fromList([
              for (var i = 0; i < 8; i++) ...(i < 4 ? [120, 160, 230, 255] : [90, 70, 50, 255]),
            ]),
            4,
            2,
          )
          ..mapping = EquirectangularReflectionMapping
          ..needsUpdate = true;

    final scene = Scene()..environment = sky;
    scene
      ..add(AmbientLight(0xffffff, 0.4))
      ..add(DirectionalLight(0xffffff, 1.8)..position.set(1, 2, 3));

    // Opaque halves behind, for the transmission target.
    for (final (color, x) in [(0xff5533, -0.5), (0x3366ff, 0.5)]) {
      scene.add(Mesh(PlaneGeometry(1, 2), MeshBasicMaterial({'color': color}))..position.set(x, 0, -1));
    }

    final material = MeshPhysicalMaterial({
      for (final name in [
        'map',
        'emissiveMap',
        'aoMap',
        'lightMap',
        'clearcoatMap',
        'sheenColorMap',
        'specularColorMap',
      ])
        name: ramp,
      for (final name in ['normalMap', 'clearcoatNormalMap', 'anisotropyMap']) name: flat,
      for (final name in [
        'alphaMap',
        'roughnessMap',
        'metalnessMap',
        'clearcoatRoughnessMap',
        'diffuseRoughnessMap',
        'iridescenceMap',
        'iridescenceThicknessMap',
        'sheenRoughnessMap',
        'specularIntensityMap',
        'thicknessMap',
        'transmissionMap',
      ])
        name: gray,
      'emissive': 0x221100,
      'roughness': 0.4,
      'metalness': 0.3,
      'anisotropy': 0.6,
      'clearcoat': 0.7,
      'diffuseRoughness': 0.6,
      'iridescence': 0.8,
      'sheen': 0.6,
      'sheenColor': 0xffccaa,
      'transmission': 1.0,
      'thickness': 0.6,
      'dispersion': 3.0,
    });

    final behind = (await renderer.render(scene, camera).toByteData(format: ui.ImageByteFormat.rawRgba))!;
    scene.add(Mesh(PlaneGeometry(1.5, 1.5), material));
    renderer.recorded = {};
    final frame = (await renderer.render(scene, camera).toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final keys = renderer.recorded!;
    renderer.recorded = null;

    expect(keys, contains(widest), reason: 'the quad drawn through the widest variant, not a narrower one');

    // The quad covers pixels 8 to 55; its inner pixels must show it, not the halves behind.
    var drawn = 0;
    final means = <String>[];

    for (final (qx, qy) in [(12, 12), (32, 12), (12, 32), (32, 32)]) {
      final sum = [0, 0, 0];

      for (var y = qy; y < qy + 20; y++) {
        for (var x = qx; x < qx + 20; x++) {
          final i = (y * 64 + x) * 4;

          for (var c = 0; c < 3; c++) {
            sum[c] += frame.getUint8(i + c);
          }

          if ([0, 1, 2].any((c) => (frame.getUint8(i + c) - behind.getUint8(i + c)).abs() > 8)) {
            drawn++;
          }
        }
      }

      means.add('(${sum.map((v) => (v / 400).toStringAsFixed(1)).join(', ')})');
    }

    // Evidence for the report.
    // ignore: avoid_print
    print('widest physical variant: $drawn of 1600 inner pixels drawn; quadrant means ${means.join(' ')}');
    expect(drawn, greaterThan(1500), reason: 'the quad drawn over the halves');
  });
}
