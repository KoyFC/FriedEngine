package fried.input;

import fried.input.InputBinding;
import fried.input.InputSource;

// The strongest binding wins rather than their sum, so a stick and a key held
// together never go past 1.
class InputAction {
	static var enabledActions:Array<InputAction> = [];
	static var snapshot:Array<InputAction> = [];

	// Binding results, kept static so a frame allocates nothing.
	static var readX:Float = 0.0;
	static var readY:Float = 0.0;

	public var name(default, null):String;
	public var type(default, null):InputActionType;

	// The value from which the action counts as pressed.
	public var pressThreshold:Float;

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

	static function readBinding(binding:InputBinding):Void {
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

	static function readSource(source:InputSource):Float {
		return switch (source) {
			case Keyboard(key): Input.isKeyPressed(key) ? 1.0 : 0.0;
			case Mouse(button): Input.isButtonPressed(button) ? 1.0 : 0.0;
			case MouseScrollX: Input.scrollX;
			case MouseScrollY: Input.scrollY;
			case PadButton(button): Input.isGamepadButtonPressed(button) ? 1.0 : 0.0;
			case PadAxis(axis): Input.getGamepadAxis(axis);
			case Touch(device): Input.isTouchPressed(device) ? 1.0 : 0.0;
		}
	}
}
