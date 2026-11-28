package fried.physics2d;

// An upright capsule `height` pixels tall in all, rounded by `radius`, before the scale of its object.
@:serializable
class CapsuleShape2D extends Shape2D {
	public var height:Float;
	public var radius:Float;

	public function new(height:Float = 48.0, radius:Float = 12.0) {
		super();
		this.height = height;
		this.radius = radius;
	}

	function worldRadius():Float {
		return radius * Math.abs(place.worldScaleX);
	}

	function halfSegment():Float {
		return Math.max(0.0, Math.abs(height * place.worldScaleY) / 2 - worldRadius());
	}

	override function create(bodyHandle:Int, centerX:Float, centerY:Float, scale:Float, material:cpp.RawPointer<cpp.Float64>):Int {
		var half = halfSegment() / scale;
		return Box2DNative.shapeCapsule(bodyHandle, centerX, centerY - half, centerX, centerY + half, worldRadius() / scale, material);
	}

	override function extents(out:Array<Float>):Void {
		var size = worldRadius();
		var half = halfSegment();
		out[0] = place.worldX + offsetX - size;
		out[1] = place.worldY + offsetY - half - size;
		out[2] = place.worldX + offsetX + size;
		out[3] = place.worldY + offsetY + half + size;
	}
}
