part of '../../../ent.dart';

// A port of mapbox/earcut version 3.0.2
// https://github.com/mapbox/earcut/tree/v3.0.2
//
// ISC License
//
// Copyright (c) 2024, Mapbox
//
// Permission to use, copy, modify, and/or distribute this software for any purpose
// with or without fee is hereby granted, provided that the above copyright notice
// and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
// REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
// INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
// OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
// TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
// THIS SOFTWARE.
//
// The library is internal to the engine (only Earcut.triangulate is public), so its functions are library-private here.
// JavaScript truthiness of numbers (`if ( invSize )`, `area() || area()`) is spelled out with _earcutTruthy: 0, NaN and
// a missing value are false.

bool _earcutTruthy(double? v) => v != null && v != 0 && !v.isNaN;

/// A stable sort with a JavaScript-style comparator (`compare( a, b ) > 0` puts `b` first), as
/// `Array.prototype.sort` is stable; Dart's `List.sort` is not guaranteed to be.
void _extrasStableSort<E>(List<E> list, double Function(E a, E b) compare) {
  // Binary insertion sort, which is what V8's TimSort uses for short runs. A comparator returning NaN
  // counts as "not greater", like V8's `< 0` tests.
  for (var i = 1; i < list.length; i++) {
    final item = list[i];
    var low = 0, high = i;

    while (low < high) {
      final mid = (low + high) >> 1;

      if (compare(item, list[mid]) < 0) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }

    for (var j = i; j > low; j--) {
      list[j] = list[j - 1];
    }

    list[low] = item;
  }
}

/// A vertex node of a polygon ring (the reference's `createNode` object literal).
class _EarcutNode {
  _EarcutNode(this.i, this.x, this.y);

  /// vertex index in coordinates array
  int i;

  /// vertex coordinates
  double x, y;

  /// previous and next vertex nodes in a polygon ring
  late _EarcutNode prev, next;

  /// z-order curve value
  int z = 0;

  /// previous and next nodes in z-order
  _EarcutNode? prevZ, nextZ;

  /// indicates whether this is a steiner point
  bool steiner = false;
}

/// The reference's default export `earcut( data, holeIndices, dim = 2 )`.
List<int> _earcut(List<num> data, [List<int>? holeIndices, int dim = 2]) {
  final hasHoles = holeIndices != null && holeIndices.isNotEmpty;
  final outerLen = hasHoles ? holeIndices[0] * dim : data.length;
  var outerNode = _earcutLinkedList(data, 0, outerLen, dim, true);
  final triangles = <int>[];

  if (outerNode == null || outerNode.next == outerNode.prev) {
    return triangles;
  }

  double? minX, minY, invSize;

  if (hasHoles) {
    outerNode = _earcutEliminateHoles(data, holeIndices, outerNode, dim);
  }

  // if the shape is not too simple, we'll use z-order curve hash later; calculate polygon bbox
  if (data.length > 80 * dim) {
    minX = data[0].toDouble();
    minY = data[1].toDouble();
    var maxX = minX;
    var maxY = minY;

    for (var i = dim; i < outerLen; i += dim) {
      final x = data[i].toDouble();
      final y = data[i + 1].toDouble();

      if (x < minX!) {
        minX = x;
      }

      if (y < minY!) {
        minY = y;
      }

      if (x > maxX) {
        maxX = x;
      }

      if (y > maxY) {
        maxY = y;
      }
    }

    // minX, minY and invSize are later used to transform coords into integers for z-order calculation
    invSize = math.max(maxX - minX!, maxY - minY!);
    invSize = invSize != 0 ? 32767 / invSize : 0;
  }

  _earcutLinked(outerNode, triangles, dim, minX, minY, invSize, 0);

  return triangles;
}

