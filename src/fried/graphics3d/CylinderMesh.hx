package fried.graphics3d;

// A cylinder, or a cone when one of its radii is zero, with a flat cap at each end unless it is turned off.
@:serializable
class CylinderMesh extends PrimitiveMesh {
	public var topRadius(default, set):Float;
	public var bottomRadius(default, set):Float;
	public var height(default, set):Float;
	public var radialSegments(default, set):Int;
	public var rings(default, set):Int;
	public var capTop(default, set):Bool;
	public var capBottom(default, set):Bool;

	public function new() {
		super();
		@:bypassAccessor topRadius = 0.5;
		@:bypassAccessor bottomRadius = 0.5;
		@:bypassAccessor height = 2.0;
		@:bypassAccessor radialSegments = 16;
		@:bypassAccessor rings = 0;
		@:bypassAccessor capTop = true;
		@:bypassAccessor capBottom = true;
	}

	function build(builder:MeshBuilder):Void {
		var segments = Std.int(Math.max(radialSegments, 3));
		var rows = Std.int(Math.max(rings, 0)) + 1;
		var first = Std.int(builder.vertices.length / 3);
		for (row in 0...rows + 1) {
			var v = row / rows;
			var radius = topRadius + (bottomRadius - topRadius) * v;
			var y = height * (0.5 - v);
			for (column in 0...segments + 1) {
				var u = column / segments;
				var x = column == segments ? 0.0 : -Math.sin(u * 2.0 * Math.PI);
				var z = column == segments ? 1.0 : Math.cos(u * 2.0 * Math.PI);
				builder.vertex(x * radius, y, z * radius, u, v);
			}
		}
		builder.strips(first, segments + 1, rows + 1);
		if (capTop) {
			cap(builder, height / 2.0, topRadius, segments);
		}
		if (capBottom) {
			cap(builder, -height / 2.0, bottomRadius, segments);
		}
		// The shape is convex, so a triangle faces outward when it faces away from a point inside.
		MeshTools.orientOutward(builder.vertices, builder.indices, 0.0, 0.0, 0.0);
	}

	// A fan of triangles from the middle of a circle, with the image laid over it as a disc.
	function cap(builder:MeshBuilder, y:Float, radius:Float, segments:Int):Void {
		var middle = builder.vertex(0.0, y, 0.0, 0.5, 0.5);
		var first = Std.int(builder.vertices.length / 3);
		for (column in 0...segments + 1) {
			var u = column / segments;
			var x = column == segments ? 0.0 : -Math.sin(u * 2.0 * Math.PI);
			var z = column == segments ? 1.0 : Math.cos(u * 2.0 * Math.PI);
			builder.vertex(x * radius, y, z * radius, 0.5 + x * 0.5, 0.5 + z * 0.5);
		}
		for (column in 0...segments) {
			builder.triangle(middle, first + column, first + column + 1);
		}
	}

	function set_topRadius(value:Float):Float {
		topRadius = value;
		rebuild();
		return value;
	}

	function set_bottomRadius(value:Float):Float {
		bottomRadius = value;
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

	function set_capTop(value:Bool):Bool {
		capTop = value;
		rebuild();
		return value;
	}

	function set_capBottom(value:Bool):Bool {
		capBottom = value;
		rebuild();
		return value;
	}
}
