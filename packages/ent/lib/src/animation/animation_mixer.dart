part of '../../ent.dart';

final Float32List _animationMixerControlInterpolantsResultBuffer = Float32List(1);

/// The cache index of a control interpolant; the reference stores it as an ad-hoc `__cacheIndex` property.
final Expando<int> _animationMixerControlCacheIndex = Expando<int>('__cacheIndex');

/// The actions known for one clip: the reference's `{ knownActions, actionByRoot }` object.
class _AnimationActionsForClip {
  _AnimationActionsForClip(AnimationAction action) : knownActions = [action];

  /// Used as prototypes.
  final List<AnimationAction> knownActions;

  /// Lookup by root uuid.
  final Map<String, AnimationAction> actionByRoot = {};
}

/// A `{ total, inUse }` entry of [AnimationMixer.stats] and [AnimationObjectGroup.stats], computed on read as the
/// reference's getters are.
class AnimationStatsEntry {
  AnimationStatsEntry(this._total, this._inUse);

  final int Function() _total;

  final int Function() _inUse;

  /// The total number of cached items.
  int get total => _total();

  /// The number of items in use.
  int get inUse => _inUse();
}

/// The memory statistics of an [AnimationMixer]: the reference's `stats` object.
class AnimationMixerStats {
  AnimationMixerStats._(AnimationMixer mixer)
    : actions = AnimationStatsEntry(() => mixer._actions.length, () => mixer._nActiveActions),
      bindings = AnimationStatsEntry(() => mixer._bindings.length, () => mixer._nActiveBindings),
      controlInterpolants = AnimationStatsEntry(
        () => mixer._controlInterpolants.length,
        () => mixer._nActiveControlInterpolants,
      );

  /// Animation actions.
  final AnimationStatsEntry actions;

  /// Property bindings.
  final AnimationStatsEntry bindings;

  /// Interpolants used for fading and warping.
  final AnimationStatsEntry controlInterpolants;
}

/// Points an interpolant's result at a property mixer's buffer; the reference's
/// `interpolant.resultBuffer = binding.buffer`. Interpolants of non-numeric tracks write into
/// [KeyframeObjectInterpolant.objectResult].
void _animationBindResult(Interpolant interpolant, List<Object?> buffer) {
  if (interpolant is KeyframeObjectInterpolant) {
    interpolant.objectResult = buffer;
  } else {
    interpolant.resultBuffer = buffer as List<double>;
  }
}

/// `AnimationMixer` is a player for animations on a particular object in the scene. When multiple objects
/// in the scene are animated independently, one `AnimationMixer` may be used for each object.
class AnimationMixer extends EventDispatcher {
  /// Constructs a new animation mixer for [root]: the object (or [AnimationObjectGroup]) whose animations
  /// it plays.
  AnimationMixer([Object? root]) : _root = root {
    _initMemoryManager();
  }

  final Object? _root;

  int _accuIndex = 0;

  /// The global mixer time (in seconds; starting with `0` on the mixer's creation).
  double time = 0;

  /// A scaling factor for the global time.
  ///
  /// Note: Setting this member to `0` and later back to `1` is a possibility to pause/unpause all actions
  /// that are controlled by this mixer.
  double timeScale = 1.0;

  late List<AnimationAction> _actions;

  late int _nActiveActions;

  late Map<String, _AnimationActionsForClip> _actionsByClip;

  late List<PropertyMixer> _bindings;

  late int _nActiveBindings;

  late Map<String, Map<String, PropertyMixer>> _bindingsByRootAndName;

  late List<Interpolant> _controlInterpolants;

  late int _nActiveControlInterpolants;

  /// Memory statistics: `stats.actions`, `stats.bindings`, `stats.controlInterpolants`, each with `total`
  /// and `inUse`.
  late final AnimationMixerStats stats;

