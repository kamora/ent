part of '../../ent.dart';

/// An instance of `AnimationAction` schedules the playback of an animation which is stored in
/// [AnimationClip].
class AnimationAction {
  /// Constructs a new animation action for [clip], played by [mixer] on [localRoot] (the mixer's root
  /// when `null`); [blendMode] defaults to the clip's.
  AnimationAction(AnimationMixer mixer, AnimationClip clip, [Object? localRoot, int? blendMode])
    : _mixer = mixer,
      _clip = clip,
      _localRoot = localRoot,
      blendMode = blendMode ?? clip.blendMode {
    final tracks = clip.tracks;
    final nTracks = tracks.length;

    final interpolantSettings = <String, Object?>{'endingStart': ZeroCurvatureEnding, 'endingEnd': ZeroCurvatureEnding};

    final interpolants = <Interpolant>[];

    for (var i = 0; i != nTracks; ++i) {
      final interpolant = tracks[i].createInterpolant(null);
      interpolants.add(interpolant);
      interpolant.settings = interpolantSettings;
    }

    _interpolantSettings = interpolantSettings;

    _interpolants = interpolants; // bound by the mixer

    // inside: PropertyMixer (managed by the mixer)
    _propertyBindings = List<PropertyMixer?>.filled(nTracks, null);
  }

  final AnimationMixer _mixer;

  final AnimationClip _clip;

  final Object? _localRoot;

  /// Defines how the animation is blended/combined when two or more animations are simultaneously played.
  int blendMode;

  late final Map<String, Object?> _interpolantSettings;

  late final List<Interpolant> _interpolants;

  late final List<PropertyMixer?> _propertyBindings;

  int? _cacheIndex; // for the memory manager

  int? _byClipCacheIndex; // for the memory manager

  Interpolant? _timeScaleInterpolant;

  double? _restoreTimeScale;

  Interpolant? _weightInterpolant;

  /// The loop mode, set via [setLoop].
  int loop = LoopRepeat;

  // A JS number: -1 before the first loop, fractional or infinite only for degenerate clips.
  double _loopCount = -1;

  // global mixer time when the action is to be started
  // it's set back to 'null' upon start of the action
  double? _startTime;

  /// For tests: the loops completed, -1 before the first.
  @visibleForTesting
  double get loopCount => _loopCount;

  /// For tests: the mixer time the action is to start at, `null` once started.
  @visibleForTesting
  double? get startTime => _startTime;

  /// The local time of this action (in seconds, starting with `0`). The value gets clamped or wrapped to
  /// `[0,clip.duration]` (according to the loop state).
  double time = 0;

  /// Scaling factor for the [time]. A value of `0` causes the animation to pause. Negative values cause the
  /// animation to play backwards.
  double timeScale = 1;

  double _effectiveTimeScale = 1;

  /// The degree of influence of this action (in the interval `[0, 1]`). Values between `0` (no impact) and
  /// `1` (full impact) can be used to blend between several actions.
  double weight = 1;

  double _effectiveWeight = 1;

  /// The number of repetitions of the performed clip over the course of this action. Can be set via
  /// [setLoop]. Setting this number has no effect if [loop] is set to `LoopOnce`.
  double repetitions = double.infinity;

  /// If set to `true`, the playback of the action is paused.
  bool paused = false;

  /// If set to `false`, the action is disabled so it has no impact. When the action is re-enabled, the
  /// animation continues from its current time (setting `enabled` to `false` doesn't reset the action).
  bool enabled = true;

  /// If set to true the animation will automatically be paused on its last frame. If set to false,
  /// [enabled] will automatically be switched to `false` when the last loop of the action has finished, so
  /// that this action has no further impact.
  ///
  /// Note: This member has no impact if the action is interrupted (it has only an effect if its last loop
  /// has really finished).
  bool clampWhenFinished = false;

  /// Enables smooth interpolation without separate clips for start, loop and end.
  bool zeroSlopeAtStart = true;

  /// Enables smooth interpolation without separate clips for start, loop and end.
  bool zeroSlopeAtEnd = true;

  /// Starts the playback of the animation.
  AnimationAction play() {
    _mixer._activateAction(this);

    return this;
  }

