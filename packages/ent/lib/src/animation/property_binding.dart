part of '../../ent.dart';

// Property access by name, as the reference's `target[ key ]` (exception E-PROPERTY). Lists are indexed by an int or an
// integer string, maps by key, the math value types by component name (`x`, `y`, `z`, `w`, `r`, `g`, `b`, `order`),
// materials and textures through their `_getValue`/`_setValue`, and any other object through its `operator []` /
// `operator []=` (Object3D and its subclasses declare them with the reference's property names). An object without such
// an operator has no animatable properties: reads give `null` (`undefined` in the reference), writes are dropped.

Object? _animationGet(Object? target, Object? key) {
  if (target == null || key == null) {
    return null;
  }

  if (target is List) {
    final index = key is int ? key : int.tryParse('$key');
    return index != null && index >= 0 && index < target.length ? target[index] : null;
  }

  if (target is Map) {
    return target[key];
  }

  final name = '$key';

  switch (target) {
    case Vector2 v:
      return switch (name) {
        'x' || 'width' => v.x,
        'y' || 'height' => v.y,
        _ => null,
      };
    case Vector3 v:
      return switch (name) {
        'x' => v.x,
        'y' => v.y,
        'z' => v.z,
        _ => null,
      };
    case Vector4 v:
      return switch (name) {
        'x' || 'width' => v.x,
        'y' || 'height' => v.y,
        'z' => v.z,
        'w' => v.w,
        _ => null,
      };
    case Quaternion q:
      return switch (name) {
        'x' => q.x,
        'y' => q.y,
        'z' => q.z,
        'w' => q.w,
        _ => null,
      };
    case Euler e:
      return switch (name) {
        'x' => e.x,
        'y' => e.y,
        'z' => e.z,
        'order' => e.order,
        _ => null,
      };
    case Color c:
      return switch (name) {
        'r' => c.r,
        'g' => c.g,
        'b' => c.b,
        _ => null,
      };
  }

  Object? value;

  if (target is Texture) {
    // Textures read and write through `_getValue`/`_setValue` (no `operator []`), with a sentinel for absent keys.
    final v = target._getValue(name);
    value = identical(v, _textureUndefined) ? null : v;
  } else {
    try {
      value = (target as dynamic)[name];
    } on NoSuchMethodError {
      value = null;
    }
  }

  return value ?? _animationStructural(target, name);
}

/// The properties the binding itself navigates (scene graph structure rather than animated values), read as
/// plain Dart members when a class does not list them in its `operator []`.
Object? _animationStructural(Object target, String name) {
  final dynamic t = target;

  try {
    return switch (name) {
      'name' => t.name,
      'uuid' => t.uuid,
      'children' => t.children,
      'material' => t.material,
      'materials' => t.materials,
      'map' => t.map,
      'skeleton' => t.skeleton,
      'bones' => t.bones,
      'geometry' => t.geometry,
      'morphAttributes' => t.morphAttributes,
      'morphTargetDictionary' => t.morphTargetDictionary,
      'morphTargetInfluences' => t.morphTargetInfluences,
      'animations' => t.animations,
      'isMaterial' => t.isMaterial,
      _ => null,
    } as Object?;
  } on NoSuchMethodError {
    return null;
  }
}

/// `target.needsUpdate = true`, for materials and textures (a setter-only property in the reference).
void _animationNeedsUpdate(Object? target) {
  try {
    (target as dynamic).needsUpdate = true;
  } on NoSuchMethodError {
    _animationSet(target, 'needsUpdate', true);
  }
}

