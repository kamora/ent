part of '../../ent.dart';

/// Creates a geometry from its JSON: a geometry class's `fromJSON( data, shapes )` (exception E-FACTORY).
typedef GeometryFromJSON = BufferGeometry Function(Map<String, Object?> data, Map<String, Shape> shapes);

/// Geometries registered with [ObjectLoader.registerGeometry], by type name.
final Map<String, GeometryFromJSON> _objectLoaderCustomGeometries = {};

/// The reference's `Geometries` namespace as ObjectLoader reads it: the type name and its `fromJSON`. EdgesGeometry and
/// WireframeGeometry have no `fromJSON` in the reference (`null` here), so loading them fails as it does there.
final Map<String, GeometryFromJSON?> _objectLoaderGeometries = {
  'BoxGeometry': (data, shapes) => BoxGeometry.fromJSON(data),
  'CapsuleGeometry': (data, shapes) => CapsuleGeometry.fromJSON(data),
  'CircleGeometry': (data, shapes) => CircleGeometry.fromJSON(data),
  'ConeGeometry': (data, shapes) => ConeGeometry.fromJSON(data),
  'CylinderGeometry': (data, shapes) => CylinderGeometry.fromJSON(data),
  'DodecahedronGeometry': (data, shapes) => DodecahedronGeometry.fromJSON(data),
  'EdgesGeometry': null,
  'ExtrudeGeometry': ExtrudeGeometry.fromJSON,
  'IcosahedronGeometry': (data, shapes) => IcosahedronGeometry.fromJSON(data),
  'LatheGeometry': (data, shapes) => LatheGeometry.fromJSON(data),
  'OctahedronGeometry': (data, shapes) => OctahedronGeometry.fromJSON(data),
  'PlaneGeometry': (data, shapes) => PlaneGeometry.fromJSON(data),
  'PolyhedronGeometry': (data, shapes) => PolyhedronGeometry.fromJSON(data),
  'RingGeometry': (data, shapes) => RingGeometry.fromJSON(data),
  'ShapeGeometry': ShapeGeometry.fromJSON,
  'SphereGeometry': (data, shapes) => SphereGeometry.fromJSON(data),
  'TetrahedronGeometry': (data, shapes) => TetrahedronGeometry.fromJSON(data),
  'TorusGeometry': (data, shapes) => TorusGeometry.fromJSON(data),
  'TorusKnotGeometry': (data, shapes) => TorusKnotGeometry.fromJSON(data),
  'TubeGeometry': (data, shapes) => TubeGeometry.fromJSON(data),
  'WireframeGeometry': null,
};

const Map<String, int> _objectLoaderTextureMapping = {
  'UVMapping': UVMapping,
  'CubeReflectionMapping': CubeReflectionMapping,
  'CubeRefractionMapping': CubeRefractionMapping,
  'EquirectangularReflectionMapping': EquirectangularReflectionMapping,
  'EquirectangularRefractionMapping': EquirectangularRefractionMapping,
};

const Map<String, int> _objectLoaderTextureWrapping = {
  'RepeatWrapping': RepeatWrapping,
  'ClampToEdgeWrapping': ClampToEdgeWrapping,
  'MirroredRepeatWrapping': MirroredRepeatWrapping,
};

const Map<String, int> _objectLoaderTextureFilter = {
  'NearestFilter': NearestFilter,
  'NearestMipmapNearestFilter': NearestMipmapNearestFilter,
  'NearestMipmapLinearFilter': NearestMipmapLinearFilter,
  'LinearFilter': LinearFilter,
  'LinearMipmapNearestFilter': LinearMipmapNearestFilter,
  'LinearMipmapLinearFilter': LinearMipmapLinearFilter,
};

final RegExp _objectLoaderAbsolute = RegExp(r'^(\/\/)|([a-z]+:(\/\/)?)', caseSensitive: false);

/// The target uuid of a parsed directional or spot light until [ObjectLoader.bindLightTargets] resolves it. The
/// reference stores the uuid string in `light.target` itself, which a typed `target` cannot hold.
final Expando<String> _objectLoaderLightTargets = Expando();

/// The skeleton uuid of a parsed skinned mesh until [ObjectLoader.bindSkeletons] resolves it; the reference stores it
/// in `mesh.skeleton`.
final Expando<String> _objectLoaderSkeletons = Expando();

/// A loader for loading a JSON resource in the JSON Object/Scene format (version 4.x). The files are internally loaded
/// via [FileLoader].
///
/// [parse] and [parseAsync] are platform-free; images referenced by URL are loaded with [ImageLoader] through
/// [Loader.platform], images stored as data become [DataImage]s.
class ObjectLoader extends Loader<Object3D> {
  /// Constructs a new object loader.
  ObjectLoader([super.manager]);

  /// Starts loading from the given URL and pass the loaded 3D object to the [onLoad] callback.
  @override
  void load(
    covariant String url, [
    void Function(Object3D object)? onLoad,
    LoaderProgressCallback? onProgress,
    LoaderErrorCallback? onError,
  ]) {
    final path = this.path == '' ? LoaderUtils.extractUrlBase(url) : this.path;
    resourcePath = resourcePath != '' ? resourcePath : path;

    final loader = FileLoader(manager)
      ..setPriority(priority)
      ..setCache(cache)
      ..setPath(this.path)
      ..setRequestHeader(requestHeader)
      ..setWithCredentials(withCredentials);

    loader.load(
      url,
      (text) {
        Object? json;

        try {
          json = jsonDecode(text! as String);
        } catch (e) {
          onError?.call(e);

          error('ObjectLoader: Can\'t parse $url.', [e is FormatException ? e.message : e]);

          return;
        }

        final metadata = json is Map ? json['metadata'] : null;

        if (metadata is! Map || metadata['type'] == null || (metadata['type'] as String).toLowerCase() == 'geometry') {
          onError?.call(EntError('ENT.ObjectLoader: Can\'t load $url'));

          error('ObjectLoader: Can\'t load $url');
          return;
        }

        parse(_loaderMap(json), onLoad);
      },
      onProgress,
      onError,
    );
  }

