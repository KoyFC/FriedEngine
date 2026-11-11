package fried.scene;

import fried.input.InputEvent;

@:autoBuild(fried.scene.serialization.ComponentBuilder.build())
class Component {
	public var gameObject(default, null):GameObject;
	public var enabled:Bool;

	public var transform(get, never):Transform;

	public function new() {
		enabled = true;
	}

	// While a scene file is being built, components wait here instead of starting, since what they start with may not exist yet.
	@:allow(fried.scene.serialization.SceneLoader)
	static var waitingToStart:Null<Array<Component>>;

	@:allow(fried.scene.GameObject)
	function attach(owner:GameObject):Void {
		gameObject = owner;
		if (waitingToStart != null) {
			waitingToStart.push(this);
		} else {
			start();
		}
	}

	@:allow(fried.scene.GameObject)
	function detach():Void {
		gameObject = null;
	}

	@:allow(fried.scene.GameObject)
	function destroy():Void {}

	@:allow(fried.scene.serialization.SceneLoader)
	function start():Void {}

	@:allow(fried.scene.GameObject)
	function update():Void {}

	@:allow(fried.scene.GameObject)
	function draw():Void {}

	// The size a component gives its object before the transform's scale, or a negative number when it gives none. Layout and the editor measure an object by it.
	@:allow(fried.scene.GameObject)
	function intrinsicWidth():Float {
		return -1;
	}

	@:allow(fried.scene.GameObject)
	function intrinsicHeight():Float {
		return -1;
	}

	// Layout runs before every draw, in the game and in the editor, so what a component sets here is seen where nothing updates. The size pass goes first for every object, so a component that places an object reads the final size of any other.
	@:allow(fried.scene.GameObject)
	function layoutSize():Void {}

	@:allow(fried.scene.GameObject)
	function layoutPosition():Void {}

	// An object that must be placed before this component places its own, whatever the order of the scene.
	@:allow(fried.scene.GameObject)
	function layoutAfter():Null<GameObject> {
		return null;
	}

	@:allow(fried.scene.GameObject)
	function onEvent(event:InputEvent):Void {}

	inline function get_transform():Transform {
		return gameObject.transform;
	}
}
