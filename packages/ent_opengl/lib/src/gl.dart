/// The EGL and OpenGL ES 3 functions the renderer calls, looked up at run time: in ANGLE's library (the `wrangle`
/// package) on macOS, where EGL is exported as `EGL_GetDisplay` for `eglGetDisplay`, and in the system's libEGL and
/// libGLESv3 on Android.
library;

import 'dart:ffi';
import 'dart:io';

import 'package:wrangle/wrangle.dart';
import 'package:ffi/ffi.dart';

final DynamicLibrary _egl = Platform.isAndroid ? DynamicLibrary.open('libEGL.so') : angle;

final DynamicLibrary _gles = Platform.isAndroid ? DynamicLibrary.open('libGLESv3.so') : angle;

// EGL's [name] (`GetDisplay`) as the library exports it.
String _e(String name) => Platform.isAndroid ? 'egl$name' : 'EGL_$name';

// EGL.
const int eglNone = 0x3038;
const int eglRenderableType = 0x3040;
const int eglOpenglEs3Bit = 0x40;
const int eglSurfaceType = 0x3033;
const int eglPbufferBit = 0x1;
const int eglWindowBit = 0x4;
const int eglWidth = 0x3057;
const int eglHeight = 0x3056;
const int eglContextClientVersion = 0x3098;

// OpenGL ES 3.
const int glNoError = 0;
const int glRendererName = 0x1F01;
const int glTexture2D = 0x0DE1;
const int glTextureCubeMapPositiveX = 0x8515;
const int glTextureCubeMap = 0x8513;
const int glTextureMinFilter = 0x2801;
const int glTextureMagFilter = 0x2800;
const int glNearest = 0x2600;
const int glFramebuffer = 0x8D40;
const int glReadFramebuffer = 0x8CA8;
const int glFramebufferComplete = 0x8CD5;
const int glColorAttachment0 = 0x8CE0;
const int glDepthStencilAttachment = 0x821A;
const int glColorBufferBit = 0x4000;
const int glDepthBufferBit = 0x100;
const int glStencilBufferBit = 0x400;
const int glScissorTest = 0x0C11;
const int glPackAlignment = 0x0D05;
const int glUnpackAlignment = 0x0CF5;
const int glArrayBuffer = 0x8892;
const int glDynamicDraw = 0x88E8;
const int glUniformBufferOffsetAlignment = 0x8A34;
const int glRgba = 0x1908;
const int glRg = 0x8227;
const int glRed = 0x1903;
const int glDepthStencil = 0x84F9;
const int glStencilIndex = 0x1901;
const int glUnsignedByte = 0x1401;
const int glHalfFloat = 0x140B;
const int glFloat = 0x1406;
const int glUnsignedInt248 = 0x84FA;
const int glFloat32UnsignedInt248Rev = 0x8DAD;
const int glRgba8 = 0x8058;
const int glSrgb8Alpha8 = 0x8C43;
const int glRgba16f = 0x881A;
const int glRgba32f = 0x8814;
const int glR32f = 0x822E;
const int glR8 = 0x8229;
const int glRg8 = 0x822B;
const int glDepth24Stencil8 = 0x88F0;
const int glDepth32fStencil8 = 0x8CAD;
const int glStencilIndex8 = 0x8D48;

typedef _Ptr = Pointer<Void>;

final eglGetDisplay = _egl.lookupFunction<_Ptr Function(_Ptr), _Ptr Function(_Ptr)>(_e('GetDisplay'));
final eglInitialize = _egl
    .lookupFunction<
      Uint32 Function(_Ptr, Pointer<Int32>, Pointer<Int32>),
      int Function(_Ptr, Pointer<Int32>, Pointer<Int32>)
    >(_e('Initialize'));
final eglChooseConfig = _egl
    .lookupFunction<
      Uint32 Function(_Ptr, Pointer<Int32>, Pointer<_Ptr>, Int32, Pointer<Int32>),
      int Function(_Ptr, Pointer<Int32>, Pointer<_Ptr>, int, Pointer<Int32>)
    >(_e('ChooseConfig'));
final eglCreateContext = _egl
    .lookupFunction<_Ptr Function(_Ptr, _Ptr, _Ptr, Pointer<Int32>), _Ptr Function(_Ptr, _Ptr, _Ptr, Pointer<Int32>)>(
      _e('CreateContext'),
    );
final eglCreatePbufferSurface = _egl
    .lookupFunction<_Ptr Function(_Ptr, _Ptr, Pointer<Int32>), _Ptr Function(_Ptr, _Ptr, Pointer<Int32>)>(
      _e('CreatePbufferSurface'),
    );