  void _bindAction(AnimationAction action, AnimationAction? prototypeAction) {
    final root = action._localRoot ?? _root;
    final tracks = action._clip.tracks;
    final nTracks = tracks.length;
    final bindings = action._propertyBindings;
    final interpolants = action._interpolants;
    final rootUuid = _animationUuid(root);
    final bindingsByRoot = _bindingsByRootAndName;

    final bindingsByName = bindingsByRoot.putIfAbsent(rootUuid, () => {});

    for (var i = 0; i != nTracks; ++i) {
      final track = tracks[i];
      final trackName = track.name;

      var binding = bindingsByName[trackName];

      if (binding != null) {
        ++binding.referenceCount;
        bindings[i] = binding;
      } else {
        binding = bindings[i];

        if (binding != null) {
          // existing binding, make sure the cache knows

          if (binding._cacheIndex == null) {
            ++binding.referenceCount;
            _addInactiveBinding(binding, rootUuid, trackName);
          }

          continue;
        }

        final path = prototypeAction?._propertyBindings[i]!.binding.parsedPath;

        binding = PropertyMixer(
          PropertyBinding.create(root, trackName, path),
          track.ValueTypeName,
          track.getValueSize().toInt(),
        );

        ++binding.referenceCount;
        _addInactiveBinding(binding, rootUuid, trackName);

        bindings[i] = binding;
      }

      _animationBindResult(interpolants[i], binding.buffer);
    }
  }

  void _activateAction(AnimationAction action) {
    if (!_isActiveAction(action)) {
      if (action._cacheIndex == null) {
        // this action has been forgotten by the cache, but the user
        // appears to be still using it -> rebind

        final rootUuid = _animationUuid(action._localRoot ?? _root);
        final clipUuid = action._clip.uuid;
        final actionsForClip = _actionsByClip[clipUuid];

        _bindAction(action, actionsForClip?.knownActions[0]);

        _addInactiveAction(action, clipUuid, rootUuid);
      }

      final bindings = action._propertyBindings;

      // increment reference counts / sort out state
      for (var i = 0, n = bindings.length; i != n; ++i) {
        final binding = bindings[i]!;

        if (binding.useCount++ == 0) {
          _lendBinding(binding);
          binding.saveOriginalState();
        }
      }

      _lendAction(action);
    }
  }

  void _deactivateAction(AnimationAction action) {
    if (_isActiveAction(action)) {
      final bindings = action._propertyBindings;

      // decrement reference counts / sort out state
      for (var i = 0, n = bindings.length; i != n; ++i) {
        final binding = bindings[i]!;

        if (--binding.useCount == 0) {
          binding.restoreOriginalState();
          _takeBackBinding(binding);
        }
      }

      _takeBackAction(action);
    }
  }

  // Memory manager

  void _initMemoryManager() {
    _actions = []; // 'nActiveActions' followed by inactive ones
    _nActiveActions = 0;

    _actionsByClip = {};

    _bindings = []; // 'nActiveBindings' followed by inactive ones
    _nActiveBindings = 0;

    _bindingsByRootAndName = {}; // inside: Map< name, PropertyMixer >

    _controlInterpolants = []; // same game as above
    _nActiveControlInterpolants = 0;

    stats = AnimationMixerStats._(this);
  }

  // Memory management for AnimationAction objects

  bool _isActiveAction(AnimationAction action) {
    final index = action._cacheIndex;
    return index != null && index < _nActiveActions;
  }

  void _addInactiveAction(AnimationAction action, String clipUuid, String rootUuid) {
    final actions = _actions;
    final actionsByClip = _actionsByClip;

    var actionsForClip = actionsByClip[clipUuid];

    if (actionsForClip == null) {
      actionsForClip = _AnimationActionsForClip(action);

      action._byClipCacheIndex = 0;

      actionsByClip[clipUuid] = actionsForClip;
    } else {
      final knownActions = actionsForClip.knownActions;

      action._byClipCacheIndex = knownActions.length;
      knownActions.add(action);
    }

    action._cacheIndex = actions.length;
    actions.add(action);

    actionsForClip.actionByRoot[rootUuid] = action;
  }

