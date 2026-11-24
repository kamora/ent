// Textures Flutter shows for the GL renderer on Android: each is a SurfaceProducer, whose Surface's native window
// becomes an EGL window surface on the Dart side.

package vn.kamora.ent_opengl

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

class EntOpenGlPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
	private lateinit var channel: MethodChannel

	private lateinit var registry: TextureRegistry

	// Each texture's producer and the native window of its surface.
	private val surfaces = mutableMapOf<Long, Pair<TextureRegistry.SurfaceProducer, Long>>()

	override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
		System.loadLibrary("ent_opengl")
		registry = binding.textureRegistry
		channel = MethodChannel(binding.binaryMessenger, "ent_opengl")
		channel.setMethodCallHandler(this)
	}

	override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
		channel.setMethodCallHandler(null)

		for ((producer, window) in surfaces.values) {
			release(window)
			producer.release()
		}

		surfaces.clear()
	}

	override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
		when (call.method) {
			"create" -> {
				val width = call.argument<Int>("width")!!
				val height = call.argument<Int>("height")!!
				val producer = registry.createSurfaceProducer()
				producer.setSize(width, height)
				val window = window(producer.surface)

				if (window == 0L) {
					producer.release()
					result.error("create", "ent_opengl: the surface has no native window", null)
					return
				}

				surfaces[producer.id()] = producer to window
				result.success(mapOf("texture" to producer.id(), "window" to window))
			}

			"frame" -> result.success(null)

			"dispose" -> {
				surfaces.remove((call.argument<Number>("texture")!!).toLong())?.let { (producer, window) ->
					release(window)
					producer.release()
				}

				result.success(null)
			}

			else -> result.notImplemented()
		}
	}

	// The native window of [surface], acquired; 0 when it has none (src/main/cpp/window.c).
	private external fun window(surface: android.view.Surface): Long

	// Releases a window [window] returned.
	private external fun release(window: Long)
}
