package fried.nodes;

import fried.graphics.DrawQueue;
import fried.graphics.Renderer;
import fried.input.InputEvent;
import fried.nodes.physics.Collider;
import haxe.ds.ArraySort;

// A tree of nodes and the lists a frame runs through. The lists hold only the nodes whose class overrides the hook, in tree order, and are filled again only when the tree changed, so a frame never walks the tree.
@:allow(fried.nodes)
class Scene {
	public var name:String;

	public var camera:Null<Camera>;

	public var nodeCount(default, null):Int;

	// The size of the view the scene is drawn to, which a node reads instead of holding the renderer. Zero until the scene has been given one.
	public var viewWidth(default, null):Int;
	public var viewHeight(default, null):Int;

	// Every node of the scene sits under this one, which is never drawn or updated.
	public var root(default, null):Node;

	@:allow(fried.nodes.CanvasItem)
	var isEventOrderDirty:Bool;

	var byId:Map<String, Node>;
	var updateList:Array<Node>;
	var drawList:Array<Node>;
	var eventTree:Array<Node>;
	var eventList:Array<Node>;
	var colliders:Array<Collider>;
	var areListsDirty:Bool;

	public function new(name:String = "Scene") {
		this.name = name;
		viewWidth = 0;
		viewHeight = 0;
		nodeCount = 0;
		byId = new Map();
		updateList = [];
		drawList = [];
		eventTree = [];
		eventList = [];
		colliders = [];
		areListsDirty = false;
		isEventOrderDirty = false;
		root = new Node("Root");
		root.enterScene(this);
	}

	@:allow(fried.nodes.SceneLayer)
	@:allow(fried.nodes.serialization.SceneLoader)
	@:allow(fried.nodes.editor.EditorPlayer)
	function setView(width:Int, height:Int):Void {
		viewWidth = width;
		viewHeight = height;
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

	@:allow(fried.nodes.Node)
	function register(node:Node):Void {
		if (node.id != "") {
			byId.set(node.id, node);
		}
		nodeCount++;
		areListsDirty = true;
	}

	@:allow(fried.nodes.Node)
	function unregister(node:Node):Void {
		if (node.id != "" && byId.get(node.id) == node) {
			byId.remove(node.id);
		}
		nodeCount--;
		areListsDirty = true;
	}

	function rebuildLists():Void {
		updateList.resize(0);
		drawList.resize(0);
		eventTree.resize(0);
		colliders.resize(0);
		collect(root);
		areListsDirty = false;
		isEventOrderDirty = true;
	}

	function collect(node:Node):Void {
		var flags = node.hooks;
		if (flags != 0) {
			if ((flags & 1) != 0) {
				updateList.push(node);
			}
			if ((flags & 2) != 0) {
				drawList.push(node);
			}
			if ((flags & 4) != 0) {
				eventTree.push(node);
			}
			if ((flags & 8) != 0) {
				colliders.push(cast node);
			}
		}
		for (child in node.children) {
			collect(child);
		}
	}

	// Every collider of the scene, in tree order, for Physics to test. Whether each is active is for the caller.
	public function activeColliders():Array<Collider> {
		if (areListsDirty) {
			rebuildLists();
		}
		return colliders;
	}

	public function update():Void {
		if (areListsDirty) {
			rebuildLists();
		}
		var list = updateList;
		var count = list.length;
		var index = 0;
		while (index < count) {
			var node = list[index];
			if (node.activeInTree) {
				node.update();
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
				node.draw();
			}
			index++;
		}
	}

	// Top first, the reverse of the order things are drawn in, and a higher priority before a lower one.
	public function propagateEvent(event:InputEvent):Void {
		if (areListsDirty) {
			rebuildLists();
		}
		if (isEventOrderDirty) {
			eventList.resize(0);
			var index = eventTree.length - 1;
			while (index >= 0) {
				eventList.push(eventTree[index]);
				index--;
			}
			ArraySort.sort(eventList, byPriorityDescending);
			isEventOrderDirty = false;
		}
		var list = eventList;
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

	public function destroy():Void {
		for (child in root.children.copy()) {
			root.removeChild(child);
			child.destroyTree();
		}
		camera = null;
	}

	static function byPriorityDescending(first:Node, second:Node):Int {
		return second.sortPriority() - first.sortPriority();
	}
}
