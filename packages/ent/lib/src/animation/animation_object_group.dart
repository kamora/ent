part of '../../ent.dart';

/// The statistics of an [AnimationObjectGroup]: the reference's `stats` object.
class AnimationObjectGroupStats {
  AnimationObjectGroupStats._(AnimationObjectGroup group)
    : objects = AnimationStatsEntry(() => group._objects.length, () => group._objects.length - group.nCachedObjects_),
      _group = group;

  final AnimationObjectGroup _group;

  /// The objects of the group: `total`, and `inUse` (the active ones).
  final AnimationStatsEntry objects;

  /// The number of property paths subscribed per object.
  int get bindingsPerObject => _group._bindings.length;
}

/// A group of objects that receives a shared animation state.
///
/// Usage:
///
/// - Add objects you would otherwise pass as 'root' to the constructor or the
///   [AnimationMixer.clipAction] method of [AnimationMixer].
/// - Instead pass this object as 'root'.
/// - You can also add and remove objects later when the mixer is running.
///
/// Note:
///
/// - Objects of this class appear as one object to the mixer, so cache control of the individual objects
///   must be done on the group.
///
/// Limitation:
///
/// - The animated properties must be compatible among the all objects in the group.
/// - A single property can either be controlled through a target group or directly, but not both.
///
/// The reference's variadic `new AnimationObjectGroup( a, b )`, `add( a, b )`, `remove( a, b )` and `uncache( a, b )`
/// take a list here (exception E-VARIADIC).
class AnimationObjectGroup {
  /// Constructs a new animation group holding [objects].
  AnimationObjectGroup([List<Object3D> objects = const []]) : _objects = List.of(objects) {
    final indices = _indicesByUUID;

    for (var i = 0, n = objects.length; i != n; ++i) {
      indices[objects[i].uuid] = i;
    }

    stats = AnimationObjectGroupStats._(this);
  }

  /// This flag can be used for type testing.
  bool get isAnimationObjectGroup => true;

  /// The UUID of the 3D object.
  String uuid = MathUtils.generateUUID();

  // cached objects followed by the active ones
  final List<Object3D> _objects;

  /// The number of cached objects at the start of the object list (threshold); read by
  /// [PropertyBindingComposite].
  int nCachedObjects_ = 0;

  final Map<String, int> _indicesByUUID = {}; // for bookkeeping

  final List<String> _paths = []; // inside: string

  final List<Map<String, Object?>> _parsedPaths = []; // inside: { we don't care, here }

  final List<List<PropertyBinding?>> _bindings = []; // inside: Array< PropertyBinding >

  final Map<String, int> _bindingsIndicesByPath = {}; // inside: indices in these arrays

  /// Group statistics: `stats.objects.total`, `stats.objects.inUse`, `stats.bindingsPerObject`.
  late final AnimationObjectGroupStats stats;

  /// Adds an arbitrary number of objects to this animation group.
  void add(List<Object3D> objectsToAdd) {
    final objects = _objects;
    final indicesByUUID = _indicesByUUID;
    final paths = _paths;
    final parsedPaths = _parsedPaths;
    final bindings = _bindings;
    final nBindings = bindings.length;

    Object3D? knownObject;
    var nObjects = objects.length;
    var nCachedObjects = nCachedObjects_;

    for (var i = 0, n = objectsToAdd.length; i != n; ++i) {
      final object = objectsToAdd[i];
      final uuid = object.uuid;
      var index = indicesByUUID[uuid];

      if (index == null) {
        // unknown object -> add it to the ACTIVE region

        index = nObjects++;
        indicesByUUID[uuid] = index;
        objects.add(object);

        // accounting is done, now do the same for all bindings

        for (var j = 0, m = nBindings; j != m; ++j) {
          bindings[j].add(PropertyBinding(object, paths[j], parsedPaths[j]));
        }
      } else if (index < nCachedObjects) {
        knownObject = objects[index];

        // move existing object to the ACTIVE region

        final firstActiveIndex = --nCachedObjects;
        final lastCachedObject = objects[firstActiveIndex];

        indicesByUUID[lastCachedObject.uuid] = index;
        objects[index] = lastCachedObject;

        indicesByUUID[uuid] = firstActiveIndex;
        objects[firstActiveIndex] = object;

        // accounting is done, now do the same for all bindings

        for (var j = 0, m = nBindings; j != m; ++j) {
          final bindingsForPath = bindings[j];
          final lastCached = bindingsForPath[firstActiveIndex];

          var binding = bindingsForPath[index];

          bindingsForPath[index] = lastCached;

          // since we do not bother to create new bindings
          // for objects that are cached, the binding may
          // or may not exist
          binding ??= PropertyBinding(object, paths[j], parsedPaths[j]);

          bindingsForPath[firstActiveIndex] = binding;
        }
      } else if (objects[index] != knownObject) {
        error(
          'AnimationObjectGroup: Different objects with the same UUID '
          'detected. Clean the caches or recreate your infrastructure when reloading scenes.',
        );
      } // else the object is already where we want it to be
    } // for arguments

    nCachedObjects_ = nCachedObjects;
  }

