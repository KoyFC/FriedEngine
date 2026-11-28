package components;

import fried.scene.Component;
import fried.scene.RectTransform;

// Turns the RectTransform it is on, or below.
@:serializable
class Spinner extends Component {
	public var degreesPerSecond:Float;

	var target:RectTransform;

	public function new(degreesPerSecond:Float) {
		super();
		this.degreesPerSecond = degreesPerSecond;
	}

	override function start():Void {
		target = gameObject.getComponentInParent(RectTransform);
		if (target == null) {
			throw 'A Spinner needs a RectTransform on its object or above it, and ${gameObject.name} has none.';
		}
	}

	override function update(delta:Float):Void {
		target.rotation += degreesPerSecond * delta;
	}
}
