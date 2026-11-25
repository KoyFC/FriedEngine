package fried.scene;

import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Font;
import fried.graphics.Rect;
import fried.input.InputEvent;
import fried.input.MouseButton;

// A rectangle with a label that calls onClick when it is pressed and released over it. Its size is its control's width and height.
@:serializable
class Button extends Control {
	public var font(default, set):Font;
	public var label(default, set):String;
	public var onClick:Void->Void;

	public var color:Color;
	public var pressedColor:Color;
	public var borderColor:Color;
	public var labelColor:Color;

	// Held, with the pointer still over the button.
	@:noSerialize public var isPressed(default, null):Bool;

	var isHeldByMouse:Bool;
	var isHeldByTouch:Bool;
	var heldFingerId:Int;

	var rect:Rect;
	var labelWidth:Int;
	var isLabelMeasured:Bool;

	// The Vita's rear pad is device 1, and reaches no further than the front screen does.
	static inline var FRONT_TOUCH_DEVICE:Int = 0;

	public function new(width:Float = 100.0, height:Float = 30.0, font:Font = null, label:String = "", ?onClick:Void->Void) {
		super("Button");
		this.width = width;
		this.height = height;
		this.font = font;
		this.label = label;
		this.onClick = onClick;
		color = Color.rgb(60, 60, 80);
		pressedColor = Color.rgb(100, 100, 135);
		borderColor = Color.rgb(150, 150, 190);
		labelColor = Color.rgb(230, 230, 240);
		isPressed = false;
		rect = new Rect(0, 0, 0, 0);
	}

	override function onEvent(event:InputEvent):Void {
		var isHeld = isHeldByMouse || isHeldByTouch;
		switch (event.type) {
			case MouseButtonDown if (!isHeld && event.mouseButton == MouseButton.Left && containsEvent(event)):
				isHeldByMouse = true;
				hold(event);
			case TouchDown if (!isHeld && event.touchDevice == FRONT_TOUCH_DEVICE && containsEvent(event)):
				isHeldByTouch = true;
				heldFingerId = event.fingerId;
				hold(event);
			case MouseMoved if (isHeldByMouse):
				isPressed = containsEvent(event);
				event.handled = true;
			case TouchMoved if (isHeldByTouch && event.fingerId == heldFingerId):
				isPressed = containsEvent(event);
				event.handled = true;
			case MouseButtonUp if (isHeldByMouse && event.mouseButton == MouseButton.Left):
				release(event);
			case TouchUp if (isHeldByTouch && event.fingerId == heldFingerId):
				release(event);
			case _:
		}
	}

	override function draw():Void {
		rect.x = Std.int(worldX);
		rect.y = Std.int(worldY);
		rect.width = Std.int(rectWidth);
		rect.height = Std.int(rectHeight);
		DrawQueue.submitFillRect(priority, rect, isPressed ? pressedColor : color);
		DrawQueue.submitRect(priority, rect, borderColor);

		if (font == null || label == null || label == "") {
			return;
		}
		var drawnLabelWidth = Std.int(measuredLabelWidth() * worldScaleX);
		var drawnLabelHeight = Std.int(font.lineHeight * worldScaleY);
		var labelX = rect.x + Std.int((rect.width - drawnLabelWidth) / 2);
		var labelY = rect.y + Std.int((rect.height - drawnLabelHeight) / 2);
		DrawQueue.submitText(priority, font, label, labelX, labelY, drawnLabelWidth, drawnLabelHeight, labelColor);
	}

	function hold(event:InputEvent):Void {
		isPressed = true;
		event.handled = true;
	}

	function release(event:InputEvent):Void {
		var isClick = containsEvent(event);
		isHeldByMouse = false;
		isHeldByTouch = false;
		isPressed = false;
		event.handled = true;
		if (isClick && onClick != null) {
			onClick();
		}
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
