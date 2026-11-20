package fried.graphics3d;

import fried.graphics.Color;

// Shapes one unit across, centred on the origin, made once for each shape and color and shared by every node that uses them.
class Primitives {
	static inline var SPHERE_SEGMENTS = 8;
	static inline var SPHERE_RINGS = 6;

	static var cache:Map<String, Mesh> = new Map();

	public static function mesh(shape:MeshShape, color:Color):Mesh {
		var key = (cast shape : Int) + ":" + (cast color : Int);
		var found = cache.get(key);
		if (found == null) {
			found = build(shape, color);
			cache.set(key, found);
		}
		return found;
	}

	static function build(shape:MeshShape, color:Color):Mesh {
		var vertices:Array<Float> = [];
		var indices:Array<Int> = [];
		switch (shape) {
			case Cube:
				for (corner in 0...8) {
					vertices.push((corner & 1) != 0 ? 0.5 : -0.5);
					vertices.push((corner & 2) != 0 ? 0.5 : -0.5);
					vertices.push((corner & 4) != 0 ? 0.5 : -0.5);
				}
				indices = [
					2, 3, 1, 2, 1, 0, // -z
					7, 6, 4, 7, 4, 5, // +z
					6, 2, 0, 6, 0, 4, // -x
					3, 7, 5, 3, 5, 1, // +x
					6, 7, 3, 6, 3, 2, // +y
					0, 1, 5, 0, 5, 4 // -y
				];
			case Plane:
				vertices = [-0.5, 0.0, -0.5, 0.5, 0.0, -0.5, -0.5, 0.0, 0.5, 0.5, 0.0, 0.5];
				indices = [2, 3, 1, 2, 1, 0];
			case Pyramid:
				vertices = [-0.5, -0.5, -0.5, 0.5, -0.5, -0.5, -0.5, -0.5, 0.5, 0.5, -0.5, 0.5, 0.0, 0.5, 0.0];
				indices = [0, 1, 3, 0, 3, 2, 4, 1, 0, 4, 2, 3, 4, 0, 2, 4, 3, 1];
			case Sphere:
				buildSphere(vertices, indices);
		}
		if (shape != Plane) {
			orientOutward(vertices, indices);
		}
		return new Mesh(vertices, indices, [for (triangle in 0...Std.int(indices.length / 3)) color]);
	}

	// A pole at each end and rings between them, each of segments that wrap round.
	static function buildSphere(vertices:Array<Float>, indices:Array<Int>):Void {
		vertices.push(0.0);
		vertices.push(0.5);
		vertices.push(0.0);
		for (ring in 1...SPHERE_RINGS) {
			var theta = Math.PI * ring / SPHERE_RINGS;
			for (segment in 0...SPHERE_SEGMENTS) {
				var phi = 2.0 * Math.PI * segment / SPHERE_SEGMENTS;
				vertices.push(0.5 * Math.sin(theta) * Math.sin(phi));
				vertices.push(0.5 * Math.cos(theta));
				vertices.push(0.5 * Math.sin(theta) * Math.cos(phi));
			}
		}
		vertices.push(0.0);
		vertices.push(-0.5);
		vertices.push(0.0);

		var bottom = 1 + (SPHERE_RINGS - 1) * SPHERE_SEGMENTS;
		for (segment in 0...SPHERE_SEGMENTS) {
			var next = (segment + 1) % SPHERE_SEGMENTS;
			indices.push(0);
			indices.push(1 + segment);
			indices.push(1 + next);
		}
		for (ring in 1...SPHERE_RINGS - 1) {
			var upper = 1 + (ring - 1) * SPHERE_SEGMENTS;
			var lower = upper + SPHERE_SEGMENTS;
			for (segment in 0...SPHERE_SEGMENTS) {
				var next = (segment + 1) % SPHERE_SEGMENTS;
				indices.push(upper + segment);
				indices.push(upper + next);
				indices.push(lower + segment);
				indices.push(upper + next);
				indices.push(lower + next);
				indices.push(lower + segment);
			}
		}
		var last = bottom - SPHERE_SEGMENTS;
		for (segment in 0...SPHERE_SEGMENTS) {
			var next = (segment + 1) % SPHERE_SEGMENTS;
			indices.push(last + segment);
			indices.push(last + next);
			indices.push(bottom);
		}
	}

	// Turns each triangle whose corners go the wrong way round for a viewer outside the shape, which has the origin inside it.
	static function orientOutward(vertices:Array<Float>, indices:Array<Int>):Void {
		var triangle = 0;
		while (triangle < indices.length) {
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
			var centerX = vertices[a] + vertices[b] + vertices[c];
			var centerY = vertices[a + 1] + vertices[b + 1] + vertices[c + 1];
			var centerZ = vertices[a + 2] + vertices[b + 2] + vertices[c + 2];
			if (normalX * centerX + normalY * centerY + normalZ * centerZ < 0.0) {
				var swap = indices[triangle + 1];
				indices[triangle + 1] = indices[triangle + 2];
				indices[triangle + 2] = swap;
			}
			triangle += 3;
		}
	}
}