  /// Async version of [load].
  @override
  Future<Object3D> loadAsync(Object? url, [LoaderProgressCallback? onProgress]) async {
    final path = this.path == '' ? LoaderUtils.extractUrlBase(url! as String) : this.path;
    resourcePath = resourcePath != '' ? resourcePath : path;

    final loader = FileLoader(manager)
      ..setPriority(priority)
      ..setCache(cache)
      ..setPath(this.path)
      ..setRequestHeader(requestHeader)
      ..setWithCredentials(withCredentials);

    final text = await loader.loadAsync(url, onProgress);

    Object? json;

    try {
      json = jsonDecode(text! as String);
    } catch (e) {
      throw EntError('ENT.ObjectLoader: Can\'t parse $url. ${e is FormatException ? e.message : e}');
    }

    final metadata = json is Map ? json['metadata'] : null;

    if (metadata is! Map || metadata['type'] == null || (metadata['type'] as String).toLowerCase() == 'geometry') {
      throw EntError('ENT.ObjectLoader: Can\'t load $url');
    }

    return await parseAsync(_loaderMap(json));
  }

  /// Parses the given JSON. This is used internally by [load] but can also be used directly to parse a
  /// previously loaded JSON structure. [onLoad] runs when all images referenced by URL are loaded, or right
  /// away when there are none.
  @override
  Object3D parse(covariant Map<String, Object?> json, [void Function(Object3D object)? onLoad]) {
    final animations = parseAnimations(json['animations'] as List?);
    final shapes = parseShapes(json['shapes'] as List?);
    final geometries = parseGeometries(json['geometries'] as List?, shapes);

    late final Object3D object;

    final images = parseImages(json['images'] as List?, () {
      onLoad?.call(object);
    });

    final textures = parseTextures(json['textures'] as List?, images);
    final materials = parseMaterials(json['materials'] as List?, textures);

    object = parseObject(_loaderMap(json['object']), geometries, materials, textures, animations);
    final skeletons = parseSkeletons(json['skeletons'] as List?, object);

    bindSkeletons(object, skeletons);
    bindLightTargets(object);

    //

    if (onLoad != null) {
      var hasImages = false;

      for (final uuid in images.keys) {
        if (images[uuid]!.data is LoaderImage) {
          hasImages = true;
          break;
        }
      }

      if (hasImages == false) {
        onLoad(object);
      }
    }

    return object;
  }

  /// Async version of [parse].
  Future<Object3D> parseAsync(Map<String, Object?> json) async {
    final animations = parseAnimations(json['animations'] as List?);
    final shapes = parseShapes(json['shapes'] as List?);
    final geometries = parseGeometries(json['geometries'] as List?, shapes);

    final images = await parseImagesAsync(json['images'] as List?);

    final textures = parseTextures(json['textures'] as List?, images);
    final materials = parseMaterials(json['materials'] as List?, textures);

    final object = parseObject(_loaderMap(json['object']), geometries, materials, textures, animations);
    final skeletons = parseSkeletons(json['skeletons'] as List?, object);

    bindSkeletons(object, skeletons);
    bindLightTargets(object);

    return object;
  }

  /// Registers the given geometry at the internal geometry library. The reference takes the class; Dart takes its
  /// `fromJSON` (exception E-FACTORY).
  static void registerGeometry(String type, GeometryFromJSON geometryClass) {
    _objectLoaderCustomGeometries[type] = geometryClass;
  }

  // internals

  /// Parses the shapes of the JSON, by uuid.
  Map<String, Shape> parseShapes(List<Object?>? json) {
    final shapes = <String, Shape>{};

    if (json != null) {
      for (var i = 0, l = json.length; i < l; i++) {
        final shape = Shape().fromJSON(_loaderMap(json[i]));

        shapes[shape.uuid] = shape;
      }
    }

    return shapes;
  }

  /// Parses the skeletons of the JSON, by uuid, with the bones found under [object].
  Map<String, Skeleton> parseSkeletons(List<Object?>? json, Object3D object) {
    final skeletons = <String, Skeleton>{};
    final bones = <String, Bone>{};

    // generate bone lookup table

    object.traverse((child) {
      if (child is Bone) {
        bones[child.uuid] = child;
      }
    });

    // create skeletons

    if (json != null) {
      for (var i = 0, l = json.length; i < l; i++) {
        final skeleton = Skeleton().fromJSON(_loaderMap(json[i]), bones);

        skeletons[skeleton.uuid] = skeleton;
      }
    }

    return skeletons;
  }