// create a circular doubly linked list from polygon points in the specified winding order
_EarcutNode? _earcutLinkedList(List<num> data, int start, int end, int dim, bool clockwise) {
  _EarcutNode? last;

  if (clockwise == (_earcutSignedArea(data, start, end, dim) > 0)) {
    for (var i = start; i < end; i += dim) {
      last = _earcutInsertNode(i ~/ dim, data[i].toDouble(), data[i + 1].toDouble(), last);
    }
  } else {
    for (var i = end - dim; i >= start; i -= dim) {
      last = _earcutInsertNode(i ~/ dim, data[i].toDouble(), data[i + 1].toDouble(), last);
    }
  }

  if (last != null && _earcutEquals(last, last.next)) {
    _earcutRemoveNode(last);
    last = last.next;
  }

  return last;
}

// eliminate colinear or duplicate points
_EarcutNode? _earcutFilterPoints(_EarcutNode? start, [_EarcutNode? end]) {
  if (start == null) {
    return start;
  }

  end ??= start;

  var p = start;
  bool again;

  do {
    again = false;

    if (!p.steiner && (_earcutEquals(p, p.next) || _earcutArea(p.prev, p, p.next) == 0)) {
      _earcutRemoveNode(p);
      p = end = p.prev;

      if (p == p.next) {
        break;
      }

      again = true;
    } else {
      p = p.next;
    }
  } while (again || p != end);

  return end;
}

// main ear slicing loop which triangulates a polygon (given as a linked list)
void _earcutLinked(
  _EarcutNode? ear,
  List<int> triangles,
  int dim,
  double? minX,
  double? minY,
  double? invSize,
  int pass,
) {
  if (ear == null) {
    return;
  }

  // interlink polygon nodes in z-order
  if (pass == 0 && _earcutTruthy(invSize)) {
    _earcutIndexCurve(ear, minX!, minY!, invSize!);
  }

  var stop = ear;

  // iterate through ears, slicing them one by one
  while (ear!.prev != ear.next) {
    final prev = ear.prev;
    final next = ear.next;

    if (_earcutTruthy(invSize) ? _earcutIsEarHashed(ear, minX!, minY!, invSize!) : _earcutIsEar(ear)) {
      triangles.addAll([prev.i, ear.i, next.i]); // cut off the triangle

      _earcutRemoveNode(ear);

      // skipping the next vertex leads to less sliver triangles
      ear = next.next;
      stop = next.next;

      continue;
    }

    ear = next;

    // if we looped through the whole remaining polygon and can't find any more ears
    if (ear == stop) {
      // try filtering points and slicing again
      if (pass == 0) {
        _earcutLinked(_earcutFilterPoints(ear), triangles, dim, minX, minY, invSize, 1);

        // if this didn't work, try curing all small self-intersections locally
      } else if (pass == 1) {
        ear = _earcutCureLocalIntersections(_earcutFilterPoints(ear)!, triangles);
        _earcutLinked(ear, triangles, dim, minX, minY, invSize, 2);

        // as a last resort, try splitting the remaining polygon into two
      } else if (pass == 2) {
        _earcutSplitEarcut(ear, triangles, dim, minX, minY, invSize);
      }

      break;
    }
  }
}

// check whether a polygon node forms a valid ear with adjacent nodes
bool _earcutIsEar(_EarcutNode ear) {
  final a = ear.prev, b = ear, c = ear.next;

  if (_earcutArea(a, b, c) >= 0) {
    return false; // reflex, can't be an ear
  }

  // now make sure we don't have other points inside the potential ear
  final ax = a.x, bx = b.x, cx = c.x, ay = a.y, by = b.y, cy = c.y;

  // triangle bbox
  final x0 = math.min(math.min(ax, bx), cx),
      y0 = math.min(math.min(ay, by), cy),
      x1 = math.max(math.max(ax, bx), cx),
      y1 = math.max(math.max(ay, by), cy);

  var p = c.next;

  while (p != a) {
    if (p.x >= x0 &&
        p.x <= x1 &&
        p.y >= y0 &&
        p.y <= y1 &&
        _earcutPointInTriangleExceptFirst(ax, ay, bx, by, cx, cy, p.x, p.y) &&
        _earcutArea(p.prev, p, p.next) >= 0) {
      return false;
    }

    p = p.next;
  }

  return true;
}