void _animationSet(Object? target, Object? key, Object? value) {
  if (target == null || key == null) {
    return;
  }

  if (target is List) {
    final index = key is int ? key : int.tryParse('$key');

    if (index != null && index >= 0 && index < target.length) {
      if (target is List<double>) {
        target[index] = _animationToNumber(value);
      } else {
        target[index] = value;
      }
    }

    return;
  }

  if (target is Map) {
    target[key] = value;
    return;
  }

  final name = '$key';
  final number = value is num ? value.toDouble() : null;

  switch (target) {
    case Vector2 v when number != null:
      switch (name) {
        case 'x' || 'width':
          v.x = number;
        case 'y' || 'height':
          v.y = number;
      }

      return;
    case Vector3 v when number != null:
      switch (name) {
        case 'x':
          v.x = number;
        case 'y':
          v.y = number;
        case 'z':
          v.z = number;
      }

      return;
    case Vector4 v when number != null:
      switch (name) {
        case 'x' || 'width':
          v.x = number;
        case 'y' || 'height':
          v.y = number;
        case 'z':
          v.z = number;
        case 'w':
          v.w = number;
      }

      return;
    case Quaternion q when number != null:
      switch (name) {
        case 'x':
          q.x = number;
        case 'y':
          q.y = number;
        case 'z':
          q.z = number;
        case 'w':
          q.w = number;
      }

      return;
    case Euler e when number != null:
      switch (name) {
        case 'x':
          e.x = number;
        case 'y':
          e.y = number;
        case 'z':
          e.z = number;
      }

      return;
    case Color c when number != null:
      switch (name) {
        case 'r':
          c.r = number;
        case 'g':
          c.g = number;
        case 'b':
          c.b = number;
      }

      return;
  }

  try {
    // Materials and textures write through `_setValue` (they expose no `operator []=`).
    if (target is Material) {
      target._setValue(name, value);
    } else if (target is Texture) {
      target._setValue(name, value);
    } else {
      (target as dynamic)[name] = value;
    }
  } on NoSuchMethodError {
    // No animatable property of that name: the reference would add one that nothing reads.
  } on ArgumentError {
    // The class reads the property in `operator []` but does not write it in `operator []=` (or it is read-only): the
    // reference would assign it. Reported once, so the gap is visible without stopping playback.
    warnOnce('PropertyBinding: Can not write property "$name" of ${target.runtimeType}.');
  }
}

/// Whether [value] has `fromArray` and `toArray` (the math types the reference's duck typing finds).
bool _animationHasFromToArray(Object? value) {
  return value is Vector2 ||
      value is Vector3 ||
      value is Vector4 ||
      value is Quaternion ||
      value is Euler ||
      value is Color ||
      value is Matrix2 ||
      value is Matrix3 ||
      value is Matrix4 ||
      value is SphericalHarmonics3;
}

/// `value.toArray( buffer, offset )` for the [_animationHasFromToArray] types, with JS typed-array stores (an Euler's
/// order string becomes NaN in a numeric buffer, as it does in the reference).
void _animationToArrayAt(Object value, List<Object?> buffer, int offset) {
  final items = _animationToArray(value)!;

  for (var i = 0; i < items.length; i++) {
    _animationStore(buffer, offset + i, items[i]);
  }
}

/// `value.fromArray( buffer, offset )` for the [_animationHasFromToArray] types.
void _animationFromArrayAt(Object value, List<Object?> buffer, int offset) {
  final numbers = buffer is List<num> ? buffer : [for (final v in buffer) _animationToNumber(v)];

  if (value is Euler) {
    // Euler.fromArray( array ) has no offset parameter, so the reference reads the start of the buffer, and its fourth
    // entry (a number there) would become the order; the port keeps the order (exception E-EULERBIND).
    value.set(numbers[0].toDouble(), numbers[1].toDouble(), numbers[2].toDouble());
    return;
  }

  (value as dynamic).fromArray(numbers, offset);
}

/// The uuid of an animation root: an Object3D or an AnimationObjectGroup (or anything else with a `uuid`).
String _animationUuid(Object? root) {
  return switch (root) {
    Object3D o => o.uuid,
    AnimationObjectGroup g => g.uuid,
    _ => _animationGet(root, 'uuid') as String,
  };
}

/// The shared interface of [PropertyBinding] and [PropertyBindingComposite], which a [PropertyMixer] drives.
abstract interface class PropertyBindingLike {
  /// The root node, or `null` for a composite binding (`undefined` in the reference).
  Object? get rootNode;

  /// The track path, or `null` for a composite binding (`undefined` in the reference).
  String? get path;

  /// The parsed track path, or `null` for a composite binding (`undefined` in the reference).
  Map<String, Object?>? get parsedPath;

  /// Writes the current value of the property into [buffer] at [offset].
  void getValue(List<Object?> buffer, int offset);

  /// Sets the property from [buffer] at [offset].
  void setValue(List<Object?> buffer, int offset);

  /// Creates a getter / setter pair for the property tracked by this binding.
  void bind();

