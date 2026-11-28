package fried.scene;

import fried.graphics.DrawQueue;
import fried.graphics.Renderer;
import fried.graphics3d.MeshPass;
import fried.input.InputEvent;
import fried.physics.Collider;
import fried.physics.ColliderGrid;
import fried.physics.KinematicBody;
import haxe.ds.ArraySort;

// What a Canvas holds for the frame: the drawing and input hooks of its subtree.
private class CanvasBucket {
	public var canvas:Canvas;
	public var drawList:Array<Component> = [];
	public var eventTree:Array<Component> = [];
	public var eventList:Array<Component> = [];

	public function new(canvas:Canvas) {
		this.canvas = canvas;
	}
}

// A tree of game objects and the lists a frame runs through. The lists hold only the components whose class overrides the hook, in tree order, and are filled again only when the tree changed, so a frame never walks the tree.
@:allow(fried.scene)
class Scene {
	// The draw order a renderer layer leaves for the canvas layers of its scene: the world is drawn at the layer's own index and each canvas layer after it, so a world node's priority never lifts it over an interface.
	@:allow(fried.graphics.Renderer)
	public static inline var CANVAS_SLOTS:Int = 64;

	public var name:String;

	public var camera(default, set):Null<Camera>;

	// What the scene's meshes are drawn through. A scene has a camera or a camera3D, and two scenes loaded together give a game both.
	public var camera3D:Null<Camera3D>;

	#if fried_editor
	// The editor's 3D view leaves out what is drawn flat, and its 2D view leaves out the meshes.
	public var isFlatHidden:Bool = false;

	public var isMeshesHidden:Bool = false;

	// The editor's scene view draws what is under a canvas layer through the camera, where it sits in the world, so it can be seen and picked.
	public var isCanvasInWorld:Bool = false;
	#end

	public var nodeCount(default, null):Int;

	// The size of the view the scene is drawn to, which a node reads instead of holding the renderer. Zero until the scene has been given one.
	public var viewWidth(default, null):Int;
	public var viewHeight(default, null):Int;

	// Every object of the scene sits under this one, which is never drawn or updated.
	public var root(default, null):Transform;

	@:allow(fried.scene.CanvasItem)
	var isEventOrderDirty:Bool;

	var byId:Map<String, GameObject>;
	var updateList:Array<Component>;
	var fixedUpdateList:Array<Component>;
	var bodyList:Array<KinematicBody>;
	var drawList:Array<Component>;
	var meshList:Array<MeshRenderer>;
	var lightList:Array<Light>;
	var eventTree:Array<Component>;
	var eventList:Array<Component>;
	var canvasBuckets:Array<CanvasBucket>;
	@:allow(fried.physics)
	var colliders:Array<Collider>;

	@:allow(fried.physics)
	var colliderGrid:ColliderGrid;
	var areListsDirty:Bool;
	var areCollidersDirty:Bool;

	public function new(name:String = "Scene") {
		this.name = name;
		viewWidth = 0;
		viewHeight = 0;
		nodeCount = 0;
		byId = new Map();
		updateList = [];
		fixedUpdateList = [];
		bodyList = [];
		drawList = [];
		meshList = [];
		lightList = [];
		eventTree = [];
		eventList = [];
		canvasBuckets = [];
		colliders = [];
		colliderGrid = new ColliderGrid();
		areListsDirty = false;
		areCollidersDirty = false;
		isEventOrderDirty = false;
		var rootObject = new GameObject("Root");
		root = rootObject.transform;
		rootObject.enterScene(this);
	}

	function set_camera(value:Null<Camera>):Null<Camera> {
		if (camera != null) {
			camera.viewScene = null;
		}
		camera = value;
		if (value != null) {
			value.viewScene = this;
		}
		return value;
	}

	@:allow(fried.scene.SceneLayer)
	@:allow(fried.scene.serialization.SceneLoader)
	@:allow(fried.editor.EditorPlayer)
	function setView(width:Int, height:Int):Void {
		if (width == viewWidth && height == viewHeight) {
			return;
		}
		viewWidth = width;
		viewHeight = height;
		notifyView(root);
	}

	function notifyView(node:Transform):Void {
		for (child in node.children) {
			child.viewChanged();
			notifyView(child);
		}
	}

	public function add(object:GameObject):GameObject {
		object.transform.setParent(root);
		return object;
	}

	public function remove(object:GameObject):Void {
		if (object.scene == this && object.transform.parent != null) {
			object.transform.setParent(null);
		}
	}

	public function findById(id:String):Null<GameObject> {
		return byId.get(id);
	}

	// The component of the object with that id, as the class a caller expects, which fails loudly when the scene has no such object or it has no such component.
	public function getById<T:Component>(id:String, type:Class<T>):T {
		var object = byId.get(id);
		if (object == null) {
			throw 'The scene $name has no object "$id".';
		}
		var typed = object.getComponent(type);
		if (typed == null) {
			throw 'The object "$id" of the scene $name has no ${Type.getClassName(type)}.';
		}
		return typed;
	}

