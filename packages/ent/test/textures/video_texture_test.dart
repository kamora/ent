// The reference unit tests of VideoTexture, plus Dart tests of the source behaviour, of VideoFrameTexture and
// HTMLTexture (no reference tests), with fake platforms recording the DOM calls the reference makes (expected texture
// values printed from the reference source in Node).

import 'package:test/test.dart';
import 'package:ent/ent.dart';

import 'support.dart';

/// A video for the fake platform: whether it has `requestVideoFrameCallback`, and its `readyState`.
class _Video {
  _Video({this.frameCallback = false, this.currentData = false});

  final bool frameCallback;

  bool currentData;

  final Map<int, void Function()> callbacks = {};

  final List<int> cancelled = [];
}

class _FakeVideoPlatform implements VideoTexturePlatform {
  int _next = 0;

  @override
  bool hasVideoFrameCallback(Object video) => video is _Video && video.frameCallback;

  @override
  int requestVideoFrameCallback(Object video, void Function() callback) {
    final id = ++_next;
    (video as _Video).callbacks[id] = callback;
    return id;
  }

  @override
  void cancelVideoFrameCallback(Object video, int handle) {
    (video as _Video).cancelled.add(handle);
  }

  @override
  bool hasCurrentData(Object video) => video is _Video && video.currentData;
}

class _Parent {
  _Parent({this.paint = true});

  final bool paint;

  void Function()? onpaint;

  int requests = 0;
}

class _Element {
  _Element(this.parent);

  final _Parent? parent;
}

class _FakeHTMLPlatform implements HTMLTexturePlatform {
  @override
  Object? parentNode(Object element) => (element as _Element).parent;

  @override
  bool hasRequestPaint(Object parent) => (parent as _Parent).paint;

  @override
  bool hasOnPaint(Object parent) => (parent as _Parent).paint;

  @override
  void setOnPaint(Object parent, void Function()? callback) => (parent as _Parent).onpaint = callback;

  @override
  void requestPaint(Object parent) => (parent as _Parent).requests++;
}

void main() {
  group('Textures', () {
    group('VideoTexture', () {
      tearDown(() => VideoTexture.platform = null);

      // INHERITANCE
      test('Extending', () {
        final videoDocumentElement = Object();
        final Object object = VideoTexture(videoDocumentElement);
        expect(object is Texture, true, reason: 'VideoTexture extends from Texture');
      });

      // INSTANCING
      test('Instancing', () {
        final videoDocumentElement = Object();
        final object = VideoTexture(videoDocumentElement);
        expect(object, isNotNull, reason: 'Can instantiate a VideoTexture.');
      });

      // PUBLIC
      test('isVideoTexture', () {
        final videoDocumentElement = Object();
        final object = VideoTexture(videoDocumentElement);
        expect(object.isVideoTexture, isTrue, reason: 'VideoTexture.isVideoTexture should be true');
      });

      // Dart tests of the source behaviour

      test('defaults: magFilter minFilter generateMipmaps', () {
        expectTextureState(VideoTexture(Object()), stateWith({'minFilter': 1006, 'generateMipmaps': false}));
      });

      test('requestVideoFrameCallback loop', () {
        VideoTexture.platform = _FakeVideoPlatform();
        final video = _Video(frameCallback: true);
        final texture = VideoTexture(video);
        expect(video.callbacks.keys, [1]);
        expect(texture.version, 0);

        video.callbacks[1]!();
        expect(texture.version, 1, reason: 'a presented frame marks the texture for update');
        expect(video.callbacks.keys, [1, 2], reason: 'and schedules the next frame');

        texture.dispose();
        expect(video.cancelled, [2], reason: 'dispose cancels the pending callback');
        texture.dispose();
        expect(video.cancelled, [2], reason: 'only once');
      });

      test('update', () {
        VideoTexture.platform = _FakeVideoPlatform();
        final video = _Video();
        final texture = VideoTexture(video)..update();
        expect(texture.version, 0, reason: 'no current data yet');
        video.currentData = true;
        texture.update();
        expect(texture.version, 1);

        final withCallback = VideoTexture(_Video(frameCallback: true, currentData: true))..update();
        expect(withCallback.version, 0, reason: 'only relevant without requestVideoFrameCallback');
      });

      test('update without a platform', () {
        final texture = VideoTexture(Object())..update();
        expect(texture.version, 0);
      });

      test('clone', () {
        VideoTexture.platform = _FakeVideoPlatform();
        final video = _Video(frameCallback: true);
        final clone = VideoTexture(video).clone();
        expect(clone, isA<VideoTexture>());
        expect(clone.image, same(video));
        expect(video.callbacks.length, 2, reason: 'the clone registers its own frame callback');
      });
    });

    group('VideoFrameTexture', () {
      test('Extending', () {
        final Object object = VideoFrameTexture();
        expect(object is VideoTexture, true);
      });

      test('isVideoFrameTexture', () {
        expect(VideoFrameTexture().isVideoFrameTexture, isTrue);
      });

      test('defaults', () {
        expectTextureState(VideoFrameTexture(), stateWith({'minFilter': 1006, 'generateMipmaps': false}));
      });

      test('setFrame update', () {
        final frame = Object();
        final texture = VideoFrameTexture()..setFrame(frame);
        expect(texture.image, same(frame));
        expect(texture.version, 1);
        texture.update();
        expect(texture.version, 1, reason: 'update() is empty: frames come from setFrame()');
      });

      test('clone', () {
        expect(VideoFrameTexture().clone(), isA<VideoFrameTexture>());
      });
    });

    group('HTMLTexture', () {
      tearDown(() => HTMLTexture.platform = null);

      test('Extending', () {
        final Object object = HTMLTexture();
        expect(object is Texture, true);
      });

      test('isHTMLTexture', () {
        expect(HTMLTexture().isHTMLTexture, isTrue);
      });

      test('defaults: generateMipmaps needsUpdate', () {
        expectTextureState(HTMLTexture(), stateWith({'version': 1, 'generateMipmaps': false}));
      });

      test('onpaint requestPaint dispose', () {
        HTMLTexture.platform = _FakeHTMLPlatform();
        final parent = _Parent();
        final texture = HTMLTexture(_Element(parent));
        expect(parent.requests, 1);
        expect(texture.version, 1);

        parent.onpaint!();
        expect(texture.version, 2, reason: 'a paint marks the texture for update');

        texture.dispose();
        expect(parent.onpaint, isNull);
      });

      test('without requestPaint or a parent', () {
        HTMLTexture.platform = _FakeHTMLPlatform();
        final parent = _Parent(paint: false);
        HTMLTexture(_Element(parent));
        expect(parent.requests, 0);
        expect(parent.onpaint, isNull);
        HTMLTexture(_Element(null)).dispose();
      });

      test('clone', () {
        expect(HTMLTexture().clone(), isA<HTMLTexture>());
      });
    });
  });
}
