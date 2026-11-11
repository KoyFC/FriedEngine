package fried.scene;

import fried.input.InputEvent;

class GameObject {
	// Empty for an object built in code. A scene file gives each one a stable id.
	public var id:String;
	public var name:String;
	public var isActive:Bool;
	public var priority:Int;

	public var isDestroyed(default, null):Bool;

	public var transform(default, null):Transform;

	@:allow(fried.scene.Scene)
	public var scene(default, null):Scene;

	@:allow(fried.physics.Physics)
	@:allow(fried.scene.serialization.SceneLoader)
	@:allow(fried.editor.EditorBounds)
	var components:Array<Component>;

	// 0 not placed yet this pass, 1 being placed, 2 placed.
	@:allow(fried.scene.Scene)
	var layoutState:Int;

	@:allow(fried.scene.Scene)
	var isLayoutCycleReported:Bool;

	public function new(name:String = "GameObject", xPosition:Float = 0.0, yPosition:Float = 0.0) {
		this.name = name;
		id = "";
		isActive = true;
		priority = 0;
		isDestroyed = false;
		layoutState = 0;
		isLayoutCycleReported = false;
		components = [];
		transform = addComponent(new Transform(xPosition, yPosition));
	}

	public function addComponent<T:Component>(component:T):T {
		if (component.gameObject != null) {
			throw 'A component may only belong to one game object. This one belongs to ${component.gameObject.name}.';
		}
		components.push(component);
		component.attach(this);
		return component;
	}

	public function getComponent<T:Component>(type:Class<T>):Null<T> {
		for (component in components) {
			var match = Std.downcast(component, type);
			if (match != null) {
				return match;
			}
		}
		return null;
	}

	public function removeComponent(component:Component):Void {
		if (component == transform) {
			throw 'The Transform of ${name} cannot be removed.';
		}
		if (!components.remove(component)) {
			return;
		}
		component.destroy();
		component.detach();
	}

	public function destroy():Void {
		if (isDestroyed) {
			return;
		}
		isDestroyed = true;
		isActive = false;
		if (scene != null) {
			scene.destroyLater(this);
			return;
		}
		destroyComponents();
	}

	@:allow(fried.scene.Scene)
	function destroyComponents():Void {
		for (component in components) {
			component.destroy();
			component.detach();
		}
		components.resize(0);
		transform = null;
	}

	@:allow(fried.scene.Scene)
	function update():Void {
		if (!isActive) {
			return;
		}
		for (component in components) {
			if (component.enabled) {
				component.update();
			}
		}
	}

	@:allow(fried.scene.Scene)
	function draw():Void {
		if (!isActive) {
			return;
		}
		for (component in components) {
			if (component.enabled) {
				component.draw();
			}
		}
	}

	@:allow(fried.scene.Scene)
	function layoutSize():Void {
		if (!isActive) {
			return;
		}
		for (component in components) {
			if (component.enabled) {
				component.layoutSize();
			}
		}
	}

	@:allow(fried.scene.Scene)
	function layoutPosition():Void {
		if (!isActive) {
			return;
		}
		for (component in components) {
			if (component.enabled) {
				component.layoutPosition();
			}
		}
	}

	@:allow(fried.scene.Scene)
	function layoutDependencies():Array<GameObject> {
		var dependencies = [];
		if (!isActive) {
			return dependencies;
		}
		for (component in components) {
			var dependency = component.enabled ? component.layoutAfter() : null;
			if (dependency != null) {
				dependencies.push(dependency);
			}
		}
		return dependencies;
	}

	@:allow(fried.scene.Scene)
	function propagateEvent(event:InputEvent):Void {
		if (!isActive) {
			return;
		}
		for (component in components) {
			if (event.handled) {
				return;
			}
			if (component.enabled) {
				component.onEvent(event);
			}
		}
	}
}
