package fried.scene;

import fried.graphics.DrawQueue;
import fried.graphics.Renderer;
import fried.graphics3d.MeshPass;
import fried.input.InputEvent;
import fried.physics.Collider;
import fried.physics.ColliderGrid;
import fried.physics.KinematicBody;
import haxe.ds.ArraySort;

// What a CanvasLayer node holds for the frame: the drawing and input hooks of its subtree.
private class CanvasBucket {
	public var node:CanvasLayer;
	public var drawList:Array<Node> = [];
	public var eventTree:Array<Node> = [];
	public var eventList:Array<Node> = [];

	public function new(node:CanvasLayer) {
		this.node = node;
	}
}

// A tree of nodes and the lists a frame runs through. The lists hold only the nodes whose class overrides the hook, in tree order, and are filled again only when the tree changed, so a frame never walks the tree.
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

	// Every node of the scene sits under this one, which is never drawn or updated.
	public var root(default, null):Node;

	@:allow(fried.scene.CanvasItem)
	var isEventOrderDirty:Bool;

	var byId:Map<String, Node>;
	var updateList:Array<Node>;
	var fixedUpdateList:Array<Node>;
	var bodyList:Array<KinematicBody>;
	var drawList:Array<Node>;
	var meshList:Array<MeshInstance>;
	var lightList:Array<DirectionalLight>;
	var eventTree:Array<Node>;
	var eventList:Array<Node>;
	var canvasBuckets:Array<CanvasBucket>;
	var colliders:Array<Collider>;
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
		root = new Node("Root");
		root.enterScene(this);
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

	function notifyView(node:Node):Void {
		for (child in node.children) {
			child.viewChanged();
			notifyView(child);
		}
	}

	public function add<T:Node>(node:T):T {
		return root.addChild(node);
	}

	public function remove(node:Node):Void {
		if (node.scene == this && node.parent != null) {
			node.parent.removeChild(node);
		}
	}

	public function findById(id:String):Null<Node> {
		return byId.get(id);
	}

	// The node with that id as the class a caller expects, which fails loudly when the scene has no such node or it is another class.
	public function getById<T:Node>(id:String, type:Class<T>):T {
		var node = byId.get(id);
		if (node == null) {
			throw 'The scene $name has no node "$id".';
		}
		var typed = Std.downcast(node, type);
		if (typed == null) {
			throw 'The node "$id" of the scene $name is not a ${Type.getClassName(type)}.';
		}
		return typed;
	}

	// Names are not unique, so this is the first match in tree order.
	public function findByName(name:String):Null<Node> {
		return search(root, name);
	}

	function search(node:Node, name:String):Null<Node> {
		for (child in node.children) {
			if (child.name == name) {
				return child;
			}
			var found = search(child, name);
			if (found != null) {
				return found;
			}
		}
		return null;
	}

	@:allow(fried.scene.Node)
	function register(node:Node):Void {
		if (node.id != "" && node.scopeOwner == null) {
			byId.set(node.id, node);
		}
		nodeCount++;
		areListsDirty = true;
		areCollidersDirty = true;
	}

	@:allow(fried.scene.Node)
	function unregister(node:Node):Void {
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

	function collect(node:Node, bucket:Null<CanvasBucket>):Void {
		var canvas = Std.downcast(node, CanvasLayer);
		if (canvas != null) {
			bucket = new CanvasBucket(canvas);
			canvasBuckets.push(bucket);
		}
		var flags = node.hooks;
		if (flags != 0) {
			if ((flags & 1) != 0) {
				updateList.push(node);
			}
			if ((flags & 2) != 0) {
				(bucket != null ? bucket.drawList : drawList).push(node);
			}
			if ((flags & 4) != 0) {
				(bucket != null ? bucket.eventTree : eventTree).push(node);
			}
			if ((flags & 16) != 0) {
				fixedUpdateList.push(node);
			}
			if ((flags & 32) != 0) {
				bodyList.push(cast node);
			}
			if ((flags & 64) != 0) {
				meshList.push(cast node);
			}
			if ((flags & 128) != 0) {
				lightList.push(cast node);
			}
		}
		for (child in node.children) {
			collect(child, bucket);
		}
	}

	function collectColliders(node:Node):Void {
		if ((node.hooks & 8) != 0) {
			colliders.push(cast node);
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
			if (node.activeInTree) {
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
			if (node.activeInTree) {
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
			if (body.activeInTree) {
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
			if (node.shownInTree) {
				#if fried_editor
				if (isFlatHidden && !Std.isOfType(node, Node3D)) {
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
			if (camera3D != null && camera3D.shownInTree && meshList.length > 0) {
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
			if (!bucket.node.shownInTree) {
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
				if (node.shownInTree) {
					#if fried_editor
					if (isFlatHidden && !Std.isOfType(node, Node3D)) {
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

	function firstLight():Null<DirectionalLight> {
		for (light in lightList) {
			if (light.shownInTree) {
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
			if (bucket.node.shownInTree) {
				dispatch(bucket.eventList, event);
			}
			bucketIndex--;
		}
		if (!event.handled) {
			dispatch(eventList, event);
		}
	}

	function dispatch(list:Array<Node>, event:InputEvent):Void {
		var count = list.length;
		var index = 0;
		while (index < count) {
			if (event.handled) {
				break;
			}
			var node = list[index];
			if (node.activeInTree) {
				node.onEvent(event);
			}
			index++;
		}
	}

	function orderEvents(tree:Array<Node>, list:Array<Node>):Void {
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
			root.removeChild(child);
			child.destroyTree();
		}
		camera = null;
		camera3D = null;
	}

	static function byCanvasLayer(first:CanvasBucket, second:CanvasBucket):Int {
		return first.node.layer - second.node.layer;
	}

	static function byPriorityDescending(first:Node, second:Node):Int {
		return second.sortPriority() - first.sortPriority();
	}
}