  /// Parses the geometries of the JSON, by uuid.
  Map<String, BufferGeometry> parseGeometries(List<Object?>? json, Map<String, Shape> shapes) {
    final geometries = <String, BufferGeometry>{};

    if (json != null) {
      final bufferGeometryLoader = BufferGeometryLoader();

      for (var i = 0, l = json.length; i < l; i++) {
        BufferGeometry? geometry;
        final data = _loaderMap(json[i]);
        final type = data['type'] as String?;

        switch (type) {
          case 'BufferGeometry':
          case 'InstancedBufferGeometry':
            geometry = bufferGeometryLoader.parse(data);

          default:
            if (_objectLoaderGeometries.containsKey(type)) {
              final fromJSON = _objectLoaderGeometries[type];

              if (fromJSON == null) {
                throw EntError('ENT.ObjectLoader: Geometries.$type.fromJSON is not a function');
              }

              geometry = fromJSON(data, shapes);
            } else if (_objectLoaderCustomGeometries.containsKey(type)) {
              geometry = _objectLoaderCustomGeometries[type]!(data, shapes);
            } else {
              warn(
                'ObjectLoader: Unknown geometry type "$type". Use .registerGeometry() before starting the deserialization process.',
              );
            }
        }

        // an unknown type leaves `geometry` undefined, and the reference fails on the next line
        geometry!.uuid = data['uuid']! as String;

        if (data['name'] != null) {
          geometry.name = data['name']! as String;
        }

        if (data['userData'] != null) {
          geometry.userData = _loaderMap(data['userData']);
        }

        geometries[data['uuid']! as String] = geometry;
      }
    }

    return geometries;
  }

  /// Parses the materials of the JSON, by uuid.
  Map<String, Material> parseMaterials(List<Object?>? json, Map<String, Texture> textures) {
    final cache = <String, Material>{}; // MultiMaterial
    final materials = <String, Material>{};

    if (json != null) {
      final loader = MaterialLoader();
      loader.setTextures(textures);

      for (var i = 0, l = json.length; i < l; i++) {
        final data = _loaderMap(json[i]);
        final uuid = data['uuid']! as String;

        cache[uuid] ??= loader.parse(data);

        materials[uuid] = cache[uuid]!;
      }
    }

    return materials;
  }

  /// Parses the animation clips of the JSON, by uuid.
  Map<String, AnimationClip> parseAnimations(List<Object?>? json) {
    final animations = <String, AnimationClip>{};

    if (json != null) {
      for (var i = 0; i < json.length; i++) {
        final data = _loaderMap(json[i]);

        final clip = AnimationClip.parse(data);

        animations[clip.uuid] = clip;
      }
    }

    return animations;
  }

  /// Parses the images of the JSON into texture sources, by uuid. Images given by URL start loading through
  /// [ImageLoader]; [onLoad] runs when all of them are loaded.
  Map<String, TextureSource> parseImages(List<Object?>? json, void Function() onLoad) {
    final images = <String, TextureSource>{};

    late ImageLoader loader;

    LoaderImage loadImage(String url) {
      url = manager.resolveURL(url);

      manager.itemStart(url);

      return loader.load(
        url,
        (image) {
          manager.itemEnd(url);
        },
        null,
        (error) {
          manager.itemError(url);
          manager.itemEnd(url);
        },
      );
    }

    Object? deserializeImage(Object? image) {
      if (image is String) {
        final url = image;

        final path = _objectLoaderAbsolute.hasMatch(url) ? url : resourcePath + url;

        return loadImage(path);
      } else {
        return _objectLoaderDataImage(image);
      }
    }

    if (json != null && json.isNotEmpty) {
      final manager = LoadingManager(onLoad);

      loader = ImageLoader(manager)
        ..setPriority(priority)
        ..setCache(cache)
        ..setCrossOrigin(crossOrigin);

      for (var i = 0, il = json.length; i < il; i++) {
        final image = _loaderMap(json[i]);
        final url = image['url'];

        if (url is List) {
          // load array of images e.g CubeTexture

          final imageArray = <Object?>[];

          for (var j = 0, jl = url.length; j < jl; j++) {
            final currentUrl = url[j];

            final deserializedImage = deserializeImage(currentUrl);

            if (deserializedImage != null) {
              if (deserializedImage is LoaderImage) {
                imageArray.add(deserializedImage);
              } else {
                // special case: handle array of data textures for cube textures

                final data = deserializedImage as DataImage;
                imageArray.add(DataTexture(data.data, data.width ?? 1, data.height ?? 1));
              }
            }
          }

          images[image['uuid']! as String] = TextureSource(imageArray);
        } else {
          // load single image

          final deserializedImage = deserializeImage(image['url']);
          images[image['uuid']! as String] = TextureSource(deserializedImage);
        }
      }
    }

    return images;
  }

  /// Async version of [parseImages].
  Future<Map<String, TextureSource>> parseImagesAsync(List<Object?>? json) async {
    final images = <String, TextureSource>{};

    late ImageLoader loader;

    Future<Object?> deserializeImage(Object? image) async {
      if (image is String) {
        final url = image;

        final path = _objectLoaderAbsolute.hasMatch(url) ? url : resourcePath + url;

        return await loader.loadAsync(path);
      } else {
        return _objectLoaderDataImage(image);
      }
    }

    if (json != null && json.isNotEmpty) {
      loader = ImageLoader(manager)
        ..setPriority(priority)
        ..setCache(cache)
        ..setCrossOrigin(crossOrigin);

      for (var i = 0, il = json.length; i < il; i++) {
        final image = _loaderMap(json[i]);
        final url = image['url'];

        if (url is List) {
          // load array of images e.g CubeTexture

          final imageArray = <Object?>[];

          for (var j = 0, jl = url.length; j < jl; j++) {
            final currentUrl = url[j];

            final deserializedImage = await deserializeImage(currentUrl);

            if (deserializedImage != null) {
              if (deserializedImage is LoaderImage) {
                imageArray.add(deserializedImage);
              } else {
                // special case: handle array of data textures for cube textures

                final data = deserializedImage as DataImage;
                imageArray.add(DataTexture(data.data, data.width ?? 1, data.height ?? 1));
              }
            }
          }

          images[image['uuid']! as String] = TextureSource(imageArray);
        } else {
          // load single image

          final deserializedImage = await deserializeImage(image['url']);
          images[image['uuid']! as String] = TextureSource(deserializedImage);
        }
      }
    }

    return images;
  }

