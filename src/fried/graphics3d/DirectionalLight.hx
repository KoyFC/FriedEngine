package fried.graphics3d;

// The direction is the way the light travels. Ambient is the share of a
// triangle's colour it keeps when it faces away, from 0 to 1.
class DirectionalLight {
	public var direction:Vec3;
	public var ambient:Float;

	public function new(direction:Vec3, ambient:Float = 0.3) {
		this.direction = direction;
		this.ambient = ambient;
	}
}
