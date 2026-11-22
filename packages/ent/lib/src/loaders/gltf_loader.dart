part of '../../ent.dart';

// GLTFLoader: glTF JSON and GLB, buffers, buffer views, accessors (interleaved, sparse, normalized), meshes and
// primitives (triangles, strips, fans, lines, line strips and loops, points), materials (metallic-roughness,
// KHR_materials_unlit, the PBR extension plugins), textures, images and samplers (KHR_texture_transform,
// EXT_texture_webp, EXT_texture_avif), nodes, cameras, KHR_lights_punctual, scenes, skins, morph targets and animations
// (with the CUBICSPLINE interpolants). Not ported, each marked where it plugs in: Draco, meshopt, KTX2
// (KHR_texture_basisu) and EXT_mesh_gpu_instancing. Promises are futures (exception E-GLTF).

/// The result of [GLTFLoader.parse].
class GLTF {
  /// Constructs a new result with the given scenes, animations, cameras, asset and parser.
  GLTF({
    required this.scene,
    required this.scenes,
    required this.animations,
    required this.cameras,
    required this.asset,
    required this.parser,
  });

  /// The default scene.
  Group? scene;

  /// The glTF assets scenes.
  List<Group> scenes;

  /// The glTF animations.
  List<AnimationClip> animations;

  /// The glTF cameras.
  List<Camera?> cameras;

  /// Meta data about the asset.
  Map<String, Object?> asset;

  /// The glTF parser.
  GLTFParser parser;

  /// Extras and unknown extensions of the root.
  Map<String, Object?> userData = {};
}

/// A factory for the material a glTF material becomes: the reference returns the class (`MeshStandardMaterial`), here
/// its constructor tear-off (`MeshStandardMaterial.new`), which compares equal to itself.
typedef GLTFMaterialType = Material Function([Map<String, Object?>? parameters]);

/// The hooks a [GLTFLoader] plugin may implement (a duck-typed object in the reference). Each returns `null` when the
/// plugin does not handle the call (in the reference, the method is missing or returns a falsy value).
abstract class GLTFLoaderPlugin {
  /// The extension name the plugin handles.
  String get name;

  /// Marks the definitions it uses before the root is parsed.
  void _markDefs() {}

  /// Called before the root is parsed.
  Future<void>? beforeRoot() => null;

  /// Called with the result before `onLoad`.
  Future<void>? afterRoot(GLTF result) => null;

  /// Loads a node.
  Future<Object3D>? loadNode(int nodeIndex) => null;

  /// Loads a mesh.
  Future<Object3D>? loadMesh(int meshIndex) => null;

  /// Loads a buffer view.
  Future<ByteBuffer>? loadBufferView(int bufferViewIndex) => null;

  /// Loads a material.
  Future<Material>? loadMaterial(int materialIndex) => null;

  /// Loads a texture.
  Future<Texture?>? loadTexture(int textureIndex) => null;

  /// Loads an animation.
  Future<AnimationClip>? loadAnimation(int animationIndex) => null;

  /// Loads a dependency of a type the parser does not know (`'light'`).
  Future<Object?>? getDependency(String type, int index) => null;

  /// The material type of a material.
  GLTFMaterialType? getMaterialType(int materialIndex) => null;

  /// Adds the extension's parameters to a material's.
  Future<void>? extendMaterialParams(int materialIndex, Map<String, Object?> materialParams) => null;

  /// Creates the mesh of a node.
  Future<Object3D>? createNodeMesh(int nodeIndex) => null;

  /// Creates an object attached to a node (a light).
  Future<Object3D>? createNodeAttachment(int nodeIndex) => null;
}

/// A plugin factory: it makes the plugin for a parser.
typedef GLTFPluginCallback = GLTFLoaderPlugin Function(GLTFParser parser);

/// A loader for the glTF 2.0 format.
///
/// [glTF](https://www.khronos.org/gltf/) (GL Transmission Format) is an open format specification for efficient
/// delivery and loading of 3D content. Assets may be provided either in JSON (.gltf) or binary (.glb) format.
/// External files store textures (.jpg, .png) and additional binary data (.bin). A glTF asset may deliver one or
/// more scenes, including meshes, materials, textures, skins, skeletons, morph targets, animations, lights,
/// and/or cameras.
///
/// In this port: meshes, lines and points, materials with textures, nodes, cameras, punctual lights, scenes,
/// skins, morph targets and animations; not Draco, meshopt, KTX2 or GPU instancing.
class GLTFLoader extends Loader<GLTF> {
  /// Constructs a new glTF loader.
  GLTFLoader([super.manager]) {
    register(_GLTFMaterialsClearcoatExtension.new);
    register(_GLTFMaterialsDiffuseRoughnessExtension.new);
    register(_GLTFMaterialsDispersionExtension.new);
    register(_GLTFTextureBasisUExtension.new);
    register(_GLTFTextureWebPExtension.new);
    register(_GLTFTextureAVIFExtension.new);
    register(_GLTFMaterialsSheenExtension.new);
    register(_GLTFMaterialsTransmissionExtension.new);
    register(_GLTFMaterialsVolumeExtension.new);
    register(_GLTFMaterialsIorExtension.new);
    register(_GLTFMaterialsEmissiveStrengthExtension.new);
    register(_GLTFMaterialsSpecularExtension.new);
    register(_GLTFMaterialsIridescenceExtension.new);
    register(_GLTFMaterialsAnisotropyExtension.new);
    register(_GLTFMaterialsBumpExtension.new);

    register(_GLTFLightsExtension.new);

    // Meshopt (EXT_ and KHR_meshopt_compression) and GPU instancing come here in the reference: not ported.
  }

  /// The Draco loader (not ported: `KHR_draco_mesh_compression` is an exception).
  Object? dracoLoader;

  /// The KTX2 loader (not ported).
  Object? ktx2Loader;

  /// The meshopt decoder (not ported).
  Object? meshoptDecoder;

  /// The registered plugin callbacks.
  final List<GLTFPluginCallback> pluginCallbacks = [];

  /// Starts loading from the given URL and passes the loaded glTF asset to the [onLoad] callback.
  ///
  /// [url] is the path/URL of the file to be loaded. This can also be a data URI.
  @override
  void load(
    covariant String url, [
    void Function(GLTF data)? onLoad,
    LoaderProgressCallback? onProgress,
    LoaderErrorCallback? onError,
  ]) {
    String resourcePath;

    if (this.resourcePath != '') {
      resourcePath = this.resourcePath;
    } else if (path != '') {
      // If a base path is set, resources will be relative paths from that plus the relative path of the gltf file
      // Example  path = 'https://my-cnd-server.com/', url = 'assets/models/model.gltf'
      // resourcePath = 'https://my-cnd-server.com/assets/models/'
      // referenced resource 'model.bin' will be loaded from 'https://my-cnd-server.com/assets/models/model.bin'
      // referenced resource '../textures/texture.png' will be loaded from
      // 'https://my-cnd-server.com/assets/textures/texture.png'
      resourcePath = LoaderUtils.resolveURL(LoaderUtils.extractUrlBase(url), path);
    } else {
      resourcePath = LoaderUtils.extractUrlBase(url);
    }

    // Tells the LoadingManager to track an extra item, which resolves after
    // the model is fully loaded. This means the count of items loaded will
    // be incorrect, but ensures manager.onLoad() does not fire early.
    manager.itemStart(url);

    void onFailure(Object e) {
      if (onError != null) {
        onError(e);
      } else {
        error(e);
      }

      manager.itemError(url);
      manager.itemEnd(url);
    }

    final loader = FileLoader(manager);
    loader.setPriority(priority);
    loader.setCache(cache);

    loader.setPath(path);
    loader.setResponseType('arraybuffer');
    loader.setRequestHeader(requestHeader);
    loader.setWithCredentials(withCredentials);

    loader.load(
      url,
      (data) {
        try {
          parse(data!, resourcePath, (gltf) {
            onLoad?.call(gltf);

            manager.itemEnd(url);
          }, onFailure);
        } catch (e) {
          onFailure(e);
        }
      },
      onProgress,
      onFailure,
    );
  }

  /// Sets the given Draco loader to this loader (not ported; kept for the API shape).
  GLTFLoader setDRACOLoader(Object? dracoLoader) {
    this.dracoLoader = dracoLoader;
    return this;
  }

  /// Sets the given KTX2 loader to this loader (not ported; kept for the API shape).
  GLTFLoader setKTX2Loader(Object? ktx2Loader) {
    this.ktx2Loader = ktx2Loader;
    return this;
  }

  /// Sets the given meshopt decoder (not ported; kept for the API shape).
  GLTFLoader setMeshoptDecoder(Object? meshoptDecoder) {
    this.meshoptDecoder = meshoptDecoder;
    return this;
  }

  /// Registers a plugin callback. This API is internally used to implement the various glTF extensions but can
  /// also used by third-party code to add additional logic to the loader.
  GLTFLoader register(GLTFPluginCallback callback) {
    if (!pluginCallbacks.contains(callback)) {
      pluginCallbacks.add(callback);
    }

    return this;
  }

  /// Unregisters a plugin callback.
  GLTFLoader unregister(GLTFPluginCallback callback) {
    pluginCallbacks.remove(callback);

    return this;
  }

  /// Parses the given glTF data and returns the resulting group.
  ///
  /// [data] is the raw glTF data: a JSON `String`, a `ByteBuffer` (glTF JSON or GLB) or the decoded JSON map.
  /// [path] is the URL base path.
  @override
  void parse(
    covariant Object data, [
    String path = '',
    void Function(GLTF gltf)? onLoad,
    LoaderErrorCallback? onError,
  ]) {
    Map<String, Object?> json;
    final extensions = <String, Object?>{};
    final plugins = <String, GLTFLoaderPlugin>{};

    if (data is String) {
      json = (jsonDecode(data) as Map).cast<String, Object?>();
    } else if (data is ByteBuffer) {
      final magic = utf8.decode(data.asUint8List(0, 4), allowMalformed: true);

      if (magic == _gltfBinaryExtensionHeaderMagic) {
        try {
          extensions[_GLTFExtensions.KHR_BINARY_GLTF] = _GLTFBinaryExtension(data);
        } catch (error) {
          onError?.call(error);
          return;
        }

        json = (jsonDecode((extensions[_GLTFExtensions.KHR_BINARY_GLTF]! as _GLTFBinaryExtension).content!) as Map)
            .cast<String, Object?>();
      } else {
        json = (jsonDecode(utf8.decode(data.asUint8List(), allowMalformed: true)) as Map).cast<String, Object?>();
      }
    } else {
      json = (data as Map).cast<String, Object?>();
    }

    final asset = json['asset'];

    if (asset is! Map || _gltfMajorVersion(asset['version']) < 2) {
      onError?.call(EntError('ENT.GLTFLoader: Unsupported asset. glTF versions >=2.0 are supported.'));
      return;
    }

    final parser = GLTFParser(
      json,
      GLTFParserOptions(
        path: path != '' ? path : resourcePath,
        crossOrigin: crossOrigin,
        priority: priority,
        cache: cache,
        withCredentials: withCredentials,
        requestHeader: requestHeader,
        manager: manager,
        ktx2Loader: ktx2Loader,
        meshoptDecoder: meshoptDecoder,
      ),
    );

    parser.fileLoader.setRequestHeader(requestHeader);

    for (var i = 0; i < pluginCallbacks.length; i++) {
      final plugin = pluginCallbacks[i](parser);

      if (plugin.name == '') {
        error('GLTFLoader: Invalid plugin found: missing name');
      }

      plugins[plugin.name] = plugin;

      // Workaround to avoid determining as unknown extension
      // in addUnknownExtensionsToUserData().
      // Remove this workaround if we move all the existing
      // extension handlers to plugin system
      extensions[plugin.name] = true;
    }

    if (json['extensionsUsed'] case final List<Object?> used) {
      for (var i = 0; i < used.length; ++i) {
        final extensionName = used[i] as String;
        final extensionsRequired = (json['extensionsRequired'] as List<Object?>?) ?? const [];

        switch (extensionName) {
          case _GLTFExtensions.KHR_MATERIALS_UNLIT:
            extensions[extensionName] = _GLTFMaterialsUnlitExtension();

          case _GLTFExtensions.KHR_MESH_QUANTIZATION:
            extensions[extensionName] = _GLTFMeshQuantizationExtension();

          case _GLTFExtensions.KHR_TEXTURE_TRANSFORM:
            extensions[extensionName] = _GLTFTextureTransformExtension();

          // KHR_draco_mesh_compression is not ported: it falls through to the unknown-extension warning when
          // required.

          default:
            if (extensionsRequired.contains(extensionName) && !plugins.containsKey(extensionName)) {
              warn('GLTFLoader: Unknown extension "$extensionName".');
            }
        }
      }
    }

    parser.setExtensions(extensions);
    parser.setPlugins(plugins);
    parser.parse(onLoad ?? (_) {}, onError ?? error);
  }

  /// Async version of [parse].
  Future<GLTF> parseAsync(Object data, [String path = '']) {
    final completer = Completer<GLTF>();

    parse(data, path, completer.complete, completer.completeError);

    return completer.future;
  }
}

/// `json.asset.version[ 0 ]` compared with a number: the first character of the version string.
int _gltfMajorVersion(Object? version) {
  if (version is! String || version.isEmpty) {
    return -1;
  }

  return int.tryParse(version[0]) ?? -1;
}

/* GLTFREGISTRY */

/// The parser's object cache.
class GLTFRegistry {
  Map<String, Object?> _objects = {};

  /// The object stored under [key], or `null`.
  Object? get(String key) {
    return _objects[key];
  }

  /// Stores [object] under [key].
  void add(String key, Object? object) {
    _objects[key] = object;
  }

  /// Removes the object stored under [key].
  void remove(String key) {
    _objects.remove(key);
  }

  /// Removes every object.
  void removeAll() {
    _objects = {};
  }
}

// EXTENSIONS

Map<String, Object?>? _gltfGetMaterialExtension(GLTFParser parser, int materialIndex, String extensionName) {
  final materialDef = _gltfMap(_gltfList(parser.json['materials'])[materialIndex]);

  if (materialDef['extensions'] case final Map<Object?, Object?> extensions when extensions[extensionName] != null) {
    return _gltfMap(extensions[extensionName]);
  }

  return null;
}

/// The extension names.
abstract final class _GLTFExtensions {
  static const KHR_BINARY_GLTF = 'KHR_binary_glTF';
  static const KHR_DRACO_MESH_COMPRESSION = 'KHR_draco_mesh_compression';
  static const KHR_LIGHTS_PUNCTUAL = 'KHR_lights_punctual';
  static const KHR_MATERIALS_CLEARCOAT = 'KHR_materials_clearcoat';
  static const KHR_MATERIALS_DIFFUSE_ROUGHNESS = 'KHR_materials_diffuse_roughness';
  static const KHR_MATERIALS_DISPERSION = 'KHR_materials_dispersion';
  static const KHR_MATERIALS_IOR = 'KHR_materials_ior';
  static const KHR_MATERIALS_SHEEN = 'KHR_materials_sheen';
  static const KHR_MATERIALS_SPECULAR = 'KHR_materials_specular';
  static const KHR_MATERIALS_TRANSMISSION = 'KHR_materials_transmission';
  static const KHR_MATERIALS_IRIDESCENCE = 'KHR_materials_iridescence';
  static const KHR_MATERIALS_ANISOTROPY = 'KHR_materials_anisotropy';
  static const KHR_MATERIALS_UNLIT = 'KHR_materials_unlit';
  static const KHR_MATERIALS_VOLUME = 'KHR_materials_volume';
  static const KHR_TEXTURE_BASISU = 'KHR_texture_basisu';
  static const KHR_TEXTURE_TRANSFORM = 'KHR_texture_transform';
  static const KHR_MESH_QUANTIZATION = 'KHR_mesh_quantization';
  static const KHR_MATERIALS_EMISSIVE_STRENGTH = 'KHR_materials_emissive_strength';
  static const EXT_MATERIALS_BUMP = 'EXT_materials_bump';
  static const EXT_TEXTURE_WEBP = 'EXT_texture_webp';
  static const EXT_TEXTURE_AVIF = 'EXT_texture_avif';
}

