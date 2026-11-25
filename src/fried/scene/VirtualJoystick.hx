package fried.scene;

import fried.Log;
import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.input.InputAction;
import fried.input.InputActionType;
import fried.input.InputEvent;
import fried.input.InputMaps;
import fried.input.MouseButton;

// A stick on the screen that sets a vector2 input action to where its tip is, from -1 to 1 on each axis with up negative, as a gamepad's stick reads. It rests at the middle of its control. The left mouse button stands in for a finger.
@:serializable
class VirtualJoystick extends Control {
	// The vector2 action it sets, by its name in the "input" block of project.fried.
	public var action:String;
	// The diameters of the base and of the tip, in pixels before the scale.
	public var baseSize:Float;
	public var tipSize:Float;
	// The share of the base's radius the tip moves before the action reads anything.
	public var deadzone:Float;
	// The base jumps to where a finger lands anywhere in the control, instead of waiting for a touch on the base.
	public var isDynamic:Bool;
	// Drawn only while a finger holds it, which suits a dynamic stick.
	public var isHiddenUntilTouched:Bool;
	// Where it is drawn and pressed: platform keys such as "android web", with "auto" for wherever a finger touches the screen the game is drawn on. Empty is "auto", which leaves out the DS, the 3DS and the calculator. The editor draws it everywhere, to be placed.
	public var platforms:String;

	public var baseColor:Color;
	public var tipColor:Color;

	@:noSerialize public var isPressed(default, null):Bool;
	@:noSerialize public var valueX(default, null):Float;
	@:noSerialize public var valueY(default, null):Float;

	static inline var NO_FINGER:Int = -1;
	static inline var MOUSE_FINGER:Int = -2;
	static inline var FRONT_TOUCH_DEVICE:Int = 0;

	var heldFinger:Int;
	var centerX:Float;
	var centerY:Float;
	var tipX:Float;
	var tipY:Float;
	var isTypeReported:Bool;

	public function new(width:Float = 200.0, height:Float = 200.0, action:String = "") {
		super("VirtualJoystick");
		this.width = width;
		this.height = height;
		this.action = action;
		baseSize = 160.0;
		tipSize = 70.0;
		deadzone = 0.1;
		isDynamic = false;
		isHiddenUntilTouched = false;
		platforms = "";
		baseColor = Color.rgba(255, 255, 255, 60);
		tipColor = Color.rgba(255, 255, 255, 140);
		isPressed = false;
		valueX = 0.0;
		valueY = 0.0;
		heldFinger = NO_FINGER;
		isTypeReported = false;
	}

	override function onEvent(event:InputEvent):Void {
		if (!isUsable()) {
			return;
		}
		switch (event.type) {
			case TouchDown if (heldFinger == NO_FINGER && event.touchDevice == FRONT_TOUCH_DEVICE && accepts(event)):
				grab(event.fingerId, event);
				event.handled = true;
			case MouseButtonDown if (heldFinger == NO_FINGER && event.mouseButton == MouseButton.Left && accepts(event)):
				grab(MOUSE_FINGER, event);
				event.handled = true;
			case TouchMoved if (heldFinger == event.fingerId):
				moveTip(eventX(event), eventY(event));
				event.handled = true;
			case MouseMoved if (heldFinger == MOUSE_FINGER):
				moveTip(eventX(event), eventY(event));
				event.handled = true;
			case TouchUp if (heldFinger == event.fingerId):
				letGo();
				event.handled = true;
			case MouseButtonUp if (heldFinger == MOUSE_FINGER && event.mouseButton == MouseButton.Left):
				letGo();
				event.handled = true;
			case _:
		}
	}

	override function draw():Void {
		if (!isUsable()) {
			return;
		}
		if (isHiddenUntilTouched && !isPressed && !PlatformList.isEditing) {
			return;
		}
		if (!isPressed) {
			rest();
		}
		DrawQueue.submitFillCircle(priority, centerX, centerY, baseRadius(), baseColor);
		DrawQueue.submitFillCircle(priority, tipX, tipY, tipSize * Math.abs(worldScaleX) / 2, tipColor);
	}

	override function leaveScene():Void {
		if (heldFinger != NO_FINGER) {
			letGo();
		}
		super.leaveScene();
	}

	function isUsable():Bool {
		return visible && PlatformList.shows(platforms);
	}

	// A fixed stick takes a touch on its base, a dynamic one anywhere in the control.
	function accepts(event:InputEvent):Bool {
		if (!containsEvent(event)) {
			return false;
		}
		if (isDynamic) {
			return true;
		}
		rest();
		var dx = eventX(event) - centerX;
		var dy = eventY(event) - centerY;
		var radius = baseRadius();
		return dx * dx + dy * dy <= radius * radius;
	}

	function grab(finger:Int, event:InputEvent):Void {
		heldFinger = finger;
		isPressed = true;
		if (isDynamic) {
			centerX = eventX(event);
			centerY = eventY(event);
		} else {
			rest();
		}
		moveTip(eventX(event), eventY(event));
	}

	function letGo():Void {
		heldFinger = NO_FINGER;
		isPressed = false;
		rest();
		valueX = 0.0;
		valueY = 0.0;
		var held = heldAction();
		if (held != null) {
			held.setVirtual(0.0, 0.0);
		}
	}

	function rest():Void {
		centerX = worldX + rectWidth / 2;
		centerY = worldY + rectHeight / 2;
		tipX = centerX;
		tipY = centerY;
	}

	function baseRadius():Float {
		return baseSize * Math.abs(worldScaleX) / 2;
	}

	function moveTip(x:Float, y:Float):Void {
		var radius = baseRadius();
		var dx = x - centerX;
		var dy = y - centerY;
		var length = Math.sqrt(dx * dx + dy * dy);
		if (length > radius && length > 0) {
			dx *= radius / length;
			dy *= radius / length;
			length = radius;
		}
		tipX = centerX + dx;
		tipY = centerY + dy;

		var dead = Math.max(0.0, deadzone) * radius;
		if (length <= dead || radius - dead <= 0) {
			valueX = 0.0;
			valueY = 0.0;
		} else {
			var scaled = (length - dead) / (radius - dead);
			valueX = dx / length * scaled;
			valueY = dy / length * scaled;
		}
		var held = heldAction();
		if (held != null) {
			held.setVirtual(valueX, valueY);
		}
	}

	function heldAction():Null<InputAction> {
		if (action == null || action == "") {
			return null;
		}
		var found = InputMaps.action(action);
		if (found != null && found.type != Vector2 && !isTypeReported) {
			isTypeReported = true;
			Log.warn('The VirtualJoystick $name sets "$action", which is not a vector2 action, so only its x is read.');
		}
		return found;
	}
}