bool _earcutIsEarHashed(_EarcutNode ear, double minX, double minY, double invSize) {
  final a = ear.prev, b = ear, c = ear.next;

  if (_earcutArea(a, b, c) >= 0) {
    return false; // reflex, can't be an ear
  }

  final ax = a.x, bx = b.x, cx = c.x, ay = a.y, by = b.y, cy = c.y;

  // triangle bbox
  final x0 = math.min(math.min(ax, bx), cx),
      y0 = math.min(math.min(ay, by), cy),
      x1 = math.max(math.max(ax, bx), cx),
      y1 = math.max(math.max(ay, by), cy);

  // z-order range for the current triangle bbox;
  final minZ = _earcutZOrder(x0, y0, minX, minY, invSize), maxZ = _earcutZOrder(x1, y1, minX, minY, invSize);

  var p = ear.prevZ, n = ear.nextZ;

  // look for points inside the triangle in both directions
  while (p != null && p.z >= minZ && n != null && n.z <= maxZ) {
    if (p.x >= x0 &&
        p.x <= x1 &&
        p.y >= y0 &&
        p.y <= y1 &&
        p != a &&
        p != c &&
        _earcutPointInTriangleExceptFirst(ax, ay, bx, by, cx, cy, p.x, p.y) &&
        _earcutArea(p.prev, p, p.next) >= 0) {
      return false;
    }

    p = p.prevZ;

    if (n.x >= x0 &&
        n.x <= x1 &&
        n.y >= y0 &&
        n.y <= y1 &&
        n != a &&
        n != c &&
        _earcutPointInTriangleExceptFirst(ax, ay, bx, by, cx, cy, n.x, n.y) &&
        _earcutArea(n.prev, n, n.next) >= 0) {
      return false;
    }

    n = n.nextZ;
  }

  // look for remaining points in decreasing z-order
  while (p != null && p.z >= minZ) {
    if (p.x >= x0 &&
        p.x <= x1 &&
        p.y >= y0 &&
        p.y <= y1 &&
        p != a &&
        p != c &&
        _earcutPointInTriangleExceptFirst(ax, ay, bx, by, cx, cy, p.x, p.y) &&
        _earcutArea(p.prev, p, p.next) >= 0) {
      return false;
    }

    p = p.prevZ;
  }

  // look for remaining points in increasing z-order
  while (n != null && n.z <= maxZ) {
    if (n.x >= x0 &&
        n.x <= x1 &&
        n.y >= y0 &&
        n.y <= y1 &&
        n != a &&
        n != c &&
        _earcutPointInTriangleExceptFirst(ax, ay, bx, by, cx, cy, n.x, n.y) &&
        _earcutArea(n.prev, n, n.next) >= 0) {
      return false;
    }

    n = n.nextZ;
  }

  return true;
}

// go through all polygon nodes and cure small local self-intersections
_EarcutNode? _earcutCureLocalIntersections(_EarcutNode start, List<int> triangles) {
  var p = start;

  do {
    final a = p.prev, b = p.next.next;

    if (!_earcutEquals(a, b) &&
        _earcutIntersects(a, p, p.next, b) &&
        _earcutLocallyInside(a, b) &&
        _earcutLocallyInside(b, a)) {
      triangles.addAll([a.i, p.i, b.i]);

      // remove two nodes involved
      _earcutRemoveNode(p);
      _earcutRemoveNode(p.next);

      p = start = b;
    }

    p = p.next;
  } while (p != start);

  return _earcutFilterPoints(p);
}

// try splitting polygon into two and triangulate them independently
void _earcutSplitEarcut(_EarcutNode start, List<int> triangles, int dim, double? minX, double? minY, double? invSize) {
  // look for a valid diagonal that divides the polygon into two
  var a = start;

  do {
    var b = a.next.next;

    while (b != a.prev) {
      if (a.i != b.i && _earcutIsValidDiagonal(a, b)) {
        // split the polygon in two by the diagonal
        var c = _earcutSplitPolygon(a, b);

        // filter colinear points around the cuts
        final a2 = _earcutFilterPoints(a, a.next);
        c = _earcutFilterPoints(c, c.next)!;

        // run earcut on each half
        _earcutLinked(a2, triangles, dim, minX, minY, invSize, 0);
        _earcutLinked(c, triangles, dim, minX, minY, invSize, 0);
        return;
      }

      b = b.next;
    }

    a = a.next;
  } while (a != start);
}

