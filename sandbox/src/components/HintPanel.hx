package components;

import fried.Log;
import fried.graphics.Color;
import fried.input.InputEvent;
import fried.input.InputEventType;
import fried.input.MouseButton;

// A box of the interface that takes the presses on it, so the world below never sees them.
@:serializable
class HintPanel extends Box {
	public function new(width:Int, height:Int, fillColor:Color, borderColor:Color) {
		super(width, height, fillColor, borderColor);
	}

	override function onEvent(event:InputEvent):Void {
		if (event.handled) {
			return;
		}
		var isClick = event.type == InputEventType.MouseButtonDown && event.mouseButton == MouseButton.Left;
		var isFrontTouch = event.type == InputEventType.TouchDown && event.touchDevice == 0;
		if (!isClick && !isFrontTouch) {
			return;
		}
		if (event.x < place.x || event.y < place.y || event.x >= place.x + width || event.y >= place.y + height) {
			return;
		}
		event.handled = true;
		Log.info('The interface took the press at ${event.x}, ${event.y}, so the world below never sees it');
	}
}
