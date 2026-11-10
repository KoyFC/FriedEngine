package fried;

// What a game adds to the engine's own startup. Every method is optional.
class Game {
	public function new() {}

	// The window and the renderer exist and the components and scenes are registered, and no scene is loaded yet.
	public function start():Void {}

	// Once a frame, before the scenes update.
	public function update():Void {}

	// After the loop ends, while the renderer still exists.
	public function shutdown():Void {}
}
