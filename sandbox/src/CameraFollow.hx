import fried.scene.Component;
import fried.scene.GameObject;

class CameraFollow extends Component {
	public var target:GameObject;
	public var offsetX:Float;
	public var offsetY:Float;

	public function new(target:GameObject, offsetX:Float = 0.0, offsetY:Float = 0.0) {
		super();
		this.target = target;
		this.offsetX = offsetX;
		this.offsetY = offsetY;
	}

	override function update():Void {
		if (target == null || target.isDestroyed) {
			return;
		}
		transform.x = target.transform.x + offsetX;
		transform.y = target.transform.y + offsetY;
	}
}