	// Names are not unique, so this is the first match in tree order.
	public function findByName(name:String):Null<GameObject> {
		return search(root, name);
	}

	function search(node:Transform, name:String):Null<GameObject> {
		for (child in node.children) {
			if (child.gameObject.name == name) {
				return child.gameObject;
			}
			var found = search(child, name);
			if (found != null) {
				return found;
			}
		}
		return null;
	}

	@:allow(fried.scene.GameObject)
	function register(node:GameObject):Void {
		if (node.id != "" && node.scopeOwner == null) {
			byId.set(node.id, node);
		}
		nodeCount++;
		areListsDirty = true;
		areCollidersDirty = true;
	}

	@:allow(fried.scene.GameObject)
	function unregister(node:GameObject):Void {
		if (node.id != "" && node.scopeOwner == null && byId.get(node.id) == node) {
			byId.remove(node.id);
		}
		nodeCount--;
		areListsDirty = true;
		areCollidersDirty = true;
	}

	function rebuildLists():Void {
		updateList.resize(0);
		fixedUpdateList.resize(0);
		bodyList.resize(0);
		drawList.resize(0);
		meshList.resize(0);
		lightList.resize(0);
		eventTree.resize(0);
		canvasBuckets.resize(0);
		collect(root, null);
		if (canvasBuckets.length >= CANVAS_SLOTS) {
			throw 'The scene $name has ${canvasBuckets.length} canvas layers, and a scene holds at most ${CANVAS_SLOTS - 1}.';
		}
		ArraySort.sort(canvasBuckets, byCanvasLayer);
		areListsDirty = false;
		isEventOrderDirty = true;
	}

	function collect(node:Transform, bucket:Null<CanvasBucket>):Void {
		for (component in node.gameObject.components) {
			var flags = component.hooks;
			if (flags == 0) {
				continue;
			}
			if ((flags & Component.CANVAS) != 0) {
				bucket = new CanvasBucket(cast component);
				canvasBuckets.push(bucket);
			}
			if ((flags & Component.UPDATE) != 0) {
				updateList.push(component);
			}
			if ((flags & Component.DRAW) != 0) {
				(bucket != null ? bucket.drawList : drawList).push(component);
			}
			if ((flags & Component.EVENT) != 0) {
				(bucket != null ? bucket.eventTree : eventTree).push(component);
			}
			if ((flags & Component.FIXED_UPDATE) != 0) {
				fixedUpdateList.push(component);
			}
			if ((flags & Component.BODY) != 0) {
				bodyList.push(cast component);
			}
			if ((flags & Component.MESH) != 0) {
				meshList.push(cast component);
			}
			if ((flags & Component.LIGHT) != 0) {
				lightList.push(cast component);
			}
		}
		for (child in node.children) {
			collect(child, bucket);
		}
	}

	function collectColliders(node:Transform):Void {
		for (component in node.gameObject.components) {
			if ((component.hooks & Component.COLLIDER) != 0) {
				colliders.push(cast component);
			}
		}
		for (child in node.children) {
			collectColliders(child);
		}
	}

	// Every collider of the scene, in tree order, for Physics to test. Whether each is active is for the caller. It is kept apart from the lists of the frame, which are never rebuilt while a phase is running, as a node asking Physics a question in its update is common.
	public function activeColliders():Array<Collider> {
		if (areCollidersDirty) {
			colliders.resize(0);
			collectColliders(root);
			colliderGrid.rebuild(colliders);
			areCollidersDirty = false;
		}
		return colliders;
	}

	// The colliders that may touch a box, in the units of a collider's box and in no order, each once. A collider that moved or changed size earlier in the frame is where it is now.
	@:allow(fried.physics)
	function colliderCandidates(left:Int, top:Int, right:Int, bottom:Int):Array<Collider> {
		if (areCollidersDirty) {
			activeColliders();
		}
		return colliderGrid.collect(left, top, right, bottom);
	}

	// How many colliders have a box that overlaps this one, ascending in tree order and with no regard to whether they are active, written to the grid's indices, which index colliders. A collider that moved or changed size earlier in the frame is where it is now.
	@:allow(fried.physics)
	function colliderOverlaps(left:Int, top:Int, right:Int, bottom:Int):Int {
		if (areCollidersDirty) {
			activeColliders();
		}
		return colliderGrid.overlapping(left, top, right, bottom);
	}

	@:allow(fried.physics)
	function colliderMoved(collider:Collider):Void {
		if (!areCollidersDirty) {
			colliderGrid.queue(collider);
		}
	}

	public function update(delta:Float):Void {
		if (areListsDirty) {
			rebuildLists();
		}
		var list = updateList;
		var count = list.length;
		var index = 0;
		while (index < count) {
			var node = list[index];
			if (node.isOn) {
				node.update(delta);
			}
			index++;
		}
	}

