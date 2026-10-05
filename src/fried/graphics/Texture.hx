package fried.graphics;

import fried.Log;
import fried.NativeError;

class Texture {
	@:allow(fried.graphics.Renderer)
	var id:Int;

	var renderer:Renderer;
	var path:String;

	public var width(default, null):Int;
	public var height(default, null):Int;

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

	@:allow(fried.graphics.Font)
	function new(renderer:Renderer, id:Int, ?path:String) {
		this.renderer = renderer;
		this.id = id;
		this.path = path;
		width = TextureNative.getWidth(id);
		height = TextureNative.getHeight(id);
		renderer.registerTexture(this, path);

		var downscale = TextureNative.getDownscale(id);
		if (downscale > 1) {
			var source = path != null ? path : "A rendered text";
			Log.warn('$source is ${width}x${height}, more than this GPU takes, so it is stored at 1/$downscale of that and drawn blurrier.');
		}
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

	@:native("fried_texture_destroy")
	static function destroy(id:Int):Void;

	@:native("fried_texture_get_width")
	static function getWidth(id:Int):Int;

	@:native("fried_texture_get_height")
	static function getHeight(id:Int):Int;

	@:native("fried_texture_get_downscale")
	static function getDownscale(id:Int):Int;
}
