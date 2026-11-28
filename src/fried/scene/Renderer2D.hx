package fried.scene;

// What draws or takes input in the plane of the screen: it is drawn in front of lower priorities and given an event first.
@:serializable
@:allow(fried.scene)
class Renderer2D extends Component {
	public var priority(default, set):Int;

	public function new() {
		super();
		priority = 0;
	}

	// The size before the scale that a component gives its RectTransform, or a negative number when it gives none.
	function intrinsicWidth():Float {
		return -1;
	}

	function intrinsicHeight():Float {
		return -1;
	}

	override function sortPriority():Int {
		return priority;
	}

	function set_priority(value:Int):Int {
		priority = value;
		if (gameObject != null && gameObject.scene != null) {
			gameObject.scene.isEventOrderDirty = true;
		}
		return value;
	}
}
