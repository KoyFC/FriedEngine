package fried.nodes.serialization;

// A class only a scene file names is never typed by Haxe, so every node a scene may use is listed here, each after the class it extends.
class Builtins {
	public static function all():Array<NodeType> {
		return [Node.describeNode(), CanvasItem.describeNode(), Node2D.describeNode(), Sprite.describeNode(), Camera.describeNode()];
	}
}
