package fried;

class Texture {
	@:allow(fried.Renderer)
	var id:Int;

	public var width(default, null):Int;
	public var height(default, null):Int;

	public function new(renderer:Renderer, path:String) {
		id = TextureNative.load(renderer.id, path);
		if (id < 0) {
			throw 'Failed to load texture: $path';
		}
		width = TextureNative.getWidth(id);
		height = TextureNative.getHeight(id);
	}

	public function destroy():Void {
		TextureNative.destroy(id);
		id = -1;
		width = 0;
		height = 0;
	}
}

@:include("texture.h")
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
