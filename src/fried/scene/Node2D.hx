package fried.scene;

// A node with a position, a rotation in degrees and a scale in the plane, relative to its parent.
@:serializable
class Node2D extends CanvasItem {
	public var x(default, set):Single;
	public var y(default, set):Single;
	public var rotation(default, set):Single;
	public var scaleX(default, set):Single;
	public var scaleY(default, set):Single;

	// The place this node's transform has in the native store while it is in a scene, and -1 when it is not in one.
	var slot:Int;

	// A node in a scene whose parent is no CanvasItem or another Node2D, which the store places without Haxe, and that parent when it is a Node2D.
	var isStored:Bool;
	var storedParent:Null<Node2D>;

	// The store's world values are out of date. What the renderer and the colliders read is the store, so they ask for it alone; the doubles that worldDirty guards are then out of date too, and are worked out from the store only when a game or a layout reads them.
	var slotDirty:Bool;

	static var worldValues:Array<Single> = [0.0, 0.0, 0.0, 0.0, 0.0];

	static inline var DEGREES_TO_RADIANS:Single = 0.017453292519943295;
	static inline var ZERO:Single = 0.0;
	static inline var ONE:Single = 1.0;

	public function new(x:Single = 0.0, y:Single = 0.0) {
		super("Node2D");
		slot = -1;
		isStored = false;
		storedParent = null;
		slotDirty = true;
		this.x = x;
		this.y = y;
		rotation = 0.0;
		scaleX = 1.0;
		scaleY = 1.0;
	}

	public function translate(dx:Single, dy:Single):Void {
		x += dx;
		y += dy;
	}

	public function setScale(scale:Single):Void {
		scaleX = scale;
		scaleY = scale;
	}

	override function enterScene(entered:Scene):Void {
		slot = Transform2D.create();
		storedParent = Std.downcast(parentItem, Node2D);
		isStored = parentItem == null || storedParent != null;
		Transform2D.setParent(slot, storedParent != null ? storedParent.slot : -1);
		Transform2D.setLocal(slot, x, y, rotation, scaleX, scaleY);
		invalidateWorld();
		super.enterScene(entered);
	}

	override function leaveScene():Void {
		super.leaveScene();
		Transform2D.release(slot);
		slot = -1;
		isStored = false;
		storedParent = null;
	}

	// Stops at a node whose world values and whose store are both out of date, whose subtree is out of date with it.
	override function markWorldDirty():Void {
		if (slotDirty && worldDirty) {
			return;
		}
		invalidateWorld();
	}

	function invalidateWorld():Void {
		slotDirty = true;
		worldDirty = true;
		for (child in children) {
			child.parentTransformChanged();
		}
	}

	// Makes the store's world values current, which is all a draw or a collider needs. A node the store cannot place is worked out in Haxe, which hands the result to the store.
	function ensureSlot():Void {
		if (!slotDirty) {
			return;
		}
		if (!isStored) {
			ensureWorld();
			return;
		}
		if (storedParent != null && storedParent.slotDirty) {
			storedParent.ensureSlot();
		}
		slotDirty = false;
		Transform2D.update(slot);
	}

	// In a scene, under another node of the store, the world values are worked out natively, in fixed point on the DS, and read out as doubles here. A node under no parent is its own world, and one outside a scene, or under a Control, whose layout reads the cache, is worked out in Haxe.
	override function ensureWorld():Void {
		if (isStored) {
			if (storedParent == null) {
				worldDirty = false;
				wx = x;
				wy = y;
				wrot = rotation;
				wsx = scaleX;
				wsy = scaleY;
				return;
			}
			ensureSlot();
			worldDirty = false;
			var out = worldValues;
			Transform2D.readWorld(slot, cpp.Pointer.ofArray(out).raw);
			wx = out[0];
			wy = out[1];
			wrot = out[2];
			wsx = out[3];
			wsy = out[4];
			return;
		}
		computeWorldInHaxe();
		if (slot >= 0) {
			var out = worldValues;
			out[0] = wx;
			out[1] = wy;
			out[2] = wrot;
			out[3] = wsx;
			out[4] = wsy;
			Transform2D.setWorld(slot, cpp.Pointer.ofArray(out).constRaw);
			slotDirty = false;
		}
	}

	// With a parent that is not turned or scaled, which is most of them, the world position is the parent's plus this one's, and the DS has no hardware floating point to spare.
	function computeWorldInHaxe():Void {
		worldDirty = false;
		var p = parentItem;
		if (p == null) {
			wx = x;
			wy = y;
			wrot = rotation;
			wsx = scaleX;
			wsy = scaleY;
			return;
		}
		if (p.worldDirty) {
			p.ensureWorld();
		}
		if (p.wrot == ZERO && p.wsx == ONE && p.wsy == ONE) {
			wx = p.wx + x;
			wy = p.wy + y;
			wrot = rotation;
			wsx = scaleX;
			wsy = scaleY;
			return;
		}
		var scaledX:Single = x * p.wsx;
		var scaledY:Single = y * p.wsy;
		if (p.wrot != ZERO) {
			var radians:Single = p.wrot * DEGREES_TO_RADIANS;
			var cosine:Single = Math.cos(radians);
			var sine:Single = Math.sin(radians);
			wx = p.wx + scaledX * cosine - scaledY * sine;
			wy = p.wy + scaledX * sine + scaledY * cosine;
		} else {
			wx = p.wx + scaledX;
			wy = p.wy + scaledY;
		}
		wrot = p.wrot + rotation;
		wsx = p.wsx * scaleX;
		wsy = p.wsy * scaleY;
	}

	function set_x(value:Single):Single {
		x = value;
		markWorldDirty();
		if (slot >= 0) {
			Transform2D.setX(slot, value);
		}
		return value;
	}

	function set_y(value:Single):Single {
		y = value;
		markWorldDirty();
		if (slot >= 0) {
			Transform2D.setY(slot, value);
		}
		return value;
	}

	function set_rotation(value:Single):Single {
		rotation = value;
		markWorldDirty();
		if (slot >= 0) {
			Transform2D.setRotation(slot, value);
		}
		return value;
	}

	function set_scaleX(value:Single):Single {
		scaleX = value;
		markWorldDirty();
		if (slot >= 0) {
			Transform2D.setScaleX(slot, value);
		}
		return value;
	}

	function set_scaleY(value:Single):Single {
		scaleY = value;
		markWorldDirty();
		if (slot >= 0) {
			Transform2D.setScaleY(slot, value);
		}
		return value;
	}
}
