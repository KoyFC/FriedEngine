package fried.scene;

import fried.Log;
import fried.graphics.CameraView;

@:allow(fried.scene)
@:serializable
class Camera extends Node2D {
	public var zoom(default, set):Single;

	static inline var MIN_ZOOM:Single = 0.01;

	public function new(zoom:Single = 1.0) {
		super();
		name = "Camera";
		this.zoom = zoom;
	}

	// What the draw queue reads, written before the scene is drawn.
	@:noSerialize public var view(default, null):CameraView = new CameraView();

	// The scene that draws through this camera, which is how a camera that sits in no scene, the editor's own, still has a view to convert against.
	var viewScene:Null<Scene>;

	// Each conversion works from the view of the scene the camera belongs to, or else the scene it draws.
	public function worldToScreenX(worldPosition:Float):Float {
		return (worldPosition - worldX) * zoom + owner().viewWidth / 2;
	}

	public function worldToScreenY(worldPosition:Float):Float {
		return (worldPosition - worldY) * zoom + owner().viewHeight / 2;
	}

	public function screenToWorldX(screenX:Float):Float {
		return (screenX - owner().viewWidth / 2) / zoom + worldX;
	}

	public function screenToWorldY(screenY:Float):Float {
		return (screenY - owner().viewHeight / 2) / zoom + worldY;
	}

	function owner():Scene {
		return scene != null ? scene : viewScene;
	}

	public function lookAt(x:Single, y:Single):Void {
		this.x = x;
		this.y = y;
	}

	function updateView():Void {
		view.x = worldX;
		view.y = worldY;
		view.zoom = zoom;
	}

	function set_zoom(value:Single):Single {
		if (value < MIN_ZOOM) {
			Log.warn('A camera zoom of $value would collapse the view, so it was raised to $MIN_ZOOM.');
			value = MIN_ZOOM;
		}
		zoom = value;
		return value;
	}
}