	public function fixedUpdate(delta:Float):Void {
		if (areListsDirty) {
			rebuildLists();
		}
		var list = fixedUpdateList;
		var count = list.length;
		var index = 0;
		while (index < count) {
			var node = list[index];
			if (node.isOn) {
				node.fixedUpdate(delta);
			}
			index++;
		}
		simulate(delta);
	}

	// Moves every body by its velocity once the fixed updates have set them. A body that is switched off does not move, and one that moved earlier is an obstacle to the ones after it.
	function simulate(delta:Float):Void {
		if (areListsDirty) {
			rebuildLists();
		}
		var list = bodyList;
		var count = list.length;
		var index = 0;
		while (index < count) {
			var body = list[index];
			if (body.isOn) {
				body.step(delta);
			}
			index++;
		}
	}

	public function draw(renderer:Renderer):Void {
		if (areListsDirty) {
			rebuildLists();
		}
		DrawQueue.currentRenderTarget = renderer;
		if (camera != null) {
			camera.updateView();
		}
		DrawQueue.currentCamera = camera != null ? camera.view : null;
		var list = drawList;
		var count = list.length;
		var index = 0;
		while (index < count) {
			var node = list[index];
			if (node.isOn) {
				#if fried_editor
				if (isFlatHidden && !node.gameObject.transform.isPlaced3D()) {
					index++;
					continue;
				}
				#end
				node.draw();
			}
			index++;
		}
		#if fried_editor
		if (!isMeshesHidden) {
		#end
			if (camera3D != null && camera3D.isOn && meshList.length > 0) {
				var camera2D = DrawQueue.currentCamera;
				DrawQueue.currentCamera = null;
				MeshPass.draw(camera3D, firstLight(), meshList, renderer.width, renderer.height);
				DrawQueue.currentCamera = camera2D;
			}
		#if fried_editor
		}
		#end
		if (canvasBuckets.length > 0) {
			drawCanvasLayers();
		}
	}

	// Each canvas layer draws after the world and the meshes, in screen space, in a draw order slot of its own.
	function drawCanvasLayers():Void {
		var world = DrawQueue.currentLayerIndex;
		var slot = 1;
		for (bucket in canvasBuckets) {
			if (!bucket.canvas.isOn) {
				continue;
			}
			DrawQueue.currentLayerIndex = world + slot;
			slot++;
			#if fried_editor
			DrawQueue.currentCamera = isCanvasInWorld && camera != null ? camera.view : null;
			#else
			DrawQueue.currentCamera = null;
			#end
			for (node in bucket.drawList) {
				if (node.isOn) {
					#if fried_editor
					if (isFlatHidden && !node.gameObject.transform.isPlaced3D()) {
						continue;
					}
					#end
					node.draw();
				}
			}
		}
		DrawQueue.currentLayerIndex = world;
		DrawQueue.currentCamera = camera != null ? camera.view : null;
	}

	function firstLight():Null<Light> {
		for (light in lightList) {
			if (light.isOn) {
				return light;
			}
		}
		return null;
	}

	// Top first, the reverse of the order things are drawn in, and a higher priority before a lower one.
	public function propagateEvent(event:InputEvent):Void {
		if (areListsDirty) {
			rebuildLists();
		}
		if (isEventOrderDirty) {
			orderEvents(eventTree, eventList);
			for (bucket in canvasBuckets) {
				orderEvents(bucket.eventTree, bucket.eventList);
			}
			isEventOrderDirty = false;
		}
		var bucketIndex = canvasBuckets.length - 1;
		while (bucketIndex >= 0 && !event.handled) {
			var bucket = canvasBuckets[bucketIndex];
			if (bucket.canvas.isOn) {
				dispatch(bucket.eventList, event);
			}
			bucketIndex--;
		}
		if (!event.handled) {
			dispatch(eventList, event);
		}
	}

	function dispatch(list:Array<Component>, event:InputEvent):Void {
		var count = list.length;
		var index = 0;
		while (index < count) {
			if (event.handled) {
				break;
			}
			var node = list[index];
			if (node.isOn) {
				node.onEvent(event);
			}
			index++;
		}
	}

	function orderEvents(tree:Array<Component>, list:Array<Component>):Void {
		list.resize(0);
		var index = tree.length - 1;
		while (index >= 0) {
			list.push(tree[index]);
			index--;
		}
		ArraySort.sort(list, byPriorityDescending);
	}

	public function destroy():Void {
		for (child in root.children.copy()) {
			child.setParent(null);
			child.gameObject.destroyTree();
		}
		camera = null;
		camera3D = null;
		colliderGrid.dispose();
	}

	static function byCanvasLayer(first:CanvasBucket, second:CanvasBucket):Int {
		return first.canvas.layer - second.canvas.layer;
	}

	static function byPriorityDescending(first:Component, second:Component):Int {
		return second.sortPriority() - first.sortPriority();
	}
}
