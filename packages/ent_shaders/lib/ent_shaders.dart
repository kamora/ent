/// The shaders of Ent Engine, for every renderer: the variant scheme that turns the material setups an app registers
/// into shader sources. The GLSL is in the package's `shaders/` folder, and `ent.shaderbundle.json` lists the fixed
/// shaders; a renderer package's toolchain compiles both into its own form when the app is built.
library;

export 'src/variants.dart';