/// The instance cache of objects that nodes share: references and uses per index.
class GLTFRefCache {
  /// How many nodes reference each index.
  final Map<int, int> refs = {};

  /// How many of those references were used so far.
  final Map<int, int> uses = {};
}

/// Punctual Lights Extension
///
/// Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_lights_punctual
class _GLTFLightsExtension extends GLTFLoaderPlugin {
  _GLTFLightsExtension(this.parser);

  final GLTFParser parser;

  @override
  final String name = _GLTFExtensions.KHR_LIGHTS_PUNCTUAL;

  // Object3D instance caches
  final GLTFRefCache cache = GLTFRefCache();

  @override
  void _markDefs() {
    final parser = this.parser;
    final nodeDefs = _gltfList(this.parser.json['nodes']);

    for (var nodeIndex = 0, nodeLength = nodeDefs.length; nodeIndex < nodeLength; nodeIndex++) {
      final nodeDef = _gltfMap(nodeDefs[nodeIndex]);

      if (nodeDef['extensions'] case final Map<Object?, Object?> extensions) {
        if (extensions[name] case final Map<Object?, Object?> light when light['light'] != null) {
          parser._addNodeRef(cache, light['light'] as int);
        }
      }
    }
  }

  Future<Light> _loadLight(int lightIndex) {
    final parser = this.parser;
    final cacheKey = 'light:$lightIndex';
    final cached = parser.cache.get(cacheKey);

    if (cached != null) {
      return cached as Future<Light>;
    }

    final json = parser.json;
    final extensions = _gltfMap((json['extensions'] as Map<Object?, Object?>?)?[name] ?? <String, Object?>{});
    final lightDefs = _gltfList(extensions['lights']);
    final lightDef = _gltfMap(lightDefs[lightIndex]);
    Light lightNode;

    final color = Color(0xffffff);

    if (lightDef['color'] case final List<Object?> c) {
      color.setRGB(_gltfNum(c[0]), _gltfNum(c[1]), _gltfNum(c[2]), LinearSRGBColorSpace);
    }

    final range = lightDef['range'] != null ? _gltfNum(lightDef['range']) : 0.0;

    switch (lightDef['type']) {
      case 'directional':
        final light = DirectionalLight(color);
        light.target.position.set(0, 0, -1);
        light.add(light.target);
        lightNode = light;

      case 'point':
        lightNode = PointLight(color)..distance = range;

      case 'spot':
        final light = SpotLight(color);
        light.distance = range;

        // Handle spotlight properties.
        final spot = _gltfMap(lightDef['spot'] ?? <String, Object?>{});
        lightDef['spot'] = spot;
        spot['innerConeAngle'] = spot['innerConeAngle'] ?? 0;
        spot['outerConeAngle'] = spot['outerConeAngle'] ?? math.pi / 4.0;
        light.angle = _gltfNum(spot['outerConeAngle']);
        light.penumbra = 1.0 - _gltfNum(spot['innerConeAngle']) / _gltfNum(spot['outerConeAngle']);
        light.target.position.set(0, 0, -1);
        light.add(light.target);
        lightNode = light;

      default:
        throw EntError('ENT.GLTFLoader: Unexpected light type: ${lightDef['type']}');
    }

    // Some lights (e.g. spot) default to a position other than the origin. Reset the position
    // here, because node-level parsing will only override position if explicitly specified.
    lightNode.position.set(0, 0, 0);

    _gltfAssignExtrasToUserData(lightNode, lightDef);

    if (lightDef['intensity'] != null) {
      lightNode.intensity = _gltfNum(lightDef['intensity']);
    }

    lightNode.name = parser.createUniqueName(_gltfTruthyString(lightDef['name']) ?? 'light_$lightIndex');

    final dependency = Future<Light>.value(lightNode);

    parser.cache.add(cacheKey, dependency);

    return dependency;
  }

  @override
  Future<Object?>? getDependency(String type, int index) {
    if (type != 'light') {
      return null;
    }

    return _loadLight(index);
  }

  @override
  Future<Object3D>? createNodeAttachment(int nodeIndex) {
    final parser = this.parser;
    final json = parser.json;
    final nodeDef = _gltfMap(_gltfList(json['nodes'])[nodeIndex]);
    final lightDef = _gltfMap((nodeDef['extensions'] as Map<Object?, Object?>?)?[name] ?? <String, Object?>{});
    final lightIndex = lightDef['light'] as int?;

    if (lightIndex == null) {
      return null;
    }

    return _loadLight(lightIndex).then((light) => parser._getNodeRef(cache, lightIndex, light));
  }
}

/// Unlit Materials Extension
///
/// Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_materials_unlit
class _GLTFMaterialsUnlitExtension {
  /// The extension name.
  final String name = _GLTFExtensions.KHR_MATERIALS_UNLIT;

  /// The material type of unlit materials, [MeshBasicMaterial].
  GLTFMaterialType getMaterialType() {
    return MeshBasicMaterial.new;
  }

  /// Sets the color, opacity and map of an unlit material.
  Future<void> extendParams(Map<String, Object?> materialParams, Map<String, Object?> materialDef, GLTFParser parser) {
    final pending = <Future<Object?>>[];

    final color = Color(1.0, 1.0, 1.0);
    materialParams['color'] = color;
    materialParams['opacity'] = 1.0;

    if (materialDef['pbrMetallicRoughness'] case final Map<Object?, Object?> metallicRoughness) {
      if (metallicRoughness['baseColorFactor'] case final List<Object?> array) {
        color.setRGB(_gltfNum(array[0]), _gltfNum(array[1]), _gltfNum(array[2]), LinearSRGBColorSpace);
        materialParams['opacity'] = _gltfNum(array[3]);
      }

      if (metallicRoughness['baseColorTexture'] != null) {
        pending.add(
          parser.assignTexture(materialParams, 'map', _gltfMap(metallicRoughness['baseColorTexture']), SRGBColorSpace),
        );
      }
    }

    return Future.wait(pending);
  }
}

/// Materials Emissive Strength Extension
///
/// Specification: https://github.com/KhronosGroup/glTF/blob/5768b3ce0ef32bc39cdf1bef10b948586635ead3/extensions/2.0/Khronos/KHR_materials_emissive_strength/README.md
class _GLTFMaterialsEmissiveStrengthExtension extends GLTFLoaderPlugin {
  _GLTFMaterialsEmissiveStrengthExtension(this.parser);

  final GLTFParser parser;

  @override
  final String name = _GLTFExtensions.KHR_MATERIALS_EMISSIVE_STRENGTH;

  @override
  Future<void>? extendMaterialParams(int materialIndex, Map<String, Object?> materialParams) {
    final extension = _gltfGetMaterialExtension(parser, materialIndex, name);

    if (extension == null) {
      return Future.value();
    }

    if (extension['emissiveStrength'] != null) {
      materialParams['emissiveIntensity'] = _gltfNum(extension['emissiveStrength']);
    }

    return Future.value();
  }
}

/// The base of the material extension plugins: each makes a [MeshPhysicalMaterial] of the materials that use
/// its extension (the reference repeats `getMaterialType` in every plugin class).
abstract class _GLTFPhysicalExtension extends GLTFLoaderPlugin {
  _GLTFPhysicalExtension(this.parser);

  final GLTFParser parser;

  @override
  GLTFMaterialType? getMaterialType(int materialIndex) {
    final extension = _gltfGetMaterialExtension(parser, materialIndex, name);

    return extension != null ? MeshPhysicalMaterial.new : null;
  }
}

/// Clearcoat Materials Extension
///
/// Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_materials_clearcoat
class _GLTFMaterialsClearcoatExtension extends _GLTFPhysicalExtension {
  _GLTFMaterialsClearcoatExtension(super.parser);

  @override
  final String name = _GLTFExtensions.KHR_MATERIALS_CLEARCOAT;

  @override
  Future<void>? extendMaterialParams(int materialIndex, Map<String, Object?> materialParams) {
    final extension = _gltfGetMaterialExtension(parser, materialIndex, name);

    if (extension == null) {
      return Future.value();
    }

    final pending = <Future<Object?>>[];

    if (extension['clearcoatFactor'] != null) {
      materialParams['clearcoat'] = _gltfNum(extension['clearcoatFactor']);
    }

    if (extension['clearcoatTexture'] != null) {
      pending.add(parser.assignTexture(materialParams, 'clearcoatMap', _gltfMap(extension['clearcoatTexture'])));
    }

    if (extension['clearcoatRoughnessFactor'] != null) {
      materialParams['clearcoatRoughness'] = _gltfNum(extension['clearcoatRoughnessFactor']);
    }

    if (extension['clearcoatRoughnessTexture'] != null) {
      pending.add(
        parser.assignTexture(materialParams, 'clearcoatRoughnessMap', _gltfMap(extension['clearcoatRoughnessTexture'])),
      );
    }

    if (extension['clearcoatNormalTexture'] != null) {
      final normalTexture = _gltfMap(extension['clearcoatNormalTexture']);

      pending.add(parser.assignTexture(materialParams, 'clearcoatNormalMap', normalTexture));

      if (normalTexture['scale'] != null) {
        final scale = _gltfNum(normalTexture['scale']);

        materialParams['clearcoatNormalScale'] = Vector2(scale, scale);
      }
    }

    return Future.wait(pending);
  }
}

/// Diffuse Roughness Materials Extension
///
/// Specification: https://github.com/MiiBond/glTF/tree/mbond/EXT_materials_diffuse_roughness/extensions/2.0/Khronos/KHR_materials_diffuse_roughness
class _GLTFMaterialsDiffuseRoughnessExtension extends _GLTFPhysicalExtension {
  _GLTFMaterialsDiffuseRoughnessExtension(super.parser);

  @override
  final String name = _GLTFExtensions.KHR_MATERIALS_DIFFUSE_ROUGHNESS;

  @override
  Future<void>? extendMaterialParams(int materialIndex, Map<String, Object?> materialParams) {
    final extension = _gltfGetMaterialExtension(parser, materialIndex, name);

    if (extension == null) {
      return Future.value();
    }

    final pending = <Future<Object?>>[];

    materialParams['diffuseRoughness'] = extension['diffuseRoughnessFactor'] != null
        ? _gltfNum(extension['diffuseRoughnessFactor'])
        : 0.0;

    if (extension['diffuseRoughnessTexture'] != null) {
      pending.add(
        parser.assignTexture(materialParams, 'diffuseRoughnessMap', _gltfMap(extension['diffuseRoughnessTexture'])),
      );
    }

    return Future.wait(pending);
  }
}

/// Materials dispersion Extension
///
/// Specification: https://github.com/KhronosGroup/glTF/tree/main/extensions/2.0/Khronos/KHR_materials_dispersion
class _GLTFMaterialsDispersionExtension extends _GLTFPhysicalExtension {
  _GLTFMaterialsDispersionExtension(super.parser);

  @override
  final String name = _GLTFExtensions.KHR_MATERIALS_DISPERSION;

  @override
  Future<void>? extendMaterialParams(int materialIndex, Map<String, Object?> materialParams) {
    final extension = _gltfGetMaterialExtension(parser, materialIndex, name);

    if (extension == null) {
      return Future.value();
    }

    materialParams['dispersion'] = extension['dispersion'] != null ? _gltfNum(extension['dispersion']) : 0.0;

    return Future.value();
  }
}

/// Iridescence Materials Extension
///
/// Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_materials_iridescence
class _GLTFMaterialsIridescenceExtension extends _GLTFPhysicalExtension {
  _GLTFMaterialsIridescenceExtension(super.parser);

  @override
  final String name = _GLTFExtensions.KHR_MATERIALS_IRIDESCENCE;

  @override
  Future<void>? extendMaterialParams(int materialIndex, Map<String, Object?> materialParams) {
    final extension = _gltfGetMaterialExtension(parser, materialIndex, name);

    if (extension == null) {
      return Future.value();
    }

    final pending = <Future<Object?>>[];

    if (extension['iridescenceFactor'] != null) {
      materialParams['iridescence'] = _gltfNum(extension['iridescenceFactor']);
    }

    if (extension['iridescenceTexture'] != null) {
      pending.add(parser.assignTexture(materialParams, 'iridescenceMap', _gltfMap(extension['iridescenceTexture'])));
    }

    if (extension['iridescenceIor'] != null) {
      materialParams['iridescenceIOR'] = _gltfNum(extension['iridescenceIor']);
    }

    if (extension['iridescenceThicknessMinimum'] != null) {
      materialParams['iridescenceThicknessMinimum'] = _gltfNum(extension['iridescenceThicknessMinimum']);
    }

    if (extension['iridescenceThicknessMaximum'] != null) {
      materialParams['iridescenceThicknessMaximum'] = _gltfNum(extension['iridescenceThicknessMaximum']);
    }

    if (extension['iridescenceThicknessTexture'] != null) {
      pending.add(
        parser.assignTexture(
          materialParams,
          'iridescenceThicknessMap',
          _gltfMap(extension['iridescenceThicknessTexture']),
        ),
      );
    }

    return Future.wait(pending);
  }
}

/// Sheen Materials Extension
///
/// Specification: https://github.com/KhronosGroup/glTF/tree/main/extensions/2.0/Khronos/KHR_materials_sheen
class _GLTFMaterialsSheenExtension extends _GLTFPhysicalExtension {
  _GLTFMaterialsSheenExtension(super.parser);

  @override
  final String name = _GLTFExtensions.KHR_MATERIALS_SHEEN;

  @override
  Future<void>? extendMaterialParams(int materialIndex, Map<String, Object?> materialParams) {
    final extension = _gltfGetMaterialExtension(parser, materialIndex, name);

    if (extension == null) {
      return Future.value();
    }

    final pending = <Future<Object?>>[];

    final sheenColor = Color(0, 0, 0);
    materialParams['sheenColor'] = sheenColor;
    materialParams['sheenRoughness'] = 0.0;
    materialParams['sheen'] = 1.0;

    if (extension['sheenColorFactor'] case final List<Object?> colorFactor) {
      sheenColor.setRGB(
        _gltfNum(colorFactor[0]),
        _gltfNum(colorFactor[1]),
        _gltfNum(colorFactor[2]),
        LinearSRGBColorSpace,
      );
    }

    if (extension['sheenRoughnessFactor'] != null) {
      materialParams['sheenRoughness'] = _gltfNum(extension['sheenRoughnessFactor']);
    }

    if (extension['sheenColorTexture'] != null) {
      pending.add(
        parser.assignTexture(materialParams, 'sheenColorMap', _gltfMap(extension['sheenColorTexture']), SRGBColorSpace),
      );
    }

    if (extension['sheenRoughnessTexture'] != null) {
      pending.add(
        parser.assignTexture(materialParams, 'sheenRoughnessMap', _gltfMap(extension['sheenRoughnessTexture'])),
      );
    }

    return Future.wait(pending);
  }
}

/// Transmission Materials Extension
///
/// Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_materials_transmission
/// Draft: https://github.com/KhronosGroup/glTF/pull/1698
class _GLTFMaterialsTransmissionExtension extends _GLTFPhysicalExtension {
  _GLTFMaterialsTransmissionExtension(super.parser);

  @override
  final String name = _GLTFExtensions.KHR_MATERIALS_TRANSMISSION;

  @override
  Future<void>? extendMaterialParams(int materialIndex, Map<String, Object?> materialParams) {
    final extension = _gltfGetMaterialExtension(parser, materialIndex, name);

    if (extension == null) {
      return Future.value();
    }

    final pending = <Future<Object?>>[];

    if (extension['transmissionFactor'] != null) {
      materialParams['transmission'] = _gltfNum(extension['transmissionFactor']);
    }

    if (extension['transmissionTexture'] != null) {
      pending.add(parser.assignTexture(materialParams, 'transmissionMap', _gltfMap(extension['transmissionTexture'])));
    }

    return Future.wait(pending);
  }
}

