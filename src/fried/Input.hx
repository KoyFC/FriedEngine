package fried;

class Input {
	public static function isKeyDown(key:Key):Bool {
		return InputNative.isKeyDown(key) != 0;
	}

	public static function isKeyPressed(key:Key):Bool {
		return InputNative.isKeyPressed(key) != 0;
	}

	public static function isKeyReleased(key:Key):Bool {
		return InputNative.isKeyReleased(key) != 0;
	}

	@:allow(fried.Application)
	static function endFrame():Void {
		InputNative.endFrame();
	}
}

@:include("input.h")
private extern class InputNative {
	@:native("fried_input_is_key_down")
	static function isKeyDown(scancode:Int):Int;

	@:native("fried_input_is_key_pressed")
	static function isKeyPressed(scancode:Int):Int;

	@:native("fried_input_is_key_released")
	static function isKeyReleased(scancode:Int):Int;

	@:native("fried_input_end_frame")
	static function endFrame():Void;
}