// link every hole into the outer loop, producing a single-ring polygon without holes
_EarcutNode _earcutEliminateHoles(List<num> data, List<int> holeIndices, _EarcutNode outerNode, int dim) {
  final queue = <_EarcutNode>[];

  for (var i = 0, len = holeIndices.length; i < len; i++) {
    final start = holeIndices[i] * dim;
    final end = i < len - 1 ? holeIndices[i + 1] * dim : data.length;
    final list = _earcutLinkedList(data, start, end, dim, false)!;

    if (list == list.next) {
      list.steiner = true;
    }

    queue.add(_earcutGetLeftmost(list));
  }

  _extrasStableSort(queue, _earcutCompareXYSlope);

  // process holes from left to right
  for (var i = 0; i < queue.length; i++) {
    outerNode = _earcutEliminateHole(queue[i], outerNode);
  }

  return outerNode;
}

double _earcutCompareXYSlope(_EarcutNode a, _EarcutNode b) {
  var result = a.x - b.x;

  // when the left-most point of 2 holes meet at a vertex, sort the holes counterclockwise so that when we find
  // the bridge to the outer shell is always the point that they meet at.
  if (result == 0) {
    result = a.y - b.y;

    if (result == 0) {
      final aSlope = (a.next.y - a.y) / (a.next.x - a.x);
      final bSlope = (b.next.y - b.y) / (b.next.x - b.x);
      result = aSlope - bSlope;
    }
  }

  return result;
}

// find a bridge between vertices that connects hole with an outer ring and link it
_EarcutNode _earcutEliminateHole(_EarcutNode hole, _EarcutNode outerNode) {
  final bridge = _earcutFindHoleBridge(hole, outerNode);

  if (bridge == null) {
    return outerNode;
  }

  final bridgeReverse = _earcutSplitPolygon(bridge, hole);

  // filter collinear points around the cuts
  _earcutFilterPoints(bridgeReverse, bridgeReverse.next);
  return _earcutFilterPoints(bridge, bridge.next)!;
}

// David Eberly's algorithm for finding a bridge between hole and outer polygon
_EarcutNode? _earcutFindHoleBridge(_EarcutNode hole, _EarcutNode outerNode) {
  var p = outerNode;
  final hx = hole.x;
  final hy = hole.y;
  var qx = double.negativeInfinity;
  _EarcutNode? m;

  // find a segment intersected by a ray from the hole's leftmost point to the left;
  // segment's endpoint with lesser x will be potential connection point
  // unless they intersect at a vertex, then choose the vertex
  if (_earcutEquals(hole, p)) {
    return p;
  }

  do {
    if (_earcutEquals(hole, p.next)) {
      return p.next;
    } else if (hy <= p.y && hy >= p.next.y && p.next.y != p.y) {
      final x = p.x + (hy - p.y) * (p.next.x - p.x) / (p.next.y - p.y);

      if (x <= hx && x > qx) {
        qx = x;
        m = p.x < p.next.x ? p : p.next;

        if (x == hx) {
          return m; // hole touches outer segment; pick leftmost endpoint
        }
      }
    }

    p = p.next;
  } while (p != outerNode);

  if (m == null) {
    return null;
  }

  // look for points inside the triangle of hole point, segment intersection and endpoint;
  // if there are no points found, we have a valid connection;
  // otherwise choose the point of the minimum angle with the ray as connection point

  final stop = m;
  final mx = m.x;
  final my = m.y;
  var tanMin = double.infinity;

  p = m;

  do {
    if (hx >= p.x &&
        p.x >= mx &&
        hx != p.x &&
        _earcutPointInTriangle(hy < my ? hx : qx, hy, mx, my, hy < my ? qx : hx, hy, p.x, p.y)) {
      final tan = (hy - p.y).abs() / (hx - p.x); // tangential

      if (_earcutLocallyInside(p, hole) &&
          (tan < tanMin || (tan == tanMin && (p.x > m!.x || (p.x == m.x && _earcutSectorContainsSector(m, p)))))) {
        m = p;
        tanMin = tan;
      }
    }

    p = p.next;
  } while (p != stop);

  return m;
}

