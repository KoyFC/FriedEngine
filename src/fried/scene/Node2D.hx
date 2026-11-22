package fried.scene;

// A node with a position, a rotation in degrees and a scale in the plane, relative to its parent.
@:serializable
class Node2D extends CanvasItem {
	public var x(default, set):Float;
	public var y(default, set):Float;
	public var rotation(default, set):Float;
	public var scaleX(default, set):Float;
	public var scaleY(default, set):Float;

	// The place this node's transform has in the native store while it is in a scene, and -1 when it is not in one.
	var slot:Int;

	static var worldValues:Array<Float> = [0.0, 0.0, 0.0, 0.0, 0.0];

	public function new(x:Float = 0.0, y:Float = 0.0) {
		super("Node2D");
		slot = -1;
		this.x = x;
		this.y = y;
		rotation = 0.0;
		scaleX = 1.0;
		scaleY = 1.0;
	}

	public function translate(dx:Float, dy:Float):Void {
		x += dx;
		y += dy;
	}

	public function setScale(scale:Float):Void {
		scaleX = scale;
		scaleY = scale;
	}

	override function enterScene(entered:Scene):Void {
		slot = Transform2D.create();
		var parentNode = Std.downcast(parentItem, Node2D);
		Transform2D.setParent(slot, parentNode != null ? parentNode.slot : -1);
		Transform2D.setLocal(slot, x, y, rotation, scaleX, scaleY);
		markWorldDirty();
		super.enterScene(entered);
	}

	override function leaveScene():Void {
		super.leaveScene();
		Transform2D.release(slot);
		slot = -1;
	}

	// In a scene, under no parent or another node of the store, the world values are worked out natively, in fixed point on the DS. A node outside a scene, or under a Control, whose layout reads the cache, is worked out here.
	override function ensureWorld():Void {
		var item = parentItem;
		var parentNode = Std.downcast(item, Node2D);
		if (slot >= 0 && (item == null || (parentNode != null && parentNode.slot >= 0))) {
			if (item != null && item.worldDirty) {
				item.ensureWorld();
			}
			worldDirty = false;
			var out = worldValues;
			Transform2D.compute(slot, cpp.Pointer.ofArray(out).raw);
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
		if (p.wrot == 0.0 && p.wsx == 1.0 && p.wsy == 1.0) {
			wx = p.wx + x;
			wy = p.wy + y;
			wrot = rotation;
			wsx = scaleX;
			wsy = scaleY;
			return;
		}
		var scaledX = x * p.wsx;
		var scaledY = y * p.wsy;
		if (p.wrot != 0.0) {
			var radians = p.wrot * (Math.PI / 180.0);
			var cosine = Math.cos(radians);
			var sine = Math.sin(radians);
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

	function set_x(value:Float):Float {
		x = value;
		markWorldDirty();
		if (slot >= 0) {
			Transform2D.setX(slot, value);
		}
		return value;
	}

	function set_y(value:Float):Float {
		y = value;
		markWorldDirty();
		if (slot >= 0) {
			Transform2D.setY(slot, value);
		}
		return value;
	}

	function set_rotation(value:Float):Float {
		rotation = value;
		markWorldDirty();
		if (slot >= 0) {
			Transform2D.setRotation(slot, value);
		}
		return value;
	}

	function set_scaleX(value:Float):Float {
		scaleX = value;
		markWorldDirty();
		if (slot >= 0) {
			Transform2D.setScaleX(slot, value);
		}
		return value;
	}

	function set_scaleY(value:Float):Float {
		scaleY = value;
		markWorldDirty();
		if (slot >= 0) {
			Transform2D.setScaleY(slot, value);
		}
		return value;
	}
}
