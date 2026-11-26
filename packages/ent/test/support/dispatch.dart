// Calls the library by name, as the reference fixtures and scenarios name methods and properties: through the tables
// tool/generate.dart writes into library.g.dart. A member is looked up on the value's class and then on its
// superclasses, as a call on the value would find it. A missing member throws NoSuchMethodError, and arguments of the
// wrong count or type throw as Function.apply does, so a renamed method fails like a wrong result.

import 'library.g.dart';

/// The name of [value]'s class, without type arguments.
String className(Object value) => value.runtimeType.toString().split('<').first;

/// [value]'s class and its superclasses, nearest first.
Iterable<String> classChain(Object value) sync* {
  for (String? name = className(value); name != null; name = superclasses[name]) {
    yield name;
  }
}

/// Calls the instance method [name] of [self] with the positional [args].
Object? invoke(Object self, String name, List<Object?> args) {
  for (final type in classChain(self)) {
    if (methods[type]?[name] case final method?) {
      return Function.apply(method(self), args);
    }
  }

  throw NoSuchMethodError.withInvocation(self, Invocation.method(Symbol(name), args));
}

/// Calls the static method [name] of the class [type] with the positional [args].
Object? invokeStatic(String type, String name, List<Object?> args) {
  if (statics[type]?[name] case final method?) {
    return Function.apply(method, args);
  }

  throw NoSuchMethodError.withInvocation(type, Invocation.method(Symbol(name), args));
}

/// Sets the property [name] of [self] to [value].
void setField(Object self, String name, Object? value) {
  for (final type in classChain(self)) {
    if (setters[type]?[name] case final setter?) {
      return setter(self, value);
    }
  }

  throw NoSuchMethodError.withInvocation(self, Invocation.setter(Symbol(name), value));
}
