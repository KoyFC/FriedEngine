package fried.scene;

// A node that is drawn: it can be hidden, and it has a place on the screen worked out from the nodes above it.
@:serializable
@:allow(fried.scene)
class CanvasItem extends Node {
	public var visible(default, set):Bool;

	// Drawn in front of lower values, and given an event first.
	public var priority(default, set):Int;

	// Where the node is in the world, after every ancestor's transform. Worked out when read, and again only after something changed.
	@:noSerialize public var worldX(get, never):Float;
	@:noSerialize public var worldY(get, never):Float;
	@:noSerialize public var worldRotation(get, never):Float;
	@:noSerialize public var worldScaleX(get, never):Float;
	@:noSerialize public var worldScaleY(get, never):Float;

	var worldDirty:Bool;
	var parentItem:Null<CanvasItem>;
	var wx:Float;
	var wy:Float;
	var wrot:Float;
	var wsx:Float;
	var wsy:Float;

	public function new(name:String = "CanvasItem") {
		super(name);
		visible = true;
		priority = 0;
		worldDirty = true;
		wx = 0.0;
		wy = 0.0;
		wrot = 0.0;
		wsx = 1.0;
		wsy = 1.0;
	}

	// The subclass that has a transform fills the world values in.
	function ensureWorld():Void {
		worldDirty = false;
	}

	// Stops at a node that is already dirty, whose subtree is dirty with it.
	function markWorldDirty():Void {
		if (worldDirty) {
			return;
		}
		worldDirty = true;
		for (child in children) {
			child.parentTransformChanged();
		}
	}

	override function parentTransformChanged():Void {
		markWorldDirty();
	}

	override function parentChanged():Void {
		parentItem = Std.downcast(parent, CanvasItem);
		markWorldDirty();
	}

	override function ownVisible():Bool {
		return visible;
	}

	override function sortPriority():Int {
		return priority;
	}

	inline function get_worldX():Float {
		if (worldDirty) {
			ensureWorld();
		}
		return wx;
	}

	inline function get_worldY():Float {
		if (worldDirty) {
			ensureWorld();
		}
		return wy;
	}

	inline function get_worldRotation():Float {
		if (worldDirty) {
			ensureWorld();
		}
		return wrot;
	}

	inline function get_worldScaleX():Float {
		if (worldDirty) {
			ensureWorld();
		}
		return wsx;
	}

	inline function get_worldScaleY():Float {
		if (worldDirty) {
			ensureWorld();
		}
		return wsy;
	}

	function set_visible(value:Bool):Bool {
		visible = value;
		refreshFlags();
		return value;
	}

	function set_priority(value:Int):Int {
		priority = value;
		if (scene != null) {
			scene.isEventOrderDirty = true;
		}
		return value;
	}
}