  /// Parses the textures of the JSON, by uuid, with the parsed [images].
  Map<String, Texture> parseTextures(List<Object?>? json, Map<String, TextureSource> images) {
    int? parseConstant(Object? value, Map<String, int> type) {
      if (value is num) {
        return value.toInt();
      }

      warn('ObjectLoader.parseTexture: Constant should be in numeric form.', [value]);

      return type[value];
    }

    final textures = <String, Texture>{};

    if (json != null) {
      for (var i = 0, l = json.length; i < l; i++) {
        final data = _loaderMap(json[i]);

        if (data['image'] == null) {
          warn('ObjectLoader: No "image" specified for', [data['uuid']]);
        }

        if (images[data['image']] == null) {
          warn('ObjectLoader: Undefined image', [data['image']]);
        }

        // an undefined image fails here in the reference too (`source.data` of undefined)
        final source = images[data['image']]!;
        final image = source.data;

        Texture texture;

        if (image is List) {
          texture = CubeTexture();

          if (image.length == 6) {
            texture.needsUpdate = true;
          }
        } else {
          if (image is DataImage && image.data != null) {
            texture = DataTexture();
          } else {
            texture = Texture();
          }

          if (image != null) {
            texture.needsUpdate = true; // textures can have undefined image data
          }
        }

        texture.source = source;

        texture.uuid = data['uuid']! as String;

        if (data['name'] != null) {
          texture.name = data['name']! as String;
        }

        // A string constant not in the table is `undefined` in the reference; the typed field keeps its value.
        if (data['mapping'] != null) {
          texture.mapping = parseConstant(data['mapping'], _objectLoaderTextureMapping) ?? texture.mapping;
        }

        if (data['channel'] != null) {
          texture.channel = _loaderInt(data['channel']);
        }

        if (data['offset'] != null) {
          texture.offset.fromArray((data['offset']! as List).cast<num>());
        }

        if (data['repeat'] != null) {
          texture.repeat.fromArray((data['repeat']! as List).cast<num>());
        }

        if (data['center'] != null) {
          texture.center.fromArray((data['center']! as List).cast<num>());
        }

        if (data['rotation'] != null) {
          texture.rotation = _loaderDouble(data['rotation']);
        }

        if (data['wrap'] != null) {
          final wrap = data['wrap']! as List;
          texture.wrapS = parseConstant(wrap[0], _objectLoaderTextureWrapping) ?? texture.wrapS;
          texture.wrapT = parseConstant(wrap[1], _objectLoaderTextureWrapping) ?? texture.wrapT;
        }

        if (data['format'] != null) {
          texture.format = _loaderInt(data['format']);
        }

        if (data['internalFormat'] != null) {
          texture.internalFormat = data['internalFormat']! as String;
        }

        if (data['type'] != null) {
          texture.type = _loaderInt(data['type']);
        }

        if (data['colorSpace'] != null) {
          texture.colorSpace = data['colorSpace']! as String;
        }

        if (data['minFilter'] != null) {
          texture.minFilter = parseConstant(data['minFilter'], _objectLoaderTextureFilter) ?? texture.minFilter;
        }

        if (data['magFilter'] != null) {
          texture.magFilter = parseConstant(data['magFilter'], _objectLoaderTextureFilter) ?? texture.magFilter;
        }

        if (data['anisotropy'] != null) {
          texture.anisotropy = _loaderDouble(data['anisotropy']);
        }

        if (data['flipY'] != null) {
          texture.flipY = data['flipY']! as bool;
        }

        if (data['generateMipmaps'] != null) {
          texture.generateMipmaps = data['generateMipmaps']! as bool;
        }

        if (data['mipmapsAutoUpdate'] != null) {
          texture.mipmapsAutoUpdate = data['mipmapsAutoUpdate']! as bool;
        }

        if (data['premultiplyAlpha'] != null) {
          texture.premultiplyAlpha = data['premultiplyAlpha']! as bool;
        }

        if (data['unpackAlignment'] != null) {
          texture.unpackAlignment = _loaderInt(data['unpackAlignment']);
        }

        // Only depth textures have compareFunction, and ObjectLoader never creates one; the reference adds an unused
        // property.
        if (data['compareFunction'] != null && texture is DepthTexture) {
          texture.compareFunction = _loaderInt(data['compareFunction']);
        }

        if (data['normalized'] != null) {
          texture.normalized = data['normalized']! as bool;
        }

        if (data['userData'] != null) {
          texture.userData = _loaderMap(data['userData']);
        }

        textures[data['uuid']! as String] = texture;
      }
    }

    return textures;
  }

