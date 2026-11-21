package fried.editor;

#if fried_editor
import fried.Layer;
import fried.scene.Scene;

// Draws a scene without running it, so editing never triggers game logic.
class EditorSceneLayer extends Layer {
	public var scene:Scene;

	// The editor shows a scene either as a flat one or as a 3D one, and each leaves out what the other draws.
	public var is3D:Bool = false;

	public function new(name:String = "Editor scene") {
		super(name);
	}

	override function draw():Void {
		if (scene == null) {
			return;
		}
		scene.isFlatHidden = is3D;
		scene.isMeshesHidden = !is3D;
		scene.draw(renderer);
		scene.isFlatHidden = false;
		scene.isMeshesHidden = false;
	}
}
#end
