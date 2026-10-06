package fried.scene;

import fried.graphics.DrawQueue;
import fried.graphics.Renderer;
import fried.input.InputEvent;
import haxe.ds.ArraySort;

class Scene {
	public var name:String;

	public var camera(default, set):Camera;

	public var objectCount(get, never):Int;

	@:allow(fried.physics.Physics)
	var sceneObjects:Array<GameObject>;
	var pendingAdds:Array<GameObject>;
	var pendingRemovals:Array<GameObject>;
	var pendingDestroys:Array<GameObject>;
	var eventOrder:Array<GameObject>;
	var isIterating:Bool;

	public function new(name:String = "Scene") {
		this.name = name;
		sceneObjects = [];
		pendingAdds = [];
		pendingRemovals = [];
		pendingDestroys = [];
		eventOrder = [];
		isIterating = false;
	}

	public function add(object:GameObject):GameObject {
		if (object.scene != null) {
			throw 'The game object ${object.name} already belongs to the scene ${object.scene.name}.';
		}
		object.scene = this;
		if (isIterating) {
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
		if (isIterating) {
			pendingRemovals.push(object);
		} else {
			sceneObjects.remove(object);
		}
	}

	public function update():Void {
		applyPendingChanges();
		isIterating = true;
		for (object in sceneObjects) {
			object.update();
		}
		isIterating = false;
	}

	public function draw(renderer:Renderer):Void {
		applyPendingChanges();
		DrawQueue.currentRenderTarget = renderer;
		DrawQueue.currentCamera = camera;
		isIterating = true;
		for (object in sceneObjects) {
			object.draw();
		}
		isIterating = false;
	}

	// Top first, the reverse of the order things are drawn in.
	public function propagateEvent(event:InputEvent, renderer:Renderer):Void {
		applyPendingChanges();
		var index = sceneObjects.length - 1;
		while (index >= 0) {
			eventOrder.push(sceneObjects[index]);
			index--;
		}
		ArraySort.sort(eventOrder, byPriorityDescending);
		for (object in eventOrder) {
			if (event.handled) {
				break;
			}
			object.propagateEvent(event, renderer);
		}
		eventOrder.resize(0);
	}

	public function destroy():Void {
		applyPendingChanges();
		isIterating = true;
		for (object in sceneObjects) {
			object.scene = null;
			object.destroy();
		}
		isIterating = false;
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

	static function byPriorityDescending(first:GameObject, second:GameObject):Int {
		return second.priority - first.priority;
	}

	function get_objectCount():Int {
		return sceneObjects.length;
	}

	function set_camera(value:Camera):Camera {
		if (value == camera) {
			return camera;
		}
		if (value != null) {
			if (value.gameObject == null) {
				throw 'A camera must belong to a game object before the scene $name can draw through it.';
			}
			if (value.assignedScene != null) {
				throw 'That camera is already the view of the scene ${value.assignedScene.name}.';
			}
		}
		if (camera != null) {
			camera.assignedScene = null;
		}
		camera = value;
		if (value != null) {
			value.assignedScene = this;
		}
		return camera;
	}
}
