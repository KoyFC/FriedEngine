package fried.graphics3d;

import fried.graphics.Color;

// A triangle is seen from the side its corners turn clockwise on, and not drawn from the other.
class Mesh {
	public var vertices(default, null):Array<Float>;
	public var indices(default, null):Array<Int>;
	public var triangleColors(default, null):Array<Color>;

	public function new(vertices:Array<Float>, indices:Array<Int>, triangleColors:Array<Color>) {
		if (vertices.length % 3 != 0) {
			throw 'A mesh takes three coordinates per vertex, but got ${vertices.length}.';
		}
		if (indices.length != triangleColors.length * 3) {
			throw 'A mesh takes three indices per colour, but ${indices.length} came with ${triangleColors.length} colours.';
		}
		var vertexCount = Std.int(vertices.length / 3);
		for (index in indices) {
			if (index < 0 || index >= vertexCount) {
				throw 'A mesh index of $index is outside its $vertexCount vertices.';
			}
		}
		this.vertices = vertices;
		this.indices = indices;
		this.triangleColors = triangleColors;
	}
}
