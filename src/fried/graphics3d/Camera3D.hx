package fried.graphics3d;

import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Rect;

// Looks along +z with y up, and does not turn.
class Camera3D {
	public var position:Vec3;
	public var fieldOfView:Float;
	public var near:Float;
	public var viewport:Rect;

	static inline var PLACEMENT_SIZE = 20;

	static var viewVertices:Array<Float> = [];
	static var depths:Array<Float> = [];
	static var shades:Array<Color> = [];
	static var drawOrder:Array<Int> = [];
	static var points:Array<Float> = [];
	static var colors:Array<Color> = [];

	public function new(viewport:Rect, fieldOfView:Float = 60.0, near:Float = 0.1) {
		position = new Vec3();
		this.fieldOfView = fieldOfView;
		this.near = near;
		this.viewport = viewport;
	}

	// Returns how many triangles went to the queue, which for a renderer that draws meshes
	// itself is all of them, since it leaves out the ones facing away.
	public function submitMesh(priority:Int, mesh:Mesh, transform:Transform3D, light:DirectionalLight):Int {
		var target = DrawQueue.currentRenderTarget;
		if (target != null && target.drawsMeshes) {
			var meshId = mesh.copyForRenderer();
			if (meshId >= 0) {
				place(DrawQueue.submitMesh(priority, meshId, PLACEMENT_SIZE), transform, light);
				return mesh.triangleColors.length;
			}
		}

		toView(mesh, transform);
		collectVisibleTriangles(mesh, light);
		if (drawOrder.length == 0) {
			return 0;
		}
		drawOrder.sort(compareFarthestFirst);
		project(mesh);
		DrawQueue.submitTriangles(priority, points, colors);
		return drawOrder.length;
	}

	// In the order graphics/mesh.h lists them, and as they are: the renderer
	// works out what the camera and the light give once for every mesh they
	// are the same for.
	function place(placement:Array<Float>, transform:Transform3D, light:DirectionalLight):Void {
		placement[0] = transform.position.x;
		placement[1] = transform.position.y;
		placement[2] = transform.position.z;
		placement[3] = transform.rotation.x;
		placement[4] = transform.rotation.y;
		placement[5] = transform.rotation.z;
		placement[6] = transform.scale;
		placement[7] = position.x;
		placement[8] = position.y;
		placement[9] = position.z;
		placement[10] = fieldOfView;
		placement[11] = viewport.x;
		placement[12] = viewport.y;
		placement[13] = viewport.width;
		placement[14] = viewport.height;
		placement[15] = near;
		placement[16] = light.direction.x;
		placement[17] = light.direction.y;
		placement[18] = light.direction.z;
		placement[19] = light.ambient;
	}

	function toView(mesh:Mesh, transform:Transform3D):Void {
		var radians = Math.PI / 180.0;
		var rotation = transform.rotation;
		var sinX = Math.sin(rotation.x * radians);
		var cosX = Math.cos(rotation.x * radians);
		var sinY = Math.sin(rotation.y * radians);
		var cosY = Math.cos(rotation.y * radians);
		var sinZ = Math.sin(rotation.z * radians);
		var cosZ = Math.cos(rotation.z * radians);
		var offsetX = transform.position.x - position.x;
		var offsetY = transform.position.y - position.y;
		var offsetZ = transform.position.z - position.z;
		var scale = transform.scale;

		var vertices = mesh.vertices;
		viewVertices.resize(vertices.length);
		var index = 0;
		while (index < vertices.length) {
			var x = vertices[index] * scale;
			var y = vertices[index + 1] * scale;
			var z = vertices[index + 2] * scale;

			var turnedY = y * cosX - z * sinX;
			var turnedZ = y * sinX + z * cosX;
			var turnedX = x * cosY + turnedZ * sinY;
			turnedZ = turnedZ * cosY - x * sinY;
			var finalX = turnedX * cosZ - turnedY * sinZ;
			var finalY = turnedX * sinZ + turnedY * cosZ;

			viewVertices[index] = finalX + offsetX;
			viewVertices[index + 1] = finalY + offsetY;
			viewVertices[index + 2] = turnedZ + offsetZ;
			index += 3;
		}
	}

	function collectVisibleTriangles(mesh:Mesh, light:DirectionalLight):Void {
		var indices = mesh.indices;
		var triangleCount = mesh.triangleColors.length;
		depths.resize(triangleCount);
		shades.resize(triangleCount);
		drawOrder.resize(0);

		var lightX = light.direction.x;
		var lightY = light.direction.y;
		var lightZ = light.direction.z;
		var lightLength = Math.sqrt(lightX * lightX + lightY * lightY + lightZ * lightZ);

		for (triangle in 0...triangleCount) {
			var a = indices[triangle * 3] * 3;
			var b = indices[triangle * 3 + 1] * 3;
			var c = indices[triangle * 3 + 2] * 3;
			var ax = viewVertices[a];
			var ay = viewVertices[a + 1];
			var az = viewVertices[a + 2];
			var bz = viewVertices[b + 2];
			var cz = viewVertices[c + 2];
			if (az < near || bz < near || cz < near) {
				continue;
			}

			var abX = viewVertices[b] - ax;
			var abY = viewVertices[b + 1] - ay;
			var abZ = bz - az;
			var acX = viewVertices[c] - ax;
			var acY = viewVertices[c + 1] - ay;
			var acZ = cz - az;
			var normalX = abY * acZ - abZ * acY;
			var normalY = abZ * acX - abX * acZ;
			var normalZ = abX * acY - abY * acX;
			if (normalX * ax + normalY * ay + normalZ * az >= 0.0) {
				continue;
			}

			var facing = 0.0;
			var normalLength = Math.sqrt(normalX * normalX + normalY * normalY + normalZ * normalZ);
			if (normalLength > 0.0 && lightLength > 0.0) {
				facing = -(normalX * lightX + normalY * lightY + normalZ * lightZ) / (normalLength * lightLength);
			}
			var brightness = light.ambient + (1.0 - light.ambient) * Math.max(facing, 0.0);
			var color = mesh.triangleColors[triangle];
			shades[triangle] = Color.rgba(Std.int(color.red * brightness), Std.int(color.green * brightness), Std.int(color.blue * brightness),
				color.alpha);

			depths[triangle] = az + bz + cz;
			drawOrder.push(triangle);
		}
	}

	function project(mesh:Mesh):Void {
		var indices = mesh.indices;
		var focalLength = (viewport.height / 2.0) / Math.tan(fieldOfView * Math.PI / 360.0);
		var centerX = viewport.x + viewport.width / 2.0;
		var centerY = viewport.y + viewport.height / 2.0;

		points.resize(drawOrder.length * 6);
		colors.resize(drawOrder.length);
		for (slot in 0...drawOrder.length) {
			var triangle = drawOrder[slot];
			for (corner in 0...3) {
				var vertex = indices[triangle * 3 + corner] * 3;
				var depth = viewVertices[vertex + 2];
				points[slot * 6 + corner * 2] = centerX + viewVertices[vertex] * focalLength / depth;
				points[slot * 6 + corner * 2 + 1] = centerY - viewVertices[vertex + 1] * focalLength / depth;
			}
			colors[slot] = shades[triangle];
		}
	}

	static function compareFarthestFirst(a:Int, b:Int):Int {
		var depthA = depths[a];
		var depthB = depths[b];
		if (depthA != depthB) {
			return depthA > depthB ? -1 : 1;
		}
		return a < b ? -1 : 1;
	}
}
