/// The game layer of Ent Engine: a [Game] loop that a frame tick drives, with pause and time scale; [Task]s (timers,
/// per-frame updates and tweens) owned by scene objects, which end when their object leaves the scene; and an [Input]
/// map of actions and axes.
library;

export 'src/game.dart';
export 'src/input.dart';