  /// Unbinds the property.
  void unbind();
}

/// A binding to the same property path on every object of an [AnimationObjectGroup]; the reference's
/// `PropertyBinding.Composite`.
class PropertyBindingComposite implements PropertyBindingLike {
  PropertyBindingComposite(AnimationObjectGroup targetGroup, String path, [Map<String, Object?>? optionalParsedPath])
    : _targetGroup = targetGroup,
      _bindings = targetGroup.subscribe_(path, optionalParsedPath ?? PropertyBinding.parseTrackName(path));

  final AnimationObjectGroup _targetGroup;

  final List<PropertyBinding?> _bindings;

  @override
  Object? get rootNode => null;

  @override
  String? get path => null;

  @override
  Map<String, Object?>? get parsedPath => null;

  @override
  void getValue(List<Object?> array, int offset) {
    bind(); // bind all binding

    final firstValidIndex = _targetGroup.nCachedObjects_;
    final binding = firstValidIndex < _bindings.length ? _bindings[firstValidIndex] : null;

    // and only call .getValue on the first
    if (binding != null) {
      binding.getValue(array, offset);
    }
  }

  @override
  void setValue(List<Object?> array, int offset) {
    final bindings = _bindings;

    for (var i = _targetGroup.nCachedObjects_, n = bindings.length; i != n; ++i) {
      bindings[i]!.setValue(array, offset);
    }
  }

  @override
  void bind() {
    final bindings = _bindings;

    for (var i = _targetGroup.nCachedObjects_, n = bindings.length; i != n; ++i) {
      bindings[i]!.bind();
    }
  }

  @override
  void unbind() {
    final bindings = _bindings;

    for (var i = _targetGroup.nCachedObjects_, n = bindings.length; i != n; ++i) {
      bindings[i]!.unbind();
    }
  }
}

// Characters [].:/ are reserved for track binding syntax.
const String _propertyBindingReservedChars = r'\[\]\.:\/';
final RegExp _propertyBindingReservedRe = RegExp('[$_propertyBindingReservedChars]');

// Attempts to allow node names from any language. ES5's `\w` regexp matches
// only latin characters, and the unicode \p{L} is not yet supported. So
// instead, we exclude reserved characters and match everything else.
const String _propertyBindingWordChar = '[^$_propertyBindingReservedChars]';
const String _propertyBindingWordCharOrDot = r'[^\[\]:\/]';

// Parent directories, delimited by '/' or ':'. Currently unused, but must
// be matched to parse the rest of the track name.
const String _propertyBindingDirectoryRe = '((?:$_propertyBindingWordChar+[\\/:])*)';

// Target node. May contain word characters (a-zA-Z0-9_) and '.' or '-'.
const String _propertyBindingNodeRe = '($_propertyBindingWordCharOrDot+)?';

// Object on target node, and accessor. May not contain reserved
// characters. Accessor may contain any character except closing bracket.
const String _propertyBindingObjectRe = '(?:\\.($_propertyBindingWordChar+)(?:\\[(.+)\\])?)?';

// Property and accessor. May not contain reserved characters. Accessor may
// contain any non-bracket characters.
const String _propertyBindingPropertyRe = '\\.($_propertyBindingWordChar+)(?:\\[(.+)\\])?';

final RegExp _propertyBindingTrackRe = RegExp(
  '^$_propertyBindingDirectoryRe$_propertyBindingNodeRe$_propertyBindingObjectRe$_propertyBindingPropertyRe\$',
);

const List<String> _propertyBindingSupportedObjectNames = ['material', 'materials', 'bones', 'map'];

// The reference's BindingType and Versioning enumerations (prototype objects there).
const int _bindingDirect = 0;
const int _bindingEntireArray = 1;
const int _bindingArrayElement = 2;
const int _bindingHasFromToArray = 3;

const int _versioningNone = 0;
const int _versioningNeedsUpdate = 1;
const int _versioningMatrixWorldNeedsUpdate = 2;

