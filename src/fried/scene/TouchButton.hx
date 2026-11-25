package fried.scene;

import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Font;
import fried.input.InputAction;
import fried.input.InputEvent;
import fried.input.InputMaps;
import fried.input.MouseButton;

// A round button on the screen that holds an input action while a finger is on it, so a game reads it as it reads a key bound to that action. The left mouse button stands in for a finger, which is how it is tried on a computer. Its circle fills the shorter side of its control.
@:serializable
class TouchButton extends Control {
	// The action it holds, by its name in the "input" block of project.fried, or empty for none.
	public var action:String;
	public var font(default, set):Font;
	public var label(default, set):String;

	// Pressed by a finger that slides onto it and let go when the finger slides off, as a row of buttons under one thumb wants.
	public var isPassBy:Bool;
	// Where it is drawn and pressed: platform keys such as "android web", with "auto" for wherever a finger touches the screen the game is drawn on. Empty is "auto", which leaves out the DS, the 3DS and the calculator. The editor draws it everywhere, to be placed.
	public var platforms:String;

	public var color:Color;
	public var pressedColor:Color;
	public var labelColor:Color;

	public var onPressed:Void->Void;
	public var onReleased:Void->Void;

	@:noSerialize public var isPressed(default, null):Bool;

	static inline var NO_FINGER:Int = -1;
	static inline var MOUSE_FINGER:Int = -2;
	// The Vita's rear pad is device 1, and is not under the button.
	static inline var FRONT_TOUCH_DEVICE:Int = 0;

	var heldFinger:Int;
	var labelWidth:Int;
	var isLabelMeasured:Bool;

	public function new(width:Float = 80.0, height:Float = 80.0, action:String = "") {
		super("TouchButton");
		this.width = width;
		this.height = height;
		this.action = action;
		label = "";
		isPassBy = false;
		platforms = "";
		color = Color.rgba(255, 255, 255, 70);
		pressedColor = Color.rgba(255, 255, 255, 150);
		labelColor = Color.rgb(255, 255, 255);
		isPressed = false;
		heldFinger = NO_FINGER;
	}

	override function onEvent(event:InputEvent):Void {
		if (!isShown()) {
			return;
		}
		switch (event.type) {
			case TouchDown if (heldFinger == NO_FINGER && event.touchDevice == FRONT_TOUCH_DEVICE && containsEvent(event)):
				press(event.fingerId);
				event.handled = true;
			case MouseButtonDown if (heldFinger == NO_FINGER && event.mouseButton == MouseButton.Left && containsEvent(event)):
				press(MOUSE_FINGER);
				event.handled = true;
			case TouchMoved if (isPassBy && event.touchDevice == FRONT_TOUCH_DEVICE):
				var isInside = containsEvent(event);
				if (heldFinger == NO_FINGER && isInside) {
					press(event.fingerId);
				} else if (heldFinger == event.fingerId && !isInside) {
					release();
				}
			case TouchUp if (heldFinger == event.fingerId):
				release();
				event.handled = true;
			case MouseButtonUp if (heldFinger == MOUSE_FINGER && event.mouseButton == MouseButton.Left):
				release();
				event.handled = true;
			case _:
		}
	}

	override function draw():Void {
		if (!isShown()) {
			return;
		}
		var radius = Math.min(Math.abs(rectWidth), Math.abs(rectHeight)) / 2;
		var centerX = worldX + rectWidth / 2;
		var centerY = worldY + rectHeight / 2;
		DrawQueue.submitFillCircle(priority, centerX, centerY, radius, isPressed ? pressedColor : color);

		if (font == null || label == null || label == "") {
			return;
		}
		var drawnWidth = Std.int(measuredLabelWidth() * worldScaleX);
		var drawnHeight = Std.int(font.lineHeight * worldScaleY);
		DrawQueue.submitText(priority, font, label, Std.int(centerX - drawnWidth / 2), Std.int(centerY - drawnHeight / 2), drawnWidth, drawnHeight, labelColor);
	}

	override function leaveScene():Void {
		if (heldFinger != NO_FINGER) {
			release();
		}
		super.leaveScene();
	}

	function isShown():Bool {
		return visible && PlatformList.shows(platforms);
	}

	function press(finger:Int):Void {
		heldFinger = finger;
		isPressed = true;
		var held = heldAction();
		if (held != null) {
			held.setVirtual(1.0);
		}
		if (onPressed != null) {
			onPressed();
		}
	}

	function release():Void {
		heldFinger = NO_FINGER;
		isPressed = false;
		var held = heldAction();
		if (held != null) {
			held.setVirtual(0.0);
		}
		if (onReleased != null) {
			onReleased();
		}
	}

	function heldAction():Null<InputAction> {
		return action == null || action == "" ? null : InputMaps.action(action);
	}

	function measuredLabelWidth():Int {
		if (!isLabelMeasured) {
			labelWidth = font.measureWidth(label);
			isLabelMeasured = true;
		}
		return labelWidth;
	}

	function set_font(value:Font):Font {
		if (value != font) {
			font = value;
			isLabelMeasured = false;
		}
		return font;
	}

	function set_label(value:String):String {
		if (value != label) {
			label = value;
			isLabelMeasured = false;
		}
		return label;
	}
}
