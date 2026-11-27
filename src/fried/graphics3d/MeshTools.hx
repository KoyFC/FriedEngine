package fried.graphics3d;

import fried.graphics.Color;

class MeshTools {
	public static function multiply(first:Color, second:Color):Color {
		return Color.rgba(Std.int(first.red * second.red / 255), Std.int(first.green * second.green / 255), Std.int(first.blue * second.blue / 255),
			Std.int(first.alpha * second.alpha / 255));
	}

	// A mirror on x turns the corners the other way, so the second and third swap back.
	public static function toEngineSpace(vertices:Array<Float>, indices:Array<Int>):Void {
		var index = 0;
		while (index < vertices.length) {
			vertices[index] = -vertices[index];
			index += 3;
		}
		var triangle = 0;
		while (triangle < indices.length) {
			var swap = indices[triangle + 1];
			indices[triangle + 1] = indices[triangle + 2];
			indices[triangle + 2] = swap;
			triangle += 3;
		}
	}

	public static function orientOutward(vertices:Array<Float>, indices:Array<Int>, insideX:Float, insideY:Float, insideZ:Float):Void {
		var triangle = 0;
		while (triangle < indices.length) {
			if (normalDot(vertices, indices, triangle, vertexCentroid(vertices, indices, triangle, 0) - insideX,
				vertexCentroid(vertices, indices, triangle, 1) - insideY, vertexCentroid(vertices, indices, triangle, 2) - insideZ) < 0.0) {
				swapCorners(indices, triangle);
			}
			triangle += 3;
		}
	}

	public static function orientAroundRing(vertices:Array<Float>, indices:Array<Int>, ringRadius:Float):Void {
		var triangle = 0;
		while (triangle < indices.length) {
			var x = vertexCentroid(vertices, indices, triangle, 0);
			var y = vertexCentroid(vertices, indices, triangle, 1);
			var z = vertexCentroid(vertices, indices, triangle, 2);
			var length = Math.sqrt(x * x + z * z);
			var centerX = length > 0.0 ? x / length * ringRadius : 0.0;
			var centerZ = length > 0.0 ? z / length * ringRadius : 0.0;
			if (normalDot(vertices, indices, triangle, x - centerX, y, z - centerZ) < 0.0) {
				swapCorners(indices, triangle);
			}
			triangle += 3;
		}
	}

	public static function dropEmpty(vertices:Array<Float>, indices:Array<Int>):Void {
		var kept = 0;
		var triangle = 0;
		while (triangle < indices.length) {
			if (normalDot(vertices, indices, triangle, 1.0, 0.0, 0.0) != 0.0 || normalDot(vertices, indices, triangle, 0.0, 1.0, 0.0) != 0.0
				|| normalDot(vertices, indices, triangle, 0.0, 0.0, 1.0) != 0.0) {
				indices[kept++] = indices[triangle];
				indices[kept++] = indices[triangle + 1];
				indices[kept++] = indices[triangle + 2];
			}
			triangle += 3;
		}
		indices.resize(kept);
	}

	static function vertexCentroid(vertices:Array<Float>, indices:Array<Int>, triangle:Int, axis:Int):Float {
		return (vertices[indices[triangle] * 3 + axis] + vertices[indices[triangle + 1] * 3 + axis] + vertices[indices[triangle + 2] * 3 + axis]) / 3.0;
	}

	static function normalDot(vertices:Array<Float>, indices:Array<Int>, triangle:Int, directionX:Float, directionY:Float, directionZ:Float):Float {
		var a = indices[triangle] * 3;
		var b = indices[triangle + 1] * 3;
		var c = indices[triangle + 2] * 3;
		var abX = vertices[b] - vertices[a];
		var abY = vertices[b + 1] - vertices[a + 1];
		var abZ = vertices[b + 2] - vertices[a + 2];
		var acX = vertices[c] - vertices[a];
		var acY = vertices[c + 1] - vertices[a + 1];
		var acZ = vertices[c + 2] - vertices[a + 2];
		var normalX = abY * acZ - abZ * acY;
		var normalY = abZ * acX - abX * acZ;
		var normalZ = abX * acY - abY * acX;
		return normalX * directionX + normalY * directionY + normalZ * directionZ;
	}

	static function swapCorners(indices:Array<Int>, triangle:Int):Void {
		var swap = indices[triangle + 1];
		indices[triangle + 1] = indices[triangle + 2];
		indices[triangle + 2] = swap;
	}
}