  /// Removes an arbitrary number of objects to this animation group.
  void remove(List<Object3D> objectsToRemove) {
    final objects = _objects;
    final indicesByUUID = _indicesByUUID;
    final bindings = _bindings;
    final nBindings = bindings.length;

    var nCachedObjects = nCachedObjects_;

    for (var i = 0, n = objectsToRemove.length; i != n; ++i) {
      final object = objectsToRemove[i];
      final uuid = object.uuid;
      final index = indicesByUUID[uuid];

      if (index != null && index >= nCachedObjects) {
        // move existing object into the CACHED region

        final lastCachedIndex = nCachedObjects++;
        final firstActiveObject = objects[lastCachedIndex];

        indicesByUUID[firstActiveObject.uuid] = index;
        objects[index] = firstActiveObject;

        indicesByUUID[uuid] = lastCachedIndex;
        objects[lastCachedIndex] = object;

        // accounting is done, now do the same for all bindings

        for (var j = 0, m = nBindings; j != m; ++j) {
          final bindingsForPath = bindings[j];
          final firstActive = bindingsForPath[lastCachedIndex];
          final binding = bindingsForPath[index];

          bindingsForPath[index] = firstActive;
          bindingsForPath[lastCachedIndex] = binding;
        }
      }
    } // for arguments

    nCachedObjects_ = nCachedObjects;
  }

  /// Deallocates all memory resources for the passed 3D objects of this animation group.
  void uncache(List<Object3D> objectsToUncache) {
    final objects = _objects;
    final indicesByUUID = _indicesByUUID;
    final bindings = _bindings;
    final nBindings = bindings.length;

    var nCachedObjects = nCachedObjects_;
    var nObjects = objects.length;

    for (var i = 0, n = objectsToUncache.length; i != n; ++i) {
      final object = objectsToUncache[i];
      final uuid = object.uuid;
      final index = indicesByUUID[uuid];

      if (index != null) {
        indicesByUUID.remove(uuid);

        if (index < nCachedObjects) {
          // object is cached, shrink the CACHED region

          final firstActiveIndex = --nCachedObjects;
          final lastCachedObject = objects[firstActiveIndex];
          final lastIndex = --nObjects;
          final lastObject = objects[lastIndex];

          if (index != firstActiveIndex) {
            // last cached object takes this object's place

            indicesByUUID[lastCachedObject.uuid] = index;
          }

          objects[index] = lastCachedObject;

          if (firstActiveIndex != lastIndex) {
            // last object goes to the activated slot and pop

            indicesByUUID[lastObject.uuid] = firstActiveIndex;
          }

          objects[firstActiveIndex] = lastObject;
          objects.removeLast();

          // accounting is done, now do the same for all bindings

          for (var j = 0, m = nBindings; j != m; ++j) {
            final bindingsForPath = bindings[j];
            final lastCached = bindingsForPath[firstActiveIndex];
            final last = bindingsForPath[lastIndex];

            bindingsForPath[index] = lastCached;
            bindingsForPath[firstActiveIndex] = last;
            bindingsForPath.removeLast();
          }
        } else {
          // object is active, just swap with the last and pop

          final lastIndex = --nObjects;
          final lastObject = objects[lastIndex];

          if (index != lastIndex) {
            indicesByUUID[lastObject.uuid] = index;
          }

          objects[index] = lastObject;
          objects.removeLast();

          // accounting is done, now do the same for all bindings

          for (var j = 0, m = nBindings; j != m; ++j) {
            final bindingsForPath = bindings[j];

            bindingsForPath[index] = bindingsForPath[lastIndex];
            bindingsForPath.removeLast();
          }
        } // cached or active
      } // if object is known
    } // for arguments

    nCachedObjects_ = nCachedObjects;
  }

  // Internal interface used by befriended PropertyBinding.Composite:

  /// Returns an array of bindings for the given path that is changed according to the contained objects in
  /// the group.
  List<PropertyBinding?> subscribe_(String path, Map<String, Object?> parsedPath) {
    final indicesByPath = _bindingsIndicesByPath;
    var index = indicesByPath[path];
    final bindings = _bindings;

    if (index != null) {
      return bindings[index];
    }

    final paths = _paths;
    final parsedPaths = _parsedPaths;
    final objects = _objects;
    final nObjects = objects.length;
    final nCachedObjects = nCachedObjects_;
    final bindingsForPath = List<PropertyBinding?>.filled(nObjects, null, growable: true);

    index = bindings.length;

    indicesByPath[path] = index;

    paths.add(path);
    parsedPaths.add(parsedPath);
    bindings.add(bindingsForPath);

    for (var i = nCachedObjects, n = objects.length; i != n; ++i) {
      final object = objects[i];
      bindingsForPath[i] = PropertyBinding(object, path, parsedPath);
    }

    return bindingsForPath;
  }

  /// Tells the group to forget about a property path and no longer update the array previously obtained
  /// with [subscribe_].
  void unsubscribe_(String path) {
    final indicesByPath = _bindingsIndicesByPath;
    final index = indicesByPath[path];

    if (index != null) {
      final paths = _paths;
      final parsedPaths = _parsedPaths;
      final bindings = _bindings;
      final lastBindingsIndex = bindings.length - 1;
      final lastBindings = bindings[lastBindingsIndex];
      final lastBindingsPath = paths[lastBindingsIndex];

      indicesByPath[lastBindingsPath] = index;

      bindings[index] = lastBindings;
      bindings.removeLast();

      parsedPaths[index] = parsedPaths[lastBindingsIndex];
      parsedPaths.removeLast();

      paths[index] = paths[lastBindingsIndex];
      paths.removeLast();
    }
  }
}
