part of '../../ent.dart';

/// Materials registered with [MaterialLoader.registerMaterial], by type name.
final Map<String, Material Function()> _materialLoaderCustom = {};

/// Class for loading materials. The files are internally loaded via [FileLoader].
class MaterialLoader extends Loader<Material> {
  /// Constructs a new material loader.
  MaterialLoader([super.manager]);

  /// A dictionary holding textures used by the material.
  Map<String, Texture> textures = {};

  /// Starts loading from the given URL and pass the loaded material to the [onLoad] callback.
  @override
  void load(
    covariant String url, [
    void Function(Material material)? onLoad,
    LoaderProgressCallback? onProgress,
    LoaderErrorCallback? onError,
  ]) {
    final loader = FileLoader(manager)
      ..setPriority(priority)
      ..setCache(cache)
      ..setPath(path)
      ..setRequestHeader(requestHeader)
      ..setWithCredentials(withCredentials);

    loader.load(
      url,
      (text) {
        try {
          onLoad!(parse(_loaderMap(jsonDecode(text! as String))));
        } catch (e) {
          if (onError != null) {
            onError(e);
          } else {
            error(e);
          }

          manager.itemError(url);
        }
      },
      onProgress,
      onError,
    );
  }

  /// Parses the given JSON object and returns a material.
  @override
  Material parse(covariant Map<String, Object?> json) {
    final material = createMaterialFromType(json['type'] as String?);

    material.fromJSON(json, textures);

    return material;
  }

  /// Textures are not embedded in the material JSON so they have to be injected before the loading
  /// process starts.
  MaterialLoader setTextures(Map<String, Texture> value) {
    textures = value;
    return this;
  }

  /// Creates a material for the given type.
  Material createMaterialFromType(String? type) {
    return MaterialLoader.createMaterialFromTypeStatic(type);
  }

  /// Creates a material for the given type: the reference's static `createMaterialFromType`, renamed because a Dart
  /// class cannot have a static and an instance member of the same name (E-STATIC).
  static Material createMaterialFromTypeStatic(String? type) {
    final Map<String, Material Function()> materialLib = {
      'ShadowMaterial': ShadowMaterial.new,
      'SpriteMaterial': SpriteMaterial.new,
      'PointsMaterial': PointsMaterial.new,
      'MeshPhysicalMaterial': MeshPhysicalMaterial.new,
      'MeshStandardMaterial': MeshStandardMaterial.new,
      'MeshPhongMaterial': MeshPhongMaterial.new,
      'MeshToonMaterial': MeshToonMaterial.new,
      'MeshNormalMaterial': MeshNormalMaterial.new,
      'MeshLambertMaterial': MeshLambertMaterial.new,
      'MeshDepthMaterial': MeshDepthMaterial.new,
      'MeshDistanceMaterial': MeshDistanceMaterial.new,
      'MeshBasicMaterial': MeshBasicMaterial.new,
      'MeshMatcapMaterial': MeshMatcapMaterial.new,
      'LineDashedMaterial': LineDashedMaterial.new,
      'LineBasicMaterial': LineBasicMaterial.new,
      'Material': Material.new,
      ..._materialLoaderCustom,
    };

    final materialType = materialLib[type];

    Material materialInstance;

    if (materialType == null) {
      warnOnce(
        'MaterialLoader: Unknown material type "$type". Use .registerMaterial() before starting the deserialization process.',
      );
      materialInstance = Material();
    } else {
      materialInstance = materialType();
    }

    return materialInstance;
  }

  /// Registers a custom material type for deserialization. The reference takes the class; Dart takes a function
  /// creating an instance, e.g. `MyMaterial.new` (exception E-FACTORY).
  static void registerMaterial(String type, Material Function() materialClass) {
    _materialLoaderCustom[type] = materialClass;
  }
}
