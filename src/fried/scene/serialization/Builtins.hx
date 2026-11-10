package fried.scene.serialization;

import fried.physics.Collider;

// A class only a scene file names is never typed by Haxe, so every component a scene may use is listed here.
class Builtins {
	public static function all():Array<ComponentType> {
		return [
			Transform.describeComponent(),
			Sprite.describeComponent(),
			Text.describeComponent(),
			Button.describeComponent(),
			Camera.describeComponent(),
			Collider.describeComponent()
		];
	}
}
