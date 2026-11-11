package fried.scene;

import fried.Log;
import fried.graphics.DrawQueue;
import fried.graphics.Renderer;
import fried.input.InputEvent;
import haxe.ds.ArraySort;

class Scene {
	public var name:String;

	public var camera(default, set):Camera;

	public var objectCount(get, never):Int;

	// The size of the view the scene is drawn to, which a component reads instead of holding the renderer. Zero until the scene has been given one.
	public var viewWidth(default, null):Int;
	public var viewHeight(default, null):Int;

	@:allow(fried.physics.Physics)
	@:allow(fried.editor.EditorPlayer)
	var sceneObjects:Array<GameObject>;
	var pendingAdds:Array<GameObject>;
	var pendingRemovals:Array<GameObject>;
	var pendingDestroys:Array<GameObject>;
	var eventOrder:Array<GameObject>;
	var isIterating:Bool;

	public function new(name:String = "Scene") {
		this.name = name;
		viewWidth = 0;
		viewHeight = 0;
		sceneObjects = [];
		pendingAdds = [];
		pendingRemovals = [];
		pendingDestroys = [];
		eventOrder = [];
		isIterating = false;
	}

	@:allow(fried.scene.SceneLayer)
	@:allow(fried.scene.serialization.SceneLoader)
	function setView(width:Int, height:Int):Void {
		viewWidth = width;
		viewHeight = height;
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

	public function findById(id:String):Null<GameObject> {
		return find(object -> object.id == id);
	}

	// Names are not unique, so this is the first match in draw order.
	public function findByName(name:String):Null<GameObject> {
		return find(object -> object.name == name);
	}

	function find(matches:GameObject->Bool):Null<GameObject> {
		applyPendingChanges();
		for (object in sceneObjects) {
			if (!object.isDestroyed && matches(object)) {
				return object;
			}
		}
		return null;
	}

	public function update():Void {
		applyPendingChanges();
		isIterating = true;
		for (object in sceneObjects) {
			object.update();
		}
		isIterating = false;
	}

	// Sizes every object, then places each one after the objects it depends on, so the result does not depend on the order of the objects or of their components. It runs before every draw, which is also where the editor reaches it, and a scene that was just built runs it once so it is placed before the first frame.
	@:allow(fried.scene.serialization.SceneLoader)
	function layout():Void {
		applyPendingChanges();
		for (object in sceneObjects) {
			object.layoutState = 0;
			object.layoutSize();
		}
		for (object in sceneObjects) {
			place(object);
		}
	}

	function place(object:GameObject):Void {
		if (object.layoutState != 0) {
			if (object.layoutState == 1 && !object.isLayoutCycleReported) {
				object.isLayoutCycleReported = true;
				Log.warn('The layout of ${object.name} depends on itself, so one of the objects in the loop is placed before the other.');
			}
			return;
		}
		object.layoutState = 1;
		for (dependency in object.layoutDependencies()) {
			if (dependency.scene == this) {
				place(dependency);
			}
		}
		object.layoutPosition();
		object.layoutState = 2;
	}

	public function draw(renderer:Renderer):Void {
		layout();
		DrawQueue.currentRenderTarget = renderer;
		DrawQueue.currentCamera = camera;
		isIterating = true;
		for (object in sceneObjects) {
			object.draw();
		}
		isIterating = false;
	}

	// Top first, the reverse of the order things are drawn in.
	public function propagateEvent(event:InputEvent):Void {
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
			object.propagateEvent(event);
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
