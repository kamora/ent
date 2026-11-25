## 0.1.0-dev.1

- First release: `OpenGlRenderer` on OpenGL ES 3, on ANGLE (from `wrangle`) on macOS and the system's OpenGL ES on
  Android, with `EntView` showing its frames through a platform texture. Its build hook compiles the shaders as
  GLSL ES 3.00 only; the app names its shader registry under `hooks: user_defines: ent_opengl: shaders:`.
