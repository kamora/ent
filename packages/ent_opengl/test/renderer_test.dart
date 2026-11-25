// OpenGlRenderer's own behaviour, beyond the parity scenes. ANGLE is bundled for macOS only.
@TestOn('mac-os')
library;

import 'package:ent_opengl/ent_opengl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The renderer loads the shader bundle through rootBundle, as an app does.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the shared core\'s warnings name this renderer', () async {
    final messages = <String>[];
    setConsoleFunction((type, message, params) => messages.add(message));
    addTearDown(() => setConsoleFunction(null));

    final scene = Scene()..add(Mesh(PlaneGeometry(2, 2), MeshLambertMaterial({'color': 0xffffff})));

    for (var i = 0; i < 9; i++) {
      scene.add(PointLight(0xffffff, 0.15, 0, 0)..position.set(0, 0, 1));
    }

    (await OpenGlRenderer.create())
      ..setSize(8, 8)
      ..draw(scene, OrthographicCamera(-1, 1, 1, -1, 0.1, 10)..position.set(0, 0, 5));

    expect(messages, contains(startsWith('ENT.OpenGlRenderer: more than 8 PointLights')));
  });
}