// whether sector in vertex m contains sector in vertex p in the same coordinates
bool _earcutSectorContainsSector(_EarcutNode m, _EarcutNode p) {
  return _earcutArea(m.prev, m, p.prev) < 0 && _earcutArea(p.next, m, m.next) < 0;
}

// interlink polygon nodes in z-order
void _earcutIndexCurve(_EarcutNode start, double minX, double minY, double invSize) {
  var p = start;

  do {
    if (p.z == 0) {
      p.z = _earcutZOrder(p.x, p.y, minX, minY, invSize);
    }

    p.prevZ = p.prev;
    p.nextZ = p.next;
    p = p.next;
  } while (p != start);

  p.prevZ!.nextZ = null;
  p.prevZ = null;

  _earcutSortLinked(p);
}

// Simon Tatham's linked list merge sort algorithm
// http://www.chiark.greenend.org.uk/~sgtatham/algorithms/listsort.html
_EarcutNode? _earcutSortLinked(_EarcutNode? list) {
  int numMerges;
  var inSize = 1;

  do {
    var p = list;
    _EarcutNode e;
    list = null;
    _EarcutNode? tail;
    numMerges = 0;

    while (p != null) {
      numMerges++;
      _EarcutNode? q = p;
      var pSize = 0;

      for (var i = 0; i < inSize; i++) {
        pSize++;
        q = q!.nextZ;

        if (q == null) {
          break;
        }
      }

      var qSize = inSize;

      while (pSize > 0 || (qSize > 0 && q != null)) {
        if (pSize != 0 && (qSize == 0 || q == null || p!.z <= q.z)) {
          e = p!;
          p = p.nextZ;
          pSize--;
        } else {
          e = q!;
          q = q.nextZ;
          qSize--;
        }

        if (tail != null) {
          tail.nextZ = e;
        } else {
          list = e;
        }

        e.prevZ = tail;
        tail = e;
      }

      p = q;
    }

    tail!.nextZ = null;
    inSize *= 2;
  } while (numMerges > 1);

  return list;
}

// z-order of a point given coords and inverse of the longer side of data bbox
int _earcutZOrder(double px, double py, double minX, double minY, double invSize) {
  // coords are transformed into non-negative 15-bit integer range
  var x = _jsToInt32((px - minX) * invSize);
  var y = _jsToInt32((py - minY) * invSize);

  x = (x | (x << 8)) & 0x00FF00FF;
  x = (x | (x << 4)) & 0x0F0F0F0F;
  x = (x | (x << 2)) & 0x33333333;
  x = (x | (x << 1)) & 0x55555555;

  y = (y | (y << 8)) & 0x00FF00FF;
  y = (y | (y << 4)) & 0x0F0F0F0F;
  y = (y | (y << 2)) & 0x33333333;
  y = (y | (y << 1)) & 0x55555555;

  // The result is a signed 32-bit integer in JavaScript.
  return _jsToInt32(x | (y << 1));
}

// find the leftmost node of a polygon ring
_EarcutNode _earcutGetLeftmost(_EarcutNode start) {
  var p = start, leftmost = start;

  do {
    if (p.x < leftmost.x || (p.x == leftmost.x && p.y < leftmost.y)) {
      leftmost = p;
    }

    p = p.next;
  } while (p != start);

  return leftmost;
}

// check if a point lies within a convex triangle
bool _earcutPointInTriangle(double ax, double ay, double bx, double by, double cx, double cy, double px, double py) {
  return (cx - px) * (ay - py) >= (ax - px) * (cy - py) &&
      (ax - px) * (by - py) >= (bx - px) * (ay - py) &&
      (bx - px) * (cy - py) >= (cx - px) * (by - py);
}

// check if a point lies within a convex triangle but false if its equal to the first point of the triangle
bool _earcutPointInTriangleExceptFirst(
  double ax,
  double ay,
  double bx,
  double by,
  double cx,
  double cy,
  double px,
  double py,
) {
  return !(ax == px && ay == py) && _earcutPointInTriangle(ax, ay, bx, by, cx, cy, px, py);
}