  /// Parses an object of the JSON and, recursively, its children.
  Object3D parseObject(
    Map<String, Object?> data, [
    Map<String, BufferGeometry> geometries = const {},
    Map<String, Material> materials = const {},
    Map<String, Texture> textures = const {},
    Map<String, AnimationClip> animations = const {},
  ]) {
    Object3D object;

    BufferGeometry? getGeometry(Object? name) {
      if (geometries[name] == null) {
        warn('ObjectLoader: Undefined geometry', [name]);
      }

      return geometries[name];
    }

    Object? getMaterial(Object? name) {
      if (name == null) {
        return null;
      }

      if (name is List) {
        final array = <Material?>[];

        for (var i = 0, l = name.length; i < l; i++) {
          final uuid = name[i];

          if (materials[uuid] == null) {
            warn('ObjectLoader: Undefined material', [uuid]);
          }

          array.add(materials[uuid]);
        }

        // the reference keeps `undefined` entries for missing materials
        return array.contains(null) ? array : array.cast<Material>().toList();
      }

      if (materials[name] == null) {
        warn('ObjectLoader: Undefined material', [name]);
      }

      return materials[name];
    }

    Texture? getTexture(Object? uuid) {
      if (textures[uuid] == null) {
        warn('ObjectLoader: Undefined texture', [uuid]);
      }

      return textures[uuid];
    }

    double? number(String key) => (data[key] as num?)?.toDouble();

    switch (data['type']) {
      case 'Scene':
        final scene = Scene();
        object = scene;

        if (data['background'] != null) {
          final background = data['background'];

          if (background is int || (background is double && background == background.truncateToDouble())) {
            scene.background = Color(background);
          } else {
            scene.background = getTexture(background);
          }
        }

        if (data['environment'] != null) {
          scene.environment = getTexture(data['environment']);
        }

        if (data['fog'] != null) {
          final fogData = _loaderMap(data['fog']);
          Object? fog;

          if (fogData['type'] == 'Fog') {
            final linear = Fog(fogData['color']);
            fog = linear;

            if (fogData['near'] != null) {
              linear.near = _loaderDouble(fogData['near']);
            }

            if (fogData['far'] != null) {
              linear.far = _loaderDouble(fogData['far']);
            }
          } else if (fogData['type'] == 'FogExp2') {
            final exponential = FogExp2(fogData['color']);
            fog = exponential;

            if (fogData['density'] != null) {
              exponential.density = _loaderDouble(fogData['density']);
            }
          }

          scene.fog = fog;

          // the reference also assigns an undefined name; a typed name keeps its value
          if (fogData['name'] != '' && fogData['name'] != null) {
            switch (fog) {
              case Fog f:
                f.name = fogData['name']! as String;
              case FogExp2 f:
                f.name = fogData['name']! as String;
            }
          }
        }

        if (data['backgroundBlurriness'] != null) {
          scene.backgroundBlurriness = number('backgroundBlurriness')!;
        }

        if (data['backgroundIntensity'] != null) {
          scene.backgroundIntensity = number('backgroundIntensity')!;
        }

        if (data['backgroundRotation'] != null) {
          scene.backgroundRotation.fromArray((data['backgroundRotation']! as List).cast<Object?>());
        }

        if (data['environmentIntensity'] != null) {
          scene.environmentIntensity = number('environmentIntensity')!;
        }

        if (data['environmentRotation'] != null) {
          scene.environmentRotation.fromArray((data['environmentRotation']! as List).cast<Object?>());
        }

      case 'PerspectiveCamera':

        // The constructor computes the projection from fov/aspect/near/far only; zoom, film and view are assigned
        // afterwards without an update, as the reference does.
        final camera = PerspectiveCamera();
        object = camera;

        if (data['fov'] != null) {
          camera.fov = number('fov')!;
        }

        if (data['aspect'] != null) {
          camera.aspect = number('aspect')!;
        }

        if (data['near'] != null) {
          camera.near = number('near')!;
        }

        if (data['far'] != null) {
          camera.far = number('far')!;
        }

        camera.updateProjectionMatrix();

        if (data['focus'] != null) {
          camera.focus = number('focus')!;
        }

        if (data['zoom'] != null) {
          camera.zoom = number('zoom')!;
        }

        if (data['filmGauge'] != null) {
          camera.filmGauge = number('filmGauge')!;
        }

        if (data['filmOffset'] != null) {
          camera.filmOffset = number('filmOffset')!;
        }

        if (data['view'] != null) {
          camera.view = _objectLoaderView(_loaderMap(data['view']));
        }

      case 'OrthographicCamera':
        final camera = OrthographicCamera();
        object = camera;

        if (data['left'] != null) {
          camera.left = number('left')!;
        }

        if (data['right'] != null) {
          camera.right = number('right')!;
        }

        if (data['top'] != null) {
          camera.top = number('top')!;
        }

        if (data['bottom'] != null) {
          camera.bottom = number('bottom')!;
        }

        if (data['near'] != null) {
          camera.near = number('near')!;
        }

        if (data['far'] != null) {
          camera.far = number('far')!;
        }

        camera.updateProjectionMatrix();

        if (data['zoom'] != null) {
          camera.zoom = number('zoom')!;
        }

        if (data['view'] != null) {
          camera.view = _objectLoaderView(_loaderMap(data['view']));
        }

      case 'AmbientLight':
        object = _objectLoaderIntensity(AmbientLight(data['color']), data);

      case 'DirectionalLight':
        object = _objectLoaderIntensity(DirectionalLight(data['color']), data);
        _objectLoaderLightTargets[object] = data['target'] as String? ?? '';

      case 'PointLight':
        final light = PointLight(data['color']);
        object = _objectLoaderIntensity(light, data);

        if (data['distance'] != null) {
          light.distance = number('distance')!;
        }

        if (data['decay'] != null) {
          light.decay = number('decay')!;
        }

      case 'RectAreaLight':
        final light = RectAreaLight(data['color']);
        object = _objectLoaderIntensity(light, data);

        if (data['width'] != null) {
          light.width = number('width')!;
        }

        if (data['height'] != null) {
          light.height = number('height')!;
        }

      case 'SpotLight':
        final light = SpotLight(data['color']);
        object = _objectLoaderIntensity(light, data);

        if (data['distance'] != null) {
          light.distance = number('distance')!;
        }

        if (data['angle'] != null) {
          light.angle = number('angle')!;
        }

        if (data['penumbra'] != null) {
          light.penumbra = number('penumbra')!;
        }

        if (data['decay'] != null) {
          light.decay = number('decay')!;
        }

        _objectLoaderLightTargets[light] = data['target'] as String? ?? '';

        if (data['map'] != null) {
          light.map = getTexture(data['map']);
        }

      case 'HemisphereLight':
        object = _objectLoaderIntensity(HemisphereLight(data['color'], data['groundColor']), data);

      case 'LightProbe':
        final sh = SphericalHarmonics3().fromArray((data['sh']! as List).cast<num>());
        object = _objectLoaderIntensity(LightProbe(sh), data);

      case 'SkinnedMesh':
        final geometry = getGeometry(data['geometry']);
        final material = getMaterial(data['material']);

        final mesh = SkinnedMesh(geometry, material);
        object = mesh;

        if (data['bindMode'] != null) {
          mesh.bindMode = data['bindMode']! as String;
        }

        if (data['bindMatrix'] != null) {
          mesh.bindMatrix.fromArray((data['bindMatrix']! as List).cast<num>());
        }

        if (data['skeleton'] != null) {
          _objectLoaderSkeletons[mesh] = data['skeleton']! as String;
        }

      case 'Mesh':
        final geometry = getGeometry(data['geometry']);
        final material = getMaterial(data['material']);

        object = Mesh(geometry, material);

      case 'InstancedMesh':
        final geometry = getGeometry(data['geometry']);
        final material = getMaterial(data['material']);
        final count = _loaderInt(data['count']);
        final instanceMatrix = _loaderMap(data['instanceMatrix']);
        final instanceColor = data['instanceColor'];

        final mesh = InstancedMesh(geometry, material, count);
        object = mesh;
        mesh.instanceMatrix = InstancedBufferAttribute(
          Float32List.fromList(_loaderDoubles(instanceMatrix['array'])),
          16,
        );

        if (instanceColor != null) {
          final color = _loaderMap(instanceColor);
          mesh.instanceColor = InstancedBufferAttribute(
            Float32List.fromList(_loaderDoubles(color['array'])),
            _loaderInt(color['itemSize']),
          );
        }

      case 'BatchedMesh':
        final geometry = getGeometry(data['geometry']);
        final material = getMaterial(data['material']);

        final mesh = BatchedMesh(
          _loaderInt(data['maxInstanceCount']),
          _loaderInt(data['maxVertexCount']),
          (data['maxIndexCount'] as num?)?.toInt(),
          material,
        );
        object = mesh;
        _objectLoaderBatchedMesh(mesh, data, geometry, getTexture);

      case 'LOD':
        object = LOD();

      case 'Line':
        object = Line(getGeometry(data['geometry']), getMaterial(data['material']));

      case 'LineLoop':
        object = LineLoop(getGeometry(data['geometry']), getMaterial(data['material']));

      case 'LineSegments':
        object = LineSegments(getGeometry(data['geometry']), getMaterial(data['material']));

      case 'PointCloud':
      case 'Points':
        object = Points(getGeometry(data['geometry']), getMaterial(data['material']));

      case 'Sprite':
        final material = getMaterial(data['material']);
        final sprite = Sprite(material is Material ? material : null);
        object = sprite;

        if (data['center'] != null) {
          sprite.center.fromArray((data['center']! as List).cast<num>());
        }

      case 'Group':
        object = Group();

      case 'Bone':
        object = Bone();

      default:
        object = Object3D();
    }

    object.uuid = data['uuid']! as String;

    if (data['name'] != null) {
      object.name = data['name']! as String;
    }

    if (data['pivot'] != null) {
      object.pivot = Vector3().fromArray((data['pivot']! as List).cast<num>());
    }

    if (data['matrix'] != null) {
      object.matrix.fromArray((data['matrix']! as List).cast<num>());

      if (data['matrixAutoUpdate'] != null) {
        object.matrixAutoUpdate = data['matrixAutoUpdate']! as bool;
      }

      if (object.matrixAutoUpdate) {
        object.matrix.decompose(object.position, object.quaternion, object.scale);

        final pivot = object.pivot;

        if (pivot != null) {
          object.position.copy(pivot).applyMatrix4(object.matrix).sub(pivot);
        }
      }
    } else {
      if (data['position'] != null) {
        object.position.fromArray((data['position']! as List).cast<num>());
      }

      if (data['rotation'] != null) {
        object.rotation.fromArray((data['rotation']! as List).cast<Object?>());
      }

      if (data['quaternion'] != null) {
        object.quaternion.fromArray((data['quaternion']! as List).cast<num>());
      }

      if (data['scale'] != null) {
        object.scale.fromArray((data['scale']! as List).cast<num>());
      }
    }

    if (data['up'] != null) {
      object.up.fromArray((data['up']! as List).cast<num>());
    }

    // The reference assigns these to any object; only meshes, lines and points have them in Dart.
    if (data['morphTargetDictionary'] != null) {
      final dictionary = {
        for (final MapEntry(:key, :value) in _loaderMap(data['morphTargetDictionary']).entries) key: _loaderInt(value),
      };

      switch (object) {
        case Mesh o:
          o.morphTargetDictionary = dictionary;
        case Line o:
          o.morphTargetDictionary = dictionary;
        case Points o:
          o.morphTargetDictionary = dictionary;
      }
    }

    if (data['morphTargetInfluences'] != null) {
      final influences = _loaderDoubles(data['morphTargetInfluences']);

      switch (object) {
        case Mesh o:
          o.morphTargetInfluences = influences;
        case Line o:
          o.morphTargetInfluences = influences;
        case Points o:
          o.morphTargetInfluences = influences;
      }
    }

    if (data['castShadow'] != null) {
      object.castShadow = data['castShadow']! as bool;
    }

    if (data['receiveShadow'] != null) {
      object.receiveShadow = data['receiveShadow']! as bool;
    }

    final shadowData = data['shadow'];

    if (shadowData != null) {
      _objectLoaderShadow(object, _loaderMap(shadowData), this);
    }

    if (data['visible'] != null) {
      object.visible = data['visible']! as bool;
    }

    if (data['frustumCulled'] != null) {
      object.frustumCulled = data['frustumCulled']! as bool;
    }

    if (data['renderOrder'] != null) {
      object.renderOrder = _loaderInt(data['renderOrder']);
    }

    if (data['static'] != null) {
      object.static = data['static']! as bool;
    }

    if (data['userData'] != null) {
      object.userData = _loaderMap(data['userData']);
    }

    if (data['layers'] != null) {
      object.layers.mask = _loaderInt(data['layers']);
    }

    if (data['children'] != null) {
      final children = data['children']! as List;

      for (var i = 0; i < children.length; i++) {
        object.add(parseObject(_loaderMap(children[i]), geometries, materials, textures, animations));
      }
    }

    if (data['animations'] != null) {
      final objectAnimations = data['animations']! as List;

      for (var i = 0; i < objectAnimations.length; i++) {
        final uuid = objectAnimations[i];

        // the reference pushes `undefined` for a missing clip; the Dart list holds clips only
        final clip = animations[uuid];

        if (clip != null) {
          object.animations.add(clip);
        }
      }
    }

    if (data['type'] == 'LOD') {
      final lod = object as LOD;

      if (data['autoUpdate'] != null) {
        lod.autoUpdate = data['autoUpdate']! as bool;
      }

      final levels = data['levels']! as List;

      for (var l = 0; l < levels.length; l++) {
        final level = _loaderMap(levels[l]);
        final child = lod.getObjectByProperty('uuid', level['object']);

        if (child != null) {
          lod.addLevel(child, _loaderDouble(level['distance']), _loaderDouble(level['hysteresis'] ?? 0));
        }
      }
    }

    return object;
  }

