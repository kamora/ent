// The GL backend's tests (packages/ent_opengl/test/backend_test.dart) on a device: the system's OpenGL ES on Android,
// ANGLE on macOS.
import 'package:integration_test/integration_test.dart';

import '../../../packages/ent_opengl/test/backend_test.dart' as backend;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  backend.main();
}
