package fried.graphics3d;

import fried.graphics.Color;

// Three coordinates per corner, three corner indices per triangle and one
// colour per triangle. A triangle is seen from the side its corners turn
// clockwise on, and not drawn from the other.
class Mesh {
	public var vertices(default, null):Array<Float>;
	public var indices(default, null):Array<Int>;
	public var colors(default, null):Array<Color>;

	public function new(vertices:Array<Float>, indices:Array<Int>, colors:Array<Color>) {
		if (vertices.length % 3 != 0) {
			throw 'A mesh takes three coordinates per corner, but got ${vertices.length}.';
		}
		if (indices.length != colors.length * 3) {
			throw 'A mesh takes three indices per colour, but ${indices.length} came with ${colors.length} colours.';
		}
		var cornerCount = Std.int(vertices.length / 3);
		for (index in indices) {
			if (index < 0 || index >= cornerCount) {
				throw 'A mesh index of $index is outside its $cornerCount corners.';
			}
		}
		this.vertices = vertices;
		this.indices = indices;
		this.colors = colors;
	}
}
