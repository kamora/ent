part of '../../ent.dart';

/// The DOM operations [HTMLTexture] performs on an element's parent (the HTML-in-canvas `requestPaint` /
/// `onpaint` API), supplied by a platform package (E-PLATFORM).
abstract class HTMLTexturePlatform {
  /// `element.parentNode`, or `null`.
  Object? parentNode(Object element);

  /// `'requestPaint' in parent`.
  bool hasRequestPaint(Object parent);

  /// `'onpaint' in parent`.
  bool hasOnPaint(Object parent);

  /// `parent.onpaint = callback` (`null` clears it).
  void setOnPaint(Object parent, void Function()? callback);

  /// `parent.requestPaint()`.
  void requestPaint(Object parent);
}

/// Creates a texture from an HTML element.
///
/// This is almost the same as the base texture class, except that it sets [needsUpdate] to `true`
/// immediately and listens for the parent canvas's paint events to trigger updates.
class HTMLTexture extends Texture {
  /// Constructs a new texture from a platform [element]; when it is left out, the texture uses
  /// [Texture.DEFAULT_IMAGE]. The other parameters default as in [Texture].
  ///
  /// When a [platform] is installed and the element's parent supports `requestPaint`, the texture registers
  /// an `onpaint` handler that sets [needsUpdate], and requests a paint.
  HTMLTexture([
    Object? element = _textureUndefined,
    int? mapping,
    int? wrapS,
    int? wrapT,
    int? magFilter,
    int? minFilter,
    int? format,
    int? type,
    double? anisotropy,
  ]) : super(
         element,
         mapping,
         wrapS ?? ClampToEdgeWrapping,
         wrapT ?? ClampToEdgeWrapping,
         magFilter ?? LinearFilter,
         minFilter ?? LinearMipmapLinearFilter,
         format ?? RGBAFormat,
         type ?? UnsignedByteType,
         anisotropy,
       ) {
    generateMipmaps = false;

    needsUpdate = true;

    final parent = _htmlTextureParent(identical(element, _textureUndefined) ? null : element);

    if (parent != null && platform!.hasRequestPaint(parent)) {
      platform!.setOnPaint(parent, () {
        needsUpdate = true;
      });

      platform!.requestPaint(parent);
    }
  }

  /// The DOM operations; `null` until a platform package installs them. Without them an element has no
  /// parent here, so no paint handler is registered.
  static HTMLTexturePlatform? platform;

  /// This flag can be used for type testing.
  bool get isHTMLTexture => true;

  /// Returns a new HTML texture with copied values from this instance (E-CLONE).
  @override
  HTMLTexture clone() {
    return HTMLTexture()..copy(this);
  }

  /// Removes the paint handler from the element's parent, then frees the GPU-related resources.
  @override
  void dispose() {
    final parent = _htmlTextureParent(image);

    if (parent != null && platform!.hasOnPaint(parent)) {
      platform!.setOnPaint(parent, null);
    }

    super.dispose();
  }

  @override
  Object? _getValue(String key) {
    return switch (key) {
      'isHTMLTexture' => isHTMLTexture,
      _ => super._getValue(key),
    };
  }
}

/// `element ? element.parentNode : null`.
Object? _htmlTextureParent(Object? element) {
  final platform = HTMLTexture.platform;

  if (element == null || platform == null) {
    return null;
  }

  return platform.parentNode(element);
}