final eglMakeCurrent = _egl
    .lookupFunction<Uint32 Function(_Ptr, _Ptr, _Ptr, _Ptr), int Function(_Ptr, _Ptr, _Ptr, _Ptr)>(_e('MakeCurrent'));
final eglGetError = _egl.lookupFunction<Int32 Function(), int Function()>(_e('GetError'));

final glGetError = _gles.lookupFunction<Uint32 Function(), int Function()>('glGetError');
final glGetIntegerv = _gles.lookupFunction<Void Function(Uint32, Pointer<Int32>), void Function(int, Pointer<Int32>)>(
  'glGetIntegerv',
);
final glGenTextures = _gles.lookupFunction<Void Function(Int32, Pointer<Uint32>), void Function(int, Pointer<Uint32>)>(
  'glGenTextures',
);
final glDeleteTextures = _gles
    .lookupFunction<Void Function(Int32, Pointer<Uint32>), void Function(int, Pointer<Uint32>)>('glDeleteTextures');
final glBindTexture = _gles.lookupFunction<Void Function(Uint32, Uint32), void Function(int, int)>('glBindTexture');
final glTexParameteri = _gles.lookupFunction<Void Function(Uint32, Uint32, Int32), void Function(int, int, int)>(
  'glTexParameteri',
);
final glTexStorage2D = _gles
    .lookupFunction<Void Function(Uint32, Int32, Uint32, Int32, Int32), void Function(int, int, int, int, int)>(
      'glTexStorage2D',
    );
final glTexSubImage2D = _gles
    .lookupFunction<
      Void Function(Uint32, Int32, Int32, Int32, Int32, Int32, Uint32, Uint32, _Ptr),
      void Function(int, int, int, int, int, int, int, int, _Ptr)
    >('glTexSubImage2D');
final glPixelStorei = _gles.lookupFunction<Void Function(Uint32, Int32), void Function(int, int)>('glPixelStorei');
final glGenFramebuffers = _gles
    .lookupFunction<Void Function(Int32, Pointer<Uint32>), void Function(int, Pointer<Uint32>)>('glGenFramebuffers');
final glDeleteFramebuffers = _gles
    .lookupFunction<Void Function(Int32, Pointer<Uint32>), void Function(int, Pointer<Uint32>)>('glDeleteFramebuffers');
final glBindFramebuffer = _gles.lookupFunction<Void Function(Uint32, Uint32), void Function(int, int)>(
  'glBindFramebuffer',
);
final glFramebufferTexture2D = _gles
    .lookupFunction<Void Function(Uint32, Uint32, Uint32, Uint32, Int32), void Function(int, int, int, int, int)>(
      'glFramebufferTexture2D',
    );
final glCheckFramebufferStatus = _gles.lookupFunction<Uint32 Function(Uint32), int Function(int)>(
  'glCheckFramebufferStatus',
);
final glViewport = _gles.lookupFunction<Void Function(Int32, Int32, Int32, Int32), void Function(int, int, int, int)>(
  'glViewport',
);
final glDisable = _gles.lookupFunction<Void Function(Uint32), void Function(int)>('glDisable');
final glColorMask = _gles.lookupFunction<Void Function(Uint8, Uint8, Uint8, Uint8), void Function(int, int, int, int)>(
  'glColorMask',
);
final glDepthMask = _gles.lookupFunction<Void Function(Uint8), void Function(int)>('glDepthMask');
final glStencilMask = _gles.lookupFunction<Void Function(Uint32), void Function(int)>('glStencilMask');
final glClearColor = _gles
    .lookupFunction<Void Function(Float, Float, Float, Float), void Function(double, double, double, double)>(
      'glClearColor',
    );
final glClearDepthf = _gles.lookupFunction<Void Function(Float), void Function(double)>('glClearDepthf');
final glClearStencil = _gles.lookupFunction<Void Function(Int32), void Function(int)>('glClearStencil');
final glClear = _gles.lookupFunction<Void Function(Uint32), void Function(int)>('glClear');
final glReadPixels = _gles
    .lookupFunction<
      Void Function(Int32, Int32, Int32, Int32, Uint32, Uint32, _Ptr),
      void Function(int, int, int, int, int, int, _Ptr)
    >('glReadPixels');
final glGenBuffers = _gles.lookupFunction<Void Function(Int32, Pointer<Uint32>), void Function(int, Pointer<Uint32>)>(
  'glGenBuffers',
);
final glDeleteBuffers = _gles
    .lookupFunction<Void Function(Int32, Pointer<Uint32>), void Function(int, Pointer<Uint32>)>('glDeleteBuffers');