// check if a diagonal between two polygon nodes is valid (lies in polygon interior)
bool _earcutIsValidDiagonal(_EarcutNode a, _EarcutNode b) {
  return a.next.i != b.i &&
          a.prev.i != b.i &&
          !_earcutIntersectsPolygon(a, b) && // doesn't intersect other edges
          (_earcutLocallyInside(a, b) &&
              _earcutLocallyInside(b, a) &&
              _earcutMiddleInside(a, b) && // locally visible
              (_earcutTruthy(_earcutArea(a.prev, a, b.prev)) ||
                  _earcutTruthy(_earcutArea(a, b.prev, b)))) || // does not create opposite-facing sectors
      (_earcutEquals(a, b) &&
          _earcutArea(a.prev, a, a.next) > 0 &&
          _earcutArea(b.prev, b, b.next) > 0); // special zero-length case
}

// signed area of a triangle
double _earcutArea(_EarcutNode p, _EarcutNode q, _EarcutNode r) {
  return (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y);
}

// check if two points are equal
bool _earcutEquals(_EarcutNode p1, _EarcutNode p2) {
  return p1.x == p2.x && p1.y == p2.y;
}

// check if two segments intersect
bool _earcutIntersects(_EarcutNode p1, _EarcutNode q1, _EarcutNode p2, _EarcutNode q2) {
  final o1 = _earcutSign(_earcutArea(p1, q1, p2));
  final o2 = _earcutSign(_earcutArea(p1, q1, q2));
  final o3 = _earcutSign(_earcutArea(p2, q2, p1));
  final o4 = _earcutSign(_earcutArea(p2, q2, q1));

  if (o1 != o2 && o3 != o4) {
    return true; // general case
  }

  if (o1 == 0 && _earcutOnSegment(p1, p2, q1)) {
    return true; // p1, q1 and p2 are collinear and p2 lies on p1q1
  }

  if (o2 == 0 && _earcutOnSegment(p1, q2, q1)) {
    return true; // p1, q1 and q2 are collinear and q2 lies on p1q1
  }

  if (o3 == 0 && _earcutOnSegment(p2, p1, q2)) {
    return true; // p2, q2 and p1 are collinear and p1 lies on p2q2
  }

  if (o4 == 0 && _earcutOnSegment(p2, q1, q2)) {
    return true; // p2, q2 and q1 are collinear and q1 lies on p2q2
  }

  return false;
}

// for collinear points p, q, r, check if point q lies on segment pr
bool _earcutOnSegment(_EarcutNode p, _EarcutNode q, _EarcutNode r) {
  return q.x <= math.max(p.x, r.x) &&
      q.x >= math.min(p.x, r.x) &&
      q.y <= math.max(p.y, r.y) &&
      q.y >= math.min(p.y, r.y);
}

int _earcutSign(double num) {
  return num > 0
      ? 1
      : num < 0
      ? -1
      : 0;
}

// check if a polygon diagonal intersects any polygon segments
bool _earcutIntersectsPolygon(_EarcutNode a, _EarcutNode b) {
  var p = a;

  do {
    if (p.i != a.i && p.next.i != a.i && p.i != b.i && p.next.i != b.i && _earcutIntersects(p, p.next, a, b)) {
      return true;
    }

    p = p.next;
  } while (p != a);

  return false;
}

// check if a polygon diagonal is locally inside the polygon
bool _earcutLocallyInside(_EarcutNode a, _EarcutNode b) {
  return _earcutArea(a.prev, a, a.next) < 0
      ? _earcutArea(a, b, a.next) >= 0 && _earcutArea(a, a.prev, b) >= 0
      : _earcutArea(a, b, a.prev) < 0 || _earcutArea(a, a.next, b) < 0;
}