/// Materials Volume Extension
///
/// Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_materials_volume
class _GLTFMaterialsVolumeExtension extends _GLTFPhysicalExtension {
  _GLTFMaterialsVolumeExtension(super.parser);

  @override
  final String name = _GLTFExtensions.KHR_MATERIALS_VOLUME;

  @override
  Future<void>? extendMaterialParams(int materialIndex, Map<String, Object?> materialParams) {
    final extension = _gltfGetMaterialExtension(parser, materialIndex, name);

    if (extension == null) {
      return Future.value();
    }

    final pending = <Future<Object?>>[];

    materialParams['thickness'] = extension['thicknessFactor'] != null ? _gltfNum(extension['thicknessFactor']) : 0.0;

    if (extension['thicknessTexture'] != null) {
      pending.add(parser.assignTexture(materialParams, 'thicknessMap', _gltfMap(extension['thicknessTexture'])));
    }

    // `extension.attenuationDistance || Infinity`: a missing or zero distance is infinite.
    final distance = extension['attenuationDistance'] != null ? _gltfNum(extension['attenuationDistance']) : 0.0;
    materialParams['attenuationDistance'] = distance != 0 && !distance.isNaN ? distance : double.infinity;

    final colorArray = (extension['attenuationColor'] as List<Object?>?) ?? const [1, 1, 1];
    materialParams['attenuationColor'] = Color().setRGB(
      _gltfNum(colorArray[0]),
      _gltfNum(colorArray[1]),
      _gltfNum(colorArray[2]),
      LinearSRGBColorSpace,
    );

    return Future.wait(pending);
  }
}

/// Materials ior Extension
///
/// Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_materials_ior
class _GLTFMaterialsIorExtension extends _GLTFPhysicalExtension {
  _GLTFMaterialsIorExtension(super.parser);

  @override
  final String name = _GLTFExtensions.KHR_MATERIALS_IOR;

  @override
  Future<void>? extendMaterialParams(int materialIndex, Map<String, Object?> materialParams) {
    final extension = _gltfGetMaterialExtension(parser, materialIndex, name);

    if (extension == null) {
      return Future.value();
    }

    materialParams['ior'] = extension['ior'] != null ? _gltfNum(extension['ior']) : 1.5;

    if (materialParams['ior'] == 0) {
      materialParams['ior'] = 1000.0; // see #26167
    }

    return Future.value();
  }
}

/// Materials specular Extension
///
/// Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_materials_specular
class _GLTFMaterialsSpecularExtension extends _GLTFPhysicalExtension {
  _GLTFMaterialsSpecularExtension(super.parser);

  @override
  final String name = _GLTFExtensions.KHR_MATERIALS_SPECULAR;

  @override
  Future<void>? extendMaterialParams(int materialIndex, Map<String, Object?> materialParams) {
    final extension = _gltfGetMaterialExtension(parser, materialIndex, name);

    if (extension == null) {
      return Future.value();
    }

    final pending = <Future<Object?>>[];

    materialParams['specularIntensity'] = extension['specularFactor'] != null
        ? _gltfNum(extension['specularFactor'])
        : 1.0;

    if (extension['specularTexture'] != null) {
      pending.add(parser.assignTexture(materialParams, 'specularIntensityMap', _gltfMap(extension['specularTexture'])));
    }

    final colorArray = (extension['specularColorFactor'] as List<Object?>?) ?? const [1, 1, 1];
    materialParams['specularColor'] = Color().setRGB(
      _gltfNum(colorArray[0]),
      _gltfNum(colorArray[1]),
      _gltfNum(colorArray[2]),
      LinearSRGBColorSpace,
    );

    if (extension['specularColorTexture'] != null) {
      pending.add(
        parser.assignTexture(
          materialParams,
          'specularColorMap',
          _gltfMap(extension['specularColorTexture']),
          SRGBColorSpace,
        ),
      );
    }

    return Future.wait(pending);
  }
}

/// Materials bump Extension
///
/// Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/EXT_materials_bump
class _GLTFMaterialsBumpExtension extends _GLTFPhysicalExtension {
  _GLTFMaterialsBumpExtension(super.parser);

  @override
  final String name = _GLTFExtensions.EXT_MATERIALS_BUMP;

  @override
  Future<void>? extendMaterialParams(int materialIndex, Map<String, Object?> materialParams) {
    final extension = _gltfGetMaterialExtension(parser, materialIndex, name);

    if (extension == null) {
      return Future.value();
    }

    final pending = <Future<Object?>>[];

    materialParams['bumpScale'] = extension['bumpFactor'] != null ? _gltfNum(extension['bumpFactor']) : 1.0;

    if (extension['bumpTexture'] != null) {
      pending.add(parser.assignTexture(materialParams, 'bumpMap', _gltfMap(extension['bumpTexture'])));
    }

    return Future.wait(pending);
  }
}

/// Materials anisotropy Extension
///
/// Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_materials_anisotropy
class _GLTFMaterialsAnisotropyExtension extends _GLTFPhysicalExtension {
  _GLTFMaterialsAnisotropyExtension(super.parser);

  @override
  final String name = _GLTFExtensions.KHR_MATERIALS_ANISOTROPY;

  @override
  Future<void>? extendMaterialParams(int materialIndex, Map<String, Object?> materialParams) {
    final extension = _gltfGetMaterialExtension(parser, materialIndex, name);

    if (extension == null) {
      return Future.value();
    }

    final pending = <Future<Object?>>[];

    if (extension['anisotropyStrength'] != null) {
      materialParams['anisotropy'] = _gltfNum(extension['anisotropyStrength']);
    }

    if (extension['anisotropyRotation'] != null) {
      materialParams['anisotropyRotation'] = _gltfNum(extension['anisotropyRotation']);
    }

    if (extension['anisotropyTexture'] != null) {
      pending.add(parser.assignTexture(materialParams, 'anisotropyMap', _gltfMap(extension['anisotropyTexture'])));
    }

    return Future.wait(pending);
  }
}

/// The texture definition of [textureIndex] when it uses the extension [name], the check of the texture plugins.
Map<String, Object?>? _gltfTextureExtension(GLTFParser parser, int textureIndex, String name) {
  final textureDef = _gltfMap(_gltfList(parser.json['textures'])[textureIndex]);

  if (textureDef['extensions'] case final Map<Object?, Object?> extensions when extensions[name] != null) {
    return _gltfMap(extensions[name]);
  }

  return null;
}

/// BasisU Texture Extension
///
/// Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_texture_basisu
///
/// The KTX2Loader is not ported (exception E-GLTF): without one the optional extension falls back to the
/// texture's own source and a required one throws, as in the reference; with an object set through
/// [GLTFLoader.setKTX2Loader] it throws.
class _GLTFTextureBasisUExtension extends GLTFLoaderPlugin {
  _GLTFTextureBasisUExtension(this.parser);

  final GLTFParser parser;

  @override
  final String name = _GLTFExtensions.KHR_TEXTURE_BASISU;

  @override
  Future<Texture?>? loadTexture(int textureIndex) {
    if (_gltfTextureExtension(parser, textureIndex, name) == null) {
      return null;
    }

    if (parser.options.ktx2Loader == null) {
      if (_gltfList(parser.json['extensionsRequired']).contains(name)) {
        throw EntError('ENT.GLTFLoader: setKTX2Loader must be called before loading KTX2 textures');
      } else {
        // Assumes that the extension is optional and that a fallback texture is present
        return null;
      }
    }

    // The reference loads the image with the KTX2Loader here.
    throw EntError('ENT.GLTFLoader: KTX2Loader is not ported; KTX2 textures cannot be loaded.');
  }
}

/// WebP Texture Extension
///
/// Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Vendor/EXT_texture_webp
///
/// The image decodes as any other through the platform (Flutter decodes WebP).
class _GLTFTextureWebPExtension extends GLTFLoaderPlugin {
  _GLTFTextureWebPExtension(this.parser);

  final GLTFParser parser;

  @override
  final String name = _GLTFExtensions.EXT_TEXTURE_WEBP;

  @override
  Future<Texture?>? loadTexture(int textureIndex) => _gltfLoadExtensionTexture(parser, textureIndex, name);
}

/// AVIF Texture Extension
///
/// Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Vendor/EXT_texture_avif
///
/// The image decodes as any other through the platform: whether AVIF decodes depends on the platform's decoder
/// (exception E-GLTF).
class _GLTFTextureAVIFExtension extends GLTFLoaderPlugin {
  _GLTFTextureAVIFExtension(this.parser);

  final GLTFParser parser;

  @override
  final String name = _GLTFExtensions.EXT_TEXTURE_AVIF;

  @override
  Future<Texture?>? loadTexture(int textureIndex) => _gltfLoadExtensionTexture(parser, textureIndex, name);
}

/// The `loadTexture` of the WebP and AVIF plugins, which the reference repeats in both.
Future<Texture?>? _gltfLoadExtensionTexture(GLTFParser parser, int textureIndex, String name) {
  final extension = _gltfTextureExtension(parser, textureIndex, name);

  if (extension == null) {
    return null;
  }

  final sourceIndex = extension['source']! as int;

  var loader = parser.textureLoader;

  if (_gltfTruthyString(_gltfMap(_gltfList(parser.json['images'])[sourceIndex])['uri']) case final String uri) {
    final handler = parser.options.manager.getHandler(uri);

    if (handler != null) {
      loader = handler;
    }
  }

  return parser.loadTextureImage(textureIndex, sourceIndex, loader);
}

/// Texture Transform Extension
///
/// Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_texture_transform
class _GLTFTextureTransformExtension {
  /// The extension name.
  final String name = _GLTFExtensions.KHR_TEXTURE_TRANSFORM;

  /// Returns [texture] with the [transform] applied: a clone, unless the transform changes nothing.
  Texture extendTexture(Texture texture, Map<String, Object?> transform) {
    if ((transform['texCoord'] == null || transform['texCoord'] == texture.channel) &&
        transform['offset'] == null &&
        transform['rotation'] == null &&
        transform['scale'] == null) {
      // An identity transform keeps the texture as it is.
      return texture;
    }

    texture = texture.clone();

    if (transform['texCoord'] != null) {
      texture.channel = (transform['texCoord']! as num).toInt();
    }

    if (transform['offset'] case final List<Object?> offset) {
      texture.offset.set(_gltfNum(offset[0]), _gltfNum(offset[1]));
    }

    if (transform['rotation'] != null) {
      texture.rotation = _gltfNum(transform['rotation']);
    }

    if (transform['scale'] case final List<Object?> scale) {
      texture.repeat.set(_gltfNum(scale[0]), _gltfNum(scale[1]));
    }

    if (transform['rotation'] != null) {
      // glTF's KHR_texture_transform order differs from ent's:
      // glTF defines the UV transform as T * R * S
      // ent defines the UV transform as T * S * R
      //
      // To fix this, we need to override the matrix with the value computed per glTF spec
      // We still set the other fields so that you can inspect/export the resulting object.

      final c = math.cos(texture.rotation);
      final s = math.sin(texture.rotation);

      texture.matrix.set(
        texture.repeat.x * c,
        texture.repeat.y * s,
        texture.offset.x,
        -texture.repeat.x * s,
        texture.repeat.y * c,
        texture.offset.y,
        0,
        0,
        1,
      );
      texture.matrixAutoUpdate = false;
    }

    texture.needsUpdate = true;

    return texture;
  }
}

/// Mesh Quantization Extension
///
/// Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_mesh_quantization
class _GLTFMeshQuantizationExtension {
  /// The extension name.
  final String name = _GLTFExtensions.KHR_MESH_QUANTIZATION;
}

/* BINARY EXTENSION */

const _gltfBinaryExtensionHeaderMagic = 'glTF';
const _gltfBinaryExtensionHeaderLength = 12;
const _gltfBinaryExtensionChunkTypeJSON = 0x4E4F534A;
const _gltfBinaryExtensionChunkTypeBIN = 0x004E4942;

/// The GLB container: its header, JSON chunk ([content]) and binary chunk ([body]).
class _GLTFBinaryExtension {
  _GLTFBinaryExtension(ByteBuffer data) {
    final headerView = ByteData.view(data, 0, _gltfBinaryExtensionHeaderLength);

    header = (
      magic: utf8.decode(data.asUint8List(0, 4), allowMalformed: true),
      version: headerView.getUint32(4, Endian.little),
      length: headerView.getUint32(8, Endian.little),
    );

    if (header.magic != _gltfBinaryExtensionHeaderMagic) {
      throw EntError('ENT.GLTFLoader: Unsupported glTF-Binary header.');
    } else if (header.version < 2.0) {
      throw EntError('ENT.GLTFLoader: Legacy binary file detected.');
    }

    final chunkContentsLength = header.length - _gltfBinaryExtensionHeaderLength;
    final chunkView = ByteData.view(data, _gltfBinaryExtensionHeaderLength);
    var chunkIndex = 0;

    while (chunkIndex < chunkContentsLength) {
      final chunkLength = chunkView.getUint32(chunkIndex, Endian.little);
      chunkIndex += 4;

      final chunkType = chunkView.getUint32(chunkIndex, Endian.little);
      chunkIndex += 4;

      if (chunkType == _gltfBinaryExtensionChunkTypeJSON) {
        final contentArray = data.asUint8List(_gltfBinaryExtensionHeaderLength + chunkIndex, chunkLength);
        content = utf8.decode(contentArray, allowMalformed: true);
      } else if (chunkType == _gltfBinaryExtensionChunkTypeBIN) {
        final byteOffset = _gltfBinaryExtensionHeaderLength + chunkIndex;
        body = _gltfSlice(data, byteOffset, byteOffset + chunkLength);
      }

      // Clients must ignore chunks with unknown types.

      chunkIndex += chunkLength;
    }

    if (content == null) {
      throw EntError('ENT.GLTFLoader: JSON content not found.');
    }
  }

  /// The extension name.
  final String name = _GLTFExtensions.KHR_BINARY_GLTF;

  /// The JSON chunk, decoded.
  String? content;

  /// The binary chunk.
  ByteBuffer? body;

  /// The header: magic, version and length.
  late final ({String magic, int version, int length}) header;
}

// INTERNALS

/* CONSTANTS */

/// The WebGL constants glTF uses.
abstract final class _GLTFWebGL {
  static const POINTS = 0;
  static const LINES = 1;
  static const LINE_LOOP = 2;
  static const LINE_STRIP = 3;
  static const TRIANGLES = 4;
  static const TRIANGLE_STRIP = 5;
  static const TRIANGLE_FAN = 6;
}

/// The element size per component type.
const _gltfComponentBytes = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4};

/// The texture filters of the sampler's WebGL filter constants.
const _gltfFilters = {
  9728: NearestFilter,
  9729: LinearFilter,
  9984: NearestMipmapNearestFilter,
  9985: LinearMipmapNearestFilter,
  9986: NearestMipmapLinearFilter,
  9987: LinearMipmapLinearFilter,
};

/// The wrapping modes of the sampler's WebGL wrap constants.
const _gltfWrappings = {33071: ClampToEdgeWrapping, 33648: MirroredRepeatWrapping, 10497: RepeatWrapping};

/// A typed view of [length] components of [componentType] at [byteOffset] in [buffer], not a copy.
List<num> _gltfTypedView(int componentType, ByteBuffer buffer, int byteOffset, int length) {
  return switch (componentType) {
    5120 => buffer.asInt8List(byteOffset, length),
    5121 => buffer.asUint8List(byteOffset, length),
    5122 => buffer.asInt16List(byteOffset, length),
    5123 => buffer.asUint16List(byteOffset, length),
    5125 => buffer.asUint32List(byteOffset, length),
    5126 => buffer.asFloat32List(byteOffset, length),
    _ => throw EntError('ENT.GLTFLoader: Unsupported component type: $componentType'),
  };
}

/// `new TypedArray( length )` for a component type.
List<num> _gltfTypedArray(int componentType, int length) {
  return _gltfTypedView(componentType, Uint8List(length * _gltfComponentBytes[componentType]!).buffer, 0, length);
}

const _gltfTypeSizes = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT2': 4, 'MAT3': 9, 'MAT4': 16};

