// The parity comparison with the reference frames, shared by test/parity_test.dart (flutter_tester, which runs Impeller
// on Vulkan through SwiftShader) and examples/worm/integration_test/parity_metal_test.dart (a macOS app on Metal):
// every scene in fixtures/rendering/reference was drawn by the reference renderer in headless Chrome
// (tool/reference/render/render.mjs, metadata in meta.json). Each test loads the scene's JSON with ObjectLoader, draws
// it with a renderer (FlutterGpuRenderer unless [declare] is given another) and compares the frames.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:ent_flutter/ent_flutter.dart';
import 'package:ent_renderer/ent_renderer.dart' show FlutterImage, FlutterImagePlatform, GpuRenderer;
import 'package:ent_renderer/gpu.dart' as gpu;

/// Reads a repository file by its path from the repository root, such as `fixtures/rendering/reference/aa_basic.json`.
typedef Read = Future<Uint8List> Function(String path);

/// Creates the renderer a scene is drawn with.
typedef Create = Future<GpuRenderer> Function({bool antialias});

/// The default [Create]: a renderer on Flutter GPU.
Future<GpuRenderer> flutterGpu({bool antialias = false}) => FlutterGpuRenderer.create(antialias: antialias);

// Saves [texture]'s pixels to [failures] as `<frame>.png`.
Future<void> save(Directory failures, String frame, gpu.Texture texture) async {
  final image = FlutterImage.fromPixels(texture.width, texture.height, (await texture.read()).buffer.asUint8List());
  File('${failures.path}/$frame.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(UriData.parse(FlutterImagePlatform().getDataURL(image, 'image/png')).contentAsBytes());
}

// Per channel, out of 255: both sides run on the same GPU, but shader arithmetic may round differently.
const int tolerance = 2;

// Triangle edges may fall on the other side of a pixel centre: ANGLE draws WebGL upside down and flips the
// image, so ties on the fill rule and sub-pixel vertex snapping go the other way (a horizontal edge through
// pixel centres is a top edge there and a bottom edge here). A differing pixel is an edge pixel when our color
// appears within one pixel in the reference; edge pixels may make up this share of the frame, and any other
// differing pixel fails. The rule hides a missing or extra one-pixel feature (a line or point pixel always has
// neighbours of its color), so a scene may also cap the count (`edges` in its JSON, from scenes.mjs).
const double maxEdgeShare = 0.005;

// Scenes whose feature is ported but not drawn yet, with the gap that keeps it off.
const Map<String, String> skipped = {
  'khronos_box_textured':
      'Metal 2 wrong (3/255, NEAREST_MIPMAP_LINEAR: the GPU picks a slightly different level of detail, not the mip '
      'levels); SwiftShader 205 wrong (146/255)',
};

// Scenes that match the reference on Metal (parity_metal_test.dart) but not under flutter_tester's SwiftShader, which
// only parity_test.dart skips.
const Map<String, String> swiftShader = {
  'shadow_vsm_directional': 'SwiftShader differs (2 wrong, 3/255); checked on Metal',
  'shadow_vsm_spot': 'SwiftShader differs (44 wrong, 14/255, spot map silhouette texels); checked on Metal',
  'point_shadow_pcf': 'SwiftShader differs (penumbra 3–9/255); checked on Metal',
  'point_shadow_pcf_radius': 'SwiftShader differs (penumbra 3–9/255); checked on Metal',
  'hdr_environment_mirror': 'SwiftShader differs (7 wrong, 6/255, low-roughness rims); checked on Metal',
  'khronos_texture_coordinate': 'SwiftShader differs (161 wrong, 11/255, textured faces); checked on Metal',
  'khronos_texture_transform': 'SwiftShader differs (312 wrong, 122/255); checked on Metal',
  'khronos_vertex_color':
      'SwiftShader differs (252 wrong, 174/255, textured faces and frame borders); checked on Metal',
  'khronos_alpha_blend_mode': 'SwiftShader differs (96 wrong, 179/255); checked on Metal within [mipmaps]',
  'khronos_normal_tangent_mirror': 'SwiftShader differs (330 wrong, 69/255); checked on Metal within [mipmaps]',
  'khronos_clearcoat': 'SwiftShader differs (234 wrong, 65/255); checked on Metal within [mipmaps]',
  'khronos_transmission': 'SwiftShader differs (569 wrong, 185/255); checked on Metal within [mipmaps]',
  'khronos_cesium_man': 'SwiftShader differs (214–287 wrong per frame, up to 170/255); checked on Metal',
};

// Our frame's texture bytes as they are (Flutter treats GPU images as premultiplied and returns them
// unchanged).
Future<ByteData> rgba(ui.Image image) async {
  return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
}

// The raw bytes of a reference PNG as render.mjs writes it: 8-bit RGBA, filter type 0 on every row. Decoded
// here rather than by dart:ui, which premultiplies on decoding and loses the colors of texels whose alpha is 0
// (MeshDepthMaterial's RGBA packing writes such pixels).
ByteData png(Uint8List bytes, int size) {
  final data = BytesBuilder();
  var at = 8;

  while (at < bytes.length) {
    final view = ByteData.sublistView(bytes);
    final length = view.getUint32(at);
    final type = String.fromCharCodes(bytes.sublist(at + 4, at + 8));

    if (type == 'IDAT') {
      data.add(bytes.sublist(at + 8, at + 8 + length));
    }

    at += 12 + length;
  }

  final rows = zlib.decode(data.toBytes());
  final out = Uint8List(size * size * 4);

  for (var y = 0; y < size; y++) {
    final row = y * (size * 4 + 1);

    if (rows[row] != 0) {
      throw StateError('reference PNG row $y uses filter ${rows[row]}; render.mjs writes filter 0');
    }

    out.setRange(y * size * 4, (y + 1) * size * 4, rows, row + 1);
  }

  return out.buffer.asByteData();
}

bool close(ByteData a, int i, ByteData b, int j) {
  for (var c = 0; c < 4; c++) {
    if ((a.getUint8(i + c) - b.getUint8(j + c)).abs() > tolerance) {
      return false;
    }
  }

  return true;
}

/// Whether the pixel at ([x], [y]) of [a] matches [b] at the same place or one pixel away.
bool near(ByteData a, ByteData b, int x, int y, int size) {
  for (var dy = -1; dy <= 1; dy++) {
    for (var dx = -1; dx <= 1; dx++) {
      final nx = x + dx, ny = y + dy;

      if (nx >= 0 && ny >= 0 && nx < size && ny < size && close(a, (y * size + x) * 4, b, (ny * size + nx) * 4)) {
        return true;
      }
    }
  }

  return false;
}

// Exact ties in the reference's own arithmetic, recorded per frame: FXAAShader's edge search stops where abs(luminance
// - edgeLuminance) >= gradient * 0.25, and at the corner of a one-texel stair step the bilinear sample gives exactly
// gradient * 0.25 (a float64 run of the shader on the frame shows it at every differing pixel), so the rounding of the
// filter and of the compiled arithmetic picks the end; another end moves the blend by up to 42/255. Measured on an M1
// (2026-11-09): composer_fxaa, along its red line over the blue wedge, 3 such pixels away from an edge (worst 42) and 4
// within one; the input frame without the FXAAPass is equal to the reference's (0 wrong, 0 edge pixels).
const Map<String, ({int wrong, int worst})> ties = {'composer_fxaa': (wrong: 3, worst: 42)};

// Differences measured only on an iPhone 11 (A13, iOS 16.3.1, 2026-11-09), where they replace [ties]; the M1 draws
// these frames exactly (beyond [ties]), and the causes are unknown. composer_fxaa: 22 pixels at the stair corners of
// one slanted edge, worst 8 (perhaps the tie above, decided the other way). shadow_vsm_directional: 3, worst 5, as on
// 2026-11-07. shadow_vsm_spot: 27 in the penumbra, 2–6/255 lighter.
const Map<String, ({int wrong, int worst})> ios = {
  'composer_fxaa': (wrong: 22, worst: 8),
  'shadow_vsm_directional': (wrong: 3, worst: 5),
  'shadow_vsm_spot': (wrong: 27, worst: 6),
};

// Differences from mip levels, recorded per frame (exception E-MIPFILTER): we build them on the CPU, each texel the
// average of a 2 × 2 block (in linear light for sRGB textures), while the reference's generateMipmap runs in ANGLE on
// the GPU, whose levels differ from ours by ±1 on many texels and from every CPU rounding tried; the GL specification
// leaves the filter to the implementation. Measured on an M1 (2026-11-10): Chrome given our levels draws both frames
// within 1/255 of ours. khronos_normal_tangent_mirror: 202 pixels on the gold spheres' highlights, worst 18 (the glossy
// 2048² maps amplify a ±1 texel). khronos_alpha_blend_mode: 8 on the small far panels, worst 89. khronos_transmission:
// 3 at the green shapes' cutout edges, worst 119: the mask's alpha there is a tie at the 0.5 alphaTest (reference
// 0.4988, ours 0.5047), and with LinearFilter on both sides the frames are equal. khronos_clearcoat: 19 on the
// normal-mapped rows, worst 14; they match with every map on LinearFilter, but whether our levels or the GPU's choice
// of level makes the gap is not separated.
// They apply only to a renderer that builds mip levels on the CPU (Flutter GPU, which cannot generate them);
// OpenGlRenderer generates them on the GPU as the reference does, and its parity runs set mipmapAllowances: false.
const Map<String, ({int wrong, int worst})> mipmaps = {
  'khronos_normal_tangent_mirror': (wrong: 202, worst: 18),
  'khronos_alpha_blend_mode': (wrong: 8, worst: 89),
  'khronos_transmission': (wrong: 3, worst: 119),
  'khronos_clearcoat': (wrong: 19, worst: 14),
};

// Compares [image] with the reference `<frame>.png` and fails on a wrong pixel (beyond [ties]) or too many edge
// pixels; a failing frame is saved to [failures] when given.
Future<void> compare(
  String frame,
  gpu.Texture image,
  Map<String, Object?> data,
  Read read,
  Directory? failures, {
  bool mipmapAllowances = true,
}) async {
  final size = image.width;
  final actual = await image.read();
  final expected = png(await read('fixtures/rendering/reference/$frame.png'), size);
  expect([image.width, image.height], [data['size'], data['size']]);

  var edges = 0;
  var wrong = 0;
  var worst = 0;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < size; x++) {
      final i = (y * size + x) * 4;

      if (close(actual, i, expected, i)) {
        continue;
      }

      if (near(actual, expected, x, y, size)) {
        edges++;
        continue;
      }

      wrong++;

      for (var c = 0; c < 4; c++) {
        final d = (actual.getUint8(i + c) - expected.getUint8(i + c)).abs();
        worst = d > worst ? d : worst;
      }
    }
  }

  final share = edges / (size * image.height);
  final cap = (data['edges'] as int?) ?? edges;

  // Evidence for the report: how close the frame came.
  // ignore: avoid_print
  print('$frame: $wrong wrong pixels (worst channel difference $worst), $edges edge pixels');

  final tie =
      (Platform.isIOS ? ios[frame] : null) ??
      ties[frame] ??
      (mipmapAllowances ? mipmaps[frame] : null) ??
      (wrong: 0, worst: 255);

  if (failures != null && (wrong > tie.wrong || worst > tie.worst || share > maxEdgeShare || edges > cap)) {
    await save(failures, frame, image);
  }

  expect(
    wrong,
    lessThanOrEqualTo(tie.wrong),
    reason: '$frame: pixels differing by more than $tolerance/255 away from an edge',
  );
  expect(worst, lessThanOrEqualTo(tie.worst), reason: '$frame: worst difference of a tied pixel');
  expect(share, lessThanOrEqualTo(maxEdgeShare), reason: '$frame: share of edge pixels');
  expect(edges, lessThanOrEqualTo(cap), reason: '$frame: edge pixels over the scene\'s cap');
}

