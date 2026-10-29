package fried.graphics3d;

import fried.graphics.Color;

// A triangle is seen from the side its corners turn clockwise on, and not drawn from the other.
// A renderer that draws meshes itself keeps a copy of one from the first time it draws it, so
// changing its arrays after that changes nothing there.
class Mesh {
	public var vertices(default, null):Array<Float>;
	public var indices(default, null):Array<Int>;
	public var triangleColors(default, null):Array<Color>;

	var nativeId:Int;

	public function new(vertices:Array<Float>, indices:Array<Int>, triangleColors:Array<Color>) {
		if (vertices.length % 3 != 0) {
			throw 'A mesh takes three coordinates per vertex, but got ${vertices.length}.';
		}
		if (indices.length != triangleColors.length * 3) {
			throw 'A mesh takes three indices per colour, but ${indices.length} came with ${triangleColors.length} colours.';
		}
		var vertexCount = Std.int(vertices.length / 3);
		for (index in indices) {
			if (index < 0 || index >= vertexCount) {
				throw 'A mesh index of $index is outside its $vertexCount vertices.';
			}
		}
		this.vertices = vertices;
		this.indices = indices;
		this.triangleColors = triangleColors;
		nativeId = -1;
	}

	// Frees the copy a renderer keeps, which drawing the mesh again makes anew.
	public function destroy():Void {
		if (nativeId < 0) {
			return;
		}
		MeshNative.destroy(nativeId);
		nativeId = -1;
	}

	// -1 where no renderer draws meshes, or the copy did not fit in memory.
	@:allow(fried.graphics3d.Camera3D)
	function copyForRenderer():Int {
		if (nativeId < 0) {
			nativeId = MeshNative.create(cpp.Pointer.ofArray(vertices).constRaw, Std.int(vertices.length / 3), cpp.Pointer.ofArray(indices).constRaw,
				cpp.Pointer.ofArray((cast triangleColors : Array<Int>)).constRaw, triangleColors.length);
		}
		return nativeId;
	}
}

@:include("graphics/mesh.h")
private extern class MeshNative {
	@:native("fried_mesh_create")
	static function create(vertices:cpp.RawConstPointer<Float>, vertexCount:Int, indices:cpp.RawConstPointer<Int>,
		argbColors:cpp.RawConstPointer<Int>, triangleCount:Int):Int;

	@:native("fried_mesh_destroy")
	static function destroy(meshId:Int):Void;
}