  /// Stops the playback of the animation.
  AnimationAction stop() {
    _mixer._deactivateAction(this);

    return reset();
  }

  /// Resets the playback of the animation.
  AnimationAction reset() {
    paused = false;
    enabled = true;

    time = 0; // restart clip
    _loopCount = -1; // forget previous loops
    _startTime = null; // forget scheduling

    return stopFading().stopWarping();
  }

  /// Returns `true` if the animation is running.
  bool isRunning() {
    return enabled && !paused && timeScale != 0 && _startTime == null && _mixer._isActiveAction(this);
  }

  /// Returns `true` when [play] has been called.
  bool isScheduled() {
    return _mixer._isActiveAction(this);
  }

  /// Defines the time when the animation should start.
  AnimationAction startAt(double time) {
    _startTime = time;

    return this;
  }

  /// Configures the loop settings for this action: [mode] is `LoopOnce`, `LoopRepeat` or `LoopPingPong`; an omitted
  /// [repetitions] is the reference's `undefined`, which compares and computes as NaN.
  AnimationAction setLoop(int mode, [double? repetitions]) {
    loop = mode;
    this.repetitions = repetitions ?? double.nan;

    return this;
  }

  /// Sets the effective weight of this action.
  ///
  /// An action has no effect and thus an effective weight of zero when the action is disabled.
  AnimationAction setEffectiveWeight(double weight) {
    this.weight = weight;

    // note: same logic as when updated at runtime
    _effectiveWeight = enabled ? weight : 0;

    return stopFading();
  }

  /// Returns the effective weight of this action.
  double getEffectiveWeight() {
    return _effectiveWeight;
  }

  /// Fades the animation in by increasing its weight gradually from `0` to `1`, within the passed time
  /// interval.
  AnimationAction fadeIn(double duration) {
    return _scheduleFading(duration, 0, 1);
  }

  /// Fades the animation out by decreasing its weight gradually from `1` to `0`, within the passed time
  /// interval.
  AnimationAction fadeOut(double duration) {
    return _scheduleFading(duration, 1, 0);
  }

  /// Causes this action to fade in and the given action to fade out, within the passed time interval;
  /// with [warp], the time scales are warped as well.
  AnimationAction crossFadeFrom(AnimationAction fadeOutAction, double duration, [bool warp = false]) {
    fadeOutAction.fadeOut(duration);
    fadeIn(duration);

    if (warp == true) {
      final fadeInDuration = _clip.duration;
      final fadeOutDuration = fadeOutAction._clip.duration;

      final startEndRatio = fadeOutDuration / fadeInDuration;
      final endStartRatio = fadeInDuration / fadeOutDuration;

      fadeOutAction._restoreTimeScale = fadeOutAction.timeScale;
      _restoreTimeScale = timeScale;

      fadeOutAction.warp(1.0, startEndRatio, duration);
      this.warp(endStartRatio, 1.0, duration);
    }

    return this;
  }

  /// Causes this action to fade out and the given action to fade in, within the passed time interval.
  AnimationAction crossFadeTo(AnimationAction fadeInAction, double duration, [bool warp = false]) {
    return fadeInAction.crossFadeFrom(this, duration, warp);
  }

  /// Stops any fading which is applied to this action.
  AnimationAction stopFading() {
    final weightInterpolant = _weightInterpolant;

    if (weightInterpolant != null) {
      _weightInterpolant = null;
      _mixer._takeBackControlInterpolant(weightInterpolant);
    }

    return this;
  }

  /// Sets the effective time scale of this action.
  ///
  /// An action has no effect and thus an effective time scale of zero when the action is paused.
  AnimationAction setEffectiveTimeScale(double timeScale) {
    this.timeScale = timeScale;
    _effectiveTimeScale = paused ? 0 : timeScale;

    return stopWarping();
  }

  /// Returns the effective time scale of this action.
  double getEffectiveTimeScale() {
    return _effectiveTimeScale;
  }

  /// Sets the duration for a single loop of this action.
  AnimationAction setDuration(double duration) {
    timeScale = _clip.duration / duration;

    return stopWarping();
  }

  /// Synchronizes this action with the passed other action.
  AnimationAction syncWith(AnimationAction action) {
    time = action.time;
    timeScale = action.timeScale;

    return stopWarping();
  }

