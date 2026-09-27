package fried.graphics;

abstract Color(Int) {
	public var red(get, never):Int;
	public var green(get, never):Int;
	public var blue(get, never):Int;
	public var alpha(get, never):Int;

	inline function new(value:Int) {
		this = value;
	}

	public static inline function rgb(red:Int, green:Int, blue:Int):Color {
		return rgba(red, green, blue, 255);
	}

	public static inline function rgba(red:Int, green:Int, blue:Int, alpha:Int):Color {
		return new Color((alpha << 24) | (red << 16) | (green << 8) | blue);
	}

	inline function get_red():Int {
		return (this >> 16) & 0xFF;
	}

	inline function get_green():Int {
		return (this >> 8) & 0xFF;
	}

	inline function get_blue():Int {
		return this & 0xFF;
	}

	inline function get_alpha():Int {
		return (this >> 24) & 0xFF;
	}
}
