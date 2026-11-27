package fried.graphics3d;

// A mesh that a few numbers describe, as a box or a sphere, made when it is first needed and again after one of them changes. It is one surface, painted with its material. Every size is in the units of the scene, centred on the origin.
@:serializable
abstract class PrimitiveMesh extends Mesh {
	public var material(default, set):Material;

	var isDirty:Bool = true;

	function new() {
		super();
	}

	// Puts the vertices, texture coordinates and triangles of the shape in the builder, with the triangles going round clockwise as seen from outside.
	abstract function build(builder:MeshBuilder):Void;

	override function ensureBuilt():Void {
		if (!isDirty) {
			return;
		}
		isDirty = false;
		var builder = new MeshBuilder();
		build(builder);
		MeshTools.dropEmpty(builder.vertices, builder.indices);
		surfaceList = [new Surface(builder.vertices, builder.indices, builder.uvs, null, material)];
	}

	// Every number of a shape calls this when it is set.
	function rebuild():Void {
		isDirty = true;
		invalidate();
	}

	function set_material(value:Material):Material {
		material = value;
		rebuild();
		return value;
	}
}