  /// Binds the parsed skeletons to the skinned meshes that reference them.
  void bindSkeletons(Object3D object, Map<String, Skeleton> skeletons) {
    if (skeletons.isEmpty) {
      return;
    }

    object.traverse((child) {
      final uuid = _objectLoaderSkeletons[child];

      if (child is SkinnedMesh && uuid != null) {
        final skeleton = skeletons[uuid];

        if (skeleton == null) {
          warn('ObjectLoader: No skeleton found with UUID:', [uuid]);
        } else {
          child.bind(skeleton, child.bindMatrix);
        }
      }
    });
  }

  /// Replaces the target uuids of directional and spot lights with the objects they name, or a new
  /// [Object3D] when there is no such object.
  void bindLightTargets(Object3D object) {
    object.traverse((child) {
      if (child is DirectionalLight || child is SpotLight) {
        // a light the loader did not create has an object as target, which no uuid equals
        final Object uuid = _objectLoaderLightTargets[child] ?? Object();

        final target = object.getObjectByProperty('uuid', uuid) ?? Object3D();

        switch (child) {
          case DirectionalLight light:
            light.target = target;
          case SpotLight light:
            light.target = target;
        }
      }
    });
  }
}

/// `{ data, width, height }` for an image stored as data in the JSON; `null` when it has no data.
DataImage? _objectLoaderDataImage(Object? image) {
  if (image is Map && image['data'] != null) {
    return DataImage(
      data: getTypedArray(image['type']! as String, _loaderArray(image['data'])),
      width: (image['width'] as num?)?.toInt(),
      height: (image['height'] as num?)?.toInt(),
    );
  }

  return null;
}

