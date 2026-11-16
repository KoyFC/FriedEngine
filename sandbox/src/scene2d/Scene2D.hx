package scene2d;

import debug.DebugOverlay;
import nodes.Box;
import nodes.CameraZoom;
import nodes.KeyShortcuts;
import nodes.Player;
import fried.Log;
import fried.graphics.Font;
import fried.graphics.Rect;
import fried.graphics.Renderer;
import fried.graphics.Texture;
import fried.input.InputAction;
import fried.input.Key;
import fried.io.Assets;
import fried.physics.Collider;
import fried.scene.Camera;
import fried.scene.Control;
import fried.scene.Label;
import fried.scene.Node2D;
import fried.scene.SceneContext;
import fried.scene.TextureRect;
import fried.scene.serialization.SceneLoader;

class Scene2D {
	static inline var WORLD_VIEW_HEIGHT = 480;

	var renderer:Renderer;
	var font:Font;
	var overlay:DebugOverlay;
	var zoom:InputAction;
	var runs:Int;

	public function new(renderer:Renderer, font:Font, overlay:DebugOverlay, zoom:InputAction, runs:Int) {
		this.renderer = renderer;
		this.font = font;
		this.overlay = overlay;
		this.zoom = zoom;
		this.runs = runs;
	}

	public function load(context:SceneContext):Void {
		var sprite = Texture.from(renderer, Assets.game("sprite.png"));
		var hints = [
			'Run $runs',
			"Space/Enter/A/click: sound",
			"M/F6/B: music",
			"WASD/arrows/stick/d-pad: move",
			"Q/E/L/R: zoom",
			"Shift+arrows: move window",
			"F2/North: next scene",
			"F3/Select: overlay",
			"F4: interface",
			"F5: collider bounds",
			"F7: gameplay actions",
			"Esc/Start: quit"
		];

		var iconSize = 64;
		var scrollRegion = new Rect(0, 0, Std.int(sprite.width / 2), Std.int(sprite.height / 2));

		var scene = context.addScene(SceneLoader.load("scenes/sandbox.scene.json", renderer));
		var wallNode = scene.getById("wall", Node2D);
		var player = scene.getById("player", Player);
		var playerCollider = scene.getById("player-hitbox", Collider);

		var colliders = [];
		for (index in 0...5) {
			colliders.push(scene.getById('post-$index-hitbox', Collider));
		}
		colliders.push(playerCollider);

		var camera = scene.getById("camera", Camera);
		camera.zoom = renderer.height / WORLD_VIEW_HEIGHT;
		camera.addChild(new CameraZoom(zoom));

		var uiScene = context.addScene(SceneLoader.load("scenes/sandbox_ui.scene.json", renderer));

		// The hints stop short of the icons down the right edge, so a narrow screen stacks more lines.
		var hintText = uiScene.getById("hints", Label);
		hintText.font = font;
		hintText.text = hints.join("   ");
		hintText.maxWidth = renderer.width - iconSize - 16 * 3;
		var panelWidth = hintText.textWidth + 8;
		var panelHeight = hintText.textHeight + 8;

		Log.info('The hints take ${hintText.textHeight / font.lineHeight} lines, ${hintText.textWidth}x${hintText.textHeight}, before a frame has drawn them');

		var panel = uiScene.getById("hint-panel", Box);
		panel.width = panelWidth;
		panel.height = panelHeight;

		var regionIcon = uiScene.getById("region-icon", TextureRect);
		uiScene.getById("region-label", Label).font = font;
		var spinningIcon = uiScene.getById("spinning-icon", TextureRect);

		var interfaceLayer = new InterfaceLayer(uiScene, panel, panelWidth, panelHeight);

		function toggleColliders():Void {
			for (collider in colliders) {
				collider.isDebugVisible = !collider.isDebugVisible;
			}
			Log.info('Collider bounds ${colliders[0].isDebugVisible ? "shown" : "hidden"} for ${colliders.length} colliders');
		}

		function toggleInterface():Void {
			if (interfaceLayer.renderer == null) {
				context.pushLayer(renderer, interfaceLayer);
				Log.info('Interface layer pushed back from inside the event walk, stack still reads ${renderer.layers.length} layers');
			} else {
				renderer.removeLayer(interfaceLayer);
				Log.info('Interface layer taken off from inside the event walk, stack still reads ${renderer.layers.length} layers');
			}
		}

		scene.add(new KeyShortcuts()).add(Key.F4, toggleInterface).add(Key.F5, toggleColliders);

		overlay.setSceneDetails(context, function() {
			var contact = player.blockedBy == null ? "none" : player.blockedBy;
			return [
				'camera ${Std.int(camera.x)}, ${Std.int(camera.y)}',
				'zoom ${Math.round(camera.zoom * 100) / 100}',
				'player priority ${player.priority}',
				'blocked by $contact'
			];
		});
		overlay.addSceneButton(context, () -> 'Interface ${interfaceLayer.renderer != null ? "on" : "off"}', toggleInterface);
		overlay.addSceneButton(context, () -> 'Colliders ${colliders[0].isDebugVisible ? "on" : "off"}', toggleColliders);

		context.pushLayer(renderer, new WorldLayer(scene, playerCollider));
		context.pushLayer(renderer, interfaceLayer);

		context.onUnload(function() {
			Log.info('Spinner reached ${spinningIcon.rotation} degrees by the time ${context.name} unloaded');
			Log.info('Region icon ended with its region at x ${regionIcon.source.x}');
		});

		Log.success('Scene "${scene.name}" holds ${scene.nodeCount} world nodes, "${uiScene.name}" holds ${uiScene.nodeCount} screen-space ones');
		var spriteScale = player.scaleX;
		Log.info('The player starts at world ${player.x}, ${player.y} and the wall sits at world y ${wallNode.y}');
		Log.info('The player collider measures ${playerCollider.right - playerCollider.left}x${playerCollider.bottom - playerCollider.top} once the scale of $spriteScale is applied to a ${sprite.width}x${sprite.height} sprite');
		Log.info('The wall carries no collider, so it stays the draw order demo and the ${colliders.length - 1} posts are what the player cannot walk through');
	}
}
