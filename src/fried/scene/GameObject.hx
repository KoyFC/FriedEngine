package fried.scene;

class GameObject {
	public var name:String;
	public var isActive:Bool;
	public var priority:Int;

	public var isDestroyed(default, null):Bool;

	public var transform(default, null):Transform;

	@:allow(fried.scene.Scene)
	public var scene(default, null):Scene;

	@:allow(fried.physics.Physics)
	var components:Array<Component>;

	public function new(name:String = "GameObject", xPosition:Float = 0.0, yPosition:Float = 0.0) {
		this.name = name;
		isActive = true;
		priority = 0;
		isDestroyed = false;
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
}