const _gltfAttributes = {
  'POSITION': 'position',
  'NORMAL': 'normal',
  'TANGENT': 'tangent',
  'TEXCOORD_0': 'uv',
  'TEXCOORD_1': 'uv1',
  'TEXCOORD_2': 'uv2',
  'TEXCOORD_3': 'uv3',
  'COLOR_0': 'color',
  'WEIGHTS_0': 'skinWeight',
  'JOINTS_0': 'skinIndex',
};

const _gltfPathProperties = {
  'scale': 'scale',
  'translation': 'position',
  'rotation': 'quaternion',
  'weights': 'morphTargetInfluences',
};

// CUBICSPLINE maps to null (undefined in the reference): we use a custom interpolant (_GLTFCubicSplineInterpolant) for
// CUBICSPLINE tracks. Each keyframe track will be initialized with a default interpolation type, then modified.
const _gltfInterpolation = <String, int?>{
  'CUBICSPLINE': null,
  'LINEAR': InterpolateLinear,
  'STEP': InterpolateDiscrete,
};

/// Spline Interpolation
/// Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#appendix-c-spline-interpolation
class _GLTFCubicSplineInterpolant extends Interpolant {
  _GLTFCubicSplineInterpolant(super.parameterPositions, super.sampleValues, super.sampleSize, [super.resultBuffer]);

  @override
  List<double> copySampleValue_(int index) {
    // Copies a sample value to the result buffer. See description of glTF
    // CUBICSPLINE values layout in interpolate_() function below.

    final result = resultBuffer;
    final values = sampleValues;
    final valueSize = this.valueSize;
    final offset = index * valueSize * 3 + valueSize;

    for (var i = 0; i != valueSize; i++) {
      result[i] = values[offset + i];
    }

    return result;
  }

  @override
  List<double> interpolate_(int i1, double t0, double t, double t1) {
    final result = resultBuffer;
    final values = sampleValues;
    final stride = valueSize;

    final stride2 = stride * 2;
    final stride3 = stride * 3;

    final td = t1 - t0;

    final p = (t - t0) / td;
    final pp = p * p;
    final ppp = pp * p;

    final offset1 = i1 * stride3;
    final offset0 = offset1 - stride3;

    final s2 = -2 * ppp + 3 * pp;
    final s3 = ppp - pp;
    final s0 = 1 - s2;
    final s1 = s3 - pp + p;

    // Layout of keyframe output values for CUBICSPLINE animations:
    //   [ inTangent_1, splineVertex_1, outTangent_1, inTangent_2, splineVertex_2, ... ]
    for (var i = 0; i != stride; i++) {
      final p0 = values[offset0 + i + stride]; // splineVertex_k
      final m0 = values[offset0 + i + stride2] * td; // outTangent_k * (t_k+1 - t_k)
      final p1 = values[offset1 + i + stride]; // splineVertex_k+1
      final m1 = values[offset1 + i] * td; // inTangent_k+1 * (t_k+1 - t_k)

      result[i] = s0 * p0 + s1 * m0 + s2 * p1 + s3 * m1;
    }

    return result;
  }
}

final _gltfQuaternion = Quaternion();

class _GLTFCubicSplineQuaternionInterpolant extends _GLTFCubicSplineInterpolant {
  _GLTFCubicSplineQuaternionInterpolant(
    super.parameterPositions,
    super.sampleValues,
    super.sampleSize, [
    super.resultBuffer,
  ]);

  @override
  List<double> interpolate_(int i1, double t0, double t, double t1) {
    final result = super.interpolate_(i1, t0, t, t1);

    _gltfQuaternion.fromArray(result).normalize().toArray(result);

    return result;
  }
}

final _gltfIdentityMatrix = Matrix4();

abstract final class _GLTFAlphaModes {
  static const OPAQUE = 'OPAQUE';
  static const MASK = 'MASK';
  static const BLEND = 'BLEND';
}

/// Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#default-material
Material _gltfCreateDefaultMaterial(GLTFRegistry cache) {
  if (cache.get('DefaultMaterial') == null) {
    cache.add(
      'DefaultMaterial',
      MeshStandardMaterial({
        'color': 0xFFFFFF,
        'emissive': 0x000000,
        'metalness': 1.0,
        'roughness': 1.0,
        'transparent': false,
        'depthTest': true,
        'side': FrontSide,
      }),
    );
  }

  return cache.get('DefaultMaterial')! as Material;
}

/// The `userData` of the objects glTF definitions become (the reference reads `object.userData` duck-typed).
Map<String, Object?> _gltfUserData(Object object) {
  return switch (object) {
    Object3D() => object.userData,
    Material() => object.userData,
    BufferGeometry() => object.userData,
    GLTF() => object.userData,
    Texture() => object.userData,
    AnimationClip() => object.userData,
    _ => throw ArgumentError.value(object, 'object', 'has no userData'),
  };
}

void _gltfAddUnknownExtensionsToUserData(
  Map<String, Object?> knownExtensions,
  Object object,
  Map<String, Object?> objectDef,
) {
  // Add unknown glTF extensions to an object's userData.

  final userData = _gltfUserData(object);

  for (final MapEntry(:key, :value) in _gltfMap(objectDef['extensions'] ?? <String, Object?>{}).entries) {
    if (knownExtensions[key] == null) {
      final extensions = (userData['gltfExtensions'] ??= <String, Object?>{}) as Map;
      extensions[key] = value;
    }
  }
}

void _gltfAssignExtrasToUserData(Object object, Map<String, Object?> gltfDef) {
  if (!gltfDef.containsKey('extras')) {
    return;
  }

  // typeof null and arrays is 'object' too: Object.assign copies an array's indices and ignores null.
  switch (gltfDef['extras']) {
    case final Map<Object?, Object?> extras:
      _gltfUserData(object).addAll(extras.cast<String, Object?>());

    case final List<Object?> extras:
      _gltfUserData(object).addAll({for (final (i, v) in extras.indexed) '$i': v});

    case null:
      break;

    case final extras:
      warn('GLTFLoader: Ignoring primitive type .extras, $extras');
  }
}

/// The geometry of a [Mesh], [Line] or [Points] (the reference reads `mesh.geometry` duck-typed).
BufferGeometry _gltfGeometry(Object3D object) {
  return switch (object) {
    Mesh() => object.geometry,
    Line() => object.geometry,
    Points() => object.geometry,
    _ => throw ArgumentError.value(object, 'object', 'has no geometry'),
  };
}

/// The single material of a [Mesh], [Line] or [Points].
Material _gltfMaterial(Object3D object) {
  return switch (object) {
        Mesh() => object.material,
        Line() => object.material,
        Points() => object.material,
        _ => throw ArgumentError.value(object, 'object', 'has no material'),
      }!
      as Material;
}

/// The `color` and `map` the reference reads from the glTF material it turns into a line or points material.
(Color, Texture?) _gltfColorAndMap(Material material) {
  return switch (material) {
    MeshStandardMaterial(:final color, :final map) || MeshBasicMaterial(:final color, :final map) => (color, map),
    _ => throw ArgumentError.value(material, 'material', 'has no color'),
  };
}

/// What `Material.prototype.copy.call( target, source )` copies: the properties of [Material.copy] alone, without
/// a subclass's.
void _gltfCopyMaterialBase(Material target, Material source) {
  target.name = source.name;

  target.blending = source.blending;
  target.side = source.side;
  target.vertexColors = source.vertexColors;

  target.opacity = source.opacity;
  target.transparent = source.transparent;

  target.blendSrc = source.blendSrc;
  target.blendDst = source.blendDst;
  target.blendEquation = source.blendEquation;
  target.blendSrcAlpha = source.blendSrcAlpha;
  target.blendDstAlpha = source.blendDstAlpha;
  target.blendEquationAlpha = source.blendEquationAlpha;
  target.blendColor.copy(source.blendColor);
  target.blendAlpha = source.blendAlpha;

  target.depthFunc = source.depthFunc;
  target.depthTest = source.depthTest;
  target.depthWrite = source.depthWrite;

  target.stencilWriteMask = source.stencilWriteMask;
  target.stencilFunc = source.stencilFunc;
  target.stencilRef = source.stencilRef;
  target.stencilFuncMask = source.stencilFuncMask;
  target.stencilFail = source.stencilFail;
  target.stencilZFail = source.stencilZFail;
  target.stencilZPass = source.stencilZPass;
  target.stencilWrite = source.stencilWrite;

  target.clippingPlanes = source.clippingPlanes == null
      ? null
      : [for (final plane in source.clippingPlanes!) plane.clone()];
  target.clipIntersection = source.clipIntersection;
  target.clipShadows = source.clipShadows;

  target.shadowSide = source.shadowSide;

  target.colorWrite = source.colorWrite;

  target.polygonOffset = source.polygonOffset;
  target.polygonOffsetFactor = source.polygonOffsetFactor;
  target.polygonOffsetUnits = source.polygonOffsetUnits;

  target.dithering = source.dithering;

  target.alphaTest = source.alphaTest;
  target.alphaHash = source.alphaHash;
  target.alphaToCoverage = source.alphaToCoverage;
  target.premultipliedAlpha = source.premultipliedAlpha;
  target.forceSinglePass = source.forceSinglePass;
  target.allowOverride = source.allowOverride;

  target.visible = source.visible;

  target.toneMapped = source.toneMapped;

  target.userData = jsonDecode(jsonEncode(source.userData)) as Map<String, Object?>;
}

/// The mime type of an image URI without a `mimeType`.
String _gltfImageURIMimeType(Object? uri) {
  final s = uri as String;

  if (RegExp(r'\.jpe?g($|\?)', caseSensitive: false).firstMatch(s)?.start case final int i when i > 0) {
    return 'image/jpeg';
  }

  if (s.startsWith('data:image/jpeg')) {
    return 'image/jpeg';
  }

  if (RegExp(r'\.webp($|\?)', caseSensitive: false).firstMatch(s)?.start case final int i when i > 0) {
    return 'image/webp';
  }

  if (s.startsWith('data:image/webp')) {
    return 'image/webp';
  }

  if (RegExp(r'\.ktx2($|\?)', caseSensitive: false).firstMatch(s)?.start case final int i when i > 0) {
    return 'image/ktx2';
  }

  if (s.startsWith('data:image/ktx2')) {
    return 'image/ktx2';
  }

  return 'image/png';
}

String _gltfCreatePrimitiveKey(Map<String, Object?> primitiveDef) {
  final dracoExtension =
      (primitiveDef['extensions'] as Map<Object?, Object?>?)?[_GLTFExtensions.KHR_DRACO_MESH_COMPRESSION];
  String geometryKey;

  if (dracoExtension is Map) {
    geometryKey =
        'draco:${_gltfJs(dracoExtension['bufferView'])}'
        ':${_gltfJs(dracoExtension['indices'])}'
        ':${_gltfCreateAttributesKey(_gltfMap(dracoExtension['attributes']))}';
  } else {
    geometryKey =
        '${_gltfJs(primitiveDef['indices'])}:${_gltfCreateAttributesKey(_gltfMap(primitiveDef['attributes']))}'
        ':${_gltfJs(primitiveDef['mode'])}';
  }

  if (primitiveDef['targets'] case final List<Object?> targets) {
    for (var i = 0, il = targets.length; i < il; i++) {
      geometryKey += ':${_gltfCreateAttributesKey(_gltfMap(targets[i]))}';
    }
  }

  return geometryKey;
}

String _gltfCreateAttributesKey(Map<String, Object?> attributes) {
  var attributesKey = '';

  final keys = attributes.keys.toList()..sort();

  for (var i = 0, il = keys.length; i < il; i++) {
    attributesKey += '${keys[i]}:${_gltfJs(attributes[keys[i]])};';
  }

  return attributesKey;
}

double _gltfGetNormalizedComponentScale(int componentType) {
  // Reference:
  // https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_mesh_quantization#encoding-quantized-data

  switch (componentType) {
    case 5120:
      return 1 / 127;

    case 5121:
      return 1 / 255;

    case 5122:
      return 1 / 32767;

    case 5123:
      return 1 / 65535;

    default:
      throw EntError('ENT.GLTFLoader: Unsupported normalized accessor component type.');
  }
}

/// The options [GLTFLoader.parse] hands its [GLTFParser].
class GLTFParserOptions {
  /// Constructs new options with the given values; see each field for its default.
  GLTFParserOptions({
    this.path = '',
    this.crossOrigin = 'anonymous',
    this.priority = 'auto',
    this.cache = 'default',
    this.withCredentials = false,
    this.requestHeader = const {},
    LoadingManager? manager,
    this.ktx2Loader,
    this.meshoptDecoder,
  }) : manager = manager ?? DefaultLoadingManager;

  /// The base path of the asset's resources.
  final String path;

  /// The CORS mode: only `'use-credentials'` has an effect (it sends credentials; exception E-GLTF).
  final String crossOrigin;

  /// The fetch priority.
  final String priority;

  /// The fetch cache mode.
  final String cache;

  /// Whether requests send credentials.
  final bool withCredentials;

  /// The request headers.
  final Map<String, String> requestHeader;

  /// The loading manager.
  final LoadingManager manager;

  /// The KTX2 loader (not ported).
  final Object? ktx2Loader;

  /// The meshopt decoder (not ported).
  final Object? meshoptDecoder;
}

/* GLTF PARSER */

/// The parser behind [GLTFLoader]: it turns the glTF definitions into ent objects, caching each dependency. Plugins
/// hook into it through [GLTFLoaderPlugin].
class GLTFParser extends GLTFLoaderPlugin {
  /// Constructs a new parser of the given glTF JSON (default empty) with the given options (default [GLTFParserOptions]).
  GLTFParser([Map<String, Object?>? json, GLTFParserOptions? options])
    : json = json ?? {},
      options = options ?? GLTFParserOptions() {
    // The reference also falls back to the TextureLoader on Safari below 17 and Firefox below 98.
    if (!(Loader.platform?.hasCreateImageBitmap ?? false)) {
      textureLoader = TextureLoader(this.options.manager);
      textureLoader.setPriority(this.options.priority);
      textureLoader.setCache(this.options.cache);
    } else {
      textureLoader = ImageBitmapLoader(this.options.manager);
      textureLoader.setPriority(this.options.priority);
      textureLoader.setCache(this.options.cache);
    }

    textureLoader.setCrossOrigin(this.options.crossOrigin);
    textureLoader.setWithCredentials(this.options.withCredentials);
    textureLoader.setRequestHeader(this.options.requestHeader);

    fileLoader = FileLoader(this.options.manager);
    fileLoader.setPriority(this.options.priority);
    fileLoader.setCache(this.options.cache);
    fileLoader.setResponseType('arraybuffer');

    if (this.options.withCredentials || this.options.crossOrigin == 'use-credentials') {
      fileLoader.setWithCredentials(true);
    }
  }

  @override
  String get name => 'GLTFParser';

  /// The glTF JSON.
  final Map<String, Object?> json;

  /// The extensions the asset uses, by name (`true` for plugins).
  Map<String, Object?> extensions = {};

  /// The plugins, by name.
  Map<String, GLTFLoaderPlugin> plugins = {};

  /// The options.
  final GLTFParserOptions options;

  /// The objects loaded so far, by key (`'mesh:0'`, `'texture:2'`, ...).
  final GLTFRegistry cache = GLTFRegistry();

  /// Associations between ent objects and glTF elements (`{ meshes, primitives, nodes, materials }`).
  Map<Object, Map<String, int>> associations = {};

  /// The geometries built so far, with the primitive each was built from.
  final Map<String, ({Map<String, Object?> primitive, Future<BufferGeometry> promise})> primitiveCache = {};

  /// The nodes loaded so far, by node index.
  Map<int, Future<Object3D>> nodeCache = {};

  /// The references to each mesh: a mesh that several nodes use is cloned for each of them.
  final GLTFRefCache meshCache = GLTFRefCache();

  /// The references to each camera, as [meshCache].
  final GLTFRefCache cameraCache = GLTFRefCache();

  /// The references to each light, as [meshCache].
  final GLTFRefCache lightCache = GLTFRefCache();

