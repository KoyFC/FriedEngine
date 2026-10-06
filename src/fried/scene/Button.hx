package fried.scene;

import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Font;
import fried.graphics.Rect;
import fried.graphics.Renderer;
import fried.input.InputEvent;
import fried.input.MouseButton;

class Button extends Component {
	public var width:Int;
	public var height:Int;
	public var font(default, set):Font;
	public var label(default, set):String;
	public var onClick:Void->Void;

	public var color:Color;
	public var pressedColor:Color;
	public var borderColor:Color;
	public var labelColor:Color;

	// Held, with the pointer still over the button.
	public var isPressed(default, null):Bool;

	var isHeldByMouse:Bool;
	var isHeldByTouch:Bool;
	var heldFingerId:Int;

	var rect:Rect;
	var labelWidth:Int;
	var isLabelMeasured:Bool;

	// The Vita's rear pad is device 1, and reaches no further than the front screen does.
	static inline var FRONT_TOUCH_DEVICE:Int = 0;

	public function new(width:Int, height:Int, font:Font, label:String, ?onClick:Void->Void) {
		super();
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

	override function onEvent(event:InputEvent, renderer:Renderer):Void {
		var isHeld = isHeldByMouse || isHeldByTouch;
		switch (event.type) {
			case MouseButtonDown if (!isHeld && event.mouseButton == MouseButton.Left && contains(event, renderer)):
				isHeldByMouse = true;
				hold(event);
			case TouchDown if (!isHeld && event.touchDevice == FRONT_TOUCH_DEVICE && contains(event, renderer)):
				isHeldByTouch = true;
				heldFingerId = event.fingerId;
				hold(event);
			case MouseMoved if (isHeldByMouse):
				isPressed = contains(event, renderer);
				event.handled = true;
			case TouchMoved if (isHeldByTouch && event.fingerId == heldFingerId):
				isPressed = contains(event, renderer);
				event.handled = true;
			case MouseButtonUp if (isHeldByMouse && event.mouseButton == MouseButton.Left):
				release(event, renderer);
			case TouchUp if (isHeldByTouch && event.fingerId == heldFingerId):
				release(event, renderer);
			case _:
		}
	}

	override function draw():Void {
		rect.x = Std.int(transform.x);
		rect.y = Std.int(transform.y);
		rect.width = Std.int(width * transform.scaleX);
		rect.height = Std.int(height * transform.scaleY);
		DrawQueue.submitFillRect(gameObject.priority, rect, isPressed ? pressedColor : color);
		DrawQueue.submitRect(gameObject.priority, rect, borderColor);

		if (font == null || label == null || label == "") {
			return;
		}
		var drawnLabelWidth = Std.int(measuredLabelWidth() * transform.scaleX);
		var drawnLabelHeight = Std.int(font.lineHeight * transform.scaleY);
		var labelX = rect.x + Std.int((rect.width - drawnLabelWidth) / 2);
		var labelY = rect.y + Std.int((rect.height - drawnLabelHeight) / 2);
		DrawQueue.submitText(gameObject.priority, font, label, labelX, labelY, drawnLabelWidth, drawnLabelHeight, labelColor);
	}

	function hold(event:InputEvent):Void {
		isPressed = true;
		event.handled = true;
	}

	function release(event:InputEvent, renderer:Renderer):Void {
		var isClick = contains(event, renderer);
		isHeldByMouse = false;
		isHeldByTouch = false;
		isPressed = false;
		event.handled = true;
		if (isClick && onClick != null) {
			onClick();
		}
	}

	function contains(event:InputEvent, renderer:Renderer):Bool {
		var camera = gameObject.scene != null ? gameObject.scene.camera : null;
		var x = camera != null ? camera.screenToWorldX(event.x, renderer) : event.x;
		var y = camera != null ? camera.screenToWorldY(event.y, renderer) : event.y;
		var right = transform.x + width * transform.scaleX;
		var bottom = transform.y + height * transform.scaleY;
		return x >= Math.min(transform.x, right) && x < Math.max(transform.x, right) && y >= Math.min(transform.y, bottom) && y < Math.max(transform.y, bottom);
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
