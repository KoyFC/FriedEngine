package fried.graphics3d;

import fried.graphics.Color;

class Surface {
	public var vertices(default, null):Array<Float>;

	public var uvs(default, null):Null<Array<Float>>;

	public var indices(default, null):Array<Int>;

	public var triangleColors(default, null):Null<Array<Color>>;

	public var material:Null<Material>;

	public function new(vertices:Array<Float>, indices:Array<Int>, ?uvs:Array<Float>, ?triangleColors:Array<Color>, ?material:Material) {
		if (vertices.length % 3 != 0) {
			throw 'A mesh takes three coordinates per vertex, but got ${vertices.length}.';
		}
		var vertexCount = Std.int(vertices.length / 3);
		if (indices.length % 3 != 0) {
			throw 'A mesh takes three indices per triangle, but got ${indices.length}.';
		}
		if (uvs != null && uvs.length != vertexCount * 2) {
			throw 'A mesh takes two texture coordinates per vertex, but ${uvs.length} came with $vertexCount vertices.';
		}
		if (triangleColors != null && indices.length != triangleColors.length * 3) {
			throw 'A mesh takes three indices per color, but ${indices.length} came with ${triangleColors.length} colors.';
		}
		for (index in indices) {
			if (index < 0 || index >= vertexCount) {
				throw 'A mesh index of $index is outside its $vertexCount vertices.';
			}
		}
		this.vertices = vertices;
		this.indices = indices;
		this.uvs = uvs;
		this.triangleColors = triangleColors;
		this.material = material;
	}

	public var triangleCount(get, never):Int;

	inline function get_triangleCount():Int {
		return Std.int(indices.length / 3);
	}
}