/// This holds a reference to a real property in the scene graph; used internally.
///
/// Note: This class uses a State pattern on a per-method basis: [bind] selects the getter and setter that
/// represent the bound state. When the property is not found, they become no-ops.
class PropertyBinding implements PropertyBindingLike {
  /// Constructs a new property binding for [path] (see [parseTrackName]) under [rootNode].
  PropertyBinding(this.rootNode, this.path, [Map<String, Object?>? parsedPath])
    : parsedPath = parsedPath ?? PropertyBinding.parseTrackName(path) {
    node = PropertyBinding.findNode(rootNode, this.parsedPath['nodeName']);

    // initial state of these methods that calls 'bind'
    _getValue = _getValue_unbound;
    _setValue = _setValue_unbound;
  }

  /// The object path to the animated property.
  @override
  String path;

  /// An object holding information about the path.
  @override
  Map<String, Object?> parsedPath;

  /// The object owns the animated property.
  Object? node;

  /// The root node.
  @override
  Object? rootNode;

  /// The object whose property is bound (after [bind]).
  Object? targetObject;

  /// The bound property value (array, element container or math object), after [bind].
  Object? resolvedProperty;

  /// The bound property name, for direct bindings.
  String? propertyName;

  /// The bound property index, for array element bindings.
  Object? propertyIndex;

  late void Function(List<Object?> buffer, int offset) _getValue;

  late void Function(List<Object?> buffer, int offset) _setValue;

  @override
  void getValue(List<Object?> buffer, int offset) => _getValue(buffer, offset);

  @override
  void setValue(List<Object?> buffer, int offset) => _setValue(buffer, offset);

  /// Factory method for creating a property binding from the given parameters: a
  /// [PropertyBindingComposite] for an [AnimationObjectGroup] root, a [PropertyBinding] otherwise.
  static PropertyBindingLike create(Object? root, String path, [Map<String, Object?>? parsedPath]) {
    if (root is! AnimationObjectGroup) {
      return PropertyBinding(root, path, parsedPath);
    } else {
      return PropertyBinding.Composite(root, path, parsedPath);
    }
  }

  /// The reference's `new PropertyBinding.Composite( targetGroup, path, optionalParsedPath )`.
  static PropertyBindingComposite Composite(
    AnimationObjectGroup targetGroup,
    String path, [
    Map<String, Object?>? optionalParsedPath,
  ]) {
    return PropertyBindingComposite(targetGroup, path, optionalParsedPath);
  }

  /// Replaces spaces with underscores and removes unsupported characters from node names, to ensure
  /// compatibility with [parseTrackName].
  static String sanitizeNodeName(String name) {
    return name.replaceAll(RegExp(r'\s'), '_').replaceAll(_propertyBindingReservedRe, '');
  }

  /// Parses the given track name (an object path to an animated property) and returns a map with `nodeName`,
  /// `objectName`, `objectIndex`, `propertyName` and `propertyIndex` (`null` where the reference has `undefined`).
  /// Matches strings in the following forms:
  ///
  /// - `nodeName.property`
  /// - `nodeName.property[accessor]`
  /// - `nodeName.material.property[accessor]`
  /// - `uuid.property[accessor]`
  /// - `uuid.objectName[objectIndex].propertyName[propertyIndex]`
  /// - `parentName/nodeName.property`
  /// - `parentName/parentName/nodeName.property[index]`
  /// - `.bone[Armature.DEF_cog].position`
  /// - `scene:helium_balloon_model:helium_balloon_model.position`
  static Map<String, Object?> parseTrackName(String trackName) {
    final matches = _propertyBindingTrackRe.firstMatch(trackName);

    if (matches == null) {
      throw EntError('ENT.PropertyBinding: Cannot parse trackName: $trackName');
    }

    final results = <String, Object?>{
      // directoryName: matches[ 1 ], // (tschw) currently unused
      'nodeName': matches[2],
      'objectName': matches[3],
      'objectIndex': matches[4],
      'propertyName': matches[5], // required
      'propertyIndex': matches[6],
    };

    final nodeName = results['nodeName'] as String?;
    final lastDot = nodeName == null || nodeName.isEmpty ? -1 : nodeName.lastIndexOf('.');

    if (lastDot != -1) {
      final objectName = nodeName!.substring(lastDot + 1);

      // Object names must be checked against an allowlist. Otherwise, there
      // is no way to parse 'foo.bar.baz': 'baz' must be a property, but
      // 'bar' could be the objectName, or part of a nodeName (which can
      // include '.' characters).
      if (_propertyBindingSupportedObjectNames.contains(objectName)) {
        results['nodeName'] = nodeName.substring(0, lastDot);
        results['objectName'] = objectName;
      }
    }

    final propertyName = results['propertyName'] as String?;

    if (propertyName == null || propertyName.isEmpty) {
      throw EntError('ENT.PropertyBinding: can not parse propertyName from trackName: $trackName');
    }

    return results;
  }

