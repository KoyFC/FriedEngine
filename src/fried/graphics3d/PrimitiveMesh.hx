package fried.graphics3d;

@:serializable
abstract class PrimitiveMesh extends Mesh {
	public var material(default, set):Material;

	var isDirty:Bool = true;

	function new() {
		super();
	}

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