final glBindBuffer = _gles.lookupFunction<Void Function(Uint32, Uint32), void Function(int, int)>('glBindBuffer');
final glBufferData = _gles
    .lookupFunction<Void Function(Uint32, IntPtr, _Ptr, Uint32), void Function(int, int, _Ptr, int)>('glBufferData');
final glBufferSubData = _gles
    .lookupFunction<Void Function(Uint32, IntPtr, IntPtr, _Ptr), void Function(int, int, int, _Ptr)>('glBufferSubData');
final glFlush = _gles.lookupFunction<Void Function(), void Function()>('glFlush');
final glFinish = _gles.lookupFunction<Void Function(), void Function()>('glFinish');
final glGetString = _gles.lookupFunction<Pointer<Utf8> Function(Uint32), Pointer<Utf8> Function(int)>('glGetString');

// Programs, state and draws.
const int glVertexShader = 0x8B31;
const int glFragmentShader = 0x8B30;
const int glCompileStatus = 0x8B81;
const int glLinkStatus = 0x8B82;
const int glInfoLogLength = 0x8B84;
const int glInvalidIndex = 0xFFFFFFFF;
const int glUniformBuffer = 0x8A11;
const int glElementArrayBuffer = 0x8893;
const int glUniformOffset = 0x8A3B;
const int glInt = 0x1404;
const int glUnsignedInt = 0x1405;
const int glUnsignedShort = 0x1403;
const int glTriangles = 0x0004;
const int glTriangleStrip = 0x0005;
const int glLines = 0x0001;
const int glLineStrip = 0x0003;
const int glPoints = 0x0000;
const int glBlend = 0x0BE2;
const int glDepthTest = 0x0B71;
const int glCullFace = 0x0B44;
const int glFront = 0x0404;
const int glBack = 0x0405;
const int glCw = 0x0900;
const int glCcw = 0x0901;
const int glTexture0 = 0x84C0;
const int glTextureWrapS = 0x2802;
const int glTextureWrapT = 0x2803;
const int glLinear = 0x2601;
const int glNearestMipmapNearest = 0x2700;
const int glLinearMipmapNearest = 0x2701;
const int glNearestMipmapLinear = 0x2702;
const int glLinearMipmapLinear = 0x2703;
const int glClampToEdge = 0x812F;
const int glRepeat = 0x2901;
const int glMirroredRepeat = 0x8370;

// EXT_texture_filter_anisotropic.
const int glTextureMaxAnisotropy = 0x84FE;
const int glMaxTextureMaxAnisotropy = 0x84FF;
const int glExtensions = 0x1F03;

final glCreateShader = _gles.lookupFunction<Uint32 Function(Uint32), int Function(int)>('glCreateShader');
final glShaderSource = _gles
    .lookupFunction<
      Void Function(Uint32, Int32, Pointer<Pointer<Utf8>>, Pointer<Int32>),
      void Function(int, int, Pointer<Pointer<Utf8>>, Pointer<Int32>)
    >('glShaderSource');
final glCompileShader = _gles.lookupFunction<Void Function(Uint32), void Function(int)>('glCompileShader');
final glGetShaderiv = _gles
    .lookupFunction<Void Function(Uint32, Uint32, Pointer<Int32>), void Function(int, int, Pointer<Int32>)>(
      'glGetShaderiv',
    );
final glGetShaderInfoLog = _gles
    .lookupFunction<
      Void Function(Uint32, Int32, Pointer<Int32>, Pointer<Utf8>),
      void Function(int, int, Pointer<Int32>, Pointer<Utf8>)
    >('glGetShaderInfoLog');
final glCreateProgram = _gles.lookupFunction<Uint32 Function(), int Function()>('glCreateProgram');
final glAttachShader = _gles.lookupFunction<Void Function(Uint32, Uint32), void Function(int, int)>('glAttachShader');
final glLinkProgram = _gles.lookupFunction<Void Function(Uint32), void Function(int)>('glLinkProgram');
final glGetProgramiv = _gles
    .lookupFunction<Void Function(Uint32, Uint32, Pointer<Int32>), void Function(int, int, Pointer<Int32>)>(
      'glGetProgramiv',
    );
final glGetProgramInfoLog = _gles
    .lookupFunction<
      Void Function(Uint32, Int32, Pointer<Int32>, Pointer<Utf8>),
      void Function(int, int, Pointer<Int32>, Pointer<Utf8>)
    >('glGetProgramInfoLog');
final glUseProgram = _gles.lookupFunction<Void Function(Uint32), void Function(int)>('glUseProgram');
final glGetUniformBlockIndex = _gles
    .lookupFunction<Uint32 Function(Uint32, Pointer<Utf8>), int Function(int, Pointer<Utf8>)>('glGetUniformBlockIndex');
