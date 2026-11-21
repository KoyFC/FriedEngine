package fried.input;

import fried.Window;

class Input {
	static inline var NO_EVENT:Int = 0;

	static var eventPool:Array<InputEvent> = [];

	public static var events(default, null):Array<InputEvent> = [];

	#if fried_editor
	// The editor shows a game in its own panel, where the window never has the keyboard or the mouse, so it sends them. Once anything has been sent, the keys, the mouse and its events are the editor's and not the window's.
	static inline var KEY_COUNT = 512;
	static inline var BUTTON_COUNT = 8;

	static var isInjecting:Bool = false;
	static var keysDown:Array<Bool> = [for (_ in 0...KEY_COUNT) false];
	static var keysBefore:Array<Bool> = [for (_ in 0...KEY_COUNT) false];
	static var buttonsDown:Array<Bool> = [for (_ in 0...BUTTON_COUNT) false];
	static var buttonsBefore:Array<Bool> = [for (_ in 0...BUTTON_COUNT) false];
	static var injectedX:Int = 0;
	static var injectedY:Int = 0;
	static var injectedScrollX:Float = 0.0;
	static var injectedScrollY:Float = 0.0;
	static var injected:Array<{type:InputEventType, window:Window, code:Int, x:Int, y:Int, scrollX:Float, scrollY:Float}> = [];

	// Queues an event of the editor's, which takes effect with the events of the next frame like a real one. A key or a button carries its code, a motion or a button the position in the game's pixels, and a wheel how far it turned.
	public static function inject(type:InputEventType, window:Window, code:Int = 0, x:Int = 0, y:Int = 0, scrollX:Float = 0.0, scrollY:Float = 0.0):Void {
		isInjecting = true;
		injected.push({type: type, window: window, code: code, x: x, y: y, scrollX: scrollX, scrollY: scrollY});
	}

	static function applyInjected():Void {
		injectedScrollX = 0.0;
		injectedScrollY = 0.0;
		for (item in injected) {
			var event = nextEvent();
			switch (item.type) {
				case KeyDown | KeyUp:
					if (item.code >= 0 && item.code < KEY_COUNT) {
						keysDown[item.code] = item.type == KeyDown;
					}
					event.setKey(item.type, item.window, cast item.code);
				case MouseButtonDown | MouseButtonUp:
					if (item.code >= 0 && item.code < BUTTON_COUNT) {
						buttonsDown[item.code] = item.type == MouseButtonDown;
					}
					injectedX = item.x;
					injectedY = item.y;
					event.setMouseButton(item.type, item.window, cast item.code, item.x, item.y);
				case MouseMoved:
					injectedX = item.x;
					injectedY = item.y;
					event.setMouseMotion(item.window, item.x, item.y);
				case MouseWheel:
					injectedScrollX += item.scrollX;
					injectedScrollY += item.scrollY;
					event.setMouseWheel(item.window, item.scrollX, item.scrollY);
				case _:
					events.pop();
			}
		}
		injected.resize(0);
	}
	#end

	public static var mouseX(get, never):Int;
	public static var mouseY(get, never):Int;
	public static var scrollX(get, never):Float;
	public static var scrollY(get, never):Float;

	public static var touchDeviceCount(get, never):Int;

	public static var isGamepadConnected(get, never):Bool;
	public static var gamepadDeadzone(get, set):Float;

	public static var gamepadAcceptButton(get, never):GamepadButton;
	public static var gamepadCancelButton(get, never):GamepadButton;

	public static function isKeyPressed(key:Key):Bool {
		#if fried_editor
		if (isInjecting) {
			return keysDown[key];
		}
		#end
		return InputNative.isKeyPressed(key) != 0;
	}

	public static function isKeyDown(key:Key):Bool {
		#if fried_editor
		if (isInjecting) {
			return keysDown[key] && !keysBefore[key];
		}
		#end
		return InputNative.isKeyDown(key) != 0;
	}

	public static function isKeyReleased(key:Key):Bool {
		#if fried_editor
		if (isInjecting) {
			return !keysDown[key] && keysBefore[key];
		}
		#end
		return InputNative.isKeyReleased(key) != 0;
	}

	public static function isButtonPressed(button:MouseButton):Bool {
		#if fried_editor
		if (isInjecting) {
			return buttonsDown[button];
		}
		#end
		return MouseNative.isButtonPressed(button) != 0;
	}

	public static function isButtonDown(button:MouseButton):Bool {
		#if fried_editor
		if (isInjecting) {
			return buttonsDown[button] && !buttonsBefore[button];
		}
		#end
		return MouseNative.isButtonDown(button) != 0;
	}

	public static function isButtonReleased(button:MouseButton):Bool {
		#if fried_editor
		if (isInjecting) {
			return !buttonsDown[button] && buttonsBefore[button];
		}
		#end
		return MouseNative.isButtonReleased(button) != 0;
	}

	// On the Vita device 0 is the front screen and 1 the rear pad. A finger's
	// index shifts down when an earlier finger lifts; its id does not.
	public static function isTouchPressed(device:Int = 0):Bool {
		return TouchNative.getFingerCount(device) > 0;
	}

	public static function isTouchDown(device:Int = 0):Bool {
		return TouchNative.isDown(device) != 0;
	}

	public static function isTouchReleased(device:Int = 0):Bool {
		return TouchNative.isReleased(device) != 0;
	}

	public static function getTouchCount(device:Int = 0):Int {
		return TouchNative.getFingerCount(device);
	}

	public static function getTouchFingerId(index:Int, device:Int = 0):Int {
		return TouchNative.getFingerId(device, index);
	}

	public static function getTouchX(index:Int, device:Int = 0):Int {
		return TouchNative.getX(device, index);
	}

