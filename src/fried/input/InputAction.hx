package fried.input;

import fried.input.InputBinding;
import fried.input.InputSource;

// The strongest binding wins rather than their sum, so a stick and a key held
// together never go past 1.
class InputAction {
	static var enabledActions:Array<InputAction> = [];
	static var snapshot:Array<InputAction> = [];

	// A source's id is its type's base plus its own code.
	static inline var KEY_ID_BASE:Int = 0;
	static inline var MOUSE_ID_BASE:Int = 1024;
	static inline var PAD_ID_BASE:Int = 2048;
	static inline var TOUCH_ID_BASE:Int = 3072;

	// Sources whose press a layer handled, silent until they are let go.
	static var consumedSources:Map<Int, Bool> = [];
	static var consumedCount:Int = 0;

	// Binding results, kept static so a frame allocates nothing.
	static var readX:Float = 0.0;
	static var readY:Float = 0.0;

	public var name(default, null):String;
	public var type(default, null):InputActionType;

	// The value from which the action counts as pressed.
	public var pressThreshold:Float;

	// Reads sources a layer already handled instead of skipping them.
	public var ignoresHandled:Bool;

	public var onPressed:Void->Void;
	public var onReleased:Void->Void;

	public var isEnabled(default, null):Bool;

	public var value(default, null):Float;
	public var x(default, null):Float;
	public var y(default, null):Float;

	public var isPressed(default, null):Bool;
	public var isDown(default, null):Bool;
	public var isReleased(default, null):Bool;

	var bindings:Array<InputBinding> = [];

	public function new(name:String, type:InputActionType) {
		this.name = name;
		this.type = type;
		pressThreshold = 0.5;
	}

	public function addBinding(binding:InputBinding):InputAction {
		bindings.push(binding);
		return this;
	}

	public function addKey(key:Key):InputAction {
		return addBinding(Single(Keyboard(key)));
	}

	public function addMouseButton(button:MouseButton):InputAction {
		return addBinding(Single(Mouse(button)));
	}

	public function addGamepadButton(button:GamepadButton):InputAction {
		return addBinding(Single(PadButton(button)));
	}

	public function addGamepadAxis(axis:GamepadAxis):InputAction {
		return addBinding(Single(PadAxis(axis)));
	}

	public function clearBindings():Void {
		bindings.resize(0);
	}

	// An input already held does not count as a press.
	public function enable():Void {
		if (isEnabled) {
			return;
		}
		isEnabled = true;
		enabledActions.push(this);
		evaluate();
		isDown = false;
		isReleased = false;
	}

	public function disable():Void {
		if (!isEnabled) {
			return;
		}
		isEnabled = false;
		enabledActions.remove(this);
		value = 0.0;
		x = 0.0;
		y = 0.0;
		isPressed = false;
		isDown = false;
		isReleased = false;
	}

	@:allow(fried.Application)
	static function updateAll():Void {
		consumeHandledEvents();
		snapshot.resize(0);
		for (action in enabledActions) {
			snapshot.push(action);
			action.evaluate();
		}
		for (action in snapshot) {
			if (!action.isEnabled) {
				continue;
			}
			if (action.isDown && action.onPressed != null) {
				action.onPressed();
			}
			if (action.isReleased && action.onReleased != null) {
				action.onReleased();
			}
		}
	}

	static function consumeHandledEvents():Void {
		for (event in Input.events) {
			switch (event.type) {
				case KeyDown if (event.handled):
					consume(KEY_ID_BASE, event.key);
				case MouseButtonDown if (event.handled):
					consume(MOUSE_ID_BASE, event.mouseButton);
				case GamepadButtonDown if (event.handled):
					consume(PAD_ID_BASE, event.gamepadButton);
				case TouchDown if (event.handled):
					consume(TOUCH_ID_BASE, event.touchDevice);
				case KeyUp:
					release(KEY_ID_BASE, event.key);
				case MouseButtonUp:
					release(MOUSE_ID_BASE, event.mouseButton);
				case GamepadButtonUp:
					release(PAD_ID_BASE, event.gamepadButton);
				default:
			}
		}
	}

	static function consume(idBase:Int, code:Int):Void {
		var id = idBase + code;
		if (!consumedSources.exists(id)) {
			consumedSources.set(id, true);
			consumedCount++;
		}
	}

	static function release(idBase:Int, code:Int):Void {
		if (consumedCount > 0 && consumedSources.remove(idBase + code)) {
			consumedCount--;
		}
	}

	// A source let go without its Up event reaching us, such as on losing focus, is released here.
	function readDigital(idBase:Int, code:Int, isHeld:Bool):Float {
		if (!isHeld) {
			release(idBase, code);
			return 0.0;
		}
		if (consumedCount > 0 && !ignoresHandled && consumedSources.exists(idBase + code)) {
			return 0.0;
		}
		return 1.0;
	}

	function evaluate():Void {
		var bestX = 0.0;
		var bestY = 0.0;
		var bestStrength = 0.0;
		for (binding in bindings) {
			readBinding(binding);
			var strength = type == Vector2 ? readX * readX + readY * readY : Math.abs(readX);
			if (strength > bestStrength) {
				bestStrength = strength;
				bestX = readX;
				bestY = readY;
			}
		}

		switch (type) {
			case Button | Value:
				x = bestX;
				y = 0.0;
				value = bestX;
			case Vector2:
				limitLength(bestX, bestY);
				x = readX;
				y = readY;
				value = Math.sqrt(x * x + y * y);
		}

		var wasPressed = isPressed;
		isPressed = Math.abs(value) >= pressThreshold;
		isDown = isPressed && !wasPressed;
		isReleased = !isPressed && wasPressed;
	}

	function readBinding(binding:InputBinding):Void {
		readY = 0.0;
		switch (binding) {
			case Single(source):
				readX = readSource(source);
			case Axis(negative, positive):
				readX = readSource(positive) - readSource(negative);
			case Vector(up, down, left, right):
				limitLength(readSource(right) - readSource(left), readSource(down) - readSource(up));
			case Stick(xAxis, yAxis):
				limitLength(Input.getGamepadAxis(xAxis), Input.getGamepadAxis(yAxis));
		}
	}

	static function limitLength(vx:Float, vy:Float):Void {
		var lengthSquared = vx * vx + vy * vy;
		if (lengthSquared > 1.0) {
			var length = Math.sqrt(lengthSquared);
			vx /= length;
			vy /= length;
		}
		readX = vx;
		readY = vy;
	}

	function readSource(source:InputSource):Float {
		return switch (source) {
			case Keyboard(key): readDigital(KEY_ID_BASE, key, Input.isKeyPressed(key));
			case Mouse(button): readDigital(MOUSE_ID_BASE, button, Input.isButtonPressed(button));
			case MouseScrollX: Input.scrollX;
			case MouseScrollY: Input.scrollY;
			case PadButton(button): readDigital(PAD_ID_BASE, button, Input.isGamepadButtonPressed(button));
			case PadAxis(axis): Input.getGamepadAxis(axis);
			case Touch(device): readDigital(TOUCH_ID_BASE, device, Input.isTouchPressed(device));
		}
	}
}
