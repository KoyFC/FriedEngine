package fried;

class Window {
	static var instances:Map<Int, Window> = new Map();

	public static var maxCount(get, never):Int;

	@:allow(fried.graphics.Renderer)
	var id:Int;

	public var width(get, never):Int;
	public var height(get, never):Int;

	/** Where the window's top left corner sits on the desktop. A console's window is its screen, so there it stays at 0, 0. **/
	public var x(get, set):Int;

	public var y(get, set):Int;

	public var onClose:Void->Void;
	public var onResize:Int->Int->Void;
	public var onMove:Int->Int->Void;
	public var onFocusChanged:Bool->Void;

	public function new(title:String, width:Int, height:Int) {
		id = WindowNative.create(title, width, height);
		if (id < 0) {
			throw NativeError.describe("Failed to create window");
		}
		instances.set(id, this);
	}

	/** Moves both coordinates in one call, which assigning x and then y does not: the second assignment reads the first one back before the window manager has applied it. **/
	public function setPosition(x:Int, y:Int):Void {
		WindowNative.setPosition(id, x, y);
	}

	public function setIcon(path:String):Void {
		if (!WindowNative.setIcon(id, path)) {
			throw NativeError.describe('Failed to set window icon: $path');
		}
	}

	public function destroy():Void {
		instances.remove(id);
		WindowNative.destroy(id);
		id = -1;
	}

	@:allow(fried.Events)
	@:allow(fried.input.Input)
	static function fromId(id:Int):Null<Window> {
		return instances.get(id);
	}

	static function get_maxCount():Int {
		return WindowNative.getMaxCount();
	}

	function get_x():Int {
		return WindowNative.getX(id);
	}

	function set_x(value:Int):Int {
		WindowNative.setPosition(id, value, y);
		return value;
	}

	function get_y():Int {
		return WindowNative.getY(id);
	}

	function set_y(value:Int):Int {
		WindowNative.setPosition(id, x, value);
		return value;
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
	@:native("fried_window_get_max_count")
	static function getMaxCount():Int;

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

	@:native("fried_window_get_x")
	static function getX(id:Int):Int;

	@:native("fried_window_get_y")
	static function getY(id:Int):Int;

	@:native("fried_window_set_position")
	static function setPosition(id:Int, x:Int, y:Int):Void;
}