  /// Searches for a node in the hierarchy of the given root object by the given node name (or uuid).
  static Object? findNode(Object? root, Object? nodeName) {
    if (nodeName == null ||
        nodeName == '' ||
        nodeName == '.' ||
        nodeName == -1 ||
        nodeName == _animationGet(root, 'name') ||
        nodeName == _animationGet(root, 'uuid')) {
      return root;
    }

    // search into skeleton bones.
    final skeleton = _animationGet(root, 'skeleton');

    if (skeleton != null) {
      final Object? bone = (skeleton as dynamic).getBoneByName(nodeName);

      if (bone != null) {
        return bone;
      }
    }

    // search into node subtree.
    final children = _animationGet(root, 'children');

    if (children is List) {
      Object? searchNodeSubtree(List<Object?> children) {
        for (var i = 0; i < children.length; i++) {
          final childNode = children[i];

          if (_animationGet(childNode, 'name') == nodeName || _animationGet(childNode, 'uuid') == nodeName) {
            return childNode;
          }

          final result = searchNodeSubtree(_animationGet(childNode, 'children') as List<Object?>? ?? const []);

          if (result != null) {
            return result;
          }
        }

        return null;
      }

      final subTreeNode = searchNodeSubtree(children.cast<Object?>());

      if (subTreeNode != null) {
        return subTreeNode;
      }
    }

    return null;
  }

  // these are used to "bind" a nonexistent property
  void _getValue_unavailable(List<Object?> buffer, int offset) {}

  void _setValue_unavailable(List<Object?> buffer, int offset) {}

  // Getters

  void _getValue_direct(List<Object?> buffer, int offset) {
    _animationStore(buffer, offset, _animationGet(targetObject, propertyName));
  }

  void _getValue_array(List<Object?> buffer, int offset) {
    final source = resolvedProperty as List;

    for (var i = 0, n = source.length; i != n; ++i) {
      _animationStore(buffer, offset++, source[i]);
    }
  }

  void _getValue_arrayElement(List<Object?> buffer, int offset) {
    _animationStore(buffer, offset, _animationGet(resolvedProperty, propertyIndex));
  }

  void _getValue_toArray(List<Object?> buffer, int offset) {
    _animationToArrayAt(resolvedProperty!, buffer, offset);
  }

  // Direct

  void _setValue_direct(List<Object?> buffer, int offset) {
    _animationSet(targetObject, propertyName, buffer[offset]);
  }

  void _setValue_direct_setNeedsUpdate(List<Object?> buffer, int offset) {
    _animationSet(targetObject, propertyName, buffer[offset]);
    _animationNeedsUpdate(targetObject);
  }

  void _setValue_direct_setMatrixWorldNeedsUpdate(List<Object?> buffer, int offset) {
    _animationSet(targetObject, propertyName, buffer[offset]);
    (targetObject as Object3D).matrixWorldNeedsUpdate = true;
  }

  // EntireArray

  void _setValue_array(List<Object?> buffer, int offset) {
    final dest = resolvedProperty as List;

    for (var i = 0, n = dest.length; i != n; ++i) {
      _animationSet(dest, i, buffer[offset++]);
    }
  }

  void _setValue_array_setNeedsUpdate(List<Object?> buffer, int offset) {
    _setValue_array(buffer, offset);
    _animationNeedsUpdate(targetObject);
  }

  void _setValue_array_setMatrixWorldNeedsUpdate(List<Object?> buffer, int offset) {
    _setValue_array(buffer, offset);
    (targetObject as Object3D).matrixWorldNeedsUpdate = true;
  }

  // ArrayElement

  void _setValue_arrayElement(List<Object?> buffer, int offset) {
    _animationSet(resolvedProperty, propertyIndex, buffer[offset]);
  }

  void _setValue_arrayElement_setNeedsUpdate(List<Object?> buffer, int offset) {
    _animationSet(resolvedProperty, propertyIndex, buffer[offset]);
    _animationNeedsUpdate(targetObject);
  }

