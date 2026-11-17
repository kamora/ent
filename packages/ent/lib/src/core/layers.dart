part of '../../ent.dart';

/// A layers object assigns a 3D object to 1 or more of 32 layers numbered `0` to `31` - internally the
/// layers are stored as a bit mask, and by default all 3D objects are a member of layer `0`.
///
/// This can be used to control visibility - an object must share a layer with a camera to be visible
/// when that camera's view is rendered.
///
/// All classes that inherit from [Object3D] have a `layers` property which is an instance of this class.
///
/// The mask follows JavaScript's 32-bit integer semantics: [set] stores an unsigned value, the other
/// operations a signed one (`enableAll()` gives `-1`), on the VM and on the web alike.
class Layers {
  /// Constructs a new layers instance, with membership initially set to layer `0`.
  Layers();

  /// A bit mask storing which of the 32 layers this layers object is currently a member of.
  int mask = 1 | 0;

  /// `1 << layer | 0`: the bit of the given layer as a signed 32-bit integer.
  static int _bit(int layer) => _jsToInt32(1 << (_jsToUint32(layer) & 31));

  /// Sets membership to the given layer, and remove membership all other layers.
  void set(int layer) {
    mask = _jsToUint32(_bit(layer));
  }

  /// Adds membership of the given layer.
  void enable(int layer) {
    mask = _jsToInt32(_jsToInt32(mask) | _bit(layer));
  }

  /// Adds membership to all layers.
  void enableAll() {
    mask = _jsToInt32(0xffffffff);
  }

  /// Toggles the membership of the given layer.
  void toggle(int layer) {
    mask = _jsToInt32(_jsToInt32(mask) ^ _bit(layer));
  }

  /// Removes membership of the given layer.
  void disable(int layer) {
    mask = _jsToInt32(_jsToInt32(mask) & _jsToInt32(~_bit(layer)));
  }

  /// Removes the membership from all layers.
  void disableAll() {
    mask = 0;
  }

  /// Returns `true` if this and the given layers object have at least one layer in common.
  bool test(Layers layers) {
    return (_jsToInt32(mask) & _jsToInt32(layers.mask)) != 0;
  }

  /// Returns `true` if the given layer is enabled.
  bool isEnabled(int layer) {
    return (_jsToInt32(mask) & _bit(layer)) != 0;
  }
}
