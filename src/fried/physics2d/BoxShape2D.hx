package fried.physics2d;

// A box, `width` by `height` pixels before the scale of its object.
@:serializable
class BoxShape2D extends Shape2D {
	public var width:Float;
	public var height:Float;

	public function new(width:Float = 32.0, height:Float = 32.0) {
		super();
		this.width = width;
		this.height = height;
	}

	override function create(bodyHandle:Int, centerX:Float, centerY:Float, scale:Float, material:cpp.RawPointer<cpp.Float64>):Int {
		var halfWidth = Math.abs(width * place.worldScaleX) / 2 / scale;
		var halfHeight = Math.abs(height * place.worldScaleY) / 2 / scale;
		return Box2DNative.shapeBox(bodyHandle, halfWidth, halfHeight, centerX, centerY, 0.0, material);
	}

	override function extents(out:Array<Float>):Void {
		var halfWidth = Math.abs(width * place.worldScaleX) / 2;
		var halfHeight = Math.abs(height * place.worldScaleY) / 2;
		out[0] = place.worldX + offsetX - halfWidth;
		out[1] = place.worldY + offsetY - halfHeight;
		out[2] = place.worldX + offsetX + halfWidth;
		out[3] = place.worldY + offsetY + halfHeight;
	}
}
