package fried.scene;

import fried.input.InputEvent;

@:build(fried.scene.serialization.ComponentBuilder.build())
@:autoBuild(fried.scene.serialization.ComponentBuilder.build())
@:serializable
@:allow(fried.scene)
class Component {
	static inline var UPDATE:Int = 1;
	static inline var DRAW:Int = 2;
	static inline var EVENT:Int = 4;
	static inline var COLLIDER:Int = 8;
	static inline var FIXED_UPDATE:Int = 16;
	static inline var BODY:Int = 32;
	static inline var MESH:Int = 64;
	static inline var LIGHT:Int = 128;
	static inline var CANVAS:Int = 256;

	// While a scene file is being built, components wait here instead of starting, since what they start with may not exist yet.
	@:allow(fried.scene.serialization.SceneLoader)
	static var waitingToStart:Null<Array<Component>>;

	public var enabled(default, set):Bool;

	@:noSerialize public var gameObject(default, null):GameObject;
	@:noSerialize public var transform(get, never):Transform;

	// Whether the component takes part in the frame: it is enabled and every object above it is active.
	@:noSerialize public var isOn(default, null):Bool;

	@:allow(fried.scene.Scene)
	var hooks:Int;

	var isStarted:Bool;

	public function new() {
		enabled = true;
		isOn = false;
		isStarted = false;
		hooks = hookFlags();
	}

	// Called when the component joins an object, with its fields set but the references of a scene file not yet resolved.
	function awake():Void {}

	// Called once, after the scene file that holds the component is built, children before their parent.
	function start():Void {}

	function update(delta:Float):Void {}

	function fixedUpdate(delta:Float):Void {}

	function draw():Void {}

	function onEvent(event:InputEvent):Void {}

	function onDestroy():Void {}

	function sceneEntered():Void {}

	function sceneLeft():Void {}

	function hookFlags():Int {
		return 0;
	}

	function sortPriority():Int {
		return 0;
	}

	function refreshOn():Void {
		isOn = enabled && gameObject != null && gameObject.activeInHierarchy;
	}

	function need<T:Transform>(type:Class<T>):T {
		var found = Std.downcast(gameObject.transform, type);
		if (found == null) {
			throw '${Type.getClassName(Type.getClass(this))} needs a ${Type.getClassName(type)} on the object ${gameObject.name}.';
		}
		return found;
	}

	function set_enabled(value:Bool):Bool {
		enabled = value;
		refreshOn();
		return value;
	}

	inline function get_transform():Transform {
		return gameObject.transform;
	}
}
