package fried;

class Window {
	static var instances:Map<Int, Window> = new Map();

	@:allow(fried.graphics.Renderer)
	var id:Int;

	public var width(get, never):Int;
	public var height(get, never):Int;

	public var onClose:Void->Void;
	public var onResize:Int->Int->Void;
	public var onFocusChanged:Bool->Void;

	public function new(title:String, width:Int, height:Int) {
		id = WindowNative.create(title, width, height);
		if (id < 0) {
			throw "Failed to create window";
		}
		instances.set(id, this);
	}

	public function setIcon(path:String):Void {
		if (!WindowNative.setIcon(id, path)) {
			throw 'Failed to set window icon: $path';
		}
	}

	public function destroy():Void {
		instances.remove(id);
		WindowNative.destroy(id);
		id = -1;
	}

	@:allow(fried.Events)
	static function fromId(id:Int):Null<Window> {
		return instances.get(id);
	}

	function get_width():Int {
		return WindowNative.getWidth(id);
	}

	function get_height():Int {
		return WindowNative.getHeight(id);
	}
}

@:include("platform/window.h")
private extern class WindowNative {
	@:native("fried_window_create")
	static function create(title:cpp.ConstCharStar, width:Int, height:Int):Int;

	@:native("fried_window_destroy")
	static function destroy(id:Int):Void;

	@:native("fried_window_set_icon")
	static function setIcon(id:Int, path:cpp.ConstCharStar):Bool;

	@:native("fried_window_get_width")
	static function getWidth(id:Int):Int;

	@:native("fried_window_get_height")
	static function getHeight(id:Int):Int;
}
