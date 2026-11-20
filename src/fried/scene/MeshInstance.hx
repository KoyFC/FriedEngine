package fried.scene;

import fried.graphics3d.Mesh;

// A mesh in the world, which a scene's camera3D draws. Meshes can be shared by any number of instances.
@:serializable
class MeshInstance extends Node3D {
	@:noSerialize public var mesh:Null<Mesh>;

	public function new() {
		super();
		name = "MeshInstance";
		mesh = null;
	}

	// Scene keeps a list of its meshes, which a flag in the same word asks for.
	override function hookFlags():Int {
		return super.hookFlags() | 64;
	}
}
