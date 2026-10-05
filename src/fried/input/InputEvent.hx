package fried.input;

import fried.Window;

// Pooled and refilled every frame, so an event may not be kept past the frame
// it arrived in. Only the fields its type carries hold anything.
class InputEvent {
	public var type(default, null):InputEventType;
	public var handled:Bool;

	// Null for a gamepad event, and for one whose window the game has destroyed.
	public var window(default, null):Window;

	public var key(default, null):Key;
	public var mouseButton(default, null):MouseButton;
	public var gamepadButton(default, null):GamepadButton;
	public var gamepadAxis(default, null):GamepadAxis;

	public var touchDevice(default, null):Int;
	public var fingerId(default, null):Int;

	public var x(default, null):Int;
	public var y(default, null):Int;
	public var scrollX(default, null):Float;
	public var scrollY(default, null):Float;
	public var axisValue(default, null):Float;

	@:allow(fried.input.Input)
	function new() {
		reset(KeyDown, null);
	}

	public function toString():String {
		return switch (type) {
			case KeyDown | KeyUp: '$type($key)';
			case MouseButtonDown | MouseButtonUp: '$type($mouseButton at $x, $y)';
			case MouseMoved: '$type($x, $y)';
			case MouseWheel: '$type($scrollX, $scrollY)';
			case GamepadButtonDown | GamepadButtonUp: '$type($gamepadButton)';
			case GamepadAxisMoved: '$type($gamepadAxis at $axisValue)';
			case TouchDown | TouchUp | TouchMoved: '$type(finger $fingerId on device $touchDevice at $x, $y)';
		}
	}

	@:allow(fried.input.Input)
	function setKey(type:InputEventType, window:Window, key:Key):Void {
		reset(type, window);
		this.key = key;
	}

	@:allow(fried.input.Input)
	function setMouseButton(type:InputEventType, window:Window, button:MouseButton, x:Int, y:Int):Void {
		reset(type, window);
		mouseButton = button;
		this.x = x;
		this.y = y;
	}

	@:allow(fried.input.Input)
	function setMouseMotion(window:Window, x:Int, y:Int):Void {
		reset(MouseMoved, window);
		this.x = x;
		this.y = y;
	}

	@:allow(fried.input.Input)
	function setMouseWheel(window:Window, scrollX:Float, scrollY:Float):Void {
		reset(MouseWheel, window);
		this.scrollX = scrollX;
		this.scrollY = scrollY;
	}

	@:allow(fried.input.Input)
	function setGamepadButton(type:InputEventType, button:GamepadButton):Void {
		reset(type, null);
		gamepadButton = button;
	}

	@:allow(fried.input.Input)
	function setGamepadAxis(axis:GamepadAxis, value:Float):Void {
		reset(GamepadAxisMoved, null);
		gamepadAxis = axis;
		axisValue = value;
	}

	@:allow(fried.input.Input)
	function setTouch(type:InputEventType, window:Window, device:Int, fingerId:Int, x:Int, y:Int):Void {
		reset(type, window);
		touchDevice = device;
		this.fingerId = fingerId;
		this.x = x;
		this.y = y;
	}

	function reset(type:InputEventType, window:Window):Void {
		this.type = type;
		this.window = window;
		handled = false;
		key = cast 0;
		mouseButton = cast 0;
		gamepadButton = cast 0;
		gamepadAxis = cast 0;
		touchDevice = 0;
		fingerId = 0;
		x = 0;
		y = 0;
		scrollX = 0.0;
		scrollY = 0.0;
		axisValue = 0.0;
	}
}