// Antialiased scenes (scenes.mjs `antialias`, exception E-ANTIALIAS): MSAA sample positions and the resolve belong to
// the GPU, and ANGLE mirrors the pattern vertically, so pixels within one pixel of a geometric edge (where our frame
// without antialias differs from ours with it) may differ from the reference by up to `tolerance`/255, and at most
// `edges` of them may differ by more than the normal 2/255; the rest of the frame keeps the normal rule. MSAA must have
// happened: at least `blended` pixels of our frame have a color found nowhere in the 3×3 neighbourhood of the frame
// without antialias (that frame has none such by definition).
//
// Measured on an M1 (2026-11-09): aa_basic 462 such pixels, worst 119/255 (lines 269, worst 119; triangle edges
// 193, worst 102, median 47: about one of four samples of a 220/255 contrast), 431 blended (Chrome 598);
// aa_standard 129, worst 47, 298 blended (Chrome 289). The caps leave about 10% room; `blended` is about half the
// measured count. Render targets with samples (E2) resolve in linear color and the frame then applies the sRGB
// transfer, which turns a one- or two-sample difference against a dark color into up to about 190/255:
// rt_samples (8-bit target) 486, worst 175, 431 blended (Chrome 598); composer_samples (HalfFloatType targets)
// 462, worst 188, 431 blended (Chrome 598).
const Map<String, ({int tolerance, int edges, int blended})> antialiased = {
  'aa_basic': (tolerance: 128, edges: 510, blended: 200),
  'aa_standard': (tolerance: 64, edges: 145, blended: 150),
  'rt_samples': (tolerance: 200, edges: 535, blended: 200),
  'composer_samples': (tolerance: 200, edges: 510, blended: 200),
};

