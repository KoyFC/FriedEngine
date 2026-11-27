package fried.graphics3d;

@:serializable
class PrismMesh extends PrimitiveMesh {
	public var leftToRight(default, set):Float;
	public var sizeX(default, set):Float;
	public var sizeY(default, set):Float;
	public var sizeZ(default, set):Float;

	public function new() {
		super();
		@:bypassAccessor leftToRight = 0.5;
		@:bypassAccessor sizeX = 1.0;
		@:bypassAccessor sizeY = 1.0;
		@:bypassAccessor sizeZ = 1.0;
	}

	function build(builder:MeshBuilder):Void {
		var left = -sizeX / 2.0;
		var right = sizeX / 2.0;
		var top = left + sizeX * leftToRight;
		var up = sizeY / 2.0;
		var down = -sizeY / 2.0;
		var near = -sizeZ / 2.0;
		var far = sizeZ / 2.0;
		triangle(builder, left, down, near, 0.0, 1.0, right, down, near, 1.0, 1.0, top, up, near, leftToRight, 0.0);
		triangle(builder, left, down, far, 0.0, 1.0, right, down, far, 1.0, 1.0, top, up, far, leftToRight, 0.0);
		quad(builder, left, down, near, right, down, near, right, down, far, left, down, far);
		quad(builder, left, down, near, top, up, near, top, up, far, left, down, far);
		quad(builder, right, down, near, top, up, near, top, up, far, right, down, far);
		MeshTools.orientOutward(builder.vertices, builder.indices, (left + right + top) / 3.0, (down + down + up) / 3.0, 0.0);
	}

	function triangle(builder:MeshBuilder, ax:Float, ay:Float, az:Float, au:Float, av:Float, bx:Float, by:Float, bz:Float, bu:Float, bv:Float, cx:Float,
			cy:Float, cz:Float, cu:Float, cv:Float):Void {
		builder.triangle(builder.vertex(ax, ay, az, au, av), builder.vertex(bx, by, bz, bu, bv), builder.vertex(cx, cy, cz, cu, cv));
	}

	function quad(builder:MeshBuilder, ax:Float, ay:Float, az:Float, bx:Float, by:Float, bz:Float, cx:Float, cy:Float, cz:Float, dx:Float, dy:Float,
			dz:Float):Void {
		var a = builder.vertex(ax, ay, az, 0.0, 0.0);
		var b = builder.vertex(bx, by, bz, 1.0, 0.0);
		var c = builder.vertex(cx, cy, cz, 1.0, 1.0);
		var d = builder.vertex(dx, dy, dz, 0.0, 1.0);
		builder.triangle(a, b, c);
		builder.triangle(a, c, d);
	}

	function set_leftToRight(value:Float):Float {
		leftToRight = value;
		rebuild();
		return value;
	}

	function set_sizeX(value:Float):Float {
		sizeX = value;
		rebuild();
		return value;
	}

	function set_sizeY(value:Float):Float {
		sizeY = value;
		rebuild();
		return value;
	}

	function set_sizeZ(value:Float):Float {
		sizeZ = value;
		rebuild();
		return value;
	}
}