  void _removeInactiveAction(AnimationAction action) {
    final actions = _actions;
    final lastInactiveAction = actions[actions.length - 1];
    final cacheIndex = action._cacheIndex!;

    lastInactiveAction._cacheIndex = cacheIndex;
    actions[cacheIndex] = lastInactiveAction;
    actions.removeLast();

    action._cacheIndex = null;

    final clipUuid = action._clip.uuid;
    final actionsByClip = _actionsByClip;
    final actionsForClip = actionsByClip[clipUuid]!;
    final knownActionsForClip = actionsForClip.knownActions;

    final lastKnownAction = knownActionsForClip[knownActionsForClip.length - 1];

    final byClipCacheIndex = action._byClipCacheIndex!;

    lastKnownAction._byClipCacheIndex = byClipCacheIndex;
    knownActionsForClip[byClipCacheIndex] = lastKnownAction;
    knownActionsForClip.removeLast();

    action._byClipCacheIndex = null;

    final actionByRoot = actionsForClip.actionByRoot;
    final rootUuid = _animationUuid(action._localRoot ?? _root);

    actionByRoot.remove(rootUuid);

    if (knownActionsForClip.isEmpty) {
      actionsByClip.remove(clipUuid);
    }

    _removeInactiveBindingsForAction(action);
  }

  void _removeInactiveBindingsForAction(AnimationAction action) {
    final bindings = action._propertyBindings;

    for (var i = 0, n = bindings.length; i != n; ++i) {
      final binding = bindings[i]!;

      if (--binding.referenceCount == 0) {
        _removeInactiveBinding(binding);
      }
    }
  }

  void _lendAction(AnimationAction action) {
    // [ active actions |  inactive actions  ]
    // [  active actions >| inactive actions ]
    //                 s        a
    //                  <-swap->
    //                 a        s

    final actions = _actions;
    final prevIndex = action._cacheIndex!;

    final lastActiveIndex = _nActiveActions++;

    final firstInactiveAction = actions[lastActiveIndex];

    action._cacheIndex = lastActiveIndex;
    actions[lastActiveIndex] = action;

    firstInactiveAction._cacheIndex = prevIndex;
    actions[prevIndex] = firstInactiveAction;
  }

  void _takeBackAction(AnimationAction action) {
    // [  active actions  | inactive actions ]
    // [ active actions |< inactive actions  ]
    //        a        s
    //         <-swap->
    //        s        a

    final actions = _actions;
    final prevIndex = action._cacheIndex!;

    final firstInactiveIndex = --_nActiveActions;

    final lastActiveAction = actions[firstInactiveIndex];

    action._cacheIndex = firstInactiveIndex;
    actions[firstInactiveIndex] = action;

    lastActiveAction._cacheIndex = prevIndex;
    actions[prevIndex] = lastActiveAction;
  }

  // Memory management for PropertyMixer objects

  void _addInactiveBinding(PropertyMixer binding, String rootUuid, String trackName) {
    final bindingsByRoot = _bindingsByRootAndName;
    final bindings = _bindings;

    final bindingByName = bindingsByRoot.putIfAbsent(rootUuid, () => {});

    bindingByName[trackName] = binding;

    binding._cacheIndex = bindings.length;
    bindings.add(binding);
  }

  void _removeInactiveBinding(PropertyMixer binding) {
    final bindings = _bindings;
    final propBinding = binding.binding;

    // A composite binding has no root node or path (in the reference: undefined); the reference then fails reading
    // `rootNode.uuid`, and so does this.
    final rootUuid = _animationUuid(propBinding.rootNode!);
    final trackName = propBinding.path;
    final bindingsByRoot = _bindingsByRootAndName;
    final bindingByName = bindingsByRoot[rootUuid]!;

    final lastInactiveBinding = bindings[bindings.length - 1];
    final cacheIndex = binding._cacheIndex!;

    lastInactiveBinding._cacheIndex = cacheIndex;
    bindings[cacheIndex] = lastInactiveBinding;
    bindings.removeLast();

    bindingByName.remove(trackName);

    if (bindingByName.isEmpty) {
      bindingsByRoot.remove(rootUuid);
    }
  }

  void _lendBinding(PropertyMixer binding) {
    final bindings = _bindings;
    final prevIndex = binding._cacheIndex!;

    final lastActiveIndex = _nActiveBindings++;

    final firstInactiveBinding = bindings[lastActiveIndex];

    binding._cacheIndex = lastActiveIndex;
    bindings[lastActiveIndex] = binding;

    firstInactiveBinding._cacheIndex = prevIndex;
    bindings[prevIndex] = firstInactiveBinding;
  }