  /// How often each node name was used, to make names unique.
  final Map<String, int> nodeNamesUsed = {};

  /// The loaded images, by image index.
  final Map<int, Future<Texture>> sourceCache = {};

  /// The textures, by image URI or buffer view and sampler.
  final Map<String, Future<Texture?>> textureCache = {};

  /// The loader of images: a [TextureLoader], or an [ImageBitmapLoader] where the platform has
  /// `createImageBitmap` (Flutter).
  late final Loader<Object?> textureLoader;

  /// The loader of buffers.
  late final FileLoader fileLoader;

  /// Sets the extensions.
  void setExtensions(Map<String, Object?> extensions) {
    this.extensions = extensions;
  }

  /// Sets the plugins.
  void setPlugins(Map<String, GLTFLoaderPlugin> plugins) {
    this.plugins = plugins;
  }

  /// Parses the glTF asset and calls [onLoad] with the result.
  void parse(void Function(GLTF gltf) onLoad, LoaderErrorCallback onError) {
    final parser = this;
    final json = this.json;
    final extensions = this.extensions;

    // Clear the loader cache
    cache.removeAll();
    nodeCache = {};

    // Mark the special nodes/meshes in json for efficient parse
    _invokeAll((ext) {
      ext._markDefs();
      return null;
    });

    Future.wait(_invokeAll((ext) => ext.beforeRoot()))
        .then((_) {
          return Future.wait<List<Object?>>([
            parser.getDependencies('scene'),
            parser.getDependencies('animation'),
            parser.getDependencies('camera'),
          ]);
        })
        .then((dependencies) {
          final scenes = dependencies[0].cast<Group>();
          final index = (json['scene'] as int?) ?? 0;

          final result = GLTF(
            scene: index < scenes.length ? scenes[index] : null,
            scenes: scenes,
            animations: dependencies[1].cast<AnimationClip>(),
            cameras: dependencies[2].cast<Camera?>(),
            asset: _gltfMap(json['asset']),
            parser: parser,
          );

          _gltfAddUnknownExtensionsToUserData(extensions, result, json);

          _gltfAssignExtrasToUserData(result, json);

          return Future.wait(parser._invokeAll((ext) => ext.afterRoot(result))).then((_) {
            for (final scene in result.scenes) {
              scene.updateMatrixWorld();
            }

            onLoad(result);
          });
        })
        .catchError((Object e) {
          onError(e);
        });
  }

  /// Marks special nodes/meshes in json for efficient parse.
  @override
  void _markDefs() {
    final nodeDefs = _gltfList(json['nodes']);
    final skinDefs = _gltfList(json['skins']);
    final meshDefs = _gltfList(json['meshes']);

    // Nothing in the node definition indicates whether it is a Bone or an
    // Object3D. Use the skins' joint references to mark bones.
    for (var skinIndex = 0, skinLength = skinDefs.length; skinIndex < skinLength; skinIndex++) {
      final joints = _gltfList(_gltfMap(skinDefs[skinIndex])['joints']);

      for (var i = 0, il = joints.length; i < il; i++) {
        _gltfMap(nodeDefs[joints[i] as int])['isBone'] = true;
      }
    }

    // Iterate over all nodes, marking references to shared resources,
    // as well as skeleton joints.
    for (var nodeIndex = 0, nodeLength = nodeDefs.length; nodeIndex < nodeLength; nodeIndex++) {
      final nodeDef = _gltfMap(nodeDefs[nodeIndex]);

      if (nodeDef['mesh'] case final int mesh) {
        _addNodeRef(meshCache, mesh);

        // Nothing in the mesh definition indicates whether it is
        // a SkinnedMesh or Mesh. Use the node's mesh reference
        // to mark SkinnedMesh if node has skin.
        if (nodeDef['skin'] != null) {
          _gltfMap(meshDefs[mesh])['isSkinnedMesh'] = true;
        }
      }

      if (nodeDef['camera'] case final int camera) {
        _addNodeRef(cameraCache, camera);
      }
    }
  }

  /// Counts references to mesh-like objects, so that [_getNodeRef] can return the original on the first use
  /// and clones afterwards.
  void _addNodeRef(GLTFRefCache cache, int? index) {
    if (index == null) {
      return;
    }

    if (cache.refs[index] == null) {
      cache.refs[index] = cache.uses[index] = 0;
    }

    cache.refs[index] = cache.refs[index]! + 1;
  }

  /// Returns a reference to a shared resource, cloning it if necessary.
  T _getNodeRef<T extends Object3D>(GLTFRefCache cache, int index, T object) {
    if ((cache.refs[index] ?? 0) <= 1) {
      return object;
    }

    final ref = object.clone() as T;

    // Propagates mappings to the cloned object, prevents mappings on the
    // original object from being lost.
    void updateMappings(Object3D original, Object3D clone) {
      final mappings = associations[original];

      if (mappings != null) {
        associations[clone] = mappings;
      }

      for (final (i, child) in original.children.indexed) {
        updateMappings(child, clone.children[i]);
      }
    }

    updateMappings(object, ref);

    final uses = cache.uses[index]!;
    cache.uses[index] = uses + 1;
    ref.name += '_instance_$uses';

    return ref;
  }

  T? _invokeOne<T extends Object>(T? Function(GLTFLoaderPlugin ext) func) {
    final extensions = [...plugins.values, this];

    for (var i = 0; i < extensions.length; i++) {
      final result = func(extensions[i]);

      if (result != null) {
        return result;
      }
    }

    return null;
  }

  List<Future<Object?>> _invokeAll(Future<Object?>? Function(GLTFLoaderPlugin ext) func) {
    final extensions = [this, ...plugins.values];
    final pending = <Future<Object?>>[];

    for (var i = 0; i < extensions.length; i++) {
      final result = func(extensions[i]);

      if (result != null) {
        pending.add(result);
      }
    }

    return pending;
  }

  /// Requests the specified dependency asynchronously, with caching.
  ///
  /// [type] is `'scene'`, `'node'`, `'mesh'`, `'accessor'`, `'bufferView'`, `'buffer'`, `'material'`,
  /// `'texture'`, `'skin'`, `'animation'`, `'camera'`, or a type a plugin loads
  /// (`'light'`).
  @override
  Future<Object?> getDependency(String type, int index) {
    final cacheKey = '$type:$index';
    var dependency = cache.get(cacheKey) as Future<Object?>?;

    if (dependency == null) {
      switch (type) {
        case 'scene':
          dependency = loadScene(index);

        case 'node':
          dependency = _invokeOne((ext) => ext.loadNode(index));

        case 'mesh':
          dependency = _invokeOne((ext) => ext.loadMesh(index));

        case 'accessor':
          dependency = loadAccessor(index);

        case 'bufferView':
          dependency = _invokeOne((ext) => ext.loadBufferView(index));

        case 'buffer':
          dependency = loadBuffer(index);

        case 'material':
          dependency = _invokeOne((ext) => ext.loadMaterial(index));

        case 'texture':
          dependency = _invokeOne((ext) => ext.loadTexture(index));

        case 'skin':
          dependency = loadSkin(index);

        case 'animation':
          dependency = _invokeOne((ext) => ext.loadAnimation(index));

        case 'camera':
          dependency = loadCamera(index);

        default:
          dependency = _invokeOne((ext) => ext != this ? ext.getDependency(type, index) : null);

          if (dependency == null) {
            throw EntError('Unknown type: $type');
          }
      }

      cache.add(cacheKey, dependency);
    }

    return dependency ?? Future.value();
  }

  /// Requests all dependencies of the specified type asynchronously, with caching.
  Future<List<Object?>> getDependencies(String type) {
    var dependencies = cache.get(type) as Future<List<Object?>>?;

    if (dependencies == null) {
      final defs = _gltfList(json[type + (type == 'mesh' ? 'es' : 's')]);

      dependencies = Future.wait([for (var index = 0; index < defs.length; index++) getDependency(type, index)]);

      cache.add(type, dependencies);
    }

    return dependencies;
  }

  /// Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#buffers-and-buffer-views
  Future<ByteBuffer> loadBuffer(int bufferIndex) {
    final bufferDef = _gltfMap(_gltfList(json['buffers'])[bufferIndex]);
    final loader = fileLoader;

    if (bufferDef['type'] case final String type when type != 'arraybuffer') {
      throw EntError('ENT.GLTFLoader: $type buffer type is not supported.');
    }

    // If present, GLB container is required to be the first buffer.
    if (bufferDef['uri'] == null && bufferIndex == 0) {
      return Future.value((extensions[_GLTFExtensions.KHR_BINARY_GLTF]! as _GLTFBinaryExtension).body);
    }

    final completer = Completer<ByteBuffer>();

    loader.load(
      LoaderUtils.resolveURL(bufferDef['uri'], options.path),
      (data) => completer.complete(data! as ByteBuffer),
      null,
      (_) {
        completer.completeError(EntError('ENT.GLTFLoader: Failed to load buffer "${bufferDef['uri']}".'));
      },
    );

    return completer.future;
  }

  /// Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#buffers-and-buffer-views
  @override
  Future<ByteBuffer> loadBufferView(int bufferViewIndex) {
    final bufferViewDef = _gltfMap(_gltfList(json['bufferViews'])[bufferViewIndex]);

    return getDependency('buffer', bufferViewDef['buffer']! as int).then((buffer) {
      final byteLength = (bufferViewDef['byteLength'] as int?) ?? 0;
      final byteOffset = (bufferViewDef['byteOffset'] as int?) ?? 0;

      return _gltfSlice(buffer! as ByteBuffer, byteOffset, byteOffset + byteLength);
    });
  }

  /// Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#accessors
  Future<BufferAttributeLike> loadAccessor(int accessorIndex) {
    final parser = this;
    final json = this.json;

    final accessorDef = _gltfMap(_gltfList(this.json['accessors'])[accessorIndex]);
    final componentType = accessorDef['componentType']! as int;
    final count = accessorDef['count']! as int;

    if (accessorDef['bufferView'] == null && accessorDef['sparse'] == null) {
      final itemSize = _gltfTypeSizes[accessorDef['type']]!;
      final normalized = accessorDef['normalized'] == true;

      return Future.value(BufferAttribute(_gltfTypedArray(componentType, count * itemSize), itemSize, normalized));
    }

    final pendingBufferViews = <Future<Object?>>[];

    if (accessorDef['bufferView'] case final int bufferView) {
      pendingBufferViews.add(getDependency('bufferView', bufferView));
    } else {
      pendingBufferViews.add(Future.value());
    }

    final sparse = accessorDef['sparse'] as Map<Object?, Object?>?;

    if (sparse != null) {
      pendingBufferViews.add(getDependency('bufferView', (sparse['indices'] as Map)['bufferView'] as int));
      pendingBufferViews.add(getDependency('bufferView', (sparse['values'] as Map)['bufferView'] as int));
    }

    return Future.wait(pendingBufferViews).then((bufferViews) {
      final bufferView = bufferViews[0] as ByteBuffer?;

      final itemSize = _gltfTypeSizes[accessorDef['type']]!;

      // For VEC3: itemSize is 3, elementBytes is 4, itemBytes is 12.
      final elementBytes = _gltfComponentBytes[componentType]!;
      final itemBytes = elementBytes * itemSize;
      final byteOffset = (accessorDef['byteOffset'] as int?) ?? 0;
      final byteStride = accessorDef['bufferView'] != null
          ? _gltfMap(_gltfList(json['bufferViews'])[accessorDef['bufferView']! as int])['byteStride'] as int?
          : null;
      final normalized = accessorDef['normalized'] == true;
      BufferAttributeLike bufferAttribute;

      // The buffer is not interleaved if the stride is the item size in bytes.
      if (byteStride != null && byteStride != 0 && byteStride != itemBytes) {
        // Each "slice" of the buffer, as defined by 'count' elements of 'byteStride' bytes, gets its own
        // InterleavedBuffer
        // This makes sure that IBA.count reflects accessor.count properly
        final ibSlice = byteOffset ~/ byteStride;
        final ibCacheKey = 'InterleavedBuffer:${accessorDef['bufferView']}:$componentType:$ibSlice:$count';
        var ib = parser.cache.get(ibCacheKey) as InterleavedBuffer?;

        if (ib == null) {
          final array = _gltfTypedView(
            componentType,
            bufferView!,
            ibSlice * byteStride,
            count * byteStride ~/ elementBytes,
          );

          // Integer parameters to IB/IBA are in array elements, not bytes.
          ib = InterleavedBuffer(array, byteStride ~/ elementBytes);

          parser.cache.add(ibCacheKey, ib);
        }

        bufferAttribute = InterleavedBufferAttribute(
          ib,
          itemSize,
          (byteOffset % byteStride) ~/ elementBytes,
          normalized,
        );
      } else {
        final array = bufferView == null
            ? _gltfTypedArray(componentType, count * itemSize)
            : _gltfTypedView(componentType, bufferView, byteOffset, count * itemSize);

        bufferAttribute = BufferAttribute(array, itemSize, normalized);
      }

      // https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#sparse-accessors
      if (sparse != null) {
        final itemSizeIndices = _gltfTypeSizes['SCALAR']!;
        final indices = _gltfMap(sparse['indices']);
        final values = _gltfMap(sparse['values']);
        final sparseCount = sparse['count']! as int;

        final byteOffsetIndices = (indices['byteOffset'] as int?) ?? 0;
        final byteOffsetValues = (values['byteOffset'] as int?) ?? 0;

        final sparseIndices = _gltfTypedView(
          indices['componentType']! as int,
          bufferViews[1]! as ByteBuffer,
          byteOffsetIndices,
          sparseCount * itemSizeIndices,
        );
        final sparseValues = _gltfTypedView(
          componentType,
          bufferViews[2]! as ByteBuffer,
          byteOffsetValues,
          sparseCount * itemSize,
        );

        if (bufferView != null) {
          // Avoid modifying the original ArrayBuffer, if the bufferView wasn't initialized with zeroes.
          bufferAttribute = BufferAttribute(
            bufferAttribute.array.sublist(0),
            bufferAttribute.itemSize,
            bufferAttribute.normalized,
          );
        }

        // Ignore normalized since we copy from sparse
        final sparseAttribute = bufferAttribute as BufferAttribute;
        sparseAttribute.normalized = false;

        for (var i = 0, il = sparseIndices.length; i < il; i++) {
          final index = sparseIndices[i].toInt();

          sparseAttribute.setX(index, sparseValues[i * itemSize].toDouble());

          if (itemSize >= 2) {
            sparseAttribute.setY(index, sparseValues[i * itemSize + 1].toDouble());
          }

          if (itemSize >= 3) {
            sparseAttribute.setZ(index, sparseValues[i * itemSize + 2].toDouble());
          }

          if (itemSize >= 4) {
            sparseAttribute.setW(index, sparseValues[i * itemSize + 3].toDouble());
          }

          if (itemSize >= 5) {
            throw EntError('ENT.GLTFLoader: Unsupported itemSize in sparse BufferAttribute.');
          }
        }

        sparseAttribute.normalized = normalized;
      }

      return bufferAttribute;
    });
  }

  /// Specification: https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#textures
  @override
  Future<Texture?> loadTexture(int textureIndex) {
    final sourceIndex = _gltfMap(_gltfList(json['textures'])[textureIndex])['source']! as int;

    var loader = textureLoader;

    if (_gltfTruthyString(_gltfMap(_gltfList(json['images'])[sourceIndex])['uri']) case final String uri) {
      final handler = options.manager.getHandler(uri);

      if (handler != null) {
        loader = handler;
      }
    }

    return loadTextureImage(textureIndex, sourceIndex, loader);
  }

