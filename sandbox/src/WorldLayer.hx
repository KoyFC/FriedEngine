import fried.Log;
import fried.input.InputEvent;
import fried.input.InputEventType;
import fried.input.MouseButton;
import fried.scene.Scene;
import fried.scene.SceneLayer;

class WorldLayer extends SceneLayer {
	public function new(scene:Scene) {
		super(scene);
	}

	override function onEvent(event:InputEvent):Void {
		if (event.type != InputEventType.MouseButtonDown || event.mouseButton != MouseButton.Left) {
			return;
		}
		var camera = scene.camera;
		var worldX = camera.screenToWorldX(event.x, renderer);
		var worldY = camera.screenToWorldY(event.y, renderer);
		Log.info('Left click at screen ${event.x}, ${event.y}, world $worldX, $worldY');
	}
}
