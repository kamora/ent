/// The OpenGL ES renderer of Ent Engine. [OpenGlRenderer] draws offscreen so far, on ANGLE (Metal) on macOS.
library;

export 'package:ent_renderer/ent_renderer.dart' show EntFrameCallback, EntPointerCallback, EntView;

export 'src/backend.dart' show GlContext, GlLibrary, GlShader, GlSurface, GlTexture, memberOffsets;
export 'src/renderer.dart';
