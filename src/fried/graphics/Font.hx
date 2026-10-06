package fried.graphics;

import fried.NativeError;

class Font {
	static var fontsByKey:Map<String, Font> = new Map();
	static var activeFonts:Array<Font> = [];

	var id:Int;
	var key:String;

	public var size(default, null):Int;
	public var lineHeight(default, null):Int;

	public static function from(path:String, size:Int):Font {
		// The size is part of the key because one file at two sizes is two TTF_Fonts
		var key = '$size:$path';
		var cached = fontsByKey.get(key);
		if (cached != null) {
			return cached;
		}

		return new Font(path, size, key);
	}

	function new(path:String, size:Int, key:String) {
		id = FontNative.load(path, size);
		if (id < 0) {
			throw NativeError.describe('Failed to load font: $path');
		}
		this.size = size;
		this.key = key;
		lineHeight = FontNative.getLineHeight(id);

		fontsByKey.set(key, this);
		activeFonts.push(this);
	}

	public function destroy():Void {
		if (id < 0) {
			return;
		}

		FontNative.destroy(id);
		id = -1;
		size = 0;
		lineHeight = 0;

		activeFonts.remove(this);
		fontsByKey.remove(key);
		key = null;
	}

	@:allow(fried.Application)
	static function destroyAll():Void {
		for (font in activeFonts.copy()) {
			font.destroy();
		}
		activeFonts.resize(0);
		fontsByKey.clear();
	}

	public function measureWidth(text:String):Int {
		return FontNative.measureWidth(id, text);
	}

	@:allow(fried.graphics.Renderer)
	function drawText(renderer:Renderer, text:String, x:Int, y:Int, width:Int, height:Int, angle:Float, color:Color):Void {
		FontNative.drawText(id, renderer.id, text, x, y, width, height, angle, color.red, color.green, color.blue, color.alpha);
	}

	public function renderText(renderer:Renderer, text:String, color:Color):Texture {
		var textureId = FontNative.renderText(id, renderer.id, text, color.red, color.green, color.blue, color.alpha);
		if (textureId < 0) {
			throw NativeError.describe('Failed to render text: $text');
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

	@:native("fried_font_draw_text")
	static function drawText(id:Int, rendererId:Int, text:cpp.ConstCharStar, x:Int, y:Int, width:Int, height:Int, angle:Float, r:Int, g:Int, b:Int,
		a:Int):Void;
}
