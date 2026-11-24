// The native window of an android.view.Surface, for EGL: only the NDK turns one into the other.

#include <android/native_window_jni.h>
#include <jni.h>

JNIEXPORT jlong JNICALL Java_vn_kamora_ent_1opengl_EntOpenGlPlugin_window(JNIEnv* env, jobject plugin, jobject surface) {
	return (jlong) ANativeWindow_fromSurface(env, surface);
}

JNIEXPORT void JNICALL Java_vn_kamora_ent_1opengl_EntOpenGlPlugin_release(JNIEnv* env, jobject plugin, jlong window) {
	ANativeWindow_release((ANativeWindow*) window);
}
