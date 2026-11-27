package fried.graphics3d;

// Collects the vertices, texture coordinates and triangles that a primitive makes.
class MeshBuilder {
	public var vertices(default, null):Array<Float> = [];
	public var uvs(default, null):Array<Float> = [];
	public var indices(default, null):Array<Int> = [];

	public function new() {}

	public function vertex(x:Float, y:Float, z:Float, u:Float, v:Float):Int {
		vertices.push(x);
		vertices.push(y);
		vertices.push(z);
		uvs.push(u);
		uvs.push(v);
		return Std.int(uvs.length / 2) - 1;
	}

	public function triangle(first:Int, second:Int, third:Int):Void {
		indices.push(first);
		indices.push(second);
		indices.push(third);
	}

	// A rectangle cut into a grid, seen from outside with its corner at the top left and its sides going right and down. Its triangles go round the way the right-hand rule says its normal points, which is the right-hand side vector crossed with the down one, so those two have to be chosen to point it outward.
	public function grid(cornerX:Float, cornerY:Float, cornerZ:Float, rightX:Float, rightY:Float, rightZ:Float, downX:Float, downY:Float, downZ:Float,
			columns:Int, rows:Int, uvLeft:Float, uvTop:Float, uvWidth:Float, uvHeight:Float):Void {
		var first = Std.int(vertices.length / 3);
		for (row in 0...rows + 1) {
			var down = row / rows;
			for (column in 0...columns + 1) {
				var right = column / columns;
				vertex(cornerX + rightX * right + downX * down, cornerY + rightY * right + downY * down, cornerZ + rightZ * right + downZ * down,
					uvLeft + uvWidth * right, uvTop + uvHeight * down);
			}
		}
		for (row in 0...rows) {
			for (column in 0...columns) {
				var topLeft = first + row * (columns + 1) + column;
				var bottomLeft = topLeft + columns + 1;
				triangle(topLeft, topLeft + 1, bottomLeft);
				triangle(topLeft + 1, bottomLeft + 1, bottomLeft);
			}
		}
	}

	// Rows of vertices with the same number in each, joined into triangles whose corners go round the way the rows and columns count. The first row to start is the first one in the vertices.
	public function strips(firstVertex:Int, columnsPerRow:Int, rowCount:Int):Void {
		for (row in 1...rowCount) {
			var previous = firstVertex + (row - 1) * columnsPerRow;
			var current = previous + columnsPerRow;
			for (column in 1...columnsPerRow) {
				triangle(previous + column - 1, previous + column, current + column - 1);
				triangle(previous + column, current + column, current + column - 1);
			}
		}
	}
}