  /// Loads the texture [textureIndex] from the image [sourceIndex] with [loader] and applies its sampler.
  Future<Texture?> loadTextureImage(int textureIndex, int sourceIndex, Loader<Object?> loader) {
    final textureDef = _gltfMap(_gltfList(json['textures'])[textureIndex]);
    final sourceDef = _gltfMap(_gltfList(json['images'])[sourceIndex]);

    final cacheKey = '${_gltfTruthyString(sourceDef['uri']) ?? sourceDef['bufferView']}:${textureDef['sampler']}';

    if (textureCache[cacheKey] case final cached?) {
      return cached;
    }

    // A microtask: the clones that other textures of the same image take in loadImageSource() run before this
    // texture's users (assignTexture) change it, as with JS promises, whose callbacks each run as their own job
    // (Dart completes a chain of futures depth-first).
    final promise = loadImageSource(sourceIndex, loader)
        .then<Texture?>(
          (texture) => Future.microtask(() {
            texture.flipY = false;

            texture.name = _gltfTruthyString(textureDef['name']) ?? _gltfTruthyString(sourceDef['name']) ?? '';

            if (sourceDef['uri'] case final String uri when texture.name == '' && !uri.startsWith('data:image/')) {
              texture.name = uri;
            }

            final samplers = _gltfList(json['samplers']);
            final index = textureDef['sampler'];
            final sampler = index is int && index < samplers.length
                ? _gltfMap(samplers[index])
                : const <String, Object?>{};

            texture.magFilter = _gltfFilters[sampler['magFilter']] ?? LinearFilter;
            texture.minFilter = _gltfFilters[sampler['minFilter']] ?? LinearMipmapLinearFilter;
            texture.wrapS = _gltfWrappings[sampler['wrapS']] ?? RepeatWrapping;
            texture.wrapT = _gltfWrappings[sampler['wrapT']] ?? RepeatWrapping;
            texture.generateMipmaps =
                texture is! CompressedTexture &&
                texture.minFilter != NearestFilter &&
                texture.minFilter != LinearFilter;

            associations[texture] = {'textures': textureIndex};

            return texture;
          }),
        )
        .catchError((Object _) => null);

    textureCache[cacheKey] = promise;

    return promise;
  }

  /// Loads the image [sourceIndex] into a texture with [loader]; a second request gets a clone.
  ///
  /// The reference wraps an image in a buffer view in a `Blob` behind an object URL; here it becomes a data URI of its
  /// `mimeType` (exception E-GLTF).
  Future<Texture> loadImageSource(int sourceIndex, Loader<Object?> loader) {
    if (sourceCache[sourceIndex] case final cached?) {
      return cached.then((texture) => texture.clone());
    }

    final sourceDef = _gltfMap(_gltfList(json['images'])[sourceIndex]);

    Object? sourceURI = _gltfTruthyString(sourceDef['uri']) ?? '';

    // The reference hands an image in a buffer view straight to a KTX2Loader here: not ported.

    if (sourceDef['bufferView'] case final int bufferView) {
      // Load binary image data from bufferView, if provided.

      sourceURI = getDependency('bufferView', bufferView).then((data) {
        sourceURI = 'data:${sourceDef['mimeType'] ?? ''};base64,${base64.encode((data! as ByteBuffer).asUint8List())}';
        return sourceURI;
      });
    } else if (sourceDef['uri'] == null) {
      throw EntError('ENT.GLTFLoader: Image $sourceIndex is missing URI and bufferView');
    }

    final promise = Future<Object?>.value(sourceURI)
        .then((uri) {
          final completer = Completer<Texture>();

          var onLoad = (Object? texture) => completer.complete(texture! as Texture);

          if (loader is ImageBitmapLoader) {
            onLoad = (Object? imageBitmap) {
              final texture = Texture(imageBitmap);
              texture.needsUpdate = true;

              completer.complete(texture);
            };
          }

          loader.load(LoaderUtils.resolveURL(uri, options.path), onLoad, null, completer.completeError);

          return completer.future;
        })
        .then((texture) {
          // Clean up resources and configure Texture (the reference revokes the object URL here).

          _gltfAssignExtrasToUserData(texture, sourceDef);

          texture.userData['mimeType'] = sourceDef['mimeType'] ?? _gltfImageURIMimeType(sourceDef['uri']);

          return texture;
        })
        .catchError((Object e) {
          error("GLTFLoader: Couldn't load texture", [sourceURI]);

          throw e;
        });

    sourceCache[sourceIndex] = promise;

    return promise;
  }

  /// Asynchronously assigns a texture to the given material parameters.
  Future<Texture?> assignTexture(
    Map<String, Object?> materialParams,
    String mapName,
    Map<String, Object?> mapDef, [
    String? colorSpace,
  ]) {
    final parser = this;

    return getDependency('texture', mapDef['index']! as int).then((result) {
      var texture = result as Texture?;

      if (texture == null) {
        return null;
      }

      if (mapDef['texCoord'] case final num texCoord when texCoord > 0) {
        texture = texture.clone();
        texture.channel = texCoord.toInt();
      }

      if (parser.extensions[_GLTFExtensions.KHR_TEXTURE_TRANSFORM]
          case final _GLTFTextureTransformExtension extension) {
        final transform = mapDef['extensions'] != null
            ? _gltfMap(mapDef['extensions'])[_GLTFExtensions.KHR_TEXTURE_TRANSFORM]
            : null;

        if (transform != null) {
          final gltfReference = parser.associations[texture];
          texture = extension.extendTexture(texture, _gltfMap(transform));

          // The reference sets `undefined` for a texture without one; a missing key reads the same.
          if (gltfReference != null) {
            parser.associations[texture] = gltfReference;
          }
        }
      }

      if (colorSpace != null) {
        texture.colorSpace = colorSpace;
      }

      materialParams[mapName] = texture;

      return texture;
    });
  }

  /// Assigns final material to a Mesh, Line, or Points instance. The instance already has a material (generated from
  /// the glTF material options alone) but reuse of the same glTF material may require multiple materials to accommodate
  /// different primitive types, defines, etc. New materials will be created if necessary, and reused from a cache.
  ///
  /// The reference copies the glTF material's base properties by calling Material's copy on the line or points
  /// material; Dart cannot call a superclass method on another class's instance, so [_gltfCopyMaterialBase] repeats
  /// what [Material.copy] copies (exception E-GLTF).
  void assignFinalMaterial(Object3D mesh) {
    final geometry = _gltfGeometry(mesh);
    var material = _gltfMaterial(mesh);

    final useDerivativeTangents = !geometry.attributes.containsKey('tangent');
    final useVertexColors = geometry.attributes.containsKey('color');
    final useFlatShading = !geometry.attributes.containsKey('normal');

    if (mesh is Points) {
      final cacheKey = 'PointsMaterial:${material.uuid}';

      var pointsMaterial = cache.get(cacheKey) as PointsMaterial?;

      if (pointsMaterial == null) {
        final source = _gltfColorAndMap(material);

        pointsMaterial = PointsMaterial();
        _gltfCopyMaterialBase(pointsMaterial, material);
        pointsMaterial.color.copy(source.$1);
        pointsMaterial.map = source.$2;
        pointsMaterial.sizeAttenuation = false; // glTF spec says points should be 1px

        cache.add(cacheKey, pointsMaterial);
      }

      material = pointsMaterial;
    } else if (mesh is Line) {
      final cacheKey = 'LineBasicMaterial:${material.uuid}';

      var lineMaterial = cache.get(cacheKey) as LineBasicMaterial?;

      if (lineMaterial == null) {
        final source = _gltfColorAndMap(material);

        lineMaterial = LineBasicMaterial();
        _gltfCopyMaterialBase(lineMaterial, material);
        lineMaterial.color.copy(source.$1);
        lineMaterial.map = source.$2;

        cache.add(cacheKey, lineMaterial);
      }

      material = lineMaterial;
    }

    // Clone the material if it will be modified
    if (useDerivativeTangents || useVertexColors || useFlatShading) {
      var cacheKey = 'ClonedMaterial:${material.uuid}:';

      if (useDerivativeTangents) {
        cacheKey += 'derivative-tangents:';
      }

      if (useVertexColors) {
        cacheKey += 'vertex-colors:';
      }

      if (useFlatShading) {
        cacheKey += 'flat-shading:';
      }

      var cachedMaterial = cache.get(cacheKey) as Material?;

      if (cachedMaterial == null) {
        cachedMaterial = material.clone();

        if (useVertexColors) {
          cachedMaterial.vertexColors = true;
        }

        // The reference sets flatShading on any material; MeshBasicMaterial has no such property and ignores it.
        if (useFlatShading && cachedMaterial is MeshStandardMaterial) {
          cachedMaterial.flatShading = true;
        }

        if (useDerivativeTangents) {
          // Without tangents in the glTF, the normal map's y is flipped.
          if (cachedMaterial case MeshStandardMaterial(:final normalScale)) {
            normalScale.y *= -1;
          }

          if (cachedMaterial case MeshPhysicalMaterial(:final clearcoatNormalScale)) {
            clearcoatNormalScale.y *= -1;
          }
        }

        cache.add(cacheKey, cachedMaterial);

        final association = associations[material];

        if (association != null) {
          associations[cachedMaterial] = association;
        }
      }

      material = cachedMaterial;
    }

    switch (mesh) {
      case Mesh():
        mesh.material = material;

      case Line():
        mesh.material = material;

      case Points():
        mesh.material = material;
    }
  }

  /// The material type of a glTF material without a plugin's: [MeshStandardMaterial].
  @override
  GLTFMaterialType getMaterialType(int materialIndex) {
    return MeshStandardMaterial.new;
  }

  /// Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#materials
  @override
  Future<Material> loadMaterial(int materialIndex) {
    final parser = this;
    final json = this.json;
    final extensions = this.extensions;
    final materialDef = _gltfMap(_gltfList(json['materials'])[materialIndex]);

    GLTFMaterialType materialType;
    final materialParams = <String, Object?>{};
    final materialExtensions = _gltfMap(materialDef['extensions'] ?? <String, Object?>{});

    final pending = <Future<Object?>>[];

    if (materialExtensions[_GLTFExtensions.KHR_MATERIALS_UNLIT] != null) {
      final kmuExtension = extensions[_GLTFExtensions.KHR_MATERIALS_UNLIT]! as _GLTFMaterialsUnlitExtension;
      materialType = kmuExtension.getMaterialType();
      pending.add(kmuExtension.extendParams(materialParams, materialDef, parser));
    } else {
      // Specification:
      // https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#metallic-roughness-material

      final metallicRoughness = _gltfMap(materialDef['pbrMetallicRoughness'] ?? <String, Object?>{});

      final color = Color(1.0, 1.0, 1.0);
      materialParams['color'] = color;
      materialParams['opacity'] = 1.0;

      if (metallicRoughness['baseColorFactor'] case final List<Object?> array) {
        color.setRGB(_gltfNum(array[0]), _gltfNum(array[1]), _gltfNum(array[2]), LinearSRGBColorSpace);
        materialParams['opacity'] = _gltfNum(array[3]);
      }

      if (metallicRoughness['baseColorTexture'] != null) {
        pending.add(
          parser.assignTexture(materialParams, 'map', _gltfMap(metallicRoughness['baseColorTexture']), SRGBColorSpace),
        );
      }

      materialParams['metalness'] = metallicRoughness['metallicFactor'] != null
          ? _gltfNum(metallicRoughness['metallicFactor'])
          : 1.0;
      materialParams['roughness'] = metallicRoughness['roughnessFactor'] != null
          ? _gltfNum(metallicRoughness['roughnessFactor'])
          : 1.0;

      if (metallicRoughness['metallicRoughnessTexture'] != null) {
        final texture = _gltfMap(metallicRoughness['metallicRoughnessTexture']);
        pending.add(parser.assignTexture(materialParams, 'metalnessMap', texture));
        pending.add(parser.assignTexture(materialParams, 'roughnessMap', texture));
      }

      materialType = _invokeOne((ext) => ext.getMaterialType(materialIndex))!;

      pending.add(Future.wait(_invokeAll((ext) => ext.extendMaterialParams(materialIndex, materialParams))));
    }

    if (materialDef['doubleSided'] == true) {
      materialParams['side'] = DoubleSide;
    }

    final alphaMode = (materialDef['alphaMode'] as String?) ?? _GLTFAlphaModes.OPAQUE;

    if (alphaMode == _GLTFAlphaModes.BLEND) {
      materialParams['transparent'] = true;

      materialParams['depthWrite'] = false;
    } else {
      materialParams['transparent'] = false;

      if (alphaMode == _GLTFAlphaModes.MASK) {
        materialParams['alphaTest'] = materialDef['alphaCutoff'] != null ? _gltfNum(materialDef['alphaCutoff']) : 0.5;
      }
    }

    final basic = materialType == MeshBasicMaterial.new;

    if (materialDef['normalTexture'] != null && !basic) {
      final normalTexture = _gltfMap(materialDef['normalTexture']);

      pending.add(parser.assignTexture(materialParams, 'normalMap', normalTexture));

      final normalScale = Vector2(1, 1);
      materialParams['normalScale'] = normalScale;

      if (normalTexture['scale'] != null) {
        final scale = _gltfNum(normalTexture['scale']);
        normalScale.set(scale, scale);
      }
    }

    if (materialDef['occlusionTexture'] != null && !basic) {
      final occlusionTexture = _gltfMap(materialDef['occlusionTexture']);

      pending.add(parser.assignTexture(materialParams, 'aoMap', occlusionTexture));

      if (occlusionTexture['strength'] != null) {
        materialParams['aoMapIntensity'] = _gltfNum(occlusionTexture['strength']);
      }
    }

    if (materialDef['emissiveFactor'] case final List<Object?> emissiveFactor when !basic) {
      materialParams['emissive'] = Color().setRGB(
        _gltfNum(emissiveFactor[0]),
        _gltfNum(emissiveFactor[1]),
        _gltfNum(emissiveFactor[2]),
        LinearSRGBColorSpace,
      );
    }

    if (materialDef['emissiveTexture'] != null && !basic) {
      pending.add(
        parser.assignTexture(materialParams, 'emissiveMap', _gltfMap(materialDef['emissiveTexture']), SRGBColorSpace),
      );
    }

    return Future.wait(pending).then((_) {
      final material = materialType(materialParams);

      if (_gltfTruthyString(materialDef['name']) case final String name) {
        material.name = name;
      }

      _gltfAssignExtrasToUserData(material, materialDef);

      parser.associations[material] = {'materials': materialIndex};

      if (materialDef['extensions'] != null) {
        _gltfAddUnknownExtensionsToUserData(extensions, material, materialDef);
      }

      return material;
    });
  }

  /// When Object3D instances are targeted by animation, they need unique names.
  String createUniqueName(String? originalName) {
    final sanitizedName = PropertyBinding.sanitizeNodeName(originalName ?? '');

    if (nodeNamesUsed.containsKey(sanitizedName)) {
      final used = nodeNamesUsed[sanitizedName]! + 1;
      nodeNamesUsed[sanitizedName] = used;
      return '${sanitizedName}_$used';
    } else {
      nodeNamesUsed[sanitizedName] = 0;

      return sanitizedName;
    }
  }

  /// Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#geometry
  ///
  /// Creates BufferGeometries from primitives.
  Future<List<BufferGeometry>> loadGeometries(List<Map<String, Object?>> primitives) {
    final parser = this;
    final extensions = this.extensions;
    final cache = primitiveCache;

    final pending = <Future<BufferGeometry>>[];

    for (var i = 0, il = primitives.length; i < il; i++) {
      final primitive = primitives[i];
      final cacheKey = _gltfCreatePrimitiveKey(primitive);

      // See if we've already created this geometry
      final cached = cache[cacheKey];

      if (cached != null) {
        // Use the cached geometry if it exists
        pending.add(cached.promise);
      } else {
        Future<BufferGeometry> geometryPromise;

        if ((primitive['extensions'] as Map<Object?, Object?>?)?[_GLTFExtensions.KHR_DRACO_MESH_COMPRESSION] != null) {
          // Draco is not ported (exception E-GLTF); the reference decodes the primitive with the DRACOLoader here.
          throw EntError(
            'ENT.GLTFLoader: ${_GLTFExtensions.KHR_DRACO_MESH_COMPRESSION} is not supported '
            '(${extensions.containsKey(_GLTFExtensions.KHR_DRACO_MESH_COMPRESSION)}).',
          );
        } else {
          // Otherwise create a new geometry
          geometryPromise = _gltfAddPrimitiveAttributes(BufferGeometry(), primitive, parser);
        }

        // Convert strip/fan primitives to triangles
        if (primitive['mode'] == _GLTFWebGL.TRIANGLE_STRIP) {
          geometryPromise = geometryPromise.then(
            (geometry) => BufferGeometryUtils.toTrianglesDrawMode(geometry, TriangleStripDrawMode),
          );
        } else if (primitive['mode'] == _GLTFWebGL.TRIANGLE_FAN) {
          geometryPromise = geometryPromise.then(
            (geometry) => BufferGeometryUtils.toTrianglesDrawMode(geometry, TriangleFanDrawMode),
          );
        }

        // Cache this geometry
        cache[cacheKey] = (primitive: primitive, promise: geometryPromise);

        pending.add(geometryPromise);
      }
    }

    return Future.wait(pending);
  }

