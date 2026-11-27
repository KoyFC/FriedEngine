package fried.graphics3d;

// A ring, like a doughnut, lying flat around the y axis. innerRadius is how far its hole reaches and outerRadius how far it goes out.
@:serializable
class TorusMesh extends PrimitiveMesh {
	public var innerRadius(default, set):Float;
	public var outerRadius(default, set):Float;
	public var rings(default, set):Int;
	public var ringSegments(default, set):Int;

	public function new() {
		super();
		@:bypassAccessor innerRadius = 0.5;
		@:bypassAccessor outerRadius = 1.0;
		@:bypassAccessor rings = 16;
		@:bypassAccessor ringSegments = 8;
	}

	function build(builder:MeshBuilder):Void {
		var around = Std.int(Math.max(rings, 3));
		var tube = Std.int(Math.max(ringSegments, 3));
		var middle = (outerRadius + innerRadius) / 2.0;
		var thickness = (outerRadius - innerRadius) / 2.0;
		var first = Std.int(builder.vertices.length / 3);
		for (ring in 0...around + 1) {
			var u = ring / around;
			var x = ring == around ? 0.0 : -Math.sin(u * 2.0 * Math.PI);
			var z = ring == around ? 1.0 : Math.cos(u * 2.0 * Math.PI);
			for (segment in 0...tube + 1) {
				var v = segment / tube;
				var angle = segment == tube ? 0.0 : v * 2.0 * Math.PI;
				var reach = middle + thickness * Math.cos(angle);
				builder.vertex(x * reach, thickness * Math.sin(angle), z * reach, u, v);
			}
		}
		builder.strips(first, tube + 1, around + 1);
		MeshTools.orientAroundRing(builder.vertices, builder.indices, middle);
	}

	function set_innerRadius(value:Float):Float {
		innerRadius = value;
		rebuild();
		return value;
	}

	function set_outerRadius(value:Float):Float {
		outerRadius = value;
		rebuild();
		return value;
	}

	function set_rings(value:Int):Int {
		rings = value;
		rebuild();
		return value;
	}

	function set_ringSegments(value:Int):Int {
		ringSegments = value;
		rebuild();
		return value;
	}
}
