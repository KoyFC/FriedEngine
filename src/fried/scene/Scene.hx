package fried.scene;

import fried.graphics.DrawQueue;
import fried.graphics.Renderer;

class Scene {
	public var name:String;

	public var objectCount(get, never):Int;

	var sceneObjects:Array<GameObject>;
	var pendingAdds:Array<GameObject>;
	var pendingRemovals:Array<GameObject>;
	var pendingDestroys:Array<GameObject>;
	var iterating:Bool;

	public function new(name:String = "Scene") {
		this.name = name;
		sceneObjects = [];
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
			sceneObjects.push(object);
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
			sceneObjects.remove(object);
		}
	}

	public function update():Void {
		applyPendingChanges();
		iterating = true;
		for (object in sceneObjects) {
			object.update();
		}
		iterating = false;
	}

	public function draw(renderer:Renderer):Void {
		applyPendingChanges();
		DrawQueue.currentRenderTarget = renderer;
		iterating = true;
		for (object in sceneObjects) {
			object.draw();
		}
		iterating = false;
	}

	public function destroy():Void {
		applyPendingChanges();
		iterating = true;
		for (object in sceneObjects) {
			object.scene = null;
			object.destroy();
		}
		iterating = false;
		sceneObjects.resize(0);
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
			sceneObjects.remove(object);
			object.scene = null;
			object.destroyComponents();
		}
		pendingDestroys.resize(0);

		for (object in pendingRemovals) {
			sceneObjects.remove(object);
		}
		pendingRemovals.resize(0);

		for (object in pendingAdds) {
			sceneObjects.push(object);
		}
		pendingAdds.resize(0);
	}

	function get_objectCount():Int {
		return sceneObjects.length;
	}
}
