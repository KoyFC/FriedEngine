package fried.graphics3d;

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
