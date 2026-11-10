package fried.scene;

import fried.Log;
import fried.graphics.Renderer;

@:serializable
class Camera extends Component {
	public var zoom(default, set):Float;

	@:allow(fried.scene.Scene)
	public var assignedScene(default, null):Scene;

	static inline var MIN_ZOOM:Float = 0.01;

	public function new(zoom:Float = 1.0) {
		super();
		this.zoom = zoom;
	}

	// Each conversion takes the view's size from the renderer given, or else from the scene the camera belongs to, so a component can call it without holding the renderer.
	public function worldToScreenX(worldX:Float, ?renderer:Renderer):Float {
		return (worldX - transform.x) * zoom + viewWidth(renderer) / 2;
	}

	public function worldToScreenY(worldY:Float, ?renderer:Renderer):Float {
		return (worldY - transform.y) * zoom + viewHeight(renderer) / 2;
	}

	public function screenToWorldX(screenX:Float, ?renderer:Renderer):Float {
		return (screenX - viewWidth(renderer) / 2) / zoom + transform.x;
	}

	public function screenToWorldY(screenY:Float, ?renderer:Renderer):Float {
		return (screenY - viewHeight(renderer) / 2) / zoom + transform.y;
	}

	function viewWidth(renderer:Null<Renderer>):Int {
		return renderer != null ? renderer.width : assignedScene.viewWidth;
	}

	function viewHeight(renderer:Null<Renderer>):Int {
		return renderer != null ? renderer.height : assignedScene.viewHeight;
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
