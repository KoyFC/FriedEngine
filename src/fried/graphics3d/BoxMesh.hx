package fried.graphics3d;

@:serializable
class BoxMesh extends PrimitiveMesh {
	public var sizeX(default, set):Float;
	public var sizeY(default, set):Float;
	public var sizeZ(default, set):Float;
	public var subdivideWidth(default, set):Int;
	public var subdivideHeight(default, set):Int;
	public var subdivideDepth(default, set):Int;

	public function new() {
		super();
		@:bypassAccessor sizeX = 1.0;
		@:bypassAccessor sizeY = 1.0;
		@:bypassAccessor sizeZ = 1.0;
		@:bypassAccessor subdivideWidth = 0;
		@:bypassAccessor subdivideHeight = 0;
		@:bypassAccessor subdivideDepth = 0;
	}

	function build(builder:MeshBuilder):Void {
		var x = sizeX / 2.0;
		var y = sizeY / 2.0;
		var z = sizeZ / 2.0;
		var width = Std.int(Math.max(subdivideWidth, 0)) + 1;
		var height = Std.int(Math.max(subdivideHeight, 0)) + 1;
		var depth = Std.int(Math.max(subdivideDepth, 0)) + 1;
		var third = 1.0 / 3.0;
		builder.grid(-x, y, -z, sizeX, 0, 0, 0, -sizeY, 0, width, height, 0, 0, third, 0.5);
		builder.grid(x, y, -z, 0, 0, sizeZ, 0, -sizeY, 0, depth, height, third, 0, third, 0.5);
		builder.grid(x, y, z, -sizeX, 0, 0, 0, -sizeY, 0, width, height, 2 * third, 0, third, 0.5);
		builder.grid(-x, y, z, 0, 0, -sizeZ, 0, -sizeY, 0, depth, height, 0, 0.5, third, 0.5);
		builder.grid(-x, y, z, sizeX, 0, 0, 0, 0, -sizeZ, width, depth, third, 0.5, third, 0.5);
		builder.grid(-x, -y, -z, sizeX, 0, 0, 0, 0, sizeZ, width, depth, 2 * third, 0.5, third, 0.5);
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

	function set_subdivideWidth(value:Int):Int {
		subdivideWidth = value;
		rebuild();
		return value;
	}

	function set_subdivideHeight(value:Int):Int {
		subdivideHeight = value;
		rebuild();
		return value;
	}

	function set_subdivideDepth(value:Int):Int {
		subdivideDepth = value;
		rebuild();
		return value;
	}
}
