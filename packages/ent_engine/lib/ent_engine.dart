/// The game layer of Ent Engine: a [Game] loop that a frame tick drives, with pause and time scale, and [Task]s
/// (timers and per-frame updates) owned by scene objects, which end when their object leaves the scene.
library;

export 'src/game.dart';
