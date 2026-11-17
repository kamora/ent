// One test per entry of docs/compatibility-exceptions.md: each pins the Dart behaviour that differs from the reference,
// so a change to it is a deliberate change to the exceptions log.

import 'dart:mirrors';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ent/ent.dart';

class _Point extends Vector3 {
  _Point([super.x, super.y, super.z]);
}

void main() {
  group('E-PRIVATE', () {
    test('underscore members exist but are private to the library', () {
      final library = reflectClass(Quaternion).owner as LibraryMirror;
      final symbol = MirrorSystem.getSymbol('_onChange', library);
      expect(reflectClass(Quaternion).declarations.containsKey(symbol), isTrue);
      expect(reflectClass(Quaternion).declarations.containsKey(#onChange), isFalse);
    });
  });

  group('E-NUM', () {
    test('integer literals are accepted where the reference takes a number', () {
      expect(Vector3(1, 2, 3).toArray(), [1.0, 2.0, 3.0]);
    });

    test('integer-valued results are int', () {
      expect(MathUtils.randInt(1, 1), isA<int>());
    });
  });

  group('E-UNDEFINED', () {
    test('an omitted optional argument keeps the current value, as with an undefined argument in the reference', () {
      expect(Vector3(1, 2, 3).set(4, 5).toArray(), [4.0, 5.0, 3.0]);
    });
  });

  group('E-ITER', () {
    test('`iterable` replaces Symbol.iterator', () {
      expect(Vector2(1, 2).iterable.toList(), [1.0, 2.0]);
      expect(Vector3(1, 2, 3).iterable.toList(), [1.0, 2.0, 3.0]);
      expect(Vector4(1, 2, 3, 4).iterable.toList(), [1.0, 2.0, 3.0, 4.0]);
      expect(Quaternion(1, 2, 3, 4).iterable.toList(), [1.0, 2.0, 3.0, 4.0]);
      expect(Euler(1, 2, 3, 'ZYX').iterable.toList(), [1.0, 2.0, 3.0, 'ZYX']);
    });
  });

  group('E-CLONE', () {
    test('clone() returns the declared class unless a subclass overrides it', () {
      final clone = _Point(1, 2, 3).clone();
      expect(clone.runtimeType, Vector3);
      expect(clone.toArray(), [1.0, 2.0, 3.0]);
    });
  });

  group('E-ARRAY', () {
    test('toArray pads a growable list with 0.0 where JS leaves holes', () {
      expect(Vector2(1, 2).toArray(<double>[], 2), [0.0, 0.0, 1.0, 2.0]);
    });

    test('toArray ignores writes past the end of a fixed-length list, like a typed array', () {
      expect(Vector3(1, 2, 3).toArray(Float32List(2)), [1.0, 2.0]);
    });

    test('fromArray past the end throws a RangeError where JS reads undefined', () {
      expect(() => Vector3().fromArray([1, 2]), throwsRangeError);
    });
  });

  group('E-ERROR', () {
    test('a reference Error is an EntError with the same message', () {
      expect(
        () => Vector3().getComponent(3),
        throwsA(isA<EntError>().having((e) => e.message, 'message', 'ENT.Vector3: index is out of range: 3')),
      );
    });
  });

  group('E-LOG', () {
    tearDown(() => setConsoleFunction(null));

    test('the console function receives type, prefixed message and a parameter list', () {
      final calls = <List<Object?>>[];
      setConsoleFunction((type, message, params) => calls.add([type, message, params]));
      warn('Test: message', [1, 'two']);
      expect(calls, [
        [
          'warn',
          'ENT.Test: message',
          [1, 'two'],
        ],
      ]);
    });
  });

  group('E-UNION', () {
    test('a Vector3|Vector4 parameter is typed Object and accepts both', () {
      expect(Vector4().copy(Vector3(1, 2, 3)).toArray(), [1.0, 2.0, 3.0, 1.0]);
      expect(Vector4().copy(Vector4(1, 2, 3, 4)).toArray(), [1.0, 2.0, 3.0, 4.0]);
      expect(Vector3().addScaledVector(Vector4(1, 2, 3, 4), 2).toArray(), [2.0, 4.0, 6.0]);
    });

    test('a Vector3|number parameter accepts both', () {
      final a = Matrix4().makeTranslation(Vector3(1, 2, 3));
      final b = Matrix4().makeTranslation(1, 2, 3);
      expect(a.equals(b), isTrue);
    });

    test('another type throws where JS would compute NaN', () {
      expect(() => Vector4().copy('x'), throwsA(isA<ArgumentError>()));
    });
  });

  group('E-STATIC', () {
    test('Triangle statics carry a Static suffix and agree with the instance methods', () {
      final a = Vector3(0, 0, 0), b = Vector3(1, 0, 0), c = Vector3(0, 1, 0);
      final normal = Triangle.getNormalStatic(a, b, c, Vector3());
      expect(normal.equals(Triangle(a, b, c).getNormal(Vector3())), isTrue);
      expect(normal.toArray(), [0.0, 0.0, 1.0]);
    });
  });

  group('E-OBJECT', () {
    test('toJSON returns a map with the reference keys', () {
      final json = Box3(Vector3(1, 2, 3), Vector3(4, 5, 6)).toJSON();
      expect(json['min'], [1.0, 2.0, 3.0]);
      expect(json['max'], [4.0, 5.0, 6.0]);
    });

    test('getHSL fills an HSL target', () {
      final hsl = Color(1, 0, 0).getHSL(HSL());
      expect([hsl.h, hsl.s, hsl.l], [0.0, 1.0, 0.5]);
    });
  });

  group('E-SINGLETON', () {
    tearDown(() => ColorManagement.enabled = true);

    test('ColorManagement members are static and mutable as in the reference', () {
      ColorManagement.enabled = false;
      expect(ColorManagement.enabled, isFalse);
      expect(ColorManagement.workingColorSpace, LinearSRGBColorSpace);
    });
  });

  group('E-CONSTOBJ', () {
    test('object-valued constants read as in the reference', () {
      expect(MOUSE.LEFT, 0);
    });
  });

  group('E-INTNAN', () {
    test('getHex with a NaN component throws instead of returning a number', () {
      expect(() => Color(double.nan, 0, 0).getHex(), throwsUnsupportedError);
    });
  });

  group('E-EVENT', () {
    test('events are Event objects with extra fields and a target set only during dispatch', () {
      final dispatcher = EventDispatcher();
      final event = Event('ping', {'value': 1});
      Object? seen;
      dispatcher.addEventListener('ping', (e) => seen = [e.target, e['value']]);
      dispatcher.dispatchEvent(event);
      expect(seen, [dispatcher, 1]);
      expect(event.target, isNull);
    });
  });

  group('E-PLATFORM', () {
    final original = performanceNow;
    tearDown(() => performanceNow = original);

    test('the time source is a replaceable function', () {
      var now = 1000.0;
      performanceNow = () => now;
      final timer = Timer();
      now = 1500;
      timer.update();
      expect(timer.getDelta(), 0.5);
    });

    test('without an image platform, a non-data image cannot be serialized', () {
      expect(ImageUtils.platform, isNull);
      expect(() => ImageUtils.getDataURL(Object()), throwsStateError);
    });
  });

  group('E-VARIADIC', () {
    test('add takes one object per call', () {
      final parent = Object3D()
        ..add(Object3D())
        ..add(Object3D());
      expect(parent.children.length, 2);
    });
  });

  group('E-PROPERTY', () {
    test('object[name] reads declared properties and null for unknown ones', () {
      final object = Object3D()..name = 'box';
      expect(object['name'], 'box');
      expect(object['unknown'], isNull);
      expect((Object3D()..add(object)).getObjectByProperty('name', 'box'), same(object));
    });
  });

  group('E-ATTRIBUTE', () {
    test('geometry attributes are typed BufferAttributeLike', () {
      final geometry = BufferGeometry()..setAttribute('position', Float32BufferAttribute([0, 0, 0], 3));
      expect(geometry.attributes, isA<Map<String, BufferAttributeLike>>());
      expect(GLBufferAttribute(Object(), 0, 3, 4, 1), isNot(isA<BufferAttributeLike>()));
    });
  });

  group('E-ARGS', () {
    test('a constructor given only some of its element arguments throws', () {
      expect(() => Matrix4(1), throwsA(isA<TypeError>()));
    });
  });
}
