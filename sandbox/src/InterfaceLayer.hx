import fried.Log;
import fried.input.InputEvent;
import fried.input.InputEventType;
import fried.input.MouseButton;
import fried.scene.GameObject;
import fried.scene.Scene;
import fried.scene.SceneLayer;

class InterfaceLayer extends SceneLayer {
	var panel:GameObject;
	var panelWidth:Int;
	var panelHeight:Int;

	public function new(scene:Scene, panel:GameObject, panelWidth:Int, panelHeight:Int) {
		super(scene);
		this.panel = panel;
		this.panelWidth = panelWidth;
		this.panelHeight = panelHeight;
	}

	override function onEvent(event:InputEvent):Void {
		if (event.type != InputEventType.MouseButtonDown || event.mouseButton != MouseButton.Left) {
			return;
		}
		if (!panelContains(event.x, event.y)) {
			return;
		}
		event.handled = true;
		Log.info('The interface took the click at ${event.x}, ${event.y}, so the world below never sees it');
	}

	function panelContains(x:Int, y:Int):Bool {
		return x >= panel.transform.x && y >= panel.transform.y && x < panel.transform.x + panelWidth && y < panel.transform.y + panelHeight;
	}
}
