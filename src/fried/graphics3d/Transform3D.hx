package fried.graphics3d;

// Scaled, then turned about x, y and z in that order, in degrees, then moved.
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