int difference(ByteData a, ByteData b, int i) {
  var d = 0;

  for (var c = 0; c < 4; c++) {
    d = math.max(d, (a.getUint8(i + c) - b.getUint8(i + c)).abs());
  }

  return d;
}

// Compares the antialiased [image] with the reference `<frame>.png` by the rule of [antialiased], [plain] being the
// same scene drawn without antialias; a failing frame is saved to [failures] when given.
Future<void> compareAntialiased(
  String frame,
  gpu.Texture image,
  gpu.Texture plain,
  Read read,
  Directory? failures,
) async {
  final size = image.width;
  final actual = await image.read();
  final flat = await plain.read();
  final expected = png(await read('fixtures/rendering/reference/$frame.png'), size);
  final rule = antialiased[frame]!;

  // Pixels within one pixel of one where antialias changed our frame.
  final zone = List.filled(size * size, false);

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      if (difference(actual, flat, (y * size + x) * 4) > tolerance) {
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (x + dx >= 0 && y + dy >= 0 && x + dx < size && y + dy < size) {
              zone[(y + dy) * size + x + dx] = true;
            }
          }
        }
      }
    }
  }

  var (edges, near1, wrong, worst, edgeWorst, blended, reference) = (0, 0, 0, 0, 0, 0, 0);

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final i = (y * size + x) * 4;

      if (!near(actual, flat, x, y, size)) {
        blended++;
      }

      if (!near(expected, flat, x, y, size)) {
        reference++;
      }

      final d = difference(actual, expected, i);

      if (d <= tolerance) {
        continue;
      }

      if (zone[y * size + x] && d <= rule.tolerance) {
        edges++;
        edgeWorst = math.max(edgeWorst, d);
      } else if (!zone[y * size + x] && near(actual, expected, x, y, size)) {
        near1++;
      } else {
        wrong++;
        worst = math.max(worst, d);
      }
    }
  }

  final share = near1 / (size * size);

  // Evidence for the report: how close the frame came, and how much MSAA blended here and in Chrome.
  // ignore: avoid_print
  print(
    '$frame: $wrong wrong pixels (worst channel difference $worst), $edges antialiased edge pixels (worst '
    '$edgeWorst), $near1 edge pixels, $blended blended pixels (Chrome $reference)',
  );

  if (failures != null && (wrong > 0 || share > maxEdgeShare || edges > rule.edges || blended < rule.blended)) {
    await save(failures, frame, image);
  }

  expect(wrong, 0, reason: '$frame: pixels differing by more than the antialias rule allows');
  expect(share, lessThanOrEqualTo(maxEdgeShare), reason: '$frame: share of edge pixels');
  expect(edges, lessThanOrEqualTo(rule.edges), reason: '$frame: antialiased edge pixels over the scene\'s cap');
  expect(blended, greaterThanOrEqualTo(rule.blended), reason: '$frame: too few blended pixels; did MSAA happen?');
}

