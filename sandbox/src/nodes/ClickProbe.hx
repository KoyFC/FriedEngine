package nodes;

import fried.Log;
import fried.input.InputEvent;
import fried.input.InputEventType;
import fried.input.MouseButton;
import fried.physics.Collider;
import fried.physics.Physics;
import fried.scene.Node;

// Reports what a click or a touch of the world lands on and what stands between it and the player, which is what the physics queries are for.
class ClickProbe extends Node {
	var player:Collider;

	public function new(player:Collider) {
		super("ClickProbe");
		this.player = player;
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
		var camera = scene.camera;
		var worldX = camera.screenToWorldX(event.x);
		var worldY = camera.screenToWorldY(event.y);
		Log.info('${isClick ? "Left click" : "Touch"} at screen ${event.x}, ${event.y}, world $worldX, $worldY');

		var clicked = Physics.overlapPoint(scene, worldX, worldY);
		Log.info(clicked == null ? "Nothing has a collider under that point" : 'That point is inside the collider of ${ownerName(clicked)}');

		var toClickX = worldX - player.centerX;
		var toClickY = worldY - player.centerY;
		var reach = Math.sqrt(toClickX * toClickX + toClickY * toClickY);
		var hit = Physics.raycast(scene, player.centerX, player.centerY, toClickX, toClickY, reach, player);
		if (hit == null) {
			Log.info('Nothing stands between the player and that point over $reach units');
			return;
		}
		Log.info('The line of sight stops on ${ownerName(hit.collider)} after ${hit.distance} of $reach units, at ${hit.x}, ${hit.y}, face normal ${hit.normalX}, ${hit.normalY}');
	}

	// A collider is named for the node it belongs to, which is its parent.
	function ownerName(collider:Collider):String {
		return collider.parent != null ? collider.parent.name : collider.name;
	}
}
