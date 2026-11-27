package nodes;

import fried.Application;
import debug.DebugOverlay;
import fried.Bootstrap;
import fried.Log;
import fried.input.Key;
import fried.physics.Collider;
import fried.scene.Camera;
import fried.scene.Node;

// What the world scene needs from code on top of its file: the camera's zoom, the keys, the click probe and what the debug overlay shows while the scene is on screen.
@:serializable
class SandboxWorld extends Node {
	static inline var WORLD_VIEW_HEIGHT = 480;

	public var player:Player;
	public var camera:Camera;
	public var hud:SandboxInterface;

	var overlay:DebugOverlay;
	var colliders:Array<Collider>;

	override function ready():Void {
		var shell = SandboxShell.of();
		overlay = shell.overlay;

		camera.zoom = Bootstrap.renderer.height / WORLD_VIEW_HEIGHT;
		camera.addChild(new CameraZoom(shell.zoom));

		var playerCollider = player.getById("player-hitbox", Collider);
		colliders = [];
		for (index in 0...5) {
			colliders.push(scene.getById('post-$index-hitbox', Collider));
		}
		colliders.push(playerCollider);

		function toggleColliders():Void {
			for (collider in colliders) {
				collider.isDebugVisible = !collider.isDebugVisible;
			}
			Log.info('Collider bounds ${colliders[0].isDebugVisible ? "shown" : "hidden"} for ${colliders.length} colliders');
		}

		function toggleInterface():Void {
			hud.visible = !hud.visible;
			Log.info('Interface ${hud.visible ? "shown" : "hidden"}');
		}

		addChild(new KeyShortcuts()).add(Key.F4, toggleInterface).add(Key.F5, toggleColliders);
		addChild(new ClickProbe(playerCollider));

		overlay.setSceneDetails(this, function() {
			var contact = player.blockedBy == null ? "none" : player.blockedBy;
			return [
				'camera ${Std.int(camera.x)}, ${Std.int(camera.y)}',
				'zoom ${Math.round(camera.zoom * 100) / 100}',
				'player priority ${player.priority}',
				'blocked by $contact'
			];
		});
		overlay.addSceneButton(this, () -> 'Interface ${hud.visible ? "on" : "off"}', toggleInterface);
		overlay.addSceneButton(this, () -> 'Colliders ${colliders[0].isDebugVisible ? "on" : "off"}', toggleColliders);

		Log.success('Scene "${scene.name}" holds ${scene.nodeCount} nodes, the interface among them' + (Application.freeMemoryKb() >= 0 ? ', ${Application.freeMemoryKb()} KB of heap left' : ""));
		Log.info('The player starts at world ${player.x}, ${player.y}, and the ${colliders.length - 1} posts are what it cannot walk through');
	}

	override function destroyed():Void {
		if (overlay != null) {
			overlay.removeOwner(this);
		}
	}
}
