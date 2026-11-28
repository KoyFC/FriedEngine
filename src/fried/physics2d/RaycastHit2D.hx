package fried.physics2d;

class RaycastHit2D {
	public var shape(default, null):Shape2D;
	public var distance(default, null):Float;
	public var x(default, null):Float;
	public var y(default, null):Float;
	public var normalX(default, null):Float;
	public var normalY(default, null):Float;

	@:allow(fried.physics2d)
	function new(shape:Shape2D, distance:Float, x:Float, y:Float, normalX:Float, normalY:Float) {
		this.shape = shape;
		this.distance = distance;
		this.x = x;
		this.y = y;
		this.normalX = normalX;
		this.normalY = normalY;
	}
}
