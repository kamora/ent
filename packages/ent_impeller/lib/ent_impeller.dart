/// The shader toolchain of Ent Engine's renderers on Impeller's shader compiler: [compileShaders] for a renderer
/// package's build hook, [strip] to keep a target's backends, [readBundle] to read a bundle's shaders back, and
/// [findImpellerc] for tools that run the compiler themselves.
library;

export 'src/bundles.dart';
export 'src/compile.dart';
export 'src/impellerc.dart';