  /// Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#meshes
  @override
  Future<Object3D> loadMesh(int meshIndex) {
    final parser = this;
    final json = this.json;
    final extensions = this.extensions;

    final meshDef = _gltfMap(_gltfList(json['meshes'])[meshIndex]);
    final primitives = [for (final p in _gltfList(meshDef['primitives'])) _gltfMap(p)];

    final pending = <Future<Object?>>[];

    for (var i = 0, il = primitives.length; i < il; i++) {
      final material = primitives[i]['material'] == null
          ? Future<Object?>.value(_gltfCreateDefaultMaterial(cache))
          : getDependency('material', primitives[i]['material']! as int);

      pending.add(material);
    }

    pending.add(parser.loadGeometries(primitives));

    return Future.wait(pending).then((results) {
      final materials = results.sublist(0, results.length - 1);
      final geometries = results[results.length - 1]! as List<BufferGeometry>;

      final meshes = <Object3D>[];

      for (var i = 0, il = geometries.length; i < il; i++) {
        final geometry = geometries[i];
        final primitive = primitives[i];

        // 1. create Mesh

        Object3D mesh;

        final material = materials[i];
        final mode = primitive['mode'];

        if (mode == _GLTFWebGL.TRIANGLES ||
            mode == _GLTFWebGL.TRIANGLE_STRIP ||
            mode == _GLTFWebGL.TRIANGLE_FAN ||
            mode == null) {
          final needsSkinning = meshDef['isSkinnedMesh'] == true;
          final hasSkinningAttributes = geometry.hasAttribute('skinIndex') && geometry.hasAttribute('skinWeight');

          if (needsSkinning && hasSkinningAttributes == false) {
            warn('GLTFLoader: Missing skinIndex or skinWeight attributes. Skinning disabled.');
          }

          // .isSkinnedMesh isn't in glTF spec. See ._markDefs()
          mesh = (needsSkinning && hasSkinningAttributes) ? SkinnedMesh(geometry, material) : Mesh(geometry, material);

          if (mesh is SkinnedMesh) {
            // normalize skin weights to fix malformed assets (see #15319)
            mesh.normalizeSkinWeights();
          }
        } else if (mode == _GLTFWebGL.LINES) {
          mesh = LineSegments(geometry, material);
        } else if (mode == _GLTFWebGL.LINE_STRIP) {
          mesh = Line(geometry, material);
        } else if (mode == _GLTFWebGL.LINE_LOOP) {
          mesh = LineLoop(geometry, material);
        } else if (mode == _GLTFWebGL.POINTS) {
          mesh = Points(geometry, material);
        } else {
          throw EntError('ENT.GLTFLoader: Primitive mode unsupported: $mode');
        }

        if (geometry.morphAttributes.isNotEmpty) {
          _gltfUpdateMorphTargets(mesh, meshDef);
        }

        mesh.name = parser.createUniqueName(_gltfTruthyString(meshDef['name']) ?? 'mesh_$meshIndex');

        _gltfAssignExtrasToUserData(mesh, meshDef);

        if (primitive['extensions'] != null) {
          _gltfAddUnknownExtensionsToUserData(extensions, mesh, primitive);
        }

        parser.assignFinalMaterial(mesh);

        meshes.add(mesh);
      }

      for (var i = 0, il = meshes.length; i < il; i++) {
        parser.associations[meshes[i]] = {'meshes': meshIndex, 'primitives': i};
      }

      if (meshes.length == 1) {
        if (meshDef['extensions'] != null) {
          _gltfAddUnknownExtensionsToUserData(extensions, meshes[0], meshDef);
        }

        return meshes[0];
      }

      final group = Group();

      if (meshDef['extensions'] != null) {
        _gltfAddUnknownExtensionsToUserData(extensions, group, meshDef);
      }

      parser.associations[group] = {'meshes': meshIndex};

      for (var i = 0, il = meshes.length; i < il; i++) {
        group.add(meshes[i]);
      }

      return group;
    });
  }

  /// Specification: https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#cameras
  Future<Camera?> loadCamera(int cameraIndex) {
    Camera camera;
    final cameraDef = _gltfMap(_gltfList(json['cameras'])[cameraIndex]);
    final params = cameraDef[cameraDef['type']] as Map<Object?, Object?>?;

    if (params == null) {
      warn('GLTFLoader: Missing camera parameters.');
      return Future.value();
    }

    // `x || d`: a missing or zero value takes the default.
    double or(Object? v, double d) => v == null || _gltfNum(v) == 0 ? d : _gltfNum(v);

    if (cameraDef['type'] == 'perspective') {
      camera = PerspectiveCamera(
        MathUtils.radToDeg(_gltfNum(params['yfov'])),
        or(params['aspectRatio'], 1),
        or(params['znear'], 1),
        or(params['zfar'], 2e6),
      );
    } else if (cameraDef['type'] == 'orthographic') {
      final xmag = _gltfNum(params['xmag']);
      final ymag = _gltfNum(params['ymag']);

      camera = OrthographicCamera(
        -xmag,
        xmag,
        ymag,
        -ymag,
        params['znear'] == null ? 0.1 : _gltfNum(params['znear']),
        params['zfar'] == null ? 2000 : _gltfNum(params['zfar']),
      );
    } else {
      // The reference throws a TypeError here: it reads `camera.name` of undefined.
      throw EntError('ENT.GLTFLoader: Unsupported camera type: ${cameraDef['type']}');
    }

    if (_gltfTruthyString(cameraDef['name']) case final String name) {
      camera.name = createUniqueName(name);
    }

    _gltfAssignExtrasToUserData(camera, cameraDef);

    return Future.value(camera);
  }

  /// Specification: https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#skins
  Future<Skeleton> loadSkin(int skinIndex) {
    final skinDef = _gltfMap(_gltfList(json['skins'])[skinIndex]);
    final joints = _gltfList(skinDef['joints']);

    final pending = <Future<Object?>>[];

    for (var i = 0, il = joints.length; i < il; i++) {
      pending.add(_loadNodeShallow(joints[i]! as int));
    }

    if (skinDef['inverseBindMatrices'] != null) {
      pending.add(getDependency('accessor', skinDef['inverseBindMatrices']! as int));
    } else {
      pending.add(Future<Object?>.value());
    }

    return Future.wait(pending).then((results) {
      final inverseBindMatrices = results.removeLast() as BufferAttributeLike?;

      // Note that bones (joint nodes) may or may not be in the
      // scene graph at this time.

      final bones = <Bone>[];
      final boneInverses = <Matrix4>[];

      // The reference warns 'Joint "%s" could not be found.' for a falsy joint node; ._loadNodeShallow() always
      // yields one here, and a joint node is always a Bone (see ._markDefs()).
      for (var i = 0, il = results.length; i < il; i++) {
        bones.add(results[i]! as Bone);

        final mat = Matrix4();

        if (inverseBindMatrices != null) {
          mat.fromArray(inverseBindMatrices.array, i * 16);
        }

        boneInverses.add(mat);
      }

      return Skeleton(bones, boneInverses);
    });
  }

  /// Specification: https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#animations
  @override
  Future<AnimationClip> loadAnimation(int animationIndex) {
    final json = this.json;
    final parser = this;

    final animationDef = _gltfMap(_gltfList(json['animations'])[animationIndex]);

    final pendingNodes = <Future<Object?>>[];
    final pendingInputAccessors = <Future<Object?>>[];
    final pendingOutputAccessors = <Future<Object?>>[];
    final samplers = <Map<String, Object?>>[];
    final targets = <Map<String, Object?>>[];

    final channels = _gltfList(animationDef['channels']);
    final parameters = animationDef['parameters'] as Map<Object?, Object?>?;

    for (var i = 0, il = channels.length; i < il; i++) {
      final channel = _gltfMap(channels[i]);
      final sampler = _gltfMap(_gltfList(animationDef['samplers'])[channel['sampler']! as int]);
      final target = _gltfMap(channel['target']);
      final input = parameters != null ? parameters[sampler['input']] : sampler['input'];
      final output = parameters != null ? parameters[sampler['output']] : sampler['output'];

      if (target['node'] == null) {
        continue;
      }

      pendingNodes.add(getDependency('node', target['node']! as int));
      pendingInputAccessors.add(getDependency('accessor', input! as int));
      pendingOutputAccessors.add(getDependency('accessor', output! as int));
      samplers.add(sampler);
      targets.add(target);
    }

    return Future.wait([
      Future.wait(pendingNodes),
      Future.wait(pendingInputAccessors),
      Future.wait(pendingOutputAccessors),
    ]).then((dependencies) {
      final nodes = dependencies[0];
      final inputAccessors = dependencies[1];
      final outputAccessors = dependencies[2];

      final tracks = <KeyframeTrack>[];

      for (var i = 0, il = nodes.length; i < il; i++) {
        final node = nodes[i] as Object3D?;

        if (node == null) {
          continue;
        }

        node.updateMatrix();

        tracks.addAll(
          parser._createAnimationTracks(
            node,
            inputAccessors[i]! as BufferAttributeLike,
            outputAccessors[i]! as BufferAttributeLike,
            samplers[i],
            targets[i],
          ),
        );
      }

      final animation = AnimationClip(
        _gltfTruthyString(animationDef['name']) ?? 'animation_$animationIndex',
        -1,
        tracks,
      );

      _gltfAssignExtrasToUserData(animation, animationDef);

      return animation;
    });
  }

  /// Creates the mesh (or group of meshes) of a node, cloned when the glTF mesh is used more than once.
  @override
  Future<Object3D>? createNodeMesh(int nodeIndex) {
    final json = this.json;
    final parser = this;
    final nodeDef = _gltfMap(_gltfList(json['nodes'])[nodeIndex]);

    final meshIndex = nodeDef['mesh'] as int?;

    if (meshIndex == null) {
      return null;
    }

    return parser.getDependency('mesh', meshIndex).then((mesh) {
      final node = parser._getNodeRef(parser.meshCache, meshIndex, mesh! as Object3D);

      // if weights are provided on the node, override weights on the mesh.
      if (nodeDef['weights'] case final List<Object?> weights) {
        node.traverse((o) {
          if (o is! Mesh) {
            return;
          }

          for (var i = 0, il = weights.length; i < il; i++) {
            o.morphTargetInfluences![i] = _gltfNum(weights[i]);
          }
        });
      }

      return node;
    });
  }

  /// Specification: https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#nodes-and-hierarchy
  @override
  Future<Object3D> loadNode(int nodeIndex) {
    final json = this.json;
    final parser = this;

    final nodeDef = _gltfMap(_gltfList(json['nodes'])[nodeIndex]);

    final nodePending = parser._loadNodeShallow(nodeIndex);

    final childPending = <Future<Object?>>[];
    final childrenDef = _gltfList(nodeDef['children']);

    for (var i = 0, il = childrenDef.length; i < il; i++) {
      childPending.add(parser.getDependency('node', childrenDef[i]! as int));
    }

    final skeletonPending = nodeDef['skin'] == null
        ? Future<Object?>.value()
        : parser.getDependency('skin', nodeDef['skin']! as int);

    return Future.wait<Object?>([nodePending, Future.wait(childPending), skeletonPending]).then((results) {
      final node = results[0]! as Object3D;
      final children = (results[1]! as List).cast<Object3D>();

      if (results[2] case final Skeleton skeleton) {
        // This full traverse should be fine because
        // child glTF nodes have not been added to this node yet.
        node.traverse((mesh) {
          if (mesh is! SkinnedMesh) {
            return;
          }

          mesh.bind(skeleton, _gltfIdentityMatrix);
        });
      }

      for (var i = 0, il = children.length; i < il; i++) {
        node.add(children[i]);
      }

      // Reconstruct pivot from container pattern created by GLTFExporter
      // The container has position+pivot, rotation, scale; child has -pivot offset and mesh
      if (node.userData['pivot'] != null && children.isNotEmpty) {
        final pivot = [for (final v in node.userData['pivot']! as List) _gltfNum(v)];
        final pivotChild = children[0];

        // Set pivot on container and adjust transforms
        node.pivot = Vector3().fromArray(pivot);

        // Adjust container position: stored as position + pivot, so subtract pivot
        node.position.x -= pivot[0];
        node.position.y -= pivot[1];
        node.position.z -= pivot[2];

        // Remove the child's -pivot offset since pivot now handles it
        pivotChild.position.set(0, 0, 0);

        node.userData.remove('pivot');
      }

      return node;
    });
  }

  // ._loadNodeShallow() parses a single node.
  // skin and child nodes are created and added in .loadNode() (no '_' prefix).
  Future<Object3D> _loadNodeShallow(int nodeIndex) {
    final json = this.json;
    final extensions = this.extensions;
    final parser = this;

    // This method is called from .loadNode() and .loadSkin().
    // Cache a node to avoid duplication.

    final cached = nodeCache[nodeIndex];

    if (cached != null) {
      return cached;
    }

    final nodeDef = _gltfMap(_gltfList(json['nodes'])[nodeIndex]);

    // reserve node's name before its dependencies, so the root has the intended name.
    final nodeName = _gltfTruthyString(nodeDef['name']) != null
        ? parser.createUniqueName(nodeDef['name'] as String)
        : '';

    final pending = <Future<Object?>>[];

    final meshPromise = parser._invokeOne((ext) => ext.createNodeMesh(nodeIndex));

    if (meshPromise != null) {
      pending.add(meshPromise);
    }

    if (nodeDef['camera'] case final int cameraIndex) {
      pending.add(
        parser.getDependency('camera', cameraIndex).then((camera) {
          return parser._getNodeRef(parser.cameraCache, cameraIndex, camera! as Camera);
        }),
      );
    }

    parser._invokeAll((ext) => ext.createNodeAttachment(nodeIndex)).forEach(pending.add);

    return nodeCache[nodeIndex] = Future.wait(pending).then((objects) {
      Object3D node;

      // .isBone isn't in glTF spec. See ._markDefs
      if (nodeDef['isBone'] == true) {
        node = Bone();
      } else if (objects.length > 1) {
        node = Group();
      } else if (objects.length == 1) {
        node = objects[0]! as Object3D;
      } else {
        node = Object3D();
      }

      if (objects.isEmpty || node != objects[0]) {
        for (var i = 0, il = objects.length; i < il; i++) {
          node.add(objects[i]! as Object3D);
        }
      }

      if (_gltfTruthyString(nodeDef['name']) case final String name) {
        node.userData['name'] = name;
        node.name = nodeName;
      }

      _gltfAssignExtrasToUserData(node, nodeDef);

      if (nodeDef['extensions'] != null) {
        _gltfAddUnknownExtensionsToUserData(extensions, node, nodeDef);
      }

      if (nodeDef['matrix'] case final List<Object?> matrix) {
        node.applyMatrix4(Matrix4()..fromArray(matrix.cast<num>()));
      } else {
        if (nodeDef['translation'] case final List<Object?> translation) {
          node.position.fromArray(translation.cast<num>());
        }

        if (nodeDef['rotation'] case final List<Object?> rotation) {
          node.quaternion.fromArray(rotation.cast<num>());
        }

        if (nodeDef['scale'] case final List<Object?> scale) {
          node.scale.fromArray(scale.cast<num>());
        }
      }

      final mapping = parser.associations[node];

      if (mapping == null) {
        parser.associations[node] = {};
      } else if (nodeDef['mesh'] != null && (parser.meshCache.refs[nodeDef['mesh']! as int] ?? 0) > 1) {
        parser.associations[node] = {...mapping};
      }

      parser.associations[node]!['nodes'] = nodeIndex;

      return node;
    });
  }

