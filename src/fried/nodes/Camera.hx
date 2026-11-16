package fried.nodes;

import fried.Log;
import fried.graphics.CameraView;

@:allow(fried.nodes)
@:serializable
class Camera extends Node2D {
	public var zoom(default, set):Float;

	static inline var MIN_ZOOM:Float = 0.01;

	public function new(zoom:Float = 1.0) {
		super();
		name = "Camera";
		this.zoom = zoom;
	}

	// What the draw queue reads, written before the scene is drawn.
	@:noSerialize public var view(default, null):CameraView = new CameraView();

	// Each conversion works from the view of the scene the camera belongs to.
	public function worldToScreenX(worldPosition:Float):Float {
		return (worldPosition - worldX) * zoom + scene.viewWidth / 2;
	}

	public function worldToScreenY(worldPosition:Float):Float {
		return (worldPosition - worldY) * zoom + scene.viewHeight / 2;
	}

	public function screenToWorldX(screenX:Float):Float {
		return (screenX - scene.viewWidth / 2) / zoom + worldX;
	}

	public function screenToWorldY(screenY:Float):Float {
		return (screenY - scene.viewHeight / 2) / zoom + worldY;
	}

	public function lookAt(x:Float, y:Float):Void {
		this.x = x;
		this.y = y;
	}

	function updateView():Void {
		view.x = worldX;
		view.y = worldY;
		view.zoom = zoom;
	}

	function set_zoom(value:Float):Float {
		if (value < MIN_ZOOM) {
			Log.warn('A camera zoom of $value would collapse the view, so it was raised to $MIN_ZOOM.');
			value = MIN_ZOOM;
		}
		zoom = value;
		return value;
	}
}
