package fried.scene;

class GameObject {
	public var name:String;
	public var active:Bool;
	public var priority:Int;

	public var transform(default, null):Transform;

	var components:Array<Component>;

	public function new(name:String = "GameObject", xPosition:Float = 0.0, yPosition:Float = 0.0) {
		this.name = name;
		active = true;
		priority = 0;
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
		for (component in components) {
			component.destroy();
			component.detach();
		}
		components.resize(0);
		transform = null;
	}

	function update():Void {
		if (!active) {
			return;
		}
		for (component in components) {
			if (component.enabled) {
				component.update();
			}
		}
	}

	function draw():Void {
		if (!active) {
			return;
		}
		for (component in components) {
			if (component.enabled) {
				component.draw();
			}
		}
	}
}