  void _takeBackBinding(PropertyMixer binding) {
    final bindings = _bindings;
    final prevIndex = binding._cacheIndex!;

    final firstInactiveIndex = --_nActiveBindings;

    final lastActiveBinding = bindings[firstInactiveIndex];

    binding._cacheIndex = firstInactiveIndex;
    bindings[firstInactiveIndex] = binding;

    lastActiveBinding._cacheIndex = prevIndex;
    bindings[prevIndex] = lastActiveBinding;
  }

  // Memory management of Interpolants for weight and time scale

  Interpolant _lendControlInterpolant() {
    final interpolants = _controlInterpolants;
    final lastActiveIndex = _nActiveControlInterpolants++;

    if (lastActiveIndex < interpolants.length) {
      return interpolants[lastActiveIndex];
    }

    final interpolant = LinearInterpolant(
      Float32List(2),
      Float32List(2),
      1,
      _animationMixerControlInterpolantsResultBuffer,
    );

    _animationMixerControlCacheIndex[interpolant] = lastActiveIndex;
    interpolants.add(interpolant);

    return interpolant;
  }

  void _takeBackControlInterpolant(Interpolant interpolant) {
    final interpolants = _controlInterpolants;
    final prevIndex = _animationMixerControlCacheIndex[interpolant]!;

    final firstInactiveIndex = --_nActiveControlInterpolants;

    final lastActiveInterpolant = interpolants[firstInactiveIndex];

    _animationMixerControlCacheIndex[interpolant] = firstInactiveIndex;
    interpolants[firstInactiveIndex] = interpolant;

    _animationMixerControlCacheIndex[lastActiveInterpolant] = prevIndex;
    interpolants[prevIndex] = lastActiveInterpolant;
  }

  /// Returns an instance of [AnimationAction] for the passed clip (an [AnimationClip] or a clip name).
  ///
  /// If an action fitting the clip and root parameters doesn't yet exist, it will be created by this
  /// method. Calling this method several times with the same clip and root parameters always returns the
  /// same action. Returns `null` for an unknown clip name.
  AnimationAction? clipAction(Object clip, [Object? optionalRoot, int? blendMode]) {
    final root = optionalRoot ?? _root;
    final rootUuid = _animationUuid(root);

    var clipObject = clip is String ? AnimationClip.findByName(root!, clip) : clip as AnimationClip;

    final clipUuid = clipObject != null ? clipObject.uuid : clip as String;

    final actionsForClip = _actionsByClip[clipUuid];
    AnimationAction? prototypeAction;

    if (blendMode == null) {
      if (clipObject != null) {
        blendMode = clipObject.blendMode;
      } else {
        blendMode = NormalAnimationBlendMode;
      }
    }

    if (actionsForClip != null) {
      final existingAction = actionsForClip.actionByRoot[rootUuid];

      if (existingAction != null && existingAction.blendMode == blendMode) {
        return existingAction;
      }

      // we know the clip, so we don't have to parse all
      // the bindings again but can just copy
      prototypeAction = actionsForClip.knownActions[0];

      // also, take the clip from the prototype action
      clipObject ??= prototypeAction._clip;
    }

    // clip must be known when specified via string
    if (clipObject == null) {
      return null;
    }

    // allocate all resources required to run it
    final newAction = AnimationAction(this, clipObject, optionalRoot, blendMode);

    _bindAction(newAction, prototypeAction);

    // and make the action known to the memory manager
    _addInactiveAction(newAction, clipUuid, rootUuid);

    return newAction;
  }

  /// Returns an existing animation action for the passed clip (an [AnimationClip] or a clip name), or
  /// `null`.
  AnimationAction? existingAction(Object clip, [Object? optionalRoot]) {
    final root = optionalRoot ?? _root;
    final rootUuid = _animationUuid(root);

    final clipObject = clip is String ? AnimationClip.findByName(root!, clip) : clip as AnimationClip;

    final clipUuid = clipObject != null ? clipObject.uuid : clip as String;

    final actionsForClip = _actionsByClip[clipUuid];

    if (actionsForClip != null) {
      return actionsForClip.actionByRoot[rootUuid];
    }

    return null;
  }

  /// Deactivates all previously scheduled actions on this mixer.
  AnimationMixer stopAllAction() {
    final actions = _actions;
    final nActions = _nActiveActions;

    for (var i = nActions - 1; i >= 0; --i) {
      actions[i].stop();
    }

    return this;
  }

