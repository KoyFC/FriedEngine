package fried.scene;

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

	public function new() {
		super();
		name = "Camera3D";
		fieldOfView = 60.0;
		near = 0.1;
		trianglesDrawn = 0;
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
