package fried.editor;

#if fried_editor
import fried.Layer;
import fried.scene.Camera;
import fried.scene.Camera3D;
import fried.scene.Scene;

// Draws a scene without running it, so editing never triggers game logic.
class EditorSceneLayer extends Layer {
	public var scene:Scene;

	// The editor shows a scene either as a flat one or as a 3D one, and each leaves out what the other draws.
	public var is3D:Bool = false;

	// A preview shows the scene as the game would: through the cameras its file names, with both kinds of drawing.
	public var isPreview:Bool = false;
	public var previewCamera:Camera;
	public var previewCamera3D:Camera3D;

	public function new(name:String = "Editor scene") {
		super(name);
	}

	override function draw():Void {
		if (scene == null) {
			return;
		}
		if (isPreview) {
			var editorCamera = scene.camera;
			var editorCamera3D = scene.camera3D;
			scene.camera = previewCamera;
			scene.camera3D = previewCamera3D;
			scene.draw(renderer);
			scene.camera = editorCamera;
			scene.camera3D = editorCamera3D;
			return;
		}
		scene.isFlatHidden = is3D;
		scene.isMeshesHidden = !is3D;
		scene.isCanvasInWorld = true;
		scene.draw(renderer);
		scene.isFlatHidden = false;
		scene.isMeshesHidden = false;
		scene.isCanvasInWorld = false;
	}
}
#end
