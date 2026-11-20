package fried.scene;

import fried.graphics3d.Rotation;

// Looks along its own forward, which is +z when it is not turned, with y up. A scene draws its meshes through its camera3D.
@:allow(fried.graphics3d.MeshPass)
@:serializable
class Camera3D extends Node3D {
	// Vertical, in degrees.
	public var fieldOfView:Float;

	// Anything nearer than this to the camera is not drawn.
	public var near:Float;

	// How many triangles the last frame sent, which for a renderer that draws meshes itself is every triangle of every mesh, since it leaves out the ones facing away.
	@:noSerialize public var trianglesDrawn(default, null):Int;

	// Where a point of the world lands, set by project().
	@:noSerialize public var projectedX(default, null):Float;
	@:noSerialize public var projectedY(default, null):Float;

	// How far in front of the camera it is.
	@:noSerialize public var projectedDepth(default, null):Float;

	static var turn:Array<Float> = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

	public function new() {
		super();
		name = "Camera3D";
		fieldOfView = 60.0;
		near = 0.1;
		trianglesDrawn = 0;
		projectedX = 0.0;
		projectedY = 0.0;
		projectedDepth = 0.0;
	}

	// Where a point of the world lands on a view of that size, in projectedX and projectedY, with its distance in front of the camera in projectedDepth. False for a point nearer than the near plane, which is not drawn.
	public function project(pointX:Float, pointY:Float, pointZ:Float, width:Float, height:Float):Bool {
		Rotation.toMatrix(worldRotationX, worldRotationY, worldRotationZ, turn);
		var offsetX = pointX - worldX;
		var offsetY = pointY - worldY;
		var offsetZ = pointZ - worldZ;
		var viewZ = turn[2] * offsetX + turn[5] * offsetY + turn[8] * offsetZ;
		if (viewZ < near) {
			return false;
		}
		var viewX = turn[0] * offsetX + turn[3] * offsetY + turn[6] * offsetZ;
		var viewY = turn[1] * offsetX + turn[4] * offsetY + turn[7] * offsetZ;
		var focalLength = (height / 2.0) / Math.tan(fieldOfView * Math.PI / 360.0);
		projectedX = width / 2.0 + viewX * focalLength / viewZ;
		projectedY = height / 2.0 - viewY * focalLength / viewZ;
		projectedDepth = viewZ;
		return true;
	}

	// Turns the camera to face a point of the world. Under a turned parent the angles are the parent's.
	public function lookAt(targetX:Float, targetY:Float, targetZ:Float):Void {
		var forwardX = targetX - worldX;
		var forwardY = targetY - worldY;
		var forwardZ = targetZ - worldZ;
		var length = Math.sqrt(forwardX * forwardX + forwardY * forwardY + forwardZ * forwardZ);
		if (length == 0.0) {
			return;
		}
		rotationX = Math.asin(-forwardY / length) * (180.0 / Math.PI);
		rotationY = Math.atan2(forwardX, forwardZ) * (180.0 / Math.PI);
		rotationZ = 0.0;
	}
}
