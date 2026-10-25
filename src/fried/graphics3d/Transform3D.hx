package fried.graphics3d;

// Rotation is in degrees, applied about x, then y, then z.
class Transform3D {
	public var position:Vec3;
	public var rotation:Vec3;
	public var scale:Float;

	public function new(x:Float = 0.0, y:Float = 0.0, z:Float = 0.0) {
		position = new Vec3(x, y, z);
		rotation = new Vec3();
		scale = 1.0;
	}
}
