import fried.Log;
import fried.input.InputEvent;
import fried.input.InputEventType;
import fried.input.MouseButton;
import fried.physics.Collider;
import fried.physics.Physics;
import fried.scene.Scene;
import fried.scene.SceneLayer;

class WorldLayer extends SceneLayer {
	var player:Collider;

	public function new(scene:Scene, player:Collider) {
		super(scene);
		this.player = player;
	}

	override function onEvent(event:InputEvent):Void {
		var isClick = event.type == InputEventType.MouseButtonDown && event.mouseButton == MouseButton.Left;
		var isFrontTouch = event.type == InputEventType.TouchDown && event.touchDevice == 0;
		if (!isClick && !isFrontTouch) {
			return;
		}
		var camera = scene.camera;
		var worldX = camera.screenToWorldX(event.x, renderer);
		var worldY = camera.screenToWorldY(event.y, renderer);
		Log.info('${isClick ? "Left click" : "Touch"} at screen ${event.x}, ${event.y}, world $worldX, $worldY');

		var clicked = Physics.overlapPoint(scene, worldX, worldY);
		Log.info(clicked == null ? "Nothing has a collider under that point" : 'That point is inside the collider of ${clicked.gameObject.name}');

		var toClickX = worldX - player.centerX;
		var toClickY = worldY - player.centerY;
		var reach = Math.sqrt(toClickX * toClickX + toClickY * toClickY);
		var hit = Physics.raycast(scene, player.centerX, player.centerY, toClickX, toClickY, reach, player);
		if (hit == null) {
			Log.info('Nothing stands between the player and that point over $reach units');
			return;
		}
		Log.info('The line of sight stops on ${hit.collider.gameObject.name} after ${hit.distance} of $reach units, at ${hit.x}, ${hit.y}, face normal ${hit.normalX}, ${hit.normalY}');
	}
}