// check if the middle point of a polygon diagonal is inside the polygon
bool _earcutMiddleInside(_EarcutNode a, _EarcutNode b) {
  var p = a;
  var inside = false;
  final px = (a.x + b.x) / 2;
  final py = (a.y + b.y) / 2;

  do {
    if (((p.y > py) != (p.next.y > py)) &&
        p.next.y != p.y &&
        (px < (p.next.x - p.x) * (py - p.y) / (p.next.y - p.y) + p.x)) {
      inside = !inside;
    }

    p = p.next;
  } while (p != a);

  return inside;
}

// link two polygon vertices with a bridge; if the vertices belong to the same ring, it splits polygon into two;
// if one belongs to the outer ring and another to a hole, it merges it into a single ring
_EarcutNode _earcutSplitPolygon(_EarcutNode a, _EarcutNode b) {
  final a2 = _EarcutNode(a.i, a.x, a.y), b2 = _EarcutNode(b.i, b.x, b.y), an = a.next, bp = b.prev;

  a.next = b;
  b.prev = a;

  a2.next = an;
  an.prev = a2;

  b2.next = a2;
  a2.prev = b2;

  bp.next = b2;
  b2.prev = bp;

  return b2;
}

// create a node and optionally link it with previous one (in a circular doubly linked list)
_EarcutNode _earcutInsertNode(int i, double x, double y, _EarcutNode? last) {
  final p = _EarcutNode(i, x, y);

  if (last == null) {
    p.prev = p;
    p.next = p;
  } else {
    p.next = last.next;
    p.prev = last;
    last.next.prev = p;
    last.next = p;
  }

  return p;
}

void _earcutRemoveNode(_EarcutNode p) {
  p.next.prev = p.prev;
  p.prev.next = p.next;

  if (p.prevZ != null) {
    p.prevZ!.nextZ = p.nextZ;
  }

  if (p.nextZ != null) {
    p.nextZ!.prevZ = p.prevZ;
  }
}

// return a percentage difference between the polygon area and its triangulation area;
// used to verify correctness of triangulation
// ignore: unused_element
double _earcutDeviation(List<num> data, List<int>? holeIndices, int dim, List<int> triangles) {
  final hasHoles = holeIndices != null && holeIndices.isNotEmpty;
  final outerLen = hasHoles ? holeIndices[0] * dim : data.length;

  var polygonArea = _earcutSignedArea(data, 0, outerLen, dim).abs();

  if (hasHoles) {
    for (var i = 0, len = holeIndices.length; i < len; i++) {
      final start = holeIndices[i] * dim;
      final end = i < len - 1 ? holeIndices[i + 1] * dim : data.length;
      polygonArea -= _earcutSignedArea(data, start, end, dim).abs();
    }
  }

  var trianglesArea = 0.0;

  for (var i = 0; i < triangles.length; i += 3) {
    final a = triangles[i] * dim;
    final b = triangles[i + 1] * dim;
    final c = triangles[i + 2] * dim;
    trianglesArea +=
        ((data[a] - data[c]) * (data[b + 1] - data[a + 1]) - (data[a] - data[b]) * (data[c + 1] - data[a + 1])).abs();
  }

  return polygonArea == 0 && trianglesArea == 0 ? 0 : ((trianglesArea - polygonArea) / polygonArea).abs();
}

double _earcutSignedArea(List<num> data, int start, int end, int dim) {
  var sum = 0.0;

  for (var i = start, j = end - dim; i < end; i += dim) {
    sum += (data[j] - data[i]) * (data[i + 1] + data[j + 1]);
    j = i;
  }

  return sum;
}

// turn a polygon in a multi-dimensional array form (e.g. as in GeoJSON) into a form Earcut accepts
// ignore: unused_element
({List<num> vertices, List<int> holes, int dimensions}) _earcutFlatten(List<List<List<num>>> data) {
  final vertices = <num>[];
  final holes = <int>[];
  final dimensions = data[0][0].length;
  var holeIndex = 0;
  var prevLen = 0;

  for (final ring in data) {
    for (final p in ring) {
      for (var d = 0; d < dimensions; d++) {
        vertices.add(p[d]);
      }
    }

    if (prevLen != 0) {
      holeIndex += prevLen;
      holes.add(holeIndex);
    }

    prevLen = ring.length;
  }

  return (vertices: vertices, holes: holes, dimensions: dimensions);
}
