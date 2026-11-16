package fried.nodes;

// A node with a position, a rotation in degrees and a scale in the plane, relative to its parent.
@:serializable
class Node2D extends CanvasItem {
	public var x(default, set):Float;
	public var y(default, set):Float;
	public var rotation(default, set):Float;
	public var scaleX(default, set):Float;
	public var scaleY(default, set):Float;

	public function new(x:Float = 0.0, y:Float = 0.0) {
		super("Node2D");
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

	// With a parent that is not turned or scaled, which is most of them, the world position is the parent's plus this one's, and the DS has no hardware floating point to spare.
	override function ensureWorld():Void {
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
		return value;
	}

	function set_y(value:Float):Float {
		y = value;
		markWorldDirty();
		return value;
	}

	function set_rotation(value:Float):Float {
		rotation = value;
		markWorldDirty();
		return value;
	}

	function set_scaleX(value:Float):Float {
		scaleX = value;
		markWorldDirty();
		return value;
	}

	function set_scaleY(value:Float):Float {
		scaleY = value;
		markWorldDirty();
		return value;
	}
}
