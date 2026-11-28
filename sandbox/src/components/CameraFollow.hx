package components;

import fried.scene.Component;
import fried.scene.Transform2D;

// Moves the camera it is on, or below, to an object, plus an offset.
@:serializable
class CameraFollow extends Component {
	public var target:Transform2D;
	public var offsetX:Float;
	public var offsetY:Float;

	var camera:Transform2D;

	public function new(target:Transform2D, offsetX:Float = 0.0, offsetY:Float = 0.0) {
		super();
		this.target = target;
		this.offsetX = offsetX;
		this.offsetY = offsetY;
	}

	override function start():Void {
		camera = gameObject.getComponentInParent(Transform2D);
		if (camera == null) {
			throw 'A CameraFollow needs a Transform2D to move, and ${gameObject.name} has none above it.';
		}
	}

	override function update(delta:Float):Void {
		if (target == null || target.gameObject.isDestroyed) {
			return;
		}
		camera.x = target.worldX + offsetX;
		camera.y = target.worldY + offsetY;
	}
}