  void _setValue_arrayElement_setMatrixWorldNeedsUpdate(List<Object?> buffer, int offset) {
    _animationSet(resolvedProperty, propertyIndex, buffer[offset]);
    (targetObject as Object3D).matrixWorldNeedsUpdate = true;
  }

  // HasToFromArray

  void _setValue_fromArray(List<Object?> buffer, int offset) {
    _animationFromArrayAt(resolvedProperty!, buffer, offset);
  }

  void _setValue_fromArray_setNeedsUpdate(List<Object?> buffer, int offset) {
    _animationFromArrayAt(resolvedProperty!, buffer, offset);
    _animationNeedsUpdate(targetObject);
  }

  void _setValue_fromArray_setMatrixWorldNeedsUpdate(List<Object?> buffer, int offset) {
    _animationFromArrayAt(resolvedProperty!, buffer, offset);
    (targetObject as Object3D).matrixWorldNeedsUpdate = true;
  }

  void _getValue_unbound(List<Object?> targetArray, int offset) {
    bind();
    getValue(targetArray, offset);
  }

  void _setValue_unbound(List<Object?> sourceArray, int offset) {
    bind();
    setValue(sourceArray, offset);
  }

  /// Creates a getter / setter pair for the property tracked by this binding.
  @override
  void bind() {
    var targetObject = node;
    final parsedPath = this.parsedPath;

    final objectName = parsedPath['objectName'] as String?;
    final propertyName = parsedPath['propertyName'] as String;
    var propertyIndex = parsedPath['propertyIndex'];

    if (targetObject == null) {
      targetObject = PropertyBinding.findNode(rootNode, parsedPath['nodeName']);

      node = targetObject;
    }

    // set fail state so we can just 'return' on error
    _getValue = _getValue_unavailable;
    _setValue = _setValue_unavailable;

    // ensure there is a value node
    if (targetObject == null) {
      warn('PropertyBinding: No target node found for track: $path.');
      return;
    }

    if (objectName != null) {
      var objectIndex = parsedPath['objectIndex'];

      // special cases were we need to reach deeper into the hierarchy to get the face materials....
      switch (objectName) {
        case 'materials':
          final material = _animationGet(targetObject, 'material');

          if (material == null) {
            error('PropertyBinding: Can not bind to material as node does not have a material.', [this]);
            return;
          }

          final materials = _animationGet(material, 'materials');

          if (materials == null) {
            error(
              'PropertyBinding: Can not bind to material.materials as node.material does not have a materials array.',
              [this],
            );
            return;
          }

          targetObject = materials;

        case 'bones':
          final skeleton = _animationGet(targetObject, 'skeleton');

          if (skeleton == null) {
            error('PropertyBinding: Can not bind to bones as node does not have a skeleton.', [this]);
            return;
          }

          // potential future optimization: skip this if propertyIndex is already an integer
          // and convert the integer string to a true integer.

          final bones = _animationGet(skeleton, 'bones') as List;
          targetObject = bones;

          // support resolving morphTarget names into indices.
          for (var i = 0; i < bones.length; i++) {
            if (_animationGet(bones[i], 'name') == objectIndex) {
              objectIndex = i;
              break;
            }
          }

        case 'map':

          // The reference tests `'map' in targetObject`; a property that is present but `null` reads as absent here.
          final map = _animationGet(targetObject, 'map');

          if (map != null) {
            targetObject = map;
            break;
          }

          final material = _animationGet(targetObject, 'material');

          if (material == null) {
            error('PropertyBinding: Can not bind to material as node does not have a material.', [this]);
            return;
          }

          final materialMap = _animationGet(material, 'map');

          if (materialMap == null) {
            error('PropertyBinding: Can not bind to material.map as node.material does not have a map.', [this]);
            return;
          }

          targetObject = materialMap;

        default:
          final object = _animationGet(targetObject, objectName);

          if (object == null) {
            error('PropertyBinding: Can not bind to objectName of node undefined.', [this]);
            return;
          }

          targetObject = object;
      }

      if (objectIndex != null) {
        final object = _animationGet(targetObject, objectIndex);

        if (object == null) {
          error('PropertyBinding: Trying to bind to objectIndex of objectName, but is undefined.', [
            this,
            targetObject,
          ]);
          return;
        }

        targetObject = object;
      }
    }

    // resolve property
    final nodeProperty = _animationGet(targetObject, propertyName);

    if (nodeProperty == null) {
      final nodeName = parsedPath['nodeName'];

      error('PropertyBinding: Trying to update property for track: $nodeName.$propertyName but it wasn\'t found.', [
        targetObject,
      ]);
      return;
    }

    // determine versioning scheme
    var versioning = _versioningNone;

    this.targetObject = targetObject;

    if (_animationStructural(targetObject, 'isMaterial') == true) {
      versioning = _versioningNeedsUpdate;
    } else if (targetObject is Object3D) {
      versioning = _versioningMatrixWorldNeedsUpdate;
    }

    // determine how the property gets bound
    var bindingType = _bindingDirect;

    if (propertyIndex != null) {
      // access a sub element of the property array (only primitives are supported right now)

      if (propertyName == 'morphTargetInfluences') {
        // potential optimization, skip this if propertyIndex is already an integer, and convert the integer string to a true integer.

        // support resolving morphTarget names into indices.
        final geometry = _animationGet(targetObject, 'geometry');

        if (geometry == null) {
          error('PropertyBinding: Can not bind to morphTargetInfluences because node does not have a geometry.', [
            this,
          ]);
          return;
        }

        final morphAttributes = geometry is BufferGeometry
            ? geometry.morphAttributes
            : _animationGet(geometry, 'morphAttributes');

        if (morphAttributes == null) {
          error(
            'PropertyBinding: Can not bind to morphTargetInfluences because node does not have a geometry.morphAttributes.',
            [this],
          );
          return;
        }

        final index = _animationGet(_animationGet(targetObject, 'morphTargetDictionary'), propertyIndex);

        if (index != null) {
          propertyIndex = index;
        }
      }

      bindingType = _bindingArrayElement;

      resolvedProperty = nodeProperty;
      this.propertyIndex = propertyIndex;
    } else if (_animationHasFromToArray(nodeProperty)) {
      // must use copy for Object3D.Euler/Quaternion

      bindingType = _bindingHasFromToArray;

      resolvedProperty = nodeProperty;
    } else if (nodeProperty is List && !isTypedArray(nodeProperty)) {
      bindingType = _bindingEntireArray;

      resolvedProperty = nodeProperty;
    } else {
      this.propertyName = propertyName;
    }

    // select getter / setter
    _getValue = switch (bindingType) {
      _bindingDirect => _getValue_direct,
      _bindingEntireArray => _getValue_array,
      _bindingArrayElement => _getValue_arrayElement,
      _bindingHasFromToArray => _getValue_toArray,
      _ => _getValue_unavailable,
    };

    _setValue = switch ((bindingType, versioning)) {
      (_bindingDirect, _versioningNone) => _setValue_direct,
      (_bindingDirect, _versioningNeedsUpdate) => _setValue_direct_setNeedsUpdate,
      (_bindingDirect, _versioningMatrixWorldNeedsUpdate) => _setValue_direct_setMatrixWorldNeedsUpdate,
      (_bindingEntireArray, _versioningNone) => _setValue_array,
      (_bindingEntireArray, _versioningNeedsUpdate) => _setValue_array_setNeedsUpdate,
      (_bindingEntireArray, _versioningMatrixWorldNeedsUpdate) => _setValue_array_setMatrixWorldNeedsUpdate,
      (_bindingArrayElement, _versioningNone) => _setValue_arrayElement,
      (_bindingArrayElement, _versioningNeedsUpdate) => _setValue_arrayElement_setNeedsUpdate,
      (_bindingArrayElement, _versioningMatrixWorldNeedsUpdate) => _setValue_arrayElement_setMatrixWorldNeedsUpdate,
      (_bindingHasFromToArray, _versioningNone) => _setValue_fromArray,
      (_bindingHasFromToArray, _versioningNeedsUpdate) => _setValue_fromArray_setNeedsUpdate,
      _ => _setValue_fromArray_setMatrixWorldNeedsUpdate,
    };
  }

  /// Unbinds the property.
  @override
  void unbind() {
    node = null;

    // back to the prototype version of getValue / setValue
    // note: avoiding to mutate the shape of 'this' via 'delete'
    _getValue = _getValue_unbound;
    _setValue = _setValue_unbound;
  }
}