/// Declares a test for each scene of [names] (reference JSON names without `.json`), sorted, reading the
/// references through [read]; [skip] gives the reason a scene is skipped, a scene of [measure] is drawn and compared
/// but marked skipped instead of failing, and a failing frame is saved to [failures] when given.
void declare(
  Iterable<String> names,
  Read read, {
  Map<String, String> skip = const {},
  Map<String, String> measure = const {},
  Directory? failures,
  Create create = flutterGpu,
  bool mipmapAllowances = true,
}) {
  setUpAll(FlutterPlatform.install);

  for (final name in names.toList()..sort()) {
    test(name, () async {
      try {
        final data =
            jsonDecode(utf8.decode(await read('fixtures/rendering/reference/$name.json'))) as Map<String, Object?>;
        final scene = await ObjectLoader().parseAsync((data['scene']! as Map).cast<String, Object?>());
        final camera = ObjectLoader().parse((data['camera']! as Map).cast<String, Object?>()) as Camera;

        // A glTF asset (scenes.mjs `gltf`): page.html adds the reference's GLTFLoader result last, its clips on its
        // scene; the Dart GLTFLoader loads the same file here. The buffers and images a .gltf names by URI are read
        // through [read] too and reach the loader as data URLs through its manager.
        if (data['gltf'] case final String url) {
          final bytes = await read(url.substring(1));
          final base = url.substring(1, url.lastIndexOf('/') + 1);
          final files = <String, String>{};

          if (url.endsWith('.gltf')) {
            final json = jsonDecode(utf8.decode(bytes)) as Map;

            for (final entry in [...?json['buffers'] as List?, ...?json['images'] as List?]) {
              if ((entry as Map)['uri'] case final String uri when !uri.startsWith('data:')) {
                files[base + uri] = UriData.fromBytes(await read(base + uri)).toString();
              }
            }
          }

          final gltf = await GLTFLoader(LoadingManager()..setURLModifier((url) => files[url] ?? url))
              .parseAsync(bytes.buffer, base);
          scene.add(gltf.scene!..animations = gltf.animations);
        }

        // An RGBE image (scenes.mjs `hdr`): page.html loads it with the reference's HDRLoader as scene.environment and
        // background; the Dart HDRLoader parses the same file here.
        if (data['hdr'] case final Map hdr) {
          final texture =
              HDRLoader()
                  .setDataType((hdr['type'] as int?) ?? HalfFloatType)
                  .createDataTexture((await read((hdr['url']! as String).substring(1))).buffer)
                ..mapping = EquirectangularReflectionMapping;
          (scene as Scene)
            ..environment = texture
            ..background = texture;
        }
        final clear = data['clear']! as List;
        final size = (data['size']! as num).toDouble();
        final options = (data['renderer'] as Map?) ?? {};
        final shadows = (options['shadowMap'] as Map?) ?? {};

        // The reference renderer's properties the scene set; the rest keep their defaults.
        GpuRenderer configured(GpuRenderer renderer) => renderer
          ..setSize(size, size)
          ..setClearColor(clear[0] as int, (clear[1] as num).toDouble())
          ..toneMapping = (options['toneMapping'] as int?) ?? NoToneMapping
          ..toneMappingExposure = (options['toneMappingExposure'] as num?)?.toDouble() ?? 1
          ..outputColorSpace = (options['outputColorSpace'] as String?) ?? SRGBColorSpace
          ..sortObjects = (options['sortObjects'] as bool?) ?? true
          ..shadowMap.enabled = (shadows['enabled'] as bool?) ?? false
          ..shadowMap.type = (shadows['type'] as int?) ?? PCFShadowMap
          ..distanceLight = data['distance'] == null
              ? null
              : scene.getObjectByProperty('uuid', data['distance']! as String) as PointLight;

        // A renderer per scene: a test that timed out keeps running, and must not reconfigure the next one's.
        final antialias = data['antialias'] == true;
        final renderer = configured(await create(antialias: antialias));
        addTearDown(renderer.dispose);

        // Per-instance morph influences (scenes.mjs `instanced`'s `morphs`): toJSON drops InstancedMesh.morphTexture.
        scene.traverse((object) {
          if (object case InstancedMesh(userData: {'morphs': final List morphs})) {
            for (final (i, influences) in morphs.indexed) {
              object.setMorphAt(
                i,
                Mesh()..morphTargetInfluences = [for (final v in influences as List) (v as num).toDouble()],
              );
            }

            object.morphTexture!.needsUpdate = true;
          }
        });

        // A render target pass first (scenes.mjs `target`): its texture is the map of the materials marked
        // `userData.renderTarget`, its `depthTexture` that of the materials marked `userData.depthTexture`, as
        // page.html sets them. [plain] drops the target's samples (the frame without MSAA
        // of the `antialiased` rule).
        Future<void> pass(GpuRenderer renderer, {bool plain = false}) async {
          if (data['target'] case final Map pass) {
            final options = {...(pass['options'] as Map).cast<String, Object?>(), if (plain) 'samples': 0};
            final [width, height] = (pass['size'] as List).cast<int>();
            final target = WebGLRenderTarget(width, height, options);
            final own = pass['clear'] as List;
            addTearDown(target.dispose);

            if (pass['depthTexture'] case final Map depth) {
              target.depthTexture = DepthTexture(width, height, depth['type'] as int? ?? UnsignedIntType)
                ..format = depth['format'] as int? ?? DepthFormat;
            }

            renderer
              ..setClearColor(own[0] as int, (own[1] as num).toDouble())
              ..setRenderTarget(target)
              ..render(
                await ObjectLoader().parseAsync((pass['scene'] as Map).cast<String, Object?>()),
                ObjectLoader().parse((pass['camera'] as Map).cast<String, Object?>()) as Camera,
              )
              ..setRenderTarget(null)
              ..setClearColor(clear[0] as int, (clear[1] as num).toDouble());

            scene.traverse((object) {
              if (object case Mesh(material: final MeshBasicMaterial m) when m.userData['renderTarget'] == true) {
                m.map = target.texture;
              }

              if (object case Mesh(material: final MeshBasicMaterial m) when m.userData['depthTexture'] == true) {
                m.map = target.depthTexture;
              }
            });
          }
        }

        await pass(renderer);

        // A CubeCamera pass (scenes.mjs `cube`): updated once with the meshes marked `userData.cubeTarget` hidden,
        // whose envMap becomes the target's texture, as page.html does.
        if (data['cube'] case final Map pass) {
          final target = WebGLCubeRenderTarget(pass['size'] as int, (pass['options'] as Map).cast<String, Object?>());
          final cube = CubeCamera((pass['near'] as num).toDouble(), (pass['far'] as num).toDouble(), target);
          final reflective = <Mesh>[];
          final [x, y, z] = (pass['position'] as List).cast<num>();
          addTearDown(target.dispose);
          cube.position.set(x.toDouble(), y.toDouble(), z.toDouble());

          scene.traverse((object) {
            if (object case Mesh(material: final Material m) when m.userData['cubeTarget'] == true) {
              reflective.add(object);
            }
          });

          for (final object in reflective) {
            object.visible = false;
          }

          cube.update(renderer, scene);

          for (final object in reflective) {
            object.visible = true;

            switch (object.material) {
              case final MeshBasicMaterial m:
                m.envMap = target.texture;
              case final MeshStandardMaterial m:
                m.envMap = target.texture;
            }
          }
        }

        // An animated scene (scenes.mjs `animate`): its objects' clips, read by ObjectLoader from `animations`, play
        // in one mixer as page.html plays them, and each time is a frame of its own, <name>@<time>.png.
        if (data['animate'] case final Map animate) {
          final mixer = AnimationMixer(scene);
          final actions = (animate['actions'] as Map?) ?? {};

          scene.traverse((object) {
            for (final clip in object.animations.cast<AnimationClip>()) {
              final options = (actions[clip.name] as Map?) ?? {};
              final action = mixer.clipAction(clip, object)!
                ..setLoop((options['loop'] as int?) ?? LoopRepeat, double.infinity)
                ..setEffectiveWeight((options['weight'] as num?)?.toDouble() ?? 1)
                ..setEffectiveTimeScale((options['timeScale'] as num?)?.toDouble() ?? 1);

              if (options['fadeIn'] case final num duration) {
                action.fadeIn(duration.toDouble());
              }

              if (options['fadeOut'] case final num duration) {
                action.fadeOut(duration.toDouble());
              }

              action.play();
            }
          });

          for (final time in (animate['times'] as List).cast<num>()) {
            mixer.setTime(time.toDouble());
            await compare(
              '$name@$time',
              renderer.draw(scene, camera),
              data,
              read,
              failures,
              mipmapAllowances: mipmapAllowances,
            );
          }
        } else if (data['composer'] case final Map composer) {
          // An EffectComposer frame (scenes.mjs `composer`): a RenderPass, an FXAAPass with `fxaa`, a VignettePass with
          // the `vignette` values, a CopyPass with the `copy` opacity and a TuningPass with the `bloom` settings when
          // given, and an OutputPass; the last pass draws the frame. With `samples` its targets
          // are HalfFloatType targets of the frame's size with them ([plain]: without).
          gpu.Texture draw(GpuRenderer renderer, {bool plain = false}) {
            final samples = plain ? 0 : (composer['samples'] as int?) ?? 0;
            final effects = samples == 0
                ? EffectComposer(renderer)
                : EffectComposer(
                    renderer,
                    WebGLRenderTarget(size.toInt(), size.toInt(), {'type': HalfFloatType, 'samples': samples}),
                  );
            effects.addPass(RenderPass(scene, camera));

            if (composer['fxaa'] == true) {
              effects.addPass(FXAAPass());
            }

            if (composer['vignette'] case final Map values) {
              effects.addPass(
                VignettePass()
                  ..material.offset = (values['offset'] as num).toDouble()
                  ..material.darkness = (values['darkness'] as num).toDouble(),
              );
            }

            if (composer['copy'] case final num opacity) {
              effects.addPass(CopyPass()..material.opacity = opacity.toDouble());
            }

            if (composer['bloom'] case final Map bloom) {
              final pass = TuningPass(
                Vector2(size, size),
                (bloom['strength'] as num).toDouble(),
                (bloom['radius'] as num).toDouble(),
                (bloom['threshold'] as num).toDouble(),
              );

              for (final (i, tint) in ((bloom['tints'] as List?) ?? []).indexed) {
                pass.bloomTintColors[i].fromArray([for (final c in tint as List) (c as num).toDouble()]);
              }

              effects.addPass(pass);
            }

            effects
              ..addPass(OutputPass())
              ..render(0);
            addTearDown(effects.dispose);

            return renderer.frame!;
          }

          if (antialiased.containsKey(name)) {
            final plain = configured(await create());
            addTearDown(plain.dispose);
            await compareAntialiased(name, draw(renderer), draw(plain, plain: true), read, failures);
          } else {
            await compare(name, draw(renderer), data, read, failures, mipmapAllowances: mipmapAllowances);
          }
        } else if (data['views'] case final Map views) {
          // A frame drawn in views (scenes.mjs `views`), as page.html draws it: per view the viewport, the scissor
          // (default the viewport), the scissor test, the clear color, clear() or clearDepth(), and the scene or the
          // overlay's; the last render's image shows them all.
          final overlay = data['overlay']! as Map;
          final (other, view) = (
            await ObjectLoader().parseAsync((overlay['scene'] as Map).cast<String, Object?>()),
            ObjectLoader().parse((overlay['camera'] as Map).cast<String, Object?>()) as Camera,
          );
          renderer.autoClear = views['autoClear'] as bool;
          late gpu.Texture image;

          for (final step in (views['list'] as List).cast<Map>()) {
            final [x, y, w, h] = [for (final v in (step['scissor'] ?? step['viewport']) as List) (v as num).toDouble()];
            final at = Vector4().fromArray([for (final v in step['viewport'] as List) (v as num).toDouble()]);
            renderer
              ..setViewport(at)
              ..setScissor(x, y, w, h)
              ..setScissorTest((step['scissorTest'] as bool?) ?? false);

            if (step['color'] case [final int color, final num alpha]) {
              renderer.setClearColor(color, alpha.toDouble());
            }

            switch (step['clear']) {
              case 'all':
                renderer.clear();
              case 'depth':
                renderer.clearDepth();
            }

            image = step['overlay'] == true ? renderer.draw(other, view) : renderer.draw(scene, camera);
          }

          await compare(name, image, data, read, failures, mipmapAllowances: mipmapAllowances);
        } else if (data['overlay'] case final Map overlay) {
          // An overlay drawn into the same frame (scenes.mjs `overlay`), as page.html draws it: autoClear off, clear,
          // the scene, clearDepth when `clearDepth` is set, the overlay; the last render's image shows both.
          renderer
            ..autoClear = false
            ..clear()
            ..render(scene, camera);

          if (overlay['clearDepth'] == true) {
            renderer.clearDepth();
          }

          final image = renderer.draw(
            await ObjectLoader().parseAsync((overlay['scene'] as Map).cast<String, Object?>()),
            ObjectLoader().parse((overlay['camera'] as Map).cast<String, Object?>()) as Camera,
          );
          await compare(name, image, data, read, failures, mipmapAllowances: mipmapAllowances);
        } else if (antialiased.containsKey(name)) {
          // The same scene without antialias (and a render target pass without samples) marks the geometric edges
          // and shows that MSAA blended them.
          final image = renderer.draw(scene, camera);
          final plain = configured(await create());
          addTearDown(plain.dispose);
          await pass(plain, plain: true);
          await compareAntialiased(name, image, plain.draw(scene, camera), read, failures);
        } else {
          await compare(name, renderer.draw(scene, camera), data, read, failures, mipmapAllowances: mipmapAllowances);
        }
      } on TestFailure catch (e) {
        if (!measure.containsKey(name)) {
          rethrow;
        }

        markTestSkipped('${measure[name]} (measured: ${e.message})');
      }
    }, skip: skip[name]);
  }
}
