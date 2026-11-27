package fried.graphics3d;

import fried.graphics.Color;
import fried.graphics.Texture;
import fried.resources.Resource;

class Mesh extends Resource {
	public var surfaces(get, never):Array<Surface>;
	public var triangleCount(get, never):Int;

	// How far the farthest vertex is from the origin, and the box that holds them all, which is what a scene skips a mesh by and an editor outlines it by.
	public var boundingRadius(get, never):Float;
	public var minX(get, never):Float;
	public var maxX(get, never):Float;
	public var minY(get, never):Float;
	public var maxY(get, never):Float;
	public var minZ(get, never):Float;
	public var maxZ(get, never):Float;

	public var sourceRoot:Null<String>;
	public var sourcePath:Null<String>;

	public var flatVertices(get, never):Array<Float>;
	public var flatUvs(get, never):Array<Float>;
	public var flatIndices(get, never):Array<Int>;

	public var surfaceStarts(get, never):Array<Int>;

	var surfaceList:Array<Surface> = [];
	var isFlat:Bool = false;
	var flatVertexList:Array<Float>;
	var flatUvList:Array<Float>;
	var flatIndexList:Array<Int>;
	var surfaceStartList:Array<Int>;
	var isBounded:Bool = false;
	var boundsRadius:Float = 0.0;
	var boundsMin:Array<Float> = [0.0, 0.0, 0.0];
	var boundsMax:Array<Float> = [0.0, 0.0, 0.0];
	var variants:Array<MeshVariant> = [];

	public function new(?vertices:Array<Float>, ?indices:Array<Int>, ?triangleColors:Array<Color>) {
		super();
		if (vertices != null && indices != null) {
			surfaceList.push(new Surface(vertices, indices, null, triangleColors));
		}
	}

	public function addSurface(surface:Surface):Void {
		surfaceList.push(surface);
		invalidate();
	}

	public function invalidate():Void {
		isFlat = false;
		isBounded = false;
		for (variant in variants) {
			destroyVariant(variant);
		}
		variants = [];
	}

	public function destroy():Void {
		for (variant in variants) {
			destroyVariant(variant);
		}
		variants = [];
	}

	function ensureBuilt():Void {}

	public function variantFor(overriding:Null<Material>):MeshVariant {
		var surfaces = this.surfaces;
		ensureFlat();
		for (position in 0...variants.length) {
			var variant = variants[position];
			if (variant.overriding != overriding) {
				continue;
			}
			var isCurrent = true;
			for (index in 0...surfaces.length) {
				var material = overriding != null ? overriding : surfaces[index].material;
				if (variant.versions[index] != (material != null ? material.version : -1)) {
					isCurrent = false;
					break;
				}
			}
			if (isCurrent) {
				return variant;
			}
			destroyVariant(variant);
			variants.splice(position, 1);
			break;
		}

		var versions = [];
		var colors:Array<Color> = [];
		var textures = [];
		for (surface in surfaces) {
			var material = overriding != null ? overriding : surface.material;
			versions.push(material != null ? material.version : -1);
			textures.push(material != null ? material.albedoImage() : null);
			var albedo = material != null ? material.albedo() : Color.rgb(255, 255, 255);
			for (triangle in 0...surface.triangleCount) {
				colors.push(surface.triangleColors != null ? MeshTools.multiply(albedo, surface.triangleColors[triangle]) : albedo);
			}
		}
		var variant = new MeshVariant(overriding, versions, colors, textures);
		variants.push(variant);
		return variant;
	}

	@:allow(fried.graphics3d.MeshPass)
	function nativeFor(variant:MeshVariant):Int {
		if (variant.nativeId < 0) {
			var vertices = flatVertices;
			var textureIds = [for (texture in variant.textures) texture != null ? texture.nativeId() : -1];
			variant.nativeId = MeshNative.create(cpp.Pointer.ofArray(vertices).constRaw, cpp.Pointer.ofArray(flatUvs).constRaw, Std.int(vertices.length / 3),
				cpp.Pointer.ofArray(flatIndices).constRaw, cpp.Pointer.ofArray((cast variant.colors : Array<Int>)).constRaw, variant.colors.length,
				cpp.Pointer.ofArray(surfaceStarts).constRaw, cpp.Pointer.ofArray(textureIds).constRaw, textureIds.length);
		}
		return variant.nativeId;
	}

