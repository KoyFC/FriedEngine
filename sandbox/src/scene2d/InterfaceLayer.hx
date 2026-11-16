package scene2d;

import fried.Log;
import fried.input.InputEvent;
import fried.input.InputEventType;
import fried.input.MouseButton;
import fried.scene.Node2D;
import fried.scene.Scene;
import fried.scene.SceneLayer;

class InterfaceLayer extends SceneLayer {
	var panel:Node2D;
	var panelWidth:Int;
	var panelHeight:Int;

	public function new(scene:Scene, panel:Node2D, panelWidth:Int, panelHeight:Int) {
		super(scene);
		this.panel = panel;
		this.panelWidth = panelWidth;
		this.panelHeight = panelHeight;
	}

	override function onEvent(event:InputEvent):Void {
		super.onEvent(event);
		if (event.handled) {
			return;
		}
		var isClick = event.type == InputEventType.MouseButtonDown && event.mouseButton == MouseButton.Left;
		var isFrontTouch = event.type == InputEventType.TouchDown && event.touchDevice == 0;
		if (!isClick && !isFrontTouch) {
			return;
		}
		if (!panelContains(event.x, event.y)) {
			return;
		}
		event.handled = true;
		Log.info('The interface took the press at ${event.x}, ${event.y}, so the world below never sees it');
	}

	function panelContains(x:Int, y:Int):Bool {
		return x >= panel.x && y >= panel.y && x < panel.x + panelWidth && y < panel.y + panelHeight;
	}
}
