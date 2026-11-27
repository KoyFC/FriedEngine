package fried.graphics3d;

// A cylinder with a half sphere at each end. The height is the whole length, ends included, so it cannot be less than twice the radius.
@:serializable
class CapsuleMesh extends PrimitiveMesh {
	public var radius(default, set):Float;
	public var height(default, set):Float;
	public var radialSegments(default, set):Int;
	public var rings(default, set):Int;

	public function new() {
		super();
		@:bypassAccessor radius = 0.5;
		@:bypassAccessor height = 2.0;
		@:bypassAccessor radialSegments = 16;
		@:bypassAccessor rings = 4;
	}

	function build(builder:MeshBuilder):Void {
		var segments = Std.int(Math.max(radialSegments, 3));
		var steps = Std.int(Math.max(rings, 1));
		var half = Math.max(height - 2.0 * radius, 0.0) / 2.0;
		var first = Std.int(builder.vertices.length / 3);
		// Rows run from the top pole down to the bottom one, each half sphere in as many steps as there are rings.
		for (row in 0...2 * (steps + 1)) {
			var isTop = row <= steps;
			var angle = (isTop ? row : row - steps - 1 + steps) / steps * Math.PI / 2.0;
			// The pole's ring is set exactly, since the sine of pi is not zero.
			var ring = row == 2 * (steps + 1) - 1 ? 0.0 : Math.sin(angle);
			var y = (isTop ? half : -half) + radius * Math.cos(angle);
			var v = (half + radius - y) / (2.0 * (half + radius));
			for (column in 0...segments + 1) {
				var u = column / segments;
				var x = column == segments ? 0.0 : -Math.sin(u * 2.0 * Math.PI);
				var z = column == segments ? 1.0 : Math.cos(u * 2.0 * Math.PI);
				builder.vertex(x * ring * radius, y, z * ring * radius, u, v);
			}
		}
		builder.strips(first, segments + 1, 2 * (steps + 1));
		MeshTools.orientOutward(builder.vertices, builder.indices, 0.0, 0.0, 0.0);
	}

	function set_radius(value:Float):Float {
		radius = value;
		rebuild();
		return value;
	}

	function set_height(value:Float):Float {
		height = value;
		rebuild();
		return value;
	}

	function set_radialSegments(value:Int):Int {
		radialSegments = value;
		rebuild();
		return value;
	}

	function set_rings(value:Int):Int {
		rings = value;
		rebuild();
		return value;
	}
}
