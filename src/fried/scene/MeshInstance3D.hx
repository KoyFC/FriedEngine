package fried.scene;

import fried.graphics3d.BoxMesh;
import fried.graphics3d.Material;
import fried.graphics3d.Mesh;

// A mesh in the world, which a scene's camera3D draws. Meshes can be shared by any number of instances.
@:serializable
class MeshInstance3D extends Node3D {
	// The shape and its materials. Every instance that holds the same mesh shares one copy of it in the renderer.
	public var mesh:Mesh;

	// Paints every surface of the mesh with this material, in place of their own. Each one it is used with makes a copy of the mesh in the renderer, which on the DS is memory, so it is not for animating.
	public var materialOverride:Material;

	public function new() {
		super();
		name = "MeshInstance3D";
		mesh = new BoxMesh();
	}

	// Scene keeps a list of its meshes, which a flag in the same word asks for.
	override function hookFlags():Int {
		return super.hookFlags() | 64;
	}
}
