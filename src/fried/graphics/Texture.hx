package fried.graphics;

class Texture {
	static var pathToTextureMap:Map<String, Texture> = new Map();
	static var activeTextures:Array<Texture> = [];

	@:allow(fried.graphics.Renderer)
	var id:Int;

	var path:String;

	public var width(default, null):Int;
	public var height(default, null):Int;

	public static function from(renderer:Renderer, path:String):Texture {
		var cached = pathToTextureMap.get(path);
		if (cached != null) {
			return cached;
		}

		var id = TextureNative.load(renderer.id, path);
		if (id < 0) {
			throw 'Failed to load texture: $path';
		}

		var texture = new Texture(id, path);
		pathToTextureMap.set(path, texture);
		return texture;
	}

	@:allow(fried.graphics.Font)
	function new(id:Int, ?path:String) {
		this.id = id;
		this.path = path;
		width = TextureNative.getWidth(id);
		height = TextureNative.getHeight(id);
		activeTextures.push(this);
	}

	public function destroy():Void {
		if (id < 0) {
			return;
		}

		TextureNative.destroy(id);
		id = -1;
		width = 0;
		height = 0;

		activeTextures.remove(this);
		if (path != null) {
			pathToTextureMap.remove(path);
			path = null;
		}
	}

	@:allow(fried.Application)
	static function destroyAll():Void {
		for (texture in activeTextures.copy()) {
			texture.destroy();
		}
		activeTextures = [];
		pathToTextureMap = new Map();
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
}
