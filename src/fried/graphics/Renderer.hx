package fried.graphics;

import fried.Window;

class Renderer {
	@:allow(fried.graphics.Texture)
	var id:Int;

	public var vsync(default, null):Bool;

	public var width(get, never):Int;
	public var height(get, never):Int;

	@:allow(fried.Application)
	function new(window:Window, requestVsync:Bool) {
		id = RendererNative.create(window.id, requestVsync);
		if (id < 0) {
			throw "Failed to create renderer";
		}
		vsync = RendererNative.hasVsync(id);
	}

	public function destroy():Void {
		RendererNative.destroy(id);
		id = -1;
	}

	public function setDrawColor(r:Int, g:Int, b:Int, a:Int = 255):Void {
		RendererNative.setDrawColor(id, r, g, b, a);
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
}
