package fried;

// What a game adds to the engine's own startup. Every method is optional.
class Game {
	public function new() {}

	// The window and the renderer exist and the nodes and scenes are registered, and no scene is loaded yet.
	public function start():Void {}

	// Once a frame, before the scenes update. The delta is the seconds the frame took.
	public function update(delta:Float):Void {}

	// After the loop ends, while the renderer still exists.
	public function shutdown():Void {}
}
