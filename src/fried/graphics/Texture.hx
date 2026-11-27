package fried.graphics;

import fried.Log;
import fried.NativeError;

class Texture {
	@:allow(fried.graphics.Renderer)
	@:allow(fried.graphics.DrawQueue)
	var id:Int;

	var renderer:Renderer;
	var path:String;

	public var width(default, null):Int;
	public var height(default, null):Int;

	// The color of the image on average, which is what would stand for it where a mesh cannot be painted with it. No renderer reports it yet, so it is white, and such a mesh is painted with its albedo alone.
	public var averageColor(get, never):Color;

	public static function from(renderer:Renderer, path:String):Texture {
		var cached = renderer.cachedTexture(path);
		if (cached != null) {
			return cached;
		}

		var id = TextureNative.load(renderer.id, path);
		if (id < 0) {
			throw NativeError.describe('Failed to load texture: $path');
		}

		return new Texture(renderer, id, path);
	}

	// The texture that a PNG already in memory is, kept under the name it is asked for by so that asking again gives the same one.
	public static function fromBytes(renderer:Renderer, bytes:haxe.io.Bytes, name:String):Texture {
		var cached = renderer.cachedTexture(name);
		if (cached != null) {
			return cached;
		}

		var id = TextureNative.loadMemory(renderer.id, cpp.Pointer.ofArray(bytes.getData()).constRaw, bytes.length);
		if (id < 0) {
			throw NativeError.describe('Failed to load texture: $name');
		}

		return new Texture(renderer, id, name);
	}

	function new(renderer:Renderer, id:Int, path:String) {
		this.renderer = renderer;
		this.id = id;
		this.path = path;
		width = TextureNative.getWidth(id);
		height = TextureNative.getHeight(id);
		renderer.registerTexture(this, path);

		var downscale = TextureNative.getDownscale(id);
		if (downscale > 1) {
			Log.warn('$path is ${width}x${height}, more than this GPU takes, so it is stored at 1/$downscale of that and drawn blurrier.');
		}
	}

	// What a renderer knows the texture by, or -1 once it is destroyed.
	@:allow(fried.graphics3d.Mesh)
	function nativeId():Int {
		return id;
	}

	function get_averageColor():Color {
		return Color.rgb(255, 255, 255);
	}

	public function destroy():Void {
		if (id < 0) {
			return;
		}

		TextureNative.destroy(id);
		id = -1;
		width = 0;
		height = 0;

		renderer.unregisterTexture(this, path);
		renderer = null;
		path = null;
	}
}

@:include("graphics/texture.h")
private extern class TextureNative {
	@:native("fried_texture_load")
	static function load(rendererId:Int, path:cpp.ConstCharStar):Int;

	@:native("fried_texture_load_memory")
	static function loadMemory(rendererId:Int, data:cpp.RawConstPointer<cpp.UInt8>, size:Int):Int;

	@:native("fried_texture_destroy")
	static function destroy(id:Int):Void;

	@:native("fried_texture_get_width")
	static function getWidth(id:Int):Int;

	@:native("fried_texture_get_height")
	static function getHeight(id:Int):Int;

	@:native("fried_texture_get_downscale")
	static function getDownscale(id:Int):Int;
}
