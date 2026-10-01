package fried.scene;

import fried.Log;
import fried.graphics.Renderer;

class Camera extends Component {
	public var zoom(default, set):Float;

	@:allow(fried.scene.Scene)
	public var assignedScene(default, null):Scene;

	static inline var MIN_ZOOM:Float = 0.01;

	public function new(zoom:Float = 1.0) {
		super();
		this.zoom = zoom;
	}

	public function worldToScreenX(worldX:Float, renderer:Renderer):Float {
		return (worldX - transform.x) * zoom + renderer.width / 2;
	}

	public function worldToScreenY(worldY:Float, renderer:Renderer):Float {
		return (worldY - transform.y) * zoom + renderer.height / 2;
	}

	public function screenToWorldX(screenX:Float, renderer:Renderer):Float {
		return (screenX - renderer.width / 2) / zoom + transform.x;
	}

	public function screenToWorldY(screenY:Float, renderer:Renderer):Float {
		return (screenY - renderer.height / 2) / zoom + transform.y;
	}

	public function lookAt(worldX:Float, worldY:Float):Void {
		transform.x = worldX;
		transform.y = worldY;
	}

	override function destroy():Void {
		if (assignedScene != null) {
			assignedScene.camera = null;
		}
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
