package fried.graphics3d;

@:serializable
class PlaneMesh extends PrimitiveMesh {
	public var sizeX(default, set):Float;
	public var sizeZ(default, set):Float;
	public var subdivideWidth(default, set):Int;
	public var subdivideDepth(default, set):Int;
	public var orientation(default, set):PlaneOrientation;

	public function new() {
		super();
		@:bypassAccessor sizeX = 2.0;
		@:bypassAccessor sizeZ = 2.0;
		@:bypassAccessor subdivideWidth = 0;
		@:bypassAccessor subdivideDepth = 0;
		@:bypassAccessor orientation = FaceY;
	}

	function build(builder:MeshBuilder):Void {
		var columns = Std.int(Math.max(subdivideWidth, 0)) + 1;
		var rows = Std.int(Math.max(subdivideDepth, 0)) + 1;
		var x = sizeX / 2.0;
		var z = sizeZ / 2.0;
		switch (orientation) {
			case FaceX:
				builder.grid(0, z, -x, 0, 0, sizeX, 0, -sizeZ, 0, columns, rows, 0, 0, 1, 1);
			case FaceY:
				builder.grid(-x, 0, z, sizeX, 0, 0, 0, 0, -sizeZ, columns, rows, 0, 0, 1, 1);
			case FaceZ:
				builder.grid(x, z, 0, -sizeX, 0, 0, 0, -sizeZ, 0, columns, rows, 0, 0, 1, 1);
		}
	}

	function set_sizeX(value:Float):Float {
		sizeX = value;
		rebuild();
		return value;
	}

	function set_sizeZ(value:Float):Float {
		sizeZ = value;
		rebuild();
		return value;
	}

	function set_subdivideWidth(value:Int):Int {
		subdivideWidth = value;
		rebuild();
		return value;
	}

	function set_subdivideDepth(value:Int):Int {
		subdivideDepth = value;
		rebuild();
		return value;
	}

	function set_orientation(value:PlaneOrientation):PlaneOrientation {
		orientation = value;
		rebuild();
		return value;
	}
}
