package fried;

import fried.scene.Scene;
import fried.scene.SceneContext;

// What a game adds to the engine's own startup. Every method is optional.
class Game {
	public function new() {}

	// The window and the renderer exist and the nodes and scenes are registered, and no scene is loaded yet.
	public function start():Void {}

	// A scene file has been loaded and is on screen, and none of its nodes has updated yet. The place to add what code gives a scene and the file cannot hold, such as a node made in code or an input handler. The context is the one that owns the scene and unloads it.
	public function sceneLoaded(context:SceneContext, scene:Scene):Void {}

	// Once a frame, before the scenes update. The delta is the seconds the frame took.
	public function update(delta:Float):Void {}

	// After the loop ends, while the renderer still exists.
	public function shutdown():Void {}
}
