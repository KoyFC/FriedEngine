package fried.graphics3d;

class DirectionalLight {
	public var direction:Vec3;
	public var ambient:Float;

	public function new(direction:Vec3, ambient:Float = 0.3) {
		this.direction = direction;
		this.ambient = ambient;
	}
}
