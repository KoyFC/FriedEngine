package fried.physics;

class RaycastHit {
	public var collider(default, null):Collider;
	public var distance(default, null):Float;
	public var x(default, null):Float;
	public var y(default, null):Float;
	public var normalX(default, null):Float;
	public var normalY(default, null):Float;

	@:allow(fried.physics.Physics)
	function new(collider:Collider, distance:Float, x:Float, y:Float, normalX:Float, normalY:Float) {
		this.collider = collider;
		this.distance = distance;
		this.x = x;
		this.y = y;
		this.normalX = normalX;
		this.normalY = normalY;
	}
}
