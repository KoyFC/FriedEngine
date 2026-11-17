package nodes;

import fried.scene.Node;
import fried.scene.Node2D;

// Moves the camera it is a child of to a node, plus an offset.
@:serializable
class CameraFollow extends Node {
	public var target:Node2D;
	public var offsetX:Float;
	public var offsetY:Float;

	var camera:Node2D;

	public function new(target:Node2D, offsetX:Float = 0.0, offsetY:Float = 0.0) {
		super("CameraFollow");
		this.target = target;
		this.offsetX = offsetX;
		this.offsetY = offsetY;
	}

	override function ready():Void {
		camera = findParent(Node2D);
		if (camera == null) {
			throw 'A CameraFollow needs a Node2D to move, and the parent of $name is not one.';
		}
	}

	override function update(delta:Float):Void {
		if (target == null || target.isDestroyed) {
			return;
		}
		camera.x = target.worldX + offsetX;
		camera.y = target.worldY + offsetY;
	}
}