final glUniformBlockBinding = _gles.lookupFunction<Void Function(Uint32, Uint32, Uint32), void Function(int, int, int)>(
  'glUniformBlockBinding',
);
final glGetUniformLocation = _gles
    .lookupFunction<Int32 Function(Uint32, Pointer<Utf8>), int Function(int, Pointer<Utf8>)>('glGetUniformLocation');
final glGetUniformIndices = _gles
    .lookupFunction<
      Void Function(Uint32, Int32, Pointer<Pointer<Utf8>>, Pointer<Uint32>),
      void Function(int, int, Pointer<Pointer<Utf8>>, Pointer<Uint32>)
    >('glGetUniformIndices');
final glGetActiveUniformsiv = _gles
    .lookupFunction<
      Void Function(Uint32, Int32, Pointer<Uint32>, Uint32, Pointer<Int32>),
      void Function(int, int, Pointer<Uint32>, int, Pointer<Int32>)
    >('glGetActiveUniformsiv');
final glUniform1i = _gles.lookupFunction<Void Function(Int32, Int32), void Function(int, int)>('glUniform1i');
final glUniform1f = _gles.lookupFunction<Void Function(Int32, Float), void Function(int, double)>('glUniform1f');
final glBindBufferRange = _gles
    .lookupFunction<Void Function(Uint32, Uint32, Uint32, IntPtr, IntPtr), void Function(int, int, int, int, int)>(
      'glBindBufferRange',
    );
final glGenVertexArrays = _gles
    .lookupFunction<Void Function(Int32, Pointer<Uint32>), void Function(int, Pointer<Uint32>)>('glGenVertexArrays');
final glBindVertexArray = _gles.lookupFunction<Void Function(Uint32), void Function(int)>('glBindVertexArray');
final glEnableVertexAttribArray = _gles.lookupFunction<Void Function(Uint32), void Function(int)>(
  'glEnableVertexAttribArray',
);
final glDisableVertexAttribArray = _gles.lookupFunction<Void Function(Uint32), void Function(int)>(
  'glDisableVertexAttribArray',
);
final glVertexAttribPointer = _gles
    .lookupFunction<
      Void Function(Uint32, Int32, Uint32, Uint8, Int32, Pointer<Void>),
      void Function(int, int, int, int, int, Pointer<Void>)
    >('glVertexAttribPointer');
final glVertexAttribIPointer = _gles
    .lookupFunction<
      Void Function(Uint32, Int32, Uint32, Int32, Pointer<Void>),
      void Function(int, int, int, int, Pointer<Void>)
    >('glVertexAttribIPointer');
final glVertexAttribDivisor = _gles.lookupFunction<Void Function(Uint32, Uint32), void Function(int, int)>(
  'glVertexAttribDivisor',
);
final glDrawArraysInstanced = _gles
    .lookupFunction<Void Function(Uint32, Int32, Int32, Int32), void Function(int, int, int, int)>(
      'glDrawArraysInstanced',
    );
final glDrawElementsInstanced = _gles
    .lookupFunction<
      Void Function(Uint32, Int32, Uint32, Pointer<Void>, Int32),
      void Function(int, int, int, Pointer<Void>, int)
    >('glDrawElementsInstanced');
final glEnable = _gles.lookupFunction<Void Function(Uint32), void Function(int)>('glEnable');
final glBlendEquationSeparate = _gles.lookupFunction<Void Function(Uint32, Uint32), void Function(int, int)>(
  'glBlendEquationSeparate',
);
final glBlendFuncSeparate = _gles
    .lookupFunction<Void Function(Uint32, Uint32, Uint32, Uint32), void Function(int, int, int, int)>(
      'glBlendFuncSeparate',
    );
final glDepthFunc = _gles.lookupFunction<Void Function(Uint32), void Function(int)>('glDepthFunc');
final glCullFaceMode = _gles.lookupFunction<Void Function(Uint32), void Function(int)>('glCullFace');
final glFrontFace = _gles.lookupFunction<Void Function(Uint32), void Function(int)>('glFrontFace');
final glScissor = _gles.lookupFunction<Void Function(Int32, Int32, Int32, Int32), void Function(int, int, int, int)>(
  'glScissor',
);
final glActiveTexture = _gles.lookupFunction<Void Function(Uint32), void Function(int)>('glActiveTexture');
final glGenSamplers = _gles.lookupFunction<Void Function(Int32, Pointer<Uint32>), void Function(int, Pointer<Uint32>)>(
  'glGenSamplers',
);
final glSamplerParameteri = _gles.lookupFunction<Void Function(Uint32, Uint32, Int32), void Function(int, int, int)>(
  'glSamplerParameteri',
);
final glSamplerParameterf = _gles.lookupFunction<Void Function(Uint32, Uint32, Float), void Function(int, int, double)>(
  'glSamplerParameterf',
);
final glGetFloatv = _gles.lookupFunction<Void Function(Uint32, Pointer<Float>), void Function(int, Pointer<Float>)>(
  'glGetFloatv',
);
final glBindSampler = _gles.lookupFunction<Void Function(Uint32, Uint32), void Function(int, int)>('glBindSampler');

