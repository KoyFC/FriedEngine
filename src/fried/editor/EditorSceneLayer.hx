package fried.editor;

#if fried_editor
import fried.Layer;
import fried.scene.Scene;

// Draws a scene without running it, so editing never triggers game logic.
class EditorSceneLayer extends Layer {
	public var scene:Scene;

	public function new(name:String = "Editor scene") {
		super(name);
	}

	override function draw():Void {
		if (scene != null) {
			scene.draw(renderer);
		}
	}
}
#end
