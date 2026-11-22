package fried.editor;

#if fried_editor
import fried.scene.Scene;
import fried.scene.SceneContext;

// What the editor's play mode watches of a game starting, running and ending, which a shipped game has no one to tell.
class BootObserver {
	public function new() {}

	// The window, the renderer, the scenes and the autoloads exist, and no scene is loaded yet.
	public function start():Void {}

	// A scene file has been loaded and is on screen, and none of its nodes has updated yet.
	public function sceneLoaded(context:SceneContext, scene:Scene):Void {}

	public function update(delta:Float):Void {}

	// After the loop ends, before anything is unloaded.
	public function shutdown():Void {}
}
#end
