// A turning cube drawn by OpenGlRenderer (OpenGL ES on ANGLE) in an EntView.
import 'package:ent/ent.dart' as ent;
import 'package:ent_opengl/ent_opengl.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(Example(await OpenGlRenderer.create(antialias: true)));
}

class Example extends StatelessWidget {
  Example(this.renderer, {super.key}) {
    scene.add(cube);
  }

  final OpenGlRenderer renderer;

  final scene = ent.Scene()..background = ent.Color(0x203040);

  final camera = ent.PerspectiveCamera(50, 1, 0.1, 100)..position.z = 3;

  final cube = ent.Mesh(ent.BoxGeometry(1, 1, 1), ent.MeshNormalMaterial());

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: EntView(
        renderer: renderer,
        scene: scene,
        camera: camera,
        onFrame: (elapsed) => cube.rotation.set(elapsed.inMilliseconds / 1000, elapsed.inMilliseconds / 1500, 0),
      ),
    );
  }
}
