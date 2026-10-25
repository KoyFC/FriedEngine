import fried.graphics.Color;
import fried.graphics3d.Mesh;

class CubeMesh {
	// Vertex i sits at -1 or +1 on x, y and z by its bits 0, 1 and 2.
	public static function create():Mesh {
		var vertices = [];
		for (corner in 0...8) {
			vertices.push((corner & 1) != 0 ? 1.0 : -1.0);
			vertices.push((corner & 2) != 0 ? 1.0 : -1.0);
			vertices.push((corner & 4) != 0 ? 1.0 : -1.0);
		}
		var indices = [
			2, 3, 1, 2, 1, 0, // -z
			7, 6, 4, 7, 4, 5, // +z
			6, 2, 0, 6, 0, 4, // -x
			3, 7, 5, 3, 5, 1, // +x
			6, 7, 3, 6, 3, 2, // +y
			0, 1, 5, 0, 5, 4 // -y
		];
		var faceColors = [
			Color.rgb(255, 140, 40),
			Color.rgb(90, 200, 140),
			Color.rgb(80, 150, 255),
			Color.rgb(230, 80, 90),
			Color.rgb(240, 220, 90),
			Color.rgb(170, 110, 230)
		];
		var triangleColors = [];
		for (color in faceColors) {
			triangleColors.push(color);
			triangleColors.push(color);
		}
		return new Mesh(vertices, indices, triangleColors);
	}
}