  /// Specification: https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#scenes
  Future<Group> loadScene(int sceneIndex) {
    final extensions = this.extensions;
    final sceneDef = _gltfMap(_gltfList(json['scenes'])[sceneIndex]);
    final parser = this;

    // Loader returns Group, not Scene.
    final scene = Group();

    if (_gltfTruthyString(sceneDef['name']) case final String name) {
      scene.name = parser.createUniqueName(name);
    }

    _gltfAssignExtrasToUserData(scene, sceneDef);

    if (sceneDef['extensions'] != null) {
      _gltfAddUnknownExtensionsToUserData(extensions, scene, sceneDef);
    }

    final nodeIds = _gltfList(sceneDef['nodes']);

    final pending = <Future<Object?>>[];

    for (var i = 0, il = nodeIds.length; i < il; i++) {
      pending.add(parser.getDependency('node', nodeIds[i]! as int));
    }

    return Future.wait(pending).then((nodes) {
      for (var i = 0, il = nodes.length; i < il; i++) {
        final node = nodes[i]! as Object3D;

        // If the node already has a parent, it means it's being reused across multiple scenes.
        // Clone it to avoid the second scene's add() removing it from the first scene.
        if (node.parent != null) {
          scene.add(SkeletonUtils.clone(node));
        } else {
          scene.add(node);
        }
      }

      // Removes dangling associations, associations that reference a node that
      // didn't make it into the scene.
      Map<Object, Map<String, int>> reduceAssociations(Object3D node) {
        final reducedAssociations = <Object, Map<String, int>>{};

        for (final MapEntry(:key, :value) in parser.associations.entries) {
          if (key is Material || key is Texture) {
            reducedAssociations[key] = value;
          }
        }

        node.traverse((node) {
          final mappings = parser.associations[node];

          if (mappings != null) {
            reducedAssociations[node] = mappings;
          }
        });

        return reducedAssociations;
      }

      parser.associations = reduceAssociations(scene);

      return scene;
    });
  }

  List<KeyframeTrack> _createAnimationTracks(
    Object3D node,
    BufferAttributeLike inputAccessor,
    BufferAttributeLike outputAccessor,
    Map<String, Object?> sampler,
    Map<String, Object?> target,
  ) {
    final tracks = <KeyframeTrack>[];

    final targetNames = <String>[];

    void collectMorphTargets(Object3D object) {
      if (_gltfMorphTargetInfluences(object) != null) {
        targetNames.add(object.name.isNotEmpty ? object.name : object.uuid);
      }
    }

    final path = _gltfPathProperties[target['path']];

    if (path == _gltfPathProperties['weights']) {
      collectMorphTargets(node);

      // for multi-primitive meshes, the node is a Group containing the sub-meshes

      if (node is Group) {
        node.children.forEach(collectMorphTargets);
      }
    } else {
      targetNames.add(node.name.isNotEmpty ? node.name : node.uuid);
    }

    final KeyframeTrack Function(String, List<Object?>, List<Object?>, [int?]) typedKeyframeTrack;

    switch (path) {
      case 'morphTargetInfluences':
        typedKeyframeTrack = NumberKeyframeTrack.new;

      case 'quaternion':
        typedKeyframeTrack = QuaternionKeyframeTrack.new;

      case 'position' || 'scale':
        typedKeyframeTrack = VectorKeyframeTrack.new;

      default:
        switch (outputAccessor.itemSize) {
          case 1:
            typedKeyframeTrack = NumberKeyframeTrack.new;

          default:
            typedKeyframeTrack = VectorKeyframeTrack.new;
        }
    }

    final interpolation = sampler['interpolation'] != null
        ? _gltfInterpolation[sampler['interpolation']]
        : InterpolateLinear;

    final outputArray = _getArrayFromAccessor(outputAccessor);

    for (var j = 0, jl = targetNames.length; j < jl; j++) {
      final track = typedKeyframeTrack('${targetNames[j]}.$path', inputAccessor.array, outputArray, interpolation);

      // Override interpolation with custom factory method.
      if (sampler['interpolation'] == 'CUBICSPLINE') {
        _createCubicSplineTrackInterpolant(track);
      }

      tracks.add(track);
    }

    return tracks;
  }

  List<num> _getArrayFromAccessor(BufferAttributeLike accessor) {
    var outputArray = accessor.array;

    if (accessor.normalized) {
      final scale = _gltfGetNormalizedComponentScale(switch (outputArray) {
        Int8List() => 5120,
        Uint8List() => 5121,
        Int16List() => 5122,
        Uint16List() => 5123,
        _ => 0,
      });
      final scaled = Float32List(outputArray.length);

      for (var j = 0, jl = outputArray.length; j < jl; j++) {
        scaled[j] = outputArray[j] * scale;
      }

      outputArray = scaled;
    }

    return outputArray;
  }

  void _createCubicSplineTrackInterpolant(KeyframeTrack track) {
    // A CUBICSPLINE keyframe in glTF has three output values for each input value,
    // representing inTangent, splineVertex, and outTangent. As a result, track.getValueSize()
    // must be divided by three to get the interpolant's sampleSize argument.
    //
    // The reference also marks the factory with isInterpolantFactoryMethodGLTFCubicSpline; here
    // track.getInterpolation() returns null for it, as the reference's returns undefined.
    track.interpolantFactory = (t, result) {
      final size = t.getValueSize() ~/ 3;
      final values = t.values as List<double>;

      return t is QuaternionKeyframeTrack
          ? _GLTFCubicSplineQuaternionInterpolant(t.times, values, size, result as List<double>?)
          : _GLTFCubicSplineInterpolant(t.times, values, size, result as List<double>?);
    };
  }
}

/// Bounds of the geometry from the accessor's min/max.
void _gltfComputeBounds(BufferGeometry geometry, Map<String, Object?> primitiveDef, GLTFParser parser) {
  final attributes = _gltfMap(primitiveDef['attributes']);

  final box = Box3();

  if (attributes['POSITION'] case final int position) {
    final accessor = _gltfMap(_gltfList(parser.json['accessors'])[position]);

    final min = accessor['min'] as List<Object?>?;
    final max = accessor['max'] as List<Object?>?;

    // glTF requires 'min' and 'max', but VRM (which extends glTF) currently ignores that requirement.

    if (min != null && max != null) {
      box.set(
        Vector3(_gltfNum(min[0]), _gltfNum(min[1]), _gltfNum(min[2])),
        Vector3(_gltfNum(max[0]), _gltfNum(max[1]), _gltfNum(max[2])),
      );

      if (accessor['normalized'] == true) {
        final boxScale = _gltfGetNormalizedComponentScale(accessor['componentType']! as int);
        box.min.multiplyScalar(boxScale);
        box.max.multiplyScalar(boxScale);
      }
    } else {
      warn('GLTFLoader: Missing min/max properties for accessor POSITION.');

      return;
    }
  } else {
    return;
  }

  if (primitiveDef['targets'] case final List<Object?> targets) {
    final maxDisplacement = Vector3();
    final vector = Vector3();

    for (var i = 0, il = targets.length; i < il; i++) {
      final target = _gltfMap(targets[i]);

      if (target['POSITION'] != null) {
        final accessor = _gltfMap(_gltfList(parser.json['accessors'])[target['POSITION']! as int]);
        final min = accessor['min'] as List<Object?>?;
        final max = accessor['max'] as List<Object?>?;

        // glTF requires 'min' and 'max', but VRM (which extends glTF) currently ignores that requirement.

        if (min != null && max != null) {
          // we need to get max of absolute components because target weight is [-1,1]
          vector.setX(math.max(_gltfNum(min[0]).abs(), _gltfNum(max[0]).abs()));
          vector.setY(math.max(_gltfNum(min[1]).abs(), _gltfNum(max[1]).abs()));
          vector.setZ(math.max(_gltfNum(min[2]).abs(), _gltfNum(max[2]).abs()));

          if (accessor['normalized'] == true) {
            vector.multiplyScalar(_gltfGetNormalizedComponentScale(accessor['componentType']! as int));
          }

          // Note: this assumes that the sum of all weights is at most 1. This isn't quite correct - it's more
          // conservative to assume that each target can have a max weight of 1. However, for some use cases -
          // notably, when morph targets are used to implement key-frame animations and as such only two are active
          // at a time - this results in very large boxes. So for now we make a box that's sometimes a touch too
          // small but is hopefully mostly of reasonable size.
          maxDisplacement.max(vector);
        } else {
          warn('GLTFLoader: Missing min/max properties for accessor POSITION.');
        }
      }
    }

    // As per comment above this box isn't conservative, but has a reasonable size for a very large number of morph
    // targets.
    box.expandByVector(maxDisplacement);
  }

  geometry.boundingBox = box;

  final sphere = Sphere();

  box.getCenter(sphere.center);
  sphere.radius = box.min.distanceTo(box.max) / 2;

  geometry.boundingSphere = sphere;
}

Future<BufferGeometry> _gltfAddPrimitiveAttributes(
  BufferGeometry geometry,
  Map<String, Object?> primitiveDef,
  GLTFParser parser,
) {
  final attributes = _gltfMap(primitiveDef['attributes']);

  final pending = <Future<void>>[];

  Future<void> assignAttributeAccessor(int accessorIndex, String attributeName) {
    return parser.getDependency('accessor', accessorIndex).then((accessor) {
      geometry.setAttribute(attributeName, accessor! as BufferAttributeLike);
    });
  }

  for (final gltfAttributeName in attributes.keys) {
    final name = _gltfAttributes[gltfAttributeName] ?? gltfAttributeName.toLowerCase();

    // Skip attributes already provided by e.g. Draco extension.
    if (geometry.attributes.containsKey(name)) {
      continue;
    }

    pending.add(assignAttributeAccessor(attributes[gltfAttributeName]! as int, name));
  }

  if (primitiveDef['indices'] != null && geometry.index == null) {
    final accessor = parser.getDependency('accessor', primitiveDef['indices']! as int).then((accessor) {
      geometry.setIndex(accessor);
    });

    pending.add(accessor);
  }

  if (ColorManagement.workingColorSpace != LinearSRGBColorSpace && attributes.containsKey('COLOR_0')) {
    warn(
      'GLTFLoader: Converting vertex colors from "srgb-linear" to "${ColorManagement.workingColorSpace}" '
      'not supported.',
    );
  }

  _gltfAssignExtrasToUserData(geometry, primitiveDef);

  _gltfComputeBounds(geometry, primitiveDef, parser);

  return Future.wait(pending).then((_) {
    if (primitiveDef['targets'] case final List<Object?> targets) {
      return _gltfAddMorphTargets(geometry, [for (final t in targets) _gltfMap(t)], parser);
    }

    return geometry;
  });
}

/// Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#morph-targets
Future<BufferGeometry> _gltfAddMorphTargets(
  BufferGeometry geometry,
  List<Map<String, Object?>> targets,
  GLTFParser parser,
) {
  var hasMorphPosition = false;
  var hasMorphNormal = false;
  var hasMorphColor = false;

  for (var i = 0, il = targets.length; i < il; i++) {
    final target = targets[i];

    if (target['POSITION'] != null) {
      hasMorphPosition = true;
    }

    if (target['NORMAL'] != null) {
      hasMorphNormal = true;
    }

    if (target['COLOR_0'] != null) {
      hasMorphColor = true;
    }

    if (hasMorphPosition && hasMorphNormal && hasMorphColor) {
      break;
    }
  }

  if (!hasMorphPosition && !hasMorphNormal && !hasMorphColor) {
    return Future.value(geometry);
  }

  final pendingPositionAccessors = <Future<Object?>>[];
  final pendingNormalAccessors = <Future<Object?>>[];
  final pendingColorAccessors = <Future<Object?>>[];

  // A target without the attribute morphs to the base attribute itself.
  Future<Object?> pendingAccessor(Map<String, Object?> target, String gltfName, String name) {
    return target[gltfName] != null
        ? parser.getDependency('accessor', target[gltfName]! as int)
        : Future.value(geometry.attributes[name]);
  }

  for (var i = 0, il = targets.length; i < il; i++) {
    final target = targets[i];

    if (hasMorphPosition) {
      pendingPositionAccessors.add(pendingAccessor(target, 'POSITION', 'position'));
    }

    if (hasMorphNormal) {
      pendingNormalAccessors.add(pendingAccessor(target, 'NORMAL', 'normal'));
    }

    if (hasMorphColor) {
      pendingColorAccessors.add(pendingAccessor(target, 'COLOR_0', 'color'));
    }
  }

  return Future.wait([
    Future.wait(pendingPositionAccessors),
    Future.wait(pendingNormalAccessors),
    Future.wait(pendingColorAccessors),
  ]).then((accessors) {
    if (hasMorphPosition) {
      geometry.morphAttributes['position'] = accessors[0].cast<BufferAttributeLike>();
    }

    if (hasMorphNormal) {
      geometry.morphAttributes['normal'] = accessors[1].cast<BufferAttributeLike>();
    }

    if (hasMorphColor) {
      geometry.morphAttributes['color'] = accessors[2].cast<BufferAttributeLike>();
    }

    geometry.morphTargetsRelative = true;

    return geometry;
  });
}

/// The `morphTargetInfluences` of [object], read duck-typed.
List<double>? _gltfMorphTargetInfluences(Object3D object) {
  return switch (object) {
    Mesh() => object.morphTargetInfluences,
    Line() => object.morphTargetInfluences,
    Points() => object.morphTargetInfluences,
    _ => null,
  };
}

void _gltfUpdateMorphTargets(Object3D mesh, Map<String, Object?> meshDef) {
  switch (mesh) {
    case Mesh():
      mesh.updateMorphTargets();

    case Line():
      mesh.updateMorphTargets();

    case Points():
      mesh.updateMorphTargets();
  }

  final influences = _gltfMorphTargetInfluences(mesh)!;

  if (meshDef['weights'] case final List<Object?> weights) {
    for (var i = 0, il = weights.length; i < il; i++) {
      influences[i] = _gltfNum(weights[i]);
    }
  }

  // .extras has user-defined data, so check that .extras.targetNames is an array.
  if (meshDef['extras'] case {'targetNames': final List<Object?> targetNames}) {
    if (influences.length == targetNames.length) {
      final dictionary = <String, int>{};

      for (var i = 0, il = targetNames.length; i < il; i++) {
        dictionary['${targetNames[i]}'] = i;
      }

      switch (mesh) {
        case Mesh():
          mesh.morphTargetDictionary = dictionary;

        case Line():
          mesh.morphTargetDictionary = dictionary;

        case Points():
          mesh.morphTargetDictionary = dictionary;
      }
    } else {
      warn('GLTFLoader: Invalid extras.targetNames length. Ignoring names.');
    }
  }
}

/* HELPERS */

/// `buffer.slice( begin, end )`: a copy in a new buffer.
ByteBuffer _gltfSlice(ByteBuffer buffer, int begin, int end) {
  final length = buffer.lengthInBytes;
  final from = math.min(begin, length);

  return Uint8List.fromList(buffer.asUint8List(from, math.max(0, math.min(end, length) - from))).buffer;
}

Map<String, Object?> _gltfMap(Object? value) => (value! as Map).cast<String, Object?>();

List<Object?> _gltfList(Object? value) => value == null ? const [] : value as List<Object?>;

double _gltfNum(Object? value) => (value! as num).toDouble();

/// A string that is truthy in JS (non-empty), or `null`.
String? _gltfTruthyString(Object? value) => value is String && value.isNotEmpty ? value : null;

/// A JSON value as JS string concatenation writes it (`undefined` for a missing one).
String _gltfJs(Object? value) => value == null ? 'undefined' : '$value';
