package fried.graphics;

class Font {
	var id:Int;

	public var size(default, null):Int;
	public var lineHeight(default, null):Int;

	public function new(path:String, size:Int) {
		id = FontNative.load(path, size);
		if (id < 0) {
			throw 'Failed to load font: $path';
		}
		this.size = size;
		lineHeight = FontNative.getLineHeight(id);
	}

	public function destroy():Void {
		FontNative.destroy(id);
		id = -1;
		size = 0;
		lineHeight = 0;
	}

	public function measureWidth(text:String):Int {
		return FontNative.measureWidth(id, text);
	}

	public function renderText(renderer:Renderer, text:String, color:Color):Texture {
		var textureId = FontNative.renderText(id, renderer.id, text, color.red, color.green, color.blue, color.alpha);
		if (textureId < 0) {
			throw 'Failed to render text: $text';
		}
		return new Texture(renderer, textureId);
	}
}

@:include("graphics/font.h")
private extern class FontNative {
	@:native("fried_font_load")
	static function load(path:cpp.ConstCharStar, size:Int):Int;

	@:native("fried_font_destroy")
	static function destroy(id:Int):Void;

	@:native("fried_font_get_line_height")
	static function getLineHeight(id:Int):Int;

	@:native("fried_font_measure_width")
	static function measureWidth(id:Int, text:cpp.ConstCharStar):Int;

	@:native("fried_font_render_text")
	static function renderText(id:Int, rendererId:Int, text:cpp.ConstCharStar, r:Int, g:Int, b:Int, a:Int):Int;
}
