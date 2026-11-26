# ent_engine

The game layer of Ent Engine, in pure Dart: a game loop with pause and time scale, timers and per-frame updates
owned by scene objects, and tweens. It sits above [`ent`][ent] and below a renderer: it imports no Flutter, and either renderer
package ([`ent_flutter`][ent_flutter], [`ent_opengl`][ent_opengl]) shows the scene it drives.

Not published yet. An input map comes next.

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

## Tweens

```dart
await game.move(door, Vector3(0, 0, 2), 1.5, delay: 0.5, easing: Ease.inOutCubic).done;
game.face(guard, player.position, 0.5);
game.fade(glass, 0, 2);
game.tween(0, 5, 2, (value) => lamp.intensity = value);
```

`move`, `turn`, `face`, `resize` (scale), `fade` (a material's opacity) and `tween` (any number) change a value over
game time, after an optional `delay`, along an `Ease` curve or your own. Each reads its start value when it starts and
returns its `Task`: `done` completes `true` on arrival and `false` if it was cancelled or its object left the scene. A
new tween of the same kind on the same target replaces the running one (`turn` and `face` are one kind).

[ent]: https://pub.dev/packages/ent
[ent_flutter]: https://pub.dev/packages/ent_flutter
[ent_opengl]: https://pub.dev/packages/ent_opengl
