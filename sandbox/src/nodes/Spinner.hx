package nodes;

import fried.scene.Control;
import fried.scene.Node;

// Turns the control it is a child of.
@:serializable
class Spinner extends Node {
	public var degreesPerSecond:Float;

	var target:Control;

	public function new(degreesPerSecond:Float) {
		super("Spinner");
		this.degreesPerSecond = degreesPerSecond;
	}

	override function ready():Void {
		target = findParent(Control);
		if (target == null) {
			throw 'A Spinner needs a Control as its parent, and the parent of $name is not one.';
		}
	}

	override function update(delta:Float):Void {
		target.rotation += degreesPerSecond * delta;
	}
}
