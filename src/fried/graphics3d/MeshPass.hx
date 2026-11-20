package fried.graphics3d;

import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.scene.Camera3D;
import fried.scene.DirectionalLight;
import fried.scene.MeshInstance;

// Draws every mesh of a scene through its camera. A triangle is seen from the side its corners turn clockwise on, and not drawn from the other.
//
// Where a renderer draws meshes itself, each one is sent as the numbers that place it. Everywhere else the triangles of all the meshes are worked out here and sorted together, farthest first, as one batch.
class MeshPass {
	// In the order graphics/mesh.h lists them.
	static inline var PLACEMENT_SIZE = 20;

	static var cameraTurn:Array<Float> = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
	static var meshTurn:Array<Float> = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
	static var combined:Array<Float> = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
	static var viewVertices:Array<Float> = [];
	static var depths:Array<Float> = [];
	static var shades:Array<Color> = [];
	static var corners:Array<Float> = [];
	static var drawOrder:Array<Int> = [];
	static var keys:Array<Int> = [];
	static var halfSorted:Array<Int> = [];
	static var buckets:Array<Int> = [for (index in 0...256) 0];
	static var points:Array<Float> = [];
	static var colors:Array<Color> = [];

	static var triangleTotal:Int = 0;
	static var isViewReady:Bool = false;
	static var focalLength:Float = 1.0;
	static var centerX:Float = 0.0;
	static var centerY:Float = 0.0;
	static var lightViewX:Float = 0.0;
	static var lightViewY:Float = 0.0;
	static var lightViewZ:Float = 0.0;
	static var lightLength:Float = 0.0;
	static var ambient:Float = 1.0;

	public static function draw(camera:Camera3D, light:Null<DirectionalLight>, meshes:Array<MeshInstance>, width:Float, height:Float):Void {
		var lightX = 0.0;
		var lightY = 0.0;
		var lightZ = 0.0;
		ambient = 1.0;
		if (light != null) {
			lightX = light.directionX;
			lightY = light.directionY;
			lightZ = light.directionZ;
			ambient = light.ambient;
		}
		isViewReady = false;
		triangleTotal = 0;
		var capacity = 0;
		for (instance in meshes) {
			if (instance.mesh != null) {
				capacity += instance.mesh.triangleColors.length;
			}
		}
		// The arrays only grow, and are written by index: a push per corner of every triangle costs more than the sums on them.
		if (depths.length < capacity) {
			depths.resize(capacity);
			shades.resize(capacity);
			corners.resize(capacity * 6);
			drawOrder.resize(capacity);
			keys.resize(capacity);
			halfSorted.resize(capacity);
		}

		var total = 0;
		var target = DrawQueue.currentRenderTarget;
		var drawsMeshes = target != null && target.drawsMeshes;
		for (instance in meshes) {
			var mesh = instance.mesh;
			if (!instance.shownInTree || mesh == null) {
				continue;
			}
			if (drawsMeshes) {
				var meshId = mesh.copyForRenderer();
				if (meshId >= 0) {
					place(DrawQueue.submitMesh(camera.priority, meshId, PLACEMENT_SIZE), instance, camera, width, height, lightX, lightY, lightZ);
					total += mesh.triangleColors.length;
					continue;
				}
			}
			if (!isViewReady) {
				prepareView(camera, lightX, lightY, lightZ, width, height);
			}
			collect(instance, mesh, camera);
		}

		if (triangleTotal > 0) {
			var count = triangleTotal;
			sortFarthestFirst(count);
			points.resize(count * 6);
			colors.resize(count);
			for (slot in 0...count) {
				var triangle = drawOrder[slot];
				for (value in 0...6) {
					points[slot * 6 + value] = corners[triangle * 6 + value];
				}
				colors[slot] = shades[triangle];
			}
			DrawQueue.submitTriangles(camera.priority, points, colors);
			total += count;
		}
		camera.trianglesDrawn = total;
	}

	// The camera's turn and the light in the camera's space, which only a mesh drawn here needs: where every mesh is drawn by the renderer, none of the trigonometry in them is done.
	static function prepareView(camera:Camera3D, lightX:Float, lightY:Float, lightZ:Float, width:Float, height:Float):Void {
		isViewReady = true;
		Rotation.toMatrix(camera.worldRotationX, camera.worldRotationY, camera.worldRotationZ, cameraTurn);
		lightViewX = cameraTurn[0] * lightX + cameraTurn[3] * lightY + cameraTurn[6] * lightZ;
		lightViewY = cameraTurn[1] * lightX + cameraTurn[4] * lightY + cameraTurn[7] * lightZ;
		lightViewZ = cameraTurn[2] * lightX + cameraTurn[5] * lightY + cameraTurn[8] * lightZ;
		lightLength = Math.sqrt(lightViewX * lightViewX + lightViewY * lightViewY + lightViewZ * lightViewZ);
		focalLength = (height / 2.0) / Math.tan(camera.fieldOfView * Math.PI / 360.0);
		centerX = width / 2.0;
		centerY = height / 2.0;
	}

