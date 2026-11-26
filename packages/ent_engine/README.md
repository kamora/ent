# ent_engine

The game layer of Ent Engine, in pure Dart: a game loop with pause and time scale, and timers and per-frame updates
owned by scene objects. It sits above [`ent`][ent] and below a renderer: it imports no Flutter, and either renderer
package ([`ent_flutter`][ent_flutter], [`ent_opengl`][ent_opengl]) shows the scene it drives.

Not published yet: this is its first part. Tweens and an input map come next.

## A game loop

```dart
import 'package:ent_engine/ent_engine.dart';
import 'package:ent_flutter/ent_flutter.dart';

final scene = Scene();
final game = Game(scene);

// The door opens 2 seconds into the game, and turns every frame after that, while it is in the scene.
final door = Mesh(BoxGeometry(1, 2, 0.1), MeshStandardMaterial());
scene.add(door);
game.after(2, () => game.everyFrame((delta) => door.rotation.y += delta, owner: door), owner: door);

// In the widget tree, EntView drives the game:
EntView(renderer: renderer, scene: scene, camera: camera, onFrame: game.frame);
```

- `Game.update(delta)` advances game time by `delta` real seconds times `timeScale`; nothing moves while `paused`.
  `Game.frame(elapsed)` does the same from a running total, as `EntView`'s `onFrame` passes it.
- `after`, `every` and `everyFrame` schedule `Task`s in game time. A task with an `owner` runs while that object is in
  the scene and ends the first frame it is not, so removing an object ends what it scheduled. `Task.cancel` and
  `Game.cancelAll(owner)` end tasks early.
- `Game.mixers` are advanced by game time each frame, so animations pause and slow down with the game.

[ent]: https://pub.dev/packages/ent
[ent_flutter]: https://pub.dev/packages/ent_flutter
[ent_opengl]: https://pub.dev/packages/ent_opengl
