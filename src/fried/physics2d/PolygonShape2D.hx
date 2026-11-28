package fried.physics2d;

// A convex polygon of up to eight points, written as pairs of numbers in pixels from the center of its object, before its scale: "0,-16 16,16 -16,16".
@:serializable
class PolygonShape2D extends Shape2D {
	public var points:String;

	public function new(points:String = "0,-16 16,16 -16,16") {
		super();
		this.points = points;
	}

	function parse(scaleX:Float, scaleY:Float):Array<Float> {
		var result:Array<Float> = [];
		for (pair in StringTools.trim(points).split(" ")) {
			if (pair == "") {
				continue;
			}
			var parts = pair.split(",");
			var x = parts.length == 2 ? Std.parseFloat(parts[0]) : Math.NaN;
			var y = parts.length == 2 ? Std.parseFloat(parts[1]) : Math.NaN;
			if (Math.isNaN(x) || Math.isNaN(y)) {
				throw 'The points of a PolygonShape2D are pairs like "0,-16 16,16 -16,16", and "$pair" is not one.';
			}
			result.push(x * scaleX);
			result.push(y * scaleY);
		}
		return result;
	}

	override function create(bodyHandle:Int, centerX:Float, centerY:Float, scale:Float, material:cpp.RawPointer<cpp.Float64>):Int {
		var pixels = parse(place.worldScaleX, place.worldScaleY);
		var meters:Array<cpp.Float64> = [];
		for (index in 0...Std.int(pixels.length / 2)) {
			meters.push(centerX + pixels[index * 2] / scale);
			meters.push(centerY + pixels[index * 2 + 1] / scale);
		}
		return Box2DNative.shapePolygon(bodyHandle, cpp.Pointer.ofArray(meters).raw, Std.int(meters.length / 2), material);
	}

	override function extents(out:Array<Float>):Void {
		var pixels = parse(place.worldScaleX, place.worldScaleY);
		var left = Math.POSITIVE_INFINITY;
		var top = Math.POSITIVE_INFINITY;
		var right = Math.NEGATIVE_INFINITY;
		var bottom = Math.NEGATIVE_INFINITY;
		for (index in 0...Std.int(pixels.length / 2)) {
			left = Math.min(left, pixels[index * 2]);
			right = Math.max(right, pixels[index * 2]);
			top = Math.min(top, pixels[index * 2 + 1]);
			bottom = Math.max(bottom, pixels[index * 2 + 1]);
		}
		out[0] = place.worldX + offsetX + left;
		out[1] = place.worldY + offsetY + top;
		out[2] = place.worldX + offsetX + right;
		out[3] = place.worldY + offsetY + bottom;
	}
}
