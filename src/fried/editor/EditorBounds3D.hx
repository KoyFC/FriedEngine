package fried.editor;

#if fried_editor
import fried.graphics3d.Rotation;
import fried.scene.Camera3D;
import fried.scene.MeshInstance;
import fried.scene.Node3D;

// Where a Node3D lands on the frame through the editor's 3D camera: the box a click on it is tested against, its distance, its origin, and where one more unit of each of its coordinates would land, which is what a gizmo's arrows follow.
class EditorBounds3D {
	static inline var MARKER_SIZE:Float = 16.0;

	static var turn:Array<Float> = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
	static var parentTurn:Array<Float> = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

	// Null when the node's origin is nearer than the camera's near plane.
	public static function of(node:Node3D, camera:Camera3D, width:Float, height:Float):Null<Dynamic> {
		if (!camera.project(node.worldX, node.worldY, node.worldZ, width, height)) {
			return null;
		}
		var originX = camera.projectedX;
		var originY = camera.projectedY;
		var depth = camera.projectedDepth;

		var left = originX - MARKER_SIZE / 2;
		var top = originY - MARKER_SIZE / 2;
		var right = originX + MARKER_SIZE / 2;
		var bottom = originY + MARKER_SIZE / 2;
		var instance = Std.downcast(node, MeshInstance);
		if (instance != null && instance.mesh != null) {
			var mesh = instance.mesh;
			Rotation.toMatrix(node.worldRotationX, node.worldRotationY, node.worldRotationZ, turn);
			var isFirst = true;
			for (corner in 0...8) {
				var x = ((corner & 1) != 0 ? mesh.maxX : mesh.minX) * node.worldScaleX;
				var y = ((corner & 2) != 0 ? mesh.maxY : mesh.minY) * node.worldScaleY;
				var z = ((corner & 4) != 0 ? mesh.maxZ : mesh.minZ) * node.worldScaleZ;
				var worldX = node.worldX + turn[0] * x + turn[1] * y + turn[2] * z;
				var worldY = node.worldY + turn[3] * x + turn[4] * y + turn[5] * z;
				var worldZ = node.worldZ + turn[6] * x + turn[7] * y + turn[8] * z;
				if (!camera.project(worldX, worldY, worldZ, width, height)) {
					continue;
				}
				if (isFirst) {
					left = camera.projectedX;
					right = left;
					top = camera.projectedY;
					bottom = top;
					isFirst = false;
				} else {
					left = Math.min(left, camera.projectedX);
					right = Math.max(right, camera.projectedX);
					top = Math.min(top, camera.projectedY);
					bottom = Math.max(bottom, camera.projectedY);
				}
			}
		}

		return {
			id: node.id,
			x: left,
			y: top,
			width: right - left,
			height: bottom - top,
			depth: depth,
			originX: originX,
			originY: originY,
			worldX: node.worldX,
			worldY: node.worldY,
			worldZ: node.worldZ,
			axes: axesOf(node, camera, width, height)
		};
	}

	// The node's x, y and z are in the space of its parent, so one more unit of each goes along the parent's axes, as long and as turned as the parent makes them. Empty when any of them falls behind the camera.
	static function axesOf(node:Node3D, camera:Camera3D, width:Float, height:Float):Array<Dynamic> {
		var parent = Std.downcast(node.parent, Node3D);
		var scaleX = 1.0;
		var scaleY = 1.0;
		var scaleZ = 1.0;
		if (parent != null) {
			Rotation.toMatrix(parent.worldRotationX, parent.worldRotationY, parent.worldRotationZ, parentTurn);
			scaleX = parent.worldScaleX;
			scaleY = parent.worldScaleY;
			scaleZ = parent.worldScaleZ;
		} else {
			Rotation.toMatrix(0.0, 0.0, 0.0, parentTurn);
		}
		var axes:Array<Dynamic> = [];
		for (axis in 0...3) {
			var length = axis == 0 ? scaleX : (axis == 1 ? scaleY : scaleZ);
			var tipX = node.worldX + parentTurn[axis] * length;
			var tipY = node.worldY + parentTurn[3 + axis] * length;
			var tipZ = node.worldZ + parentTurn[6 + axis] * length;
			if (!camera.project(tipX, tipY, tipZ, width, height)) {
				return [];
			}
			axes.push({x: camera.projectedX, y: camera.projectedY});
		}
		return axes;
	}
}
#end
