part of '../../ent.dart';

/// A continuous line. This is nearly the same as [Line]; the only difference is that the last vertex is
/// connected with the first vertex in order to close the line to form a loop.
class LineLoop extends Line {
  /// Constructs a new line loop.
  LineLoop([super.geometry, super.material]) {
    type = 'LineLoop';
  }

  /// This flag can be used for type testing.
  bool get isLineLoop => true;

  @override
  Object? operator [](String key) {
    return key == 'isLineLoop' ? isLineLoop : super[key];
  }

  @override
  LineLoop clone([bool recursive = true]) {
    return LineLoop().copy(this, recursive) as LineLoop;
  }
}