// Multisampling.
const int glRenderbuffer = 0x8D41;
const int glDrawFramebuffer = 0x8CA9;

final glGenRenderbuffers = _gles
    .lookupFunction<Void Function(Int32, Pointer<Uint32>), void Function(int, Pointer<Uint32>)>('glGenRenderbuffers');
final glDeleteRenderbuffers = _gles
    .lookupFunction<Void Function(Int32, Pointer<Uint32>), void Function(int, Pointer<Uint32>)>(
      'glDeleteRenderbuffers',
    );
final glBindRenderbuffer = _gles.lookupFunction<Void Function(Uint32, Uint32), void Function(int, int)>(
  'glBindRenderbuffer',
);
final glRenderbufferStorageMultisample = _gles
    .lookupFunction<Void Function(Uint32, Int32, Uint32, Int32, Int32), void Function(int, int, int, int, int)>(
      'glRenderbufferStorageMultisample',
    );
final glFramebufferRenderbuffer = _gles
    .lookupFunction<Void Function(Uint32, Uint32, Uint32, Uint32), void Function(int, int, int, int)>(
      'glFramebufferRenderbuffer',
    );
final glBlitFramebuffer = _gles
    .lookupFunction<
      Void Function(Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Uint32, Uint32),
      void Function(int, int, int, int, int, int, int, int, int, int)
    >('glBlitFramebuffer');
final glReadBuffer = _gles.lookupFunction<Void Function(Uint32), void Function(int)>('glReadBuffer');

// IOSurfaces (EGL_ANGLE_iosurface_client_buffer).
const int eglIosurfaceAngle = 0x3454;
const int eglIosurfacePlaneAngle = 0x345A;
const int eglTextureTarget = 0x3081;
const int eglTextureFormat = 0x3080;
const int eglTextureRgba = 0x305E;
const int eglTextureInternalFormatAngle = 0x345D;
const int eglTextureTypeAngle = 0x345C;
const int eglBindToTextureTargetAngle = 0x348D;
const int glBgraExt = 0x80E1;

final eglCreatePbufferFromClientBuffer = _egl
    .lookupFunction<
      Pointer<Void> Function(Pointer<Void>, Uint32, Pointer<Void>, Pointer<Void>, Pointer<Int32>),
      Pointer<Void> Function(Pointer<Void>, int, Pointer<Void>, Pointer<Void>, Pointer<Int32>)
    >(_e('CreatePbufferFromClientBuffer'));
final eglGetConfigAttrib = _egl
    .lookupFunction<
      Uint32 Function(Pointer<Void>, Pointer<Void>, Int32, Pointer<Int32>),
      int Function(Pointer<Void>, Pointer<Void>, int, Pointer<Int32>)
    >(_e('GetConfigAttrib'));
final eglDestroySurface = _egl
    .lookupFunction<Uint32 Function(Pointer<Void>, Pointer<Void>), int Function(Pointer<Void>, Pointer<Void>)>(
      _e('DestroySurface'),
    );

// Window surfaces (Android).
final eglCreateWindowSurface = _egl
    .lookupFunction<
      Pointer<Void> Function(Pointer<Void>, Pointer<Void>, Pointer<Void>, Pointer<Int32>),
      Pointer<Void> Function(Pointer<Void>, Pointer<Void>, Pointer<Void>, Pointer<Int32>)
    >(_e('CreateWindowSurface'));
final eglSwapBuffers = _egl
    .lookupFunction<Uint32 Function(Pointer<Void>, Pointer<Void>), int Function(Pointer<Void>, Pointer<Void>)>(
      _e('SwapBuffers'),
    );
final eglSwapInterval = _egl.lookupFunction<Uint32 Function(Pointer<Void>, Int32), int Function(Pointer<Void>, int)>(
  _e('SwapInterval'),
);

// Mipmaps.
final glGenerateMipmap = _gles.lookupFunction<Void Function(Uint32), void Function(int)>('glGenerateMipmap');
