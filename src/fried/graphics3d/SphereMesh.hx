package fried.graphics3d;

@:serializable
class SphereMesh extends PrimitiveMesh {
	public var radius(default, set):Float;
	public var height(default, set):Float;
	public var radialSegments(default, set):Int;
	public var rings(default, set):Int;
	public var isHemisphere(default, set):Bool;

	public function new() {
		super();
		@:bypassAccessor radius = 0.5;
		@:bypassAccessor height = 1.0;
		@:bypassAccessor radialSegments = 16;
		@:bypassAccessor rings = 8;
		@:bypassAccessor isHemisphere = false;
	}

	function build(builder:MeshBuilder):Void {
		var segments = Std.int(Math.max(radialSegments, 3));
		var rows = Std.int(Math.max(rings, 1)) + 1;
		var scale = radius > 0.0 ? height / radius * (isHemisphere ? 1.0 : 0.5) : 0.0;
		var first = Std.int(builder.vertices.length / 3);
		for (row in 0...rows + 1) {
			var v = row / rows;
			// The pole is set exactly, since sin(pi) is not zero.
			var ring = row == rows ? 0.0 : Math.sin(Math.PI * v);
			var y = row == rows ? -1.0 : Math.cos(Math.PI * v);
			for (column in 0...segments + 1) {
				var u = column / segments;
				var x = column == segments ? 0.0 : -Math.sin(u * 2.0 * Math.PI);
				var z = column == segments ? 1.0 : Math.cos(u * 2.0 * Math.PI);
				if (isHemisphere && y < 0.0) {
					builder.vertex(x * radius * ring, 0.0, z * radius * ring, u, v);
				} else {
					builder.vertex(x * ring * radius, y * scale * radius, z * ring * radius, u, v);
				}
			}
		}
		builder.strips(first, segments + 1, rows + 1);
		MeshTools.orientOutward(builder.vertices, builder.indices, 0.0, isHemisphere ? Math.abs(height) / 4.0 : 0.0, 0.0);
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

	function set_isHemisphere(value:Bool):Bool {
		isHemisphere = value;
		rebuild();
		return value;
	}
}