  /// Advances the global mixer time and updates the animation.
  ///
  /// This is usually done in the render loop by passing the delta time from [Clock] or [Timer].
  AnimationMixer update(double deltaTime) {
    deltaTime *= timeScale;

    final actions = _actions;
    final nActions = _nActiveActions;

    final time = this.time += deltaTime;
    final timeDirection = deltaTime.sign;

    final accuIndex = _accuIndex ^= 1;

    // run active actions

    for (var i = 0; i != nActions; ++i) {
      final action = actions[i];

      action._update(time, deltaTime, timeDirection, accuIndex);
    }

    // update scene graph

    final bindings = _bindings;
    final nBindings = _nActiveBindings;

    for (var i = 0; i != nBindings; ++i) {
      bindings[i].apply(accuIndex);
    }

    return this;
  }

  /// Sets the global mixer to a specific time and updates the animation accordingly.
  ///
  /// This is useful when you need to jump to an exact time in an animation. The input parameter will be
  /// scaled by [timeScale].
  AnimationMixer setTime(double time) {
    this.time = 0; // Zero out time attribute for AnimationMixer object;

    for (var i = 0; i < _actions.length; i++) {
      _actions[i].time = 0; // Zero out time attribute for all associated AnimationAction objects.
    }

    return update(time); // Update used to set exact time. Returns "this" AnimationMixer object.
  }

  /// Returns this mixer's root object.
  Object? getRoot() {
    return _root;
  }

  /// Deallocates all memory resources for a clip. Before using this method make sure to call
  /// [AnimationAction.stop] for all related actions.
  void uncacheClip(AnimationClip clip) {
    final actions = _actions;
    final clipUuid = clip.uuid;
    final actionsByClip = _actionsByClip;
    final actionsForClip = actionsByClip[clipUuid];

    if (actionsForClip != null) {
      // note: just calling _removeInactiveAction would mess up the
      // iteration state and also require updating the state we can
      // just throw away

      final actionsToRemove = actionsForClip.knownActions;

      for (var i = 0, n = actionsToRemove.length; i != n; ++i) {
        final action = actionsToRemove[i];

        _deactivateAction(action);

        final cacheIndex = action._cacheIndex!;
        final lastInactiveAction = actions[actions.length - 1];

        action._cacheIndex = null;
        action._byClipCacheIndex = null;

        lastInactiveAction._cacheIndex = cacheIndex;
        actions[cacheIndex] = lastInactiveAction;
        actions.removeLast();

        _removeInactiveBindingsForAction(action);
      }

      actionsByClip.remove(clipUuid);
    }
  }

  /// Deallocates all memory resources for a root object. Before using this method make sure to call
  /// [AnimationAction.stop] for all related actions or alternatively [stopAllAction] when the mixer
  /// operates on a single root.
  void uncacheRoot(Object root) {
    final rootUuid = _animationUuid(root);
    final actionsByClip = _actionsByClip;

    // for-in visits the keys present when it reaches them; a copy of the keys, rechecked, does the same.
    for (final clipUuid in actionsByClip.keys.toList()) {
      final actionsForClip = actionsByClip[clipUuid];

      if (actionsForClip == null) {
        continue;
      }

      final action = actionsForClip.actionByRoot[rootUuid];

      if (action != null) {
        _deactivateAction(action);
        _removeInactiveAction(action);
      }
    }

    final bindingsByRoot = _bindingsByRootAndName;
    final bindingByName = bindingsByRoot[rootUuid];

    if (bindingByName != null) {
      for (final trackName in bindingByName.keys.toList()) {
        final binding = bindingByName[trackName];

        if (binding == null) {
          continue;
        }

        binding.restoreOriginalState();
        _removeInactiveBinding(binding);
      }
    }
  }

  /// Deallocates all memory resources for an action. The action is identified by the given clip and an
  /// optional root object. Before using this method make sure to call [AnimationAction.stop] to deactivate
  /// the action.
  void uncacheAction(Object clip, [Object? optionalRoot]) {
    final action = existingAction(clip, optionalRoot);

    if (action != null) {
      _deactivateAction(action);
      _removeInactiveAction(action);
    }
  }
}
