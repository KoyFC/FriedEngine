package fried.scene;

import fried.graphics.Color;
import fried.graphics3d.Mesh;
import fried.graphics3d.MeshShape;
import fried.graphics3d.Primitives;

// A mesh in the world, which a scene's camera3D draws. Meshes can be shared by any number of instances.
@:serializable
class MeshInstance extends Node3D {
	public var shape(default, set):MeshShape;

	// Every color a shape is given makes a mesh of its own that is kept, which on the DS is a copy in the renderer too, so it is not for animating.
	public var color(default, set):Color;

	// The shape in the color, or the mesh the code gives instead, which stays until the shape or the color changes again.
	@:noSerialize public var mesh:Null<Mesh>;

	public function new() {
		super();
		name = "MeshInstance";
		@:bypassAccessor shape = Cube;
		@:bypassAccessor color = Color.rgb(200, 200, 200);
		mesh = Primitives.mesh(shape, color);
	}

	// Scene keeps a list of its meshes, which a flag in the same word asks for.
	override function hookFlags():Int {
		return super.hookFlags() | 64;
	}

	function set_shape(value:MeshShape):MeshShape {
		shape = value;
		mesh = Primitives.mesh(shape, color);
		return value;
	}

	function set_color(value:Color):Color {
		color = value;
		mesh = Primitives.mesh(shape, color);
		return value;
	}
}
