package fried.scene;

import fried.graphics3d.Rotation;

// A node with a position, a rotation in degrees about each axis and a scale on each, relative to the nearest Node3D above it. It is left handed with y up and z forward, and turns about z, then x, then y.
//
// A 2D node under it is placed as if it had no parent, since the plane of the screen is not part of the 3D world.
@:serializable
class Node3D extends CanvasItem {
	public var x(default, set):Float;
	public var y(default, set):Float;
	public var z(default, set):Float;
	public var rotationX(default, set):Float;
	public var rotationY(default, set):Float;
	public var rotationZ(default, set):Float;
	public var scaleX(default, set):Float;
	public var scaleY(default, set):Float;
	public var scaleZ(default, set):Float;

	// Where the node is in the world, the world's x and y being CanvasItem's worldX and worldY.
	@:noSerialize public var worldZ(get, never):Float;
	@:noSerialize public var worldRotationX(get, never):Float;
	@:noSerialize public var worldRotationY(get, never):Float;
	@:noSerialize public var worldRotationZ(get, never):Float;
	@:noSerialize public var worldScaleZ(get, never):Float;

	var wz:Float;
	var wrx:Float;
	var wry:Float;
	var wrz:Float;
	var wsz:Float;

	// Whether the world rotation is zero and the world scale is one, which most nodes under a parent are, and which spares their children the sums of a turned or scaled one.
	var hasPlainTurn:Bool;
	var parent3D:Null<Node3D>;

	static var parentTurn:Array<Float> = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
	static var ownTurn:Array<Float> = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
	static var worldTurn:Array<Float> = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
	static var angles:Array<Float> = [0.0, 0.0, 0.0];

	public function new(x:Float = 0.0, y:Float = 0.0, z:Float = 0.0) {
		super("Node3D");
		this.x = x;
		this.y = y;
		this.z = z;
		rotationX = 0.0;
		rotationY = 0.0;
		rotationZ = 0.0;
		scaleX = 1.0;
		scaleY = 1.0;
		scaleZ = 1.0;
		wz = 0.0;
		wrx = 0.0;
		wry = 0.0;
		wrz = 0.0;
		wsz = 1.0;
		hasPlainTurn = true;
	}

	public function translate(dx:Float, dy:Float, dz:Float):Void {
		x += dx;
		y += dy;
		z += dz;
	}

	public function setScale(scale:Float):Void {
		scaleX = scale;
		scaleY = scale;
		scaleZ = scale;
	}

	override function parentChanged():Void {
		super.parentChanged();
		parent3D = Std.downcast(parent, Node3D);
	}

	// With a parent that is not turned or scaled, which is most of them, the world position is the parent's plus this one's, and the DS has no hardware floating point to spare.
	override function ensureWorld():Void {
		worldDirty = false;
		var p = parent3D;
		if (p == null) {
			wx = x;
			wy = y;
			wz = z;
			wrx = rotationX;
			wry = rotationY;
			wrz = rotationZ;
			wsx = scaleX;
			wsy = scaleY;
			wsz = scaleZ;
		} else {
			if (p.worldDirty) {
				p.ensureWorld();
			}
			if (p.hasPlainTurn) {
				wx = p.wx + x;
				wy = p.wy + y;
				wz = p.wz + z;
				wrx = rotationX;
				wry = rotationY;
				wrz = rotationZ;
				wsx = scaleX;
				wsy = scaleY;
				wsz = scaleZ;
			} else if (p.wrx == 0.0 && p.wry == 0.0 && p.wrz == 0.0) {
				wx = p.wx + x * p.wsx;
				wy = p.wy + y * p.wsy;
				wz = p.wz + z * p.wsz;
				wrx = rotationX;
				wry = rotationY;
				wrz = rotationZ;
				wsx = p.wsx * scaleX;
				wsy = p.wsy * scaleY;
				wsz = p.wsz * scaleZ;
			} else {
				Rotation.toMatrix(p.wrx, p.wry, p.wrz, parentTurn);
				var scaledX = x * p.wsx;
				var scaledY = y * p.wsy;
				var scaledZ = z * p.wsz;
				wx = p.wx + parentTurn[0] * scaledX + parentTurn[1] * scaledY + parentTurn[2] * scaledZ;
				wy = p.wy + parentTurn[3] * scaledX + parentTurn[4] * scaledY + parentTurn[5] * scaledZ;
				wz = p.wz + parentTurn[6] * scaledX + parentTurn[7] * scaledY + parentTurn[8] * scaledZ;
				Rotation.toMatrix(rotationX, rotationY, rotationZ, ownTurn);
				Rotation.multiply(parentTurn, ownTurn, worldTurn);
				Rotation.toAngles(worldTurn, angles);
				wrx = angles[0];
				wry = angles[1];
				wrz = angles[2];
				wsx = p.wsx * scaleX;
				wsy = p.wsy * scaleY;
				wsz = p.wsz * scaleZ;
			}
		}
		hasPlainTurn = wrx == 0.0 && wry == 0.0 && wrz == 0.0 && wsx == 1.0 && wsy == 1.0 && wsz == 1.0;
	}

	inline function get_worldZ():Float {
		if (worldDirty) {
			ensureWorld();
		}
		return wz;
	}

	inline function get_worldRotationX():Float {
		if (worldDirty) {
			ensureWorld();
		}
		return wrx;
	}

	inline function get_worldRotationY():Float {
		if (worldDirty) {
			ensureWorld();
		}
		return wry;
	}

	inline function get_worldRotationZ():Float {
		if (worldDirty) {
			ensureWorld();
		}
		return wrz;
	}

	inline function get_worldScaleZ():Float {
		if (worldDirty) {
			ensureWorld();
		}
		return wsz;
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

	function set_z(value:Float):Float {
		z = value;
		markWorldDirty();
		return value;
	}

	function set_rotationX(value:Float):Float {
		rotationX = value;
		markWorldDirty();
		return value;
	}

	function set_rotationY(value:Float):Float {
		rotationY = value;
		markWorldDirty();
		return value;
	}

	function set_rotationZ(value:Float):Float {
		rotationZ = value;
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

	function set_scaleZ(value:Float):Float {
		scaleZ = value;
		markWorldDirty();
		return value;
	}
}