/// A camera view from its JSON, `Object.assign( {}, data.view )`.
CameraView _objectLoaderView(Map<String, Object?> json) {
  final view = CameraView();

  if (json['enabled'] != null) {
    view.enabled = json['enabled']! as bool;
  }

  for (final key in ['fullWidth', 'fullHeight', 'offsetX', 'offsetY', 'width', 'height']) {
    final value = json[key];

    if (value != null) {
      final number = _loaderDouble(value);

      switch (key) {
        case 'fullWidth':
          view.fullWidth = number;
        case 'fullHeight':
          view.fullHeight = number;
        case 'offsetX':
          view.offsetX = number;
        case 'offsetY':
          view.offsetY = number;
        case 'width':
          view.width = number;
        case 'height':
          view.height = number;
      }
    }
  }

  return view;
}

/// Sets the light intensity when the JSON has one, as the light constructors do.
Light _objectLoaderIntensity(Light light, Map<String, Object?> data) {
  if (data['intensity'] != null) {
    light.intensity = _loaderDouble(data['intensity']);
  }

  return light;
}

/// Applies the `shadow` JSON of a light. The reference sets every key on `object.shadow`; keys a Dart shadow class
/// lacks (`focus`, `aspect` outside spot lights) have no effect there either.
void _objectLoaderShadow(Object3D object, Map<String, Object?> shadow, ObjectLoader loader) {
  final LightShadow? target = switch (object) {
    DirectionalLight o => o.shadow,
    SpotLight o => o.shadow,
    PointLight o => o.shadow,
    _ => null,
  };

  if (target == null) {
    throw StateError('ENT.ObjectLoader: ${object.type} has no shadow to load into');
  }

  if (shadow['intensity'] != null) {
    target.intensity = _loaderDouble(shadow['intensity']);
  }

  if (shadow['bias'] != null) {
    target.bias = _loaderDouble(shadow['bias']);
  }

  if (shadow['normalBias'] != null) {
    target.normalBias = _loaderDouble(shadow['normalBias']);
  }

  if (shadow['radius'] != null) {
    target.radius = _loaderDouble(shadow['radius']);
  }

  if (shadow['blurSamples'] != null) {
    target.blurSamples = _loaderInt(shadow['blurSamples']);
  }

  if (target is SpotLightShadow) {
    if (shadow['focus'] != null) {
      target.focus = _loaderDouble(shadow['focus']);
    }

    if (shadow['aspect'] != null) {
      target.aspect = _loaderDouble(shadow['aspect']);
    }
  }

  if (shadow['mapSize'] != null) {
    target.mapSize.fromArray((shadow['mapSize']! as List).cast<num>());
  }

  if (shadow['mapType'] != null) {
    target.mapType = _loaderInt(shadow['mapType']);
  }

  if (shadow['camera'] != null) {
    target.camera = loader.parseObject(_loaderMap(shadow['camera'])) as Camera;
  }
}