  /// Decelerates this animation's speed to `0` within the passed time interval.
  AnimationAction halt(double duration) {
    return warp(_effectiveTimeScale, 0, duration);
  }

  /// Changes the playback speed, within the passed time interval, by modifying [timeScale] gradually from
  /// [startTimeScale] to [endTimeScale].
  AnimationAction warp(double startTimeScale, double endTimeScale, double duration) {
    final mixer = _mixer;
    final now = mixer.time;
    final timeScale = this.timeScale;

    var interpolant = _timeScaleInterpolant;

    if (interpolant == null) {
      interpolant = mixer._lendControlInterpolant();
      _timeScaleInterpolant = interpolant;
    }

    final times = interpolant.parameterPositions;
    final values = interpolant.sampleValues;

    times[0] = now;
    times[1] = now + duration;

    values[0] = startTimeScale / timeScale;
    values[1] = endTimeScale / timeScale;

    return this;
  }

  /// Stops any scheduled warping which is applied to this action.
  AnimationAction stopWarping() {
    final timeScaleInterpolant = _timeScaleInterpolant;

    if (timeScaleInterpolant != null) {
      _timeScaleInterpolant = null;
      _mixer._takeBackControlInterpolant(timeScaleInterpolant);
    }

    _restoreTimeScale = null;

    return this;
  }

  /// Returns the animation mixer of this animation action.
  AnimationMixer getMixer() {
    return _mixer;
  }

  /// Returns the animation clip of this animation action.
  AnimationClip getClip() {
    return _clip;
  }

  /// Returns the root object of this animation action.
  Object? getRoot() {
    return _localRoot ?? _mixer._root;
  }

  // Internal

  void _update(double time, double deltaTime, double timeDirection, int accuIndex) {
    // called by the mixer

    if (!enabled) {
      // call ._updateWeight() to update ._effectiveWeight

      _updateWeight(time);
      return;
    }

    final startTime = _startTime;

    if (startTime != null) {
      // check for scheduled start of action

      final timeRunning = (time - startTime) * timeDirection;

      if (timeRunning < 0 || timeDirection == 0) {
        deltaTime = 0;
      } else {
        _startTime = null; // unschedule
        deltaTime = timeDirection * timeRunning;
      }
    }

    // apply time scale and advance time

    deltaTime *= _updateTimeScale(time);
    final clipTime = _updateTime(deltaTime);

    // note: _updateTime may disable the action resulting in
    // an effective weight of 0

    final weight = _updateWeight(time);

    if (weight > 0) {
      final interpolants = _interpolants;
      final propertyMixers = _propertyBindings;

      switch (blendMode) {
        case AdditiveAnimationBlendMode:
          for (var j = 0, m = interpolants.length; j != m; ++j) {
            interpolants[j].evaluate(clipTime);
            propertyMixers[j]!.accumulateAdditive(weight);
          }

        case NormalAnimationBlendMode:
        default:
          for (var j = 0, m = interpolants.length; j != m; ++j) {
            interpolants[j].evaluate(clipTime);
            propertyMixers[j]!.accumulate(accuIndex, weight);
          }
      }
    }
  }

  double _updateWeight(double time) {
    var weight = 0.0;

    if (enabled) {
      weight = this.weight;
      final interpolant = _weightInterpolant;

      if (interpolant != null) {
        final interpolantValue = interpolant.evaluate(time)[0];

        weight *= interpolantValue;

        if (time > interpolant.parameterPositions[1]) {
          stopFading();

          if (interpolantValue == 0) {
            // faded out, disable
            enabled = false;
          }
        }
      }
    }

    _effectiveWeight = weight;
    return weight;
  }

  double _updateTimeScale(double time) {
    var timeScale = 0.0;

    if (!paused) {
      timeScale = this.timeScale;

      final interpolant = _timeScaleInterpolant;

      if (interpolant != null) {
        final interpolantValue = interpolant.evaluate(time)[0];

        timeScale *= interpolantValue;

        if (time > interpolant.parameterPositions[1]) {
          if (timeScale == 0) {
            // motion has halted, pause
            paused = true;
          } else {
            final restoreTimeScale = _restoreTimeScale;

            if (restoreTimeScale != null) {
              timeScale = restoreTimeScale;
            }

            // warp done - apply final time scale
            this.timeScale = timeScale;
          }

          stopWarping();
        }
      }
    }

    _effectiveTimeScale = timeScale;
    return timeScale;
  }

