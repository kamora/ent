// Textures Flutter shows for the GL renderer: each is an IOSurface that ANGLE draws into (through
// EGL_ANGLE_iosurface_client_buffer) and Flutter reads as a CVPixelBuffer.

import Cocoa
import CoreVideo
import FlutterMacOS
import IOSurface

public class EntOpenGlPlugin: NSObject, FlutterPlugin {
	private let registry: FlutterTextureRegistry

	private var surfaces: [Int64: Surface] = [:]

	init(registry: FlutterTextureRegistry) {
		self.registry = registry
	}

	public static func register(with registrar: FlutterPluginRegistrar) {
		let channel = FlutterMethodChannel(name: "ent_opengl", binaryMessenger: registrar.messenger)
		registrar.addMethodCallDelegate(EntOpenGlPlugin(registry: registrar.textures), channel: channel)
	}

	public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
		let arguments = call.arguments as? [String: Any] ?? [:]

		switch call.method {
		case "create":
			guard let width = arguments["width"] as? Int, let height = arguments["height"] as? Int,
				let surface = Surface(width: width, height: height)
			else {
				result(FlutterError(code: "create", message: "ent_opengl: no IOSurface of that size", details: nil))
				return
			}

			let texture = registry.register(surface)
			surfaces[texture] = surface
			result([
				"texture": texture,
				"surface": Int(bitPattern: Unmanaged.passUnretained(surface.surface).toOpaque()),
			])
		case "frame":
			if let texture = arguments["texture"] as? Int64 {
				registry.textureFrameAvailable(texture)
			}

			result(nil)
		case "dispose":
			if let texture = arguments["texture"] as? Int64 {
				registry.unregisterTexture(texture)
				surfaces[texture] = nil
			}

			result(nil)
		default:
			result(FlutterMethodNotImplemented)
		}
	}
}

// An IOSurface of 8-bit BGRA pixels and the pixel buffer Flutter reads it through.
final class Surface: NSObject, FlutterTexture {
	let surface: IOSurfaceRef

	private let buffer: CVPixelBuffer

	init?(width: Int, height: Int) {
		let properties: [String: Any] = [
			kIOSurfaceWidth as String: width,
			kIOSurfaceHeight as String: height,
			kIOSurfacePixelFormat as String: kCVPixelFormatType_32BGRA,
			kIOSurfaceBytesPerElement as String: 4,
		]

		guard width > 0, height > 0, let surface = IOSurfaceCreate(properties as CFDictionary) else {
			return nil
		}

		var buffer: Unmanaged<CVPixelBuffer>?
		let attributes = [kCVPixelBufferMetalCompatibilityKey: true] as CFDictionary

		guard CVPixelBufferCreateWithIOSurface(nil, surface, attributes, &buffer) == kCVReturnSuccess,
			let buffer
		else {
			return nil
		}

		self.surface = surface
		self.buffer = buffer.takeRetainedValue()
	}

	func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
		Unmanaged.passRetained(buffer)
	}
}
