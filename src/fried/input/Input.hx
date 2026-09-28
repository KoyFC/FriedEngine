package fried.input;

class Input {
	public static var mouseX(get, never):Int;
	public static var mouseY(get, never):Int;
	public static var scrollX(get, never):Float;
	public static var scrollY(get, never):Float;

	public static var isGamepadConnected(get, never):Bool;
	public static var gamepadDeadzone(get, set):Float;

	public static function isKeyPressed(key:Key):Bool {
		return InputNative.isKeyPressed(key) != 0;
	}

	public static function isKeyDown(key:Key):Bool {
		return InputNative.isKeyDown(key) != 0;
	}

	public static function isKeyReleased(key:Key):Bool {
		return InputNative.isKeyReleased(key) != 0;
	}

	public static function isButtonPressed(button:MouseButton):Bool {
		return MouseNative.isButtonPressed(button) != 0;
	}

	public static function isButtonDown(button:MouseButton):Bool {
		return MouseNative.isButtonDown(button) != 0;
	}

	public static function isButtonReleased(button:MouseButton):Bool {
		return MouseNative.isButtonReleased(button) != 0;
	}

	public static function isGamepadButtonPressed(button:GamepadButton):Bool {
		return GamepadNative.isButtonPressed(button) != 0;
	}

	public static function isGamepadButtonDown(button:GamepadButton):Bool {
		return GamepadNative.isButtonDown(button) != 0;
	}

	public static function isGamepadButtonReleased(button:GamepadButton):Bool {
		return GamepadNative.isButtonReleased(button) != 0;
	}

	public static function getGamepadAxis(axis:GamepadAxis):Float {
		return GamepadNative.getAxis(axis);
	}

	@:allow(fried.Application)
	static function endFrame():Void {
		InputNative.endFrame();
		MouseNative.endFrame();
		GamepadNative.endFrame();
	}

	static function get_mouseX():Int {
		return MouseNative.getX();
	}

	static function get_mouseY():Int {
		return MouseNative.getY();
	}

	static function get_scrollX():Float {
		return MouseNative.getScrollX();
	}

	static function get_scrollY():Float {
		return MouseNative.getScrollY();
	}

	static function get_isGamepadConnected():Bool {
		return GamepadNative.isConnected() != 0;
	}

	static function get_gamepadDeadzone():Float {
		return GamepadNative.getDeadzone();
	}

	static function set_gamepadDeadzone(deadzone:Float):Float {
		GamepadNative.setDeadzone(deadzone);
		return GamepadNative.getDeadzone();
	}
}

@:include("platform/input.h")
private extern class InputNative {
	@:native("fried_input_is_key_pressed")
	static function isKeyPressed(scancode:Int):Int;

	@:native("fried_input_is_key_down")
	static function isKeyDown(scancode:Int):Int;

	@:native("fried_input_is_key_released")
	static function isKeyReleased(scancode:Int):Int;

	@:native("fried_input_end_frame")
	static function endFrame():Void;
}

@:include("platform/mouse.h")
private extern class MouseNative {
	@:native("fried_mouse_get_x")
	static function getX():Int;

	@:native("fried_mouse_get_y")
	static function getY():Int;

	@:native("fried_mouse_is_button_pressed")
	static function isButtonPressed(button:Int):Int;

	@:native("fried_mouse_is_button_down")
	static function isButtonDown(button:Int):Int;

	@:native("fried_mouse_is_button_released")
	static function isButtonReleased(button:Int):Int;

	@:native("fried_mouse_get_scroll_x")
	static function getScrollX():Float;

	@:native("fried_mouse_get_scroll_y")
	static function getScrollY():Float;

	@:native("fried_mouse_end_frame")
	static function endFrame():Void;
}

@:include("platform/gamepad.h")
private extern class GamepadNative {
	@:native("fried_gamepad_is_connected")
	static function isConnected():Int;

	@:native("fried_gamepad_is_button_pressed")
	static function isButtonPressed(button:Int):Int;

	@:native("fried_gamepad_is_button_down")
	static function isButtonDown(button:Int):Int;

	@:native("fried_gamepad_is_button_released")
	static function isButtonReleased(button:Int):Int;

	@:native("fried_gamepad_get_axis")
	static function getAxis(axis:Int):Float;

	@:native("fried_gamepad_get_deadzone")
	static function getDeadzone():Float;

	@:native("fried_gamepad_set_deadzone")
	static function setDeadzone(deadzone:Float):Void;

	@:native("fried_gamepad_end_frame")
	static function endFrame():Void;
}
