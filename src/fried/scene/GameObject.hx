package fried.scene;

@:allow(fried.scene)
final class GameObject {
	// Empty for an object built in code. A scene file gives each one a stable id.
	public var id:String;
	public var name:String;

	public var active(default, set):Bool;

	@:noSerialize public var activeInHierarchy(default, null):Bool;
	@:noSerialize public var isDestroyed(default, null):Bool;
	@:noSerialize public var scene(default, null):Null<Scene>;
	@:noSerialize public var transform(default, null):Transform;

	var components:Array<Component>;

	// The instance root whose ids this object's id lives among, which is null for an object of the scene itself.
	@:allow(fried.scene.serialization)
	@:allow(fried.editor)
	var scopeOwner:Null<GameObject>;

	// Set on the root of an instanced scene file, which holds the ids of the file's objects.
	@:allow(fried.scene.serialization)
	var scopeObjects:Null<Map<String, GameObject>>;

	public var isInstanceRoot(get, never):Bool;

	public function new(name:String = "GameObject", ?transform:Transform) {
		this.name = name;
		id = "";
		components = [];
		active = true;
		activeInHierarchy = true;
		isDestroyed = false;
		this.transform = transform != null ? transform : new Transform();
		this.transform.gameObject = this;
		this.transform.refreshOn();
	}

	static inline function as<T:Component>(component:Component, type:Class<T>):Null<T> {
		return Std.downcast(component, type);
	}

	public function addComponent<T:Component>(component:T):T {
		if (component.gameObject != null) {
			throw 'The component ${Type.getClassName(Type.getClass(component))} already belongs to the object ${component.gameObject.name}.';
		}
		component.gameObject = this;
		components.push(component);
		component.refreshOn();
		component.awake();
		if (scene != null) {
			scene.areListsDirty = true;
			scene.areCollidersDirty = true;
			component.sceneEntered();
			startComponents();
		}
		return component;
	}

	public function removeComponent(component:Component):Void {
		if (components.remove(component)) {
			if (scene != null) {
				component.sceneLeft();
				scene.areListsDirty = true;
				scene.areCollidersDirty = true;
			}
			component.isOn = false;
			component.onDestroy();
			component.gameObject = null;
		}
	}

	public function getComponent<T:Component>(type:Class<T>):Null<T> {
		var own = as(transform, type);
		if (own != null) {
			return own;
		}
		for (component in components) {
			var match = Std.downcast(component, type);
			if (match != null) {
				return match;
			}
		}
		return null;
	}

	public function getComponents<T:Component>(type:Class<T>):Array<T> {
		var found:Array<T> = [];
		var own = as(transform, type);
		if (own != null) {
			found.push(own);
		}
		for (component in components) {
			var match = Std.downcast(component, type);
			if (match != null) {
				found.push(match);
			}
		}
		return found;
	}

	// The component on this object or the first object below it, depth first.
	public function getComponentInChildren<T:Component>(type:Class<T>):Null<T> {
		var own = getComponent(type);
		if (own != null) {
			return own;
		}
		for (child in transform.children) {
			var match = child.gameObject.getComponentInChildren(type);
			if (match != null) {
				return match;
			}
		}
		return null;
	}

	// The component on this object or the nearest object above it.
	public function getComponentInParent<T:Component>(type:Class<T>):Null<T> {
		var current:Null<Transform> = transform;
		while (current != null) {
			var match = current.gameObject.getComponent(type);
			if (match != null) {
				return match;
			}
			current = current.parent;
		}
		return null;
	}

	// An object of the scene file this object is the instance of, by the id the file gave it.
	public function getById<T:Component>(id:String, type:Class<T>):T {
		if (scopeObjects == null) {
			throw 'The object $name is not the instance of a scene, so it has no object "$id".';
		}
		var object = scopeObjects.get(id);
		if (object == null) {
			throw 'The instance $name has no object "$id".';
		}
		var typed = object.getComponent(type);
		if (typed == null) {
			throw 'The object "$id" of the instance $name has no ${Type.getClassName(type)}.';
		}
		return typed;
	}

	public function destroy():Void {
		if (isDestroyed) {
			return;
		}
		if (transform.parent != null) {
			transform.setParent(null);
		}
		destroyTree();
	}

	function destroyTree():Void {
		isDestroyed = true;
		activeInHierarchy = false;
		refreshComponents();
		for (child in transform.children) {
			child.gameObject.destroyTree();
		}
		for (component in components) {
			component.onDestroy();
		}
	}

	function refreshComponents():Void {
		transform.refreshOn();
		for (component in components) {
			component.refreshOn();
		}
	}

	function enterScene(entered:Scene):Void {
		scene = entered;
		entered.register(this);
		transform.sceneEntered();
		for (component in components) {
			component.sceneEntered();
		}
		for (child in transform.children) {
			child.gameObject.enterScene(entered);
		}
	}

	function leaveScene():Void {
		scene.unregister(this);
		for (child in transform.children) {
			child.gameObject.leaveScene();
		}
		for (component in components) {
			component.sceneLeft();
		}
		transform.sceneLeft();
		scene = null;
		activeInHierarchy = false;
		refreshComponents();
	}

	function startComponents():Void {
		var index = 0;
		while (index < components.length) {
			var component = components[index];
			index++;
			if (component.isStarted) {
				continue;
			}
			component.isStarted = true;
			if (Component.waitingToStart != null) {
				Component.waitingToStart.push(component);
			} else {
				component.start();
			}
		}
	}

	function set_active(value:Bool):Bool {
		active = value;
		if (transform != null) {
			transform.refreshFlags();
		}
		return value;
	}

	inline function get_isInstanceRoot():Bool {
		return scopeObjects != null;
	}
}
