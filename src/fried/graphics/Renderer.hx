package fried.graphics;

import fried.Window;

class Renderer {
	@:allow(fried.graphics.Texture)
	@:allow(fried.graphics.Font)
	var id:Int;

	public var isVsyncEnabled(default, null):Bool;

	public var width(get, never):Int;
	public var height(get, never):Int;

	public var drawColor(default, set):Color;

	var cachedByPath:Map<String, Texture>;
	var liveTextures:Array<Texture>;

	@:allow(fried.Application)
	function new(window:Window, requestVsync:Bool) {
		id = RendererNative.create(window.id, requestVsync);
		if (id < 0) {
			throw "Failed to create renderer";
		}
		isVsyncEnabled = RendererNative.hasVsync(id);
		drawColor = Color.rgb(255, 255, 255);
		cachedByPath = new Map();
		liveTextures = [];
	}

	@:allow(fried.Application)
	function destroy():Void {
		for (texture in liveTextures.copy()) {
			texture.destroy();
		}
		liveTextures.resize(0);
		cachedByPath.clear();

		RendererNative.destroy(id);
		id = -1;
	}

	@:allow(fried.graphics.Texture)
	function cachedTexture(path:String):Texture {
		return cachedByPath.get(path);
	}

	@:allow(fried.graphics.Texture)
	function registerTexture(texture:Texture, path:String):Void {
		liveTextures.push(texture);
		if (path != null) {
			cachedByPath.set(path, texture);
		}
	}

	@:allow(fried.graphics.Texture)
	function unregisterTexture(texture:Texture, path:String):Void {
		liveTextures.remove(texture);
		if (path != null) {
			cachedByPath.remove(path);
		}
	}

	function set_drawColor(color:Color):Color {
		drawColor = color;
		RendererNative.setDrawColor(id, color.red, color.green, color.blue, color.alpha);
		return color;
	}

	public function clear():Void {
		RendererNative.clear(id);
	}

	public function present():Void {
		RendererNative.present(id);
	}

	public function drawTexture(texture:Texture, x:Int, y:Int, ?width:Int, ?height:Int):Void {
		RendererNative.drawTexture(id, texture.id, x, y, width != null ? width : texture.width, height != null ? height : texture.height);
	}

	public function drawTextureRegion(texture:Texture, x:Int, y:Int, ?source:Rect, ?width:Int, ?height:Int, angle:Float = 0.0, flip:FlipMode = None):Void {
		var srcWidth = source != null ? source.width : texture.width;
		var srcHeight = source != null ? source.height : texture.height;
		RendererNative.drawTextureEx(id, texture.id, source != null ? source.x : 0, source != null ? source.y : 0, srcWidth, srcHeight, x, y,
			width != null ? width : srcWidth, height != null ? height : srcHeight, angle, cast flip);
	}

	public function fillRect(rect:Rect):Void {
		RendererNative.fillRect(id, rect.x, rect.y, rect.width, rect.height);
	}

	public function drawRect(rect:Rect):Void {
		RendererNative.drawRect(id, rect.x, rect.y, rect.width, rect.height);
	}

	function get_width():Int {
		return RendererNative.getWidth(id);
	}

	function get_height():Int {
		return RendererNative.getHeight(id);
	}
}

@:include("graphics/renderer.h")
private extern class RendererNative {
	@:native("fried_renderer_create")
	static function create(windowId:Int, vsync:Bool):Int;

	@:native("fried_renderer_destroy")
	static function destroy(id:Int):Void;

	@:native("fried_renderer_has_vsync")
	static function hasVsync(id:Int):Bool;

	@:native("fried_renderer_get_width")
	static function getWidth(id:Int):Int;

	@:native("fried_renderer_get_height")
	static function getHeight(id:Int):Int;

	@:native("fried_renderer_set_draw_color")
	static function setDrawColor(id:Int, r:Int, g:Int, b:Int, a:Int):Void;

	@:native("fried_renderer_clear")
	static function clear(id:Int):Void;

	@:native("fried_renderer_present")
	static function present(id:Int):Void;

	@:native("fried_renderer_draw_texture")
	static function drawTexture(id:Int, textureId:Int, x:Int, y:Int, width:Int, height:Int):Void;

	@:native("fried_renderer_draw_texture_ex")
	static function drawTextureEx(id:Int, textureId:Int, srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, x:Int, y:Int, width:Int, height:Int, angle:Float,
		flipMode:Int):Void;

	@:native("fried_renderer_fill_rect")
	static function fillRect(id:Int, x:Int, y:Int, width:Int, height:Int):Void;

	@:native("fried_renderer_draw_rect")
	static function drawRect(id:Int, x:Int, y:Int, width:Int, height:Int):Void;
}
