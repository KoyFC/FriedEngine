package fried.scene;

import fried.graphics.Renderer;
import fried.input.InputEvent;

class Component {
	public var gameObject(default, null):GameObject;
	public var enabled:Bool;

	public var transform(get, never):Transform;

	public function new() {
		enabled = true;
	}

	@:allow(fried.scene.GameObject)
	function attach(owner:GameObject):Void {
		gameObject = owner;
		start();
	}

	@:allow(fried.scene.GameObject)
	function detach():Void {
		gameObject = null;
	}

	@:allow(fried.scene.GameObject)
	function destroy():Void {}

	function start():Void {}

	@:allow(fried.scene.GameObject)
	function update():Void {}

	@:allow(fried.scene.GameObject)
	function draw():Void {}

	@:allow(fried.scene.GameObject)
	function onEvent(event:InputEvent, renderer:Renderer):Void {}

	inline function get_transform():Transform {
		return gameObject.transform;
	}
}