/// Restores the internal state of a BatchedMesh from its JSON, as the reference assigns its private fields.
void _objectLoaderBatchedMesh(
  BatchedMesh mesh,
  Map<String, Object?> data,
  BufferGeometry? geometry,
  Texture? Function(Object? uuid) getTexture,
) {
  if (geometry != null) {
    mesh.geometry = geometry;
  }

  if (data['perObjectFrustumCulled'] != null) {
    mesh.perObjectFrustumCulled = data['perObjectFrustumCulled']! as bool;
  }

  if (data['sortObjects'] != null) {
    mesh.sortObjects = data['sortObjects']! as bool;
  }

  // `drawRanges`/`reservedRanges` are no longer written by toJSON; the reference assigns `undefined` to them.

  mesh._geometryInfo = [
    for (final item in data['geometryInfo']! as List)
      () {
        final info = _loaderMap(item);
        final result = _BatchedMeshGeometryInfo()
          ..vertexStart = _loaderInt(info['vertexStart'])
          ..vertexCount = _loaderInt(info['vertexCount'])
          ..reservedVertexCount = _loaderInt(info['reservedVertexCount'])
          ..indexStart = _loaderInt(info['indexStart'])
          ..indexCount = _loaderInt(info['indexCount'])
          ..reservedIndexCount = _loaderInt(info['reservedIndexCount'])
          ..start = _loaderInt(info['start'])
          ..count = _loaderInt(info['count'])
          ..active = info['active'] as bool? ?? true;

        if (info['boundingBox'] != null) {
          result.boundingBox = Box3().fromJSON(_loaderMap(info['boundingBox']));
        }

        if (info['boundingSphere'] != null) {
          result.boundingSphere = Sphere().fromJSON(_loaderMap(info['boundingSphere']));
        }

        return result;
      }(),
  ];

  mesh._instanceInfo = [
    for (final item in data['instanceInfo']! as List)
      () {
        final info = _loaderMap(item);
        return _BatchedMeshInstanceInfo(_loaderInt(info['geometryIndex']))
          ..visible = info['visible'] as bool? ?? true
          ..active = info['active'] as bool? ?? true;
      }(),
  ];

  mesh._availableInstanceIds = [for (final id in data['availableInstanceIds']! as List) (id as num).toInt()];
  mesh._availableGeometryIds = [for (final id in data['availableGeometryIds']! as List) (id as num).toInt()];

  mesh._nextIndexStart = _loaderInt(data['nextIndexStart']);
  mesh._nextVertexStart = _loaderInt(data['nextVertexStart']);
  mesh._geometryCount = _loaderInt(data['geometryCount']);

  mesh._maxInstanceCount = _loaderInt(data['maxInstanceCount']);
  mesh._maxVertexCount = _loaderInt(data['maxVertexCount']);
  mesh._maxIndexCount = _loaderInt(data['maxIndexCount']);

  mesh._geometryInitialized = data['geometryInitialized']! as bool;

  mesh._matricesTexture = getTexture(_loaderMap(data['matricesTexture'])['uuid']) as DataTexture?;

  mesh._indirectTexture = getTexture(_loaderMap(data['indirectTexture'])['uuid']) as DataTexture?;

  if (data['colorsTexture'] != null) {
    mesh._colorsTexture = getTexture(_loaderMap(data['colorsTexture'])['uuid']) as DataTexture?;
  }

  if (data['boundingSphere'] != null) {
    mesh.boundingSphere = Sphere().fromJSON(_loaderMap(data['boundingSphere']));
  }

  if (data['boundingBox'] != null) {
    mesh.boundingBox = Box3().fromJSON(_loaderMap(data['boundingBox']));
  }
}