  double _updateTime(double deltaTime) {
    final duration = _clip.duration;
    final loop = this.loop;

    var time = this.time + deltaTime;
    var loopCount = _loopCount;

    final pingPong = loop == LoopPingPong;

    if (deltaTime == 0) {
      if (loopCount == -1) {
        return time;
      }

      return (pingPong && (_jsToInt32(loopCount) & 1) == 1) ? duration - time : time;
    }

    if (loop == LoopOnce) {
      if (loopCount == -1) {
        // just started

        _loopCount = 0;
        _setEndings(true, true, false);
      }

      handle_stop:
      {
        if (time >= duration) {
          time = duration;
        } else if (time < 0) {
          time = 0;
        } else {
          this.time = time;

          break handle_stop;
        }

        if (clampWhenFinished) {
          paused = true;
        } else {
          enabled = false;
        }

        this.time = time;

        _mixer.dispatchEvent(Event('finished', {'action': this, 'direction': deltaTime < 0 ? -1 : 1}));
      }
    } else {
      // repetitive Repeat or PingPong

      if (loopCount == -1) {
        // just started

        if (deltaTime >= 0) {
          loopCount = 0;

          _setEndings(true, repetitions == 0, pingPong);
        } else {
          // when looping in reverse direction, the initial
          // transition through zero counts as a repetition,
          // so leave loopCount at -1

          _setEndings(repetitions == 0, true, pingPong);
        }
      }

      if (time >= duration || time < 0) {
        // wrap around

        final loopDelta = (time / duration).floorToDouble(); // signed
        time -= duration * loopDelta;

        loopCount += loopDelta.abs();

        final pending = repetitions - loopCount;

        if (pending <= 0) {
          // have to stop (switch state, clamp time, fire event)

          if (clampWhenFinished) {
            paused = true;
          } else {
            enabled = false;
          }

          time = deltaTime > 0 ? duration : 0;

          this.time = time;

          _mixer.dispatchEvent(Event('finished', {'action': this, 'direction': deltaTime > 0 ? 1 : -1}));
        } else {
          // keep running

          if (pending == 1) {
            // entering the last round

            final atStart = deltaTime < 0;
            _setEndings(atStart, !atStart, pingPong);
          } else {
            _setEndings(false, false, pingPong);
          }

          _loopCount = loopCount;

          this.time = time;

          _mixer.dispatchEvent(Event('loop', {'action': this, 'loopDelta': loopDelta}));
        }
      } else {
        _loopCount = loopCount;
        this.time = time;
      }

      if (pingPong && (_jsToInt32(loopCount) & 1) == 1) {
        // invert time for the "pong round"

        return duration - time;
      }
    }

    return time;
  }

  void _setEndings(bool atStart, bool atEnd, bool pingPong) {
    final settings = _interpolantSettings;

    if (pingPong) {
      settings['endingStart'] = ZeroSlopeEnding;
      settings['endingEnd'] = ZeroSlopeEnding;
    } else {
      // assuming for LoopOnce atStart == atEnd == true

      if (atStart) {
        settings['endingStart'] = zeroSlopeAtStart ? ZeroSlopeEnding : ZeroCurvatureEnding;
      } else {
        settings['endingStart'] = WrapAroundEnding;
      }

      if (atEnd) {
        settings['endingEnd'] = zeroSlopeAtEnd ? ZeroSlopeEnding : ZeroCurvatureEnding;
      } else {
        settings['endingEnd'] = WrapAroundEnding;
      }
    }
  }

  AnimationAction _scheduleFading(double duration, double weightNow, double weightThen) {
    final mixer = _mixer;
    final now = mixer.time;
    var interpolant = _weightInterpolant;

    if (interpolant == null) {
      interpolant = mixer._lendControlInterpolant();
      _weightInterpolant = interpolant;
    }

    final times = interpolant.parameterPositions;
    final values = interpolant.sampleValues;

    times[0] = now;
    values[0] = weightNow;
    times[1] = now + duration;
    values[1] = weightThen;

    return this;
  }
}