	static function place(placement:Array<Float>, instance:MeshInstance, camera:Camera3D, width:Float, height:Float, lightX:Float, lightY:Float,
			lightZ:Float):Void {
		placement[0] = instance.worldX;
		placement[1] = instance.worldY;
		placement[2] = instance.worldZ;
		placement[3] = instance.worldRotationX;
		placement[4] = instance.worldRotationY;
		placement[5] = instance.worldRotationZ;
		placement[6] = instance.worldScaleX;
		placement[7] = camera.worldX;
		placement[8] = camera.worldY;
		placement[9] = camera.worldZ;
		placement[10] = camera.fieldOfView;
		placement[11] = 0.0;
		placement[12] = 0.0;
		placement[13] = width;
		placement[14] = height;
		placement[15] = camera.near;
		placement[16] = lightX;
		placement[17] = lightY;
		placement[18] = lightZ;
		placement[19] = ambient;
	}

	static function collect(instance:MeshInstance, mesh:Mesh, camera:Camera3D):Void {
		var near = camera.near;
		Rotation.toMatrix(instance.worldRotationX, instance.worldRotationY, instance.worldRotationZ, meshTurn);
		var scaleX = instance.worldScaleX;
		var scaleY = instance.worldScaleY;
		var scaleZ = instance.worldScaleZ;
		// The camera's turn undone and then the mesh's, with the mesh's scale applied first.
		for (row in 0...3) {
			for (column in 0...3) {
				var scaleOf = column == 0 ? scaleX : (column == 1 ? scaleY : scaleZ);
				combined[row * 3 + column] = (cameraTurn[row] * meshTurn[column] + cameraTurn[3 + row] * meshTurn[3 + column]
					+ cameraTurn[6 + row] * meshTurn[6 + column]) * scaleOf;
			}
		}
		var offsetX = instance.worldX - camera.worldX;
		var offsetY = instance.worldY - camera.worldY;
		var offsetZ = instance.worldZ - camera.worldZ;
		var shiftX = cameraTurn[0] * offsetX + cameraTurn[3] * offsetY + cameraTurn[6] * offsetZ;
		var shiftY = cameraTurn[1] * offsetX + cameraTurn[4] * offsetY + cameraTurn[7] * offsetZ;
		var shiftZ = cameraTurn[2] * offsetX + cameraTurn[5] * offsetY + cameraTurn[8] * offsetZ;

		var vertices = mesh.vertices;
		viewVertices.resize(vertices.length);
		var index = 0;
		while (index < vertices.length) {
			var x = vertices[index];
			var y = vertices[index + 1];
			var z = vertices[index + 2];
			viewVertices[index] = combined[0] * x + combined[1] * y + combined[2] * z + shiftX;
			viewVertices[index + 1] = combined[3] * x + combined[4] * y + combined[5] * z + shiftY;
			viewVertices[index + 2] = combined[6] * x + combined[7] * y + combined[8] * z + shiftZ;
			index += 3;
		}

		var indices = mesh.indices;
		var triangleCount = mesh.triangleColors.length;
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
				facing = -(normalX * lightViewX + normalY * lightViewY + normalZ * lightViewZ) / (normalLength * lightLength);
			}
			var brightness = ambient + (1.0 - ambient) * Math.max(facing, 0.0);
			var color = mesh.triangleColors[triangle];
			var slot = triangleTotal++;
			shades[slot] = Color.rgba(Std.int(color.red * brightness), Std.int(color.green * brightness), Std.int(color.blue * brightness), color.alpha);
			depths[slot] = az + bz + cz;

			var bx = viewVertices[b];
			var by = viewVertices[b + 1];
			var cx = viewVertices[c];
			var cy = viewVertices[c + 1];
			var at = slot * 6;
			corners[at] = centerX + ax * focalLength / az;
			corners[at + 1] = centerY - ay * focalLength / az;
			corners[at + 2] = centerX + bx * focalLength / bz;
			corners[at + 3] = centerY - by * focalLength / bz;
			corners[at + 4] = centerX + cx * focalLength / cz;
			corners[at + 5] = centerY - cy * focalLength / cz;
		}
	}

	// Puts drawOrder in the order of the triangles' depths, farthest first, and triangles of the same depth in the order they were made. A comparison sort of the thousands of triangles a scene has takes longer than all the rest of the pass, so the depths are cut into 65536 steps between the nearest and the farthest and sorted a byte at a time.
	static function sortFarthestFirst(count:Int):Void {
		var nearest = depths[0];
		var farthest = nearest;
		for (slot in 1...count) {
			var depth = depths[slot];
			if (depth < nearest) {
				nearest = depth;
			} else if (depth > farthest) {
				farthest = depth;
			}
		}
		var scale = farthest > nearest ? 65535.0 / (farthest - nearest) : 0.0;
		for (slot in 0...count) {
			keys[slot] = 65535 - Std.int((depths[slot] - nearest) * scale);
		}

		clearBuckets();
		for (slot in 0...count) {
			buckets[keys[slot] & 255]++;
		}
		startBuckets();
		for (slot in 0...count) {
			var bucket = keys[slot] & 255;
			halfSorted[buckets[bucket]++] = slot;
		}

		clearBuckets();
		for (slot in 0...count) {
			buckets[keys[slot] >> 8]++;
		}
		startBuckets();
		for (position in 0...count) {
			var slot = halfSorted[position];
			var bucket = keys[slot] >> 8;
			drawOrder[buckets[bucket]++] = slot;
		}
	}

	static function clearBuckets():Void {
		for (bucket in 0...256) {
			buckets[bucket] = 0;
		}
	}

	// Turns each bucket's count into where its first triangle goes.
	static function startBuckets():Void {
		var start = 0;
		for (bucket in 0...256) {
			var count = buckets[bucket];
			buckets[bucket] = start;
			start += count;
		}
	}
}
