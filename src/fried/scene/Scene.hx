package fried.scene;

class Scene {
	public var name:String;

	public var objectCount(get, never):Int;

	var objects:Array<GameObject>;
	var pendingAdds:Array<GameObject>;
	var pendingRemovals:Array<GameObject>;
	var pendingDestroys:Array<GameObject>;
	var iterating:Bool;

	public function new(name:String = "Scene") {
		this.name = name;
		objects = [];
		pendingAdds = [];
		pendingRemovals = [];
		pendingDestroys = [];
		iterating = false;
	}

	public function add(object:GameObject):GameObject {
		if (object.scene != null) {
			throw 'The game object ${object.name} already belongs to the scene ${object.scene.name}.';
		}
		object.scene = this;
		if (iterating) {
			pendingAdds.push(object);
		} else {
			objects.push(object);
		}
		return object;
	}

	public function remove(object:GameObject):Void {
		if (object.scene != this) {
			return;
		}
		object.scene = null;
		if (iterating) {
			pendingRemovals.push(object);
		} else {
			objects.remove(object);
		}
	}

	public function update():Void {
		applyPendingChanges();
		iterating = true;
		for (object in objects) {
			object.update();
		}
		iterating = false;
	}

	public function draw():Void {
		applyPendingChanges();
		iterating = true;
		for (object in objects) {
			object.draw();
		}
		iterating = false;
	}

	public function destroy():Void {
		applyPendingChanges();
		iterating = true;
		for (object in objects) {
			object.scene = null;
			object.destroy();
		}
		iterating = false;
		objects.resize(0);
		pendingAdds.resize(0);
		pendingRemovals.resize(0);
		pendingDestroys.resize(0);
	}

	@:allow(fried.scene.GameObject)
	function destroyLater(object:GameObject):Void {
		pendingDestroys.push(object);
	}

	function applyPendingChanges():Void {
		for (object in pendingDestroys) {
			objects.remove(object);
			object.scene = null;
			object.destroyComponents();
		}
		pendingDestroys.resize(0);

		for (object in pendingRemovals) {
			objects.remove(object);
		}
		pendingRemovals.resize(0);

		for (object in pendingAdds) {
			objects.push(object);
		}
		pendingAdds.resize(0);
	}

	function get_objectCount():Int {
		return objects.length;
	}
}
