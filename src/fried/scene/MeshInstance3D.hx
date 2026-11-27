package fried.scene;

import fried.graphics3d.BoxMesh;
import fried.graphics3d.Material;
import fried.graphics3d.Mesh;

@:serializable
class MeshInstance3D extends Node3D {
	public var mesh:Mesh;

	public var materialOverride:Material;

	public function new() {
		super();
		name = "MeshInstance3D";
		mesh = new BoxMesh();
	}

	override function hookFlags():Int {
		return super.hookFlags() | 64;
	}
}