	public static function getTouchY(index:Int, device:Int = 0):Int {
		return TouchNative.getY(device, index);
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

	@:allow(fried.Events)
	static function collectEvents():Void {
		events.resize(0);

		var nativeType = EventsNative.pollInputEvent();
		while (nativeType != NO_EVENT) {
			var type:InputEventType = cast nativeType;
			var window = Window.fromId(EventsNative.getWindowId());
			var code = EventsNative.getCode();
			var event = nextEvent();
			switch (type) {
				case KeyDown | KeyUp:
					event.setKey(type, window, cast code);
				case MouseButtonDown | MouseButtonUp:
					event.setMouseButton(type, window, cast code, EventsNative.getX(), EventsNative.getY());
				case MouseMoved:
					event.setMouseMotion(window, EventsNative.getX(), EventsNative.getY());
				case MouseWheel:
					event.setMouseWheel(window, EventsNative.getScrollX(), EventsNative.getScrollY());
				case GamepadButtonDown | GamepadButtonUp:
					event.setGamepadButton(type, cast code);
				case GamepadAxisMoved:
					event.setGamepadAxis(cast code, EventsNative.getValue());
				case TouchDown | TouchUp | TouchMoved:
					event.setTouch(type, window, EventsNative.getDevice(), code, EventsNative.getX(), EventsNative.getY());
			}
			nativeType = EventsNative.pollInputEvent();
		}
		#if fried_editor
		applyInjected();
		#end
	}

	static function nextEvent():InputEvent {
		if (events.length == eventPool.length) {
			eventPool.push(new InputEvent());
		}
		var event = eventPool[events.length];
		events.push(event);
		return event;
	}

	@:allow(fried.Application)
	static function endFrame():Void {
		#if fried_editor
		for (index in 0...KEY_COUNT) {
			keysBefore[index] = keysDown[index];
		}
		for (index in 0...BUTTON_COUNT) {
			buttonsBefore[index] = buttonsDown[index];
		}
		#end
		InputNative.endFrame();
		MouseNative.endFrame();
		GamepadNative.endFrame();
		TouchNative.endFrame();
	}

	static function get_mouseX():Int {
		#if fried_editor
		if (isInjecting) {
			return injectedX;
		}
		#end
		return MouseNative.getX();
	}

	static function get_mouseY():Int {
		#if fried_editor
		if (isInjecting) {
			return injectedY;
		}
		#end
		return MouseNative.getY();
	}

	static function get_scrollX():Float {
		#if fried_editor
		if (isInjecting) {
			return injectedScrollX;
		}
		#end
		return MouseNative.getScrollX();
	}

	static function get_scrollY():Float {
		#if fried_editor
		if (isInjecting) {
			return injectedScrollY;
		}
		#end
		return MouseNative.getScrollY();
	}

	static function get_touchDeviceCount():Int {
		return TouchNative.getDeviceCount();
	}

	static function get_isGamepadConnected():Bool {
		return GamepadNative.isConnected() != 0;
	}

	static function get_gamepadAcceptButton():GamepadButton {
		return cast GamepadNative.getAcceptButton();
	}

	static function get_gamepadCancelButton():GamepadButton {
		return cast GamepadNative.getCancelButton();
	}

	static function get_gamepadDeadzone():Float {
		return GamepadNative.getDeadzone();
	}

	static function set_gamepadDeadzone(deadzone:Float):Float {
		GamepadNative.setDeadzone(deadzone);
		return GamepadNative.getDeadzone();
	}
}

// `fried.Events` drains the window half of this same header, so each class owns
// the events it exposes.
@:include("platform/events.h")
private extern class EventsNative {
	@:native("fried_events_poll_input_event")
	static function pollInputEvent():Int;

	@:native("fried_events_get_input_window_id")
	static function getWindowId():Int;

	@:native("fried_events_get_input_code")
	static function getCode():Int;

	@:native("fried_events_get_input_device")
	static function getDevice():Int;

	@:native("fried_events_get_input_x")
	static function getX():Int;

	@:native("fried_events_get_input_y")
	static function getY():Int;

	@:native("fried_events_get_input_scroll_x")
	static function getScrollX():Float;

	@:native("fried_events_get_input_scroll_y")
	static function getScrollY():Float;

	@:native("fried_events_get_input_value")
	static function getValue():Float;
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

	@:native("fried_gamepad_get_accept_button")
	static function getAcceptButton():Int;

	@:native("fried_gamepad_get_cancel_button")
	static function getCancelButton():Int;

	@:native("fried_gamepad_get_axis")
	static function getAxis(axis:Int):Float;

	@:native("fried_gamepad_get_deadzone")
	static function getDeadzone():Float;

	@:native("fried_gamepad_set_deadzone")
	static function setDeadzone(deadzone:Float):Void;

	@:native("fried_gamepad_end_frame")
	static function endFrame():Void;
}

@:include("platform/touch.h")
private extern class TouchNative {
	@:native("fried_touch_get_device_count")
	static function getDeviceCount():Int;

	@:native("fried_touch_get_finger_count")
	static function getFingerCount(device:Int):Int;

	@:native("fried_touch_get_finger_id")
	static function getFingerId(device:Int, index:Int):Int;

	@:native("fried_touch_get_x")
	static function getX(device:Int, index:Int):Int;

	@:native("fried_touch_get_y")
	static function getY(device:Int, index:Int):Int;

	@:native("fried_touch_is_down")
	static function isDown(device:Int):Int;

	@:native("fried_touch_is_released")
	static function isReleased(device:Int):Int;

	@:native("fried_touch_end_frame")
	static function endFrame():Void;
}
