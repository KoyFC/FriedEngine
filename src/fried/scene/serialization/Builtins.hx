package fried.scene.serialization;

import fried.physics.Collider;
import fried.physics.KinematicBody;

// A class only a scene file names is never typed by Haxe, so every node a scene may use is listed here, each after the class it extends.
class Builtins {
	public static function all():Array<NodeType> {
		return [Node.describeNode(), KinematicBody.describeNode(), CanvasItem.describeNode(), Node2D.describeNode(), Sprite.describeNode(), Camera.describeNode(), Collider.describeNode(), Control.describeNode(), Label.describeNode(), Button.describeNode(), TextureRect.describeNode(), Node3D.describeNode()];
	}
}