	function destroyVariant(variant:MeshVariant):Void {
		if (variant.nativeId >= 0) {
			MeshNative.destroy(variant.nativeId);
			variant.nativeId = -1;
		}
	}

	function ensureFlat():Void {
		ensureBuilt();
		if (isFlat) {
			return;
		}
		flatVertexList = [];
		flatUvList = [];
		flatIndexList = [];
		surfaceStartList = [];
		var triangles = 0;
		for (surface in surfaceList) {
			var offset = Std.int(flatVertexList.length / 3);
			surfaceStartList.push(triangles);
			for (value in surface.vertices) {
				flatVertexList.push(value);
			}
			for (index in 0...Std.int(surface.vertices.length / 3)) {
				flatUvList.push(surface.uvs != null ? surface.uvs[index * 2] : 0.0);
				flatUvList.push(surface.uvs != null ? surface.uvs[index * 2 + 1] : 0.0);
			}
			for (index in surface.indices) {
				flatIndexList.push(index + offset);
			}
			triangles += surface.triangleCount;
		}
		surfaceStartList.push(triangles);
		isFlat = true;
	}

	function ensureBounds():Void {
		if (isBounded) {
			return;
		}
		var vertices = flatVertices;
		boundsRadius = 0.0;
		for (axis in 0...3) {
			boundsMin[axis] = 0.0;
			boundsMax[axis] = 0.0;
		}
		var corner = 0;
		while (corner < vertices.length) {
			var x = vertices[corner];
			var y = vertices[corner + 1];
			var z = vertices[corner + 2];
			boundsRadius = Math.max(boundsRadius, Math.sqrt(x * x + y * y + z * z));
			boundsMin[0] = Math.min(boundsMin[0], x);
			boundsMax[0] = Math.max(boundsMax[0], x);
			boundsMin[1] = Math.min(boundsMin[1], y);
			boundsMax[1] = Math.max(boundsMax[1], y);
			boundsMin[2] = Math.min(boundsMin[2], z);
			boundsMax[2] = Math.max(boundsMax[2], z);
			corner += 3;
		}
		isBounded = true;
	}

	function get_surfaces():Array<Surface> {
		ensureBuilt();
		return surfaceList;
	}

	function get_triangleCount():Int {
		ensureFlat();
		return surfaceStartList[surfaceStartList.length - 1];
	}

	function get_flatVertices():Array<Float> {
		ensureFlat();
		return flatVertexList;
	}

	function get_flatUvs():Array<Float> {
		ensureFlat();
		return flatUvList;
	}

	function get_flatIndices():Array<Int> {
		ensureFlat();
		return flatIndexList;
	}

	function get_surfaceStarts():Array<Int> {
		ensureFlat();
		return surfaceStartList;
	}

	function get_boundingRadius():Float {
		ensureFlat();
		ensureBounds();
		return boundsRadius;
	}

	function get_minX():Float {
		ensureFlat();
		ensureBounds();
		return boundsMin[0];
	}

	function get_maxX():Float {
		ensureFlat();
		ensureBounds();
		return boundsMax[0];
	}

	function get_minY():Float {
		ensureFlat();
		ensureBounds();
		return boundsMin[1];
	}

	function get_maxY():Float {
		ensureFlat();
		ensureBounds();
		return boundsMax[1];
	}

	function get_minZ():Float {
		ensureFlat();
		ensureBounds();
		return boundsMin[2];
	}

	function get_maxZ():Float {
		ensureFlat();
		ensureBounds();
		return boundsMax[2];
	}
}

@:include("graphics/mesh.h")
private extern class MeshNative {
	@:native("fried_mesh_create")
	static function create(vertices:cpp.RawConstPointer<Float>, uvs:cpp.RawConstPointer<Float>, vertexCount:Int, indices:cpp.RawConstPointer<Int>,
		argbColors:cpp.RawConstPointer<Int>, triangleCount:Int, surfaceFirstTriangles:cpp.RawConstPointer<Int>, surfaceTextureIds:cpp.RawConstPointer<Int>,
		surfaceCount:Int):Int;

	@:native("fried_mesh_destroy")
	static function destroy(meshId:Int):Void;
}
