package fried.graphics3d;

import fried.Log;
import fried.NativeError;
import fried.graphics.Color;
import fried.graphics.Renderer;
import fried.graphics.Texture;
import fried.io.Filesystem;
import haxe.io.Bytes;
import haxe.io.Path;

class MeshFile {
	static var cache:Map<String, Mesh> = new Map();

	public static function load(renderer:Renderer, path:String, root:String, relativePath:String):Mesh {
		var cached = cache.get(path);
		if (cached != null) {
			return cached;
		}

		var bytes = Filesystem.readBytes(path);
		if (!isFrms(bytes)) {
			bytes = convert(path);
		}
		var mesh = parse(renderer, bytes, Path.directory(path), path);
		mesh.sourceRoot = root;
		mesh.sourcePath = relativePath;
		cache.set(path, mesh);
		return mesh;
	}

	public static function clearCache():Void {
		cache = new Map();
	}

	static function isFrms(bytes:Bytes):Bool {
		return bytes.length >= 4 && bytes.get(0) == 0x46 && bytes.get(1) == 0x52 && bytes.get(2) == 0x4d && bytes.get(3) == 0x53;
	}

	static function convert(path:String):Bytes {
		var handle = ModelNative.convertFile(path);
		if (handle < 0) {
			throw NativeError.describe('Failed to read the model $path');
		}
		var size = ModelNative.getSize(handle);
		var bytes = Bytes.alloc(size);
		ModelNative.copy(handle, cpp.Pointer.ofArray(bytes.getData()).raw);
		ModelNative.release(handle);
		return bytes;
	}

	static function parse(renderer:Renderer, bytes:Bytes, directory:String, path:String):Mesh {
		if (!isFrms(bytes) || bytes.getUInt16(4) != 1) {
			throw 'The model $path is not a version 1 FRMS file.';
		}
		var mesh = new Mesh();
		var surfaceCount = bytes.getInt32(8);
		var at = 12;
		for (surfaceIndex in 0...surfaceCount) {
			var vertexCount = bytes.getInt32(at);
			var triangleCount = bytes.getInt32(at + 4);
			var flags = bytes.getInt32(at + 8);
			var albedo = bytes.getInt32(at + 12);
			var imageKind = bytes.getInt32(at + 16);
			at += 20;

			var texture:Null<Texture> = null;
			if (imageKind != 0) {
				var length = bytes.getInt32(at);
				at += 4;
				var content = bytes.sub(at, length);
				at += (length + 3) & ~3;
				texture = loadImage(renderer, imageKind, content, directory, path, surfaceIndex);
			}

			var vertices:Array<Float> = [];
			for (value in 0...vertexCount * 3) {
				vertices.push(bytes.getFloat(at));
				at += 4;
			}
			var uvs:Null<Array<Float>> = null;
			if ((flags & 1) != 0) {
				uvs = [];
				for (value in 0...vertexCount * 2) {
					uvs.push(bytes.getFloat(at));
					at += 4;
				}
			}
			var indices:Array<Int> = [];
			var isWide = (flags & 2) != 0;
			for (value in 0...triangleCount * 3) {
				indices.push(isWide ? bytes.getInt32(at) : bytes.getUInt16(at));
				at += isWide ? 4 : 2;
			}
			at = (at + 3) & ~3;

			var material = new StandardMaterial3D();
			material.albedoColor = Color.rgba((albedo >> 16) & 0xff, (albedo >> 8) & 0xff, albedo & 0xff, (albedo >> 24) & 0xff);
			material.albedoTexture = texture;
			mesh.addSurface(new Surface(vertices, indices, uvs, null, material));
		}
		return mesh;
	}

	static function loadImage(renderer:Renderer, kind:Int, content:Bytes, directory:String, path:String, surface:Int):Null<Texture> {
		try {
			if (kind == 1) {
				return Texture.from(renderer, Path.join([directory, content.toString()]));
			}
			return Texture.fromBytes(renderer, content, path + "#" + surface);
		} catch (error:Dynamic) {
			Log.warn('The image of a surface of $path could not be read: $error');
			return null;
		}
	}
}

@:include("model/model_native.h")
private extern class ModelNative {
	@:native("fried_model_convert_file")
	static function convertFile(path:cpp.ConstCharStar):Int;

	@:native("fried_model_get_size")
	static function getSize(handle:Int):Int;

	@:native("fried_model_copy")
	static function copy(handle:Int, out:cpp.RawPointer<cpp.UInt8>):Void;

	@:native("fried_model_release")
	static function release(handle:Int):Void;
}
