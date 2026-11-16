package fried.scene;

import fried.input.InputEvent;

// The base of everything in a scene: a name, a place in a tree, and hooks a game overrides.
//
// A hook is only called if a class overrides it. NodeBuilder notes that when the class is compiled, so a node that does not override update never costs a call, however many there are.
@:build(fried.scene.serialization.NodeBuilder.build())
@:autoBuild(fried.scene.serialization.NodeBuilder.build())
@:serializable
@:allow(fried.scene)
class Node {
	static inline var UPDATE:Int = 1;
	static inline var DRAW:Int = 2;
	static inline var EVENT:Int = 4;
	static inline var COLLIDER:Int = 8;

	// While a scene file is being built, nodes wait here instead of becoming ready, since what they start with may not exist yet.
	@:allow(fried.scene.serialization.SceneLoader)
	static var waitingToReady:Null<Array<Node>>;

	// Empty for a node built in code. A scene file gives each one a stable id.
	@:noSerialize public var id:String;
	@:noSerialize public var name:String;

	// Whether the node and its subtree take part in the frame. A node is active in the tree only while every node above it is.
	public var active(default, set):Bool;

	@:noSerialize public var activeInTree(default, null):Bool;
	@:noSerialize public var shownInTree(default, null):Bool;
	@:noSerialize public var parent(default, null):Null<Node>;
	@:noSerialize public var scene(default, null):Null<Scene>;
	@:noSerialize public var isDestroyed(default, null):Bool;
	@:noSerialize public var childCount(get, never):Int;

	@:allow(fried.scene.Scene)
	@:allow(fried.scene.serialization.SceneLoader)
	@:allow(fried.editor.EditorPlayer)
	@:allow(fried.editor.EditorBounds)
	var children:Array<Node>;

	// What hookFlags said when the node was made.
	@:allow(fried.scene.Scene)
	var hooks:Int;

	var isReady:Bool;

	public function new(name:String = "Node") {
		this.name = name;
		id = "";
		children = [];
		activeInTree = true;
		shownInTree = true;
		active = true;
		isDestroyed = false;
		isReady = false;
		hooks = hookFlags();
	}

	// Called once, after the node and everything its scene file names exist, children before their parent.
	function ready():Void {}

	function update():Void {}

	function draw():Void {}

	function onEvent(event:InputEvent):Void {}

	// Called when the node leaves the game for good, children first.
	function destroyed():Void {}

	// Which hooks the class overrides. NodeBuilder adds an override to every class that declares one.
	function hookFlags():Int {
		return 0;
	}

	function ownVisible():Bool {
		return true;
	}

	function sortPriority():Int {
		return 0;
	}

	function parentChanged():Void {}

	function parentTransformChanged():Void {}

	// The size of the view the scene is drawn to changed.
	function viewChanged():Void {}

	public function addChild<T:Node>(child:T, ?index:Int):T {
		if (child.parent != null) {
			throw 'The node ${child.name} already has the parent ${child.parent.name}.';
		}
		var ancestor:Null<Node> = this;
		while (ancestor != null) {
			if (ancestor == child) {
				throw 'The node ${child.name} cannot be a child of ${name}, which is inside it.';
			}
			ancestor = ancestor.parent;
		}
		if (index == null || index >= children.length) {
			children.push(child);
		} else {
			children.insert(index < 0 ? 0 : index, child);
		}
		child.parent = this;
		child.parentChanged();
		child.refreshFlags();
		if (scene != null) {
			child.enterScene(scene);
			child.readyTree();
		}
		return child;
	}

	public function removeChild(child:Node):Void {
		if (child.parent != this) {
			return;
		}
		children.remove(child);
		child.parent = null;
		child.parentChanged();
		if (scene != null) {
			child.leaveScene();
		}
	}

	public function getChild(index:Int):Node {
		return children[index];
	}

	public function indexOfChild(child:Node):Int {
		return children.indexOf(child);
	}

	// The first direct child of that class.
	public function findChild<T:Node>(type:Class<T>):Null<T> {
		for (child in children) {
			var match = Std.downcast(child, type);
			if (match != null) {
				return match;
			}
		}
		return null;
	}

	// The nearest ancestor of that class.
	public function findParent<T:Node>(type:Class<T>):Null<T> {
		var ancestor = parent;
		while (ancestor != null) {
			var match = Std.downcast(ancestor, type);
			if (match != null) {
				return match;
			}
			ancestor = ancestor.parent;
		}
		return null;
	}

	public function destroy():Void {
		if (isDestroyed) {
			return;
		}
		if (parent != null) {
			parent.removeChild(this);
		}
		destroyTree();
	}

	function destroyTree():Void {
		isDestroyed = true;
		activeInTree = false;
		shownInTree = false;
		for (child in children) {
			child.destroyTree();
		}
		destroyed();
	}

	// Recomputes what depends on the nodes above, and passes a change down once.
	@:allow(fried.scene.CanvasItem)
	function refreshFlags():Void {
		var isActive = active && (parent == null || parent.activeInTree);
		var isShown = isActive && ownVisible() && (parent == null || parent.shownInTree);
		if (isActive == activeInTree && isShown == shownInTree) {
			return;
		}
		activeInTree = isActive;
		shownInTree = isShown;
		for (child in children) {
			child.refreshFlags();
		}
	}

	function enterScene(entered:Scene):Void {
		scene = entered;
		entered.register(this);
		for (child in children) {
			child.enterScene(entered);
		}
	}

	function leaveScene():Void {
		scene.unregister(this);
		scene = null;
		activeInTree = false;
		shownInTree = false;
		for (child in children) {
			child.leaveScene();
		}
	}

	@:allow(fried.scene.Scene)
	function readyTree():Void {
		for (child in children) {
			child.readyTree();
		}
		if (isReady) {
			return;
		}
		isReady = true;
		if (waitingToReady != null) {
			waitingToReady.push(this);
		} else {
			ready();
		}
	}

	function set_active(value:Bool):Bool {
		active = value;
		refreshFlags();
		return value;
	}

	inline function get_childCount():Int {
		return children.length;
	}
}
