package fried.physics2d;

// A circle of `radius` pixels before the scale of its object, which is the larger of the two scales.
@:serializable
class CircleShape2D extends Shape2D {
	public var radius:Float;

	public function new(radius:Float = 16.0) {
		super();
		this.radius = radius;
	}

	function worldRadius():Float {
		return radius * Math.max(Math.abs(place.worldScaleX), Math.abs(place.worldScaleY));
	}

	override function create(bodyHandle:Int, centerX:Float, centerY:Float, scale:Float, material:cpp.RawPointer<cpp.Float64>):Int {
		return Box2DNative.shapeCircle(bodyHandle, worldRadius() / scale, centerX, centerY, material);
	}

	override function extents(out:Array<Float>):Void {
		var size = worldRadius();
		out[0] = place.worldX + offsetX - size;
		out[1] = place.worldY + offsetY - size;
		out[2] = place.worldX + offsetX + size;
		out[3] = place.worldY + offsetY + size;
	}
}
