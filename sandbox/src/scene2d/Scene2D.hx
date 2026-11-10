package scene2d;

import components.Box;
import components.CameraZoom;
import components.KeyShortcuts;
import components.PlayerController;
import components.Spinner;
import debug.DebugOverlay;
import fried.Log;
import fried.graphics.Color;
import fried.graphics.Font;
import fried.graphics.Rect;
import fried.graphics.Renderer;
import fried.graphics.Texture;
import fried.input.InputAction;
import fried.input.Key;
import fried.io.Assets;
import fried.physics.Collider;
import fried.scene.Camera;
import fried.scene.GameObject;
import fried.scene.Scene;
import fried.scene.SceneContext;
import fried.scene.Sprite;
import fried.scene.Text;
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
		var labelColor = Color.rgb(220, 220, 230);
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
		var wallObject = scene.findById("wall");
		var playerObject = scene.findById("player");
		var playerCollider = playerObject.getComponent(Collider);
		var playerController = playerObject.getComponent(PlayerController);

		var colliders = [];
		for (index in 0...5) {
			colliders.push(scene.findById('post-$index').getComponent(Collider));
		}
		colliders.push(playerCollider);

		var cameraObject = scene.findById("camera");
		var camera = cameraObject.getComponent(Camera);
		camera.zoom = renderer.height / WORLD_VIEW_HEIGHT;
		cameraObject.addComponent(new CameraZoom(zoom));

		var uiScene = context.addScene(SceneLoader.load("scenes/sandbox_ui.scene.json", renderer));

		// The hints stop short of the icons down the right edge, so a narrow screen stacks more lines.
		var hintMaxWidth = renderer.width - iconSize - 16 * 3;
		var hintLines = LinePacker.pack(font, hints, hintMaxWidth);
		var hintTextWidth = 0;
		var hintTextHeight = 0;
		for (index in 0...hintLines.length) {
			var labelObject = uiScene.add(new GameObject('Hint label, line ${index + 1}', 16, 16 + hintTextHeight));
			labelObject.priority = 1;
			var label = labelObject.addComponent(new Text(font, hintLines[index], labelColor));
			hintTextWidth = label.width > hintTextWidth ? label.width : hintTextWidth;
			hintTextHeight += label.height;
		}

		Log.info('The hints take ${hintLines.length} lines, ${hintTextWidth}x${hintTextHeight}, before a frame has drawn them');

		var panelWidth = hintTextWidth + 8;
		var panelHeight = hintTextHeight + 8;

		var panelObject = uiScene.findById("hint-panel");
		var panelBox = panelObject.getComponent(Box);
		panelBox.width = panelWidth;
		panelBox.height = panelHeight;

		// What sits along the right edge is placed from the screen's width, which a scene file cannot know.
		var regionObject = uiScene.findById("region-icon");
		regionObject.transform.x = renderer.width - iconSize - 16;
		var regionSprite = regionObject.getComponent(Sprite);

		var regionLabelObject = uiScene.findById("region-label");
		var regionLabelText = regionLabelObject.getComponent(Text);
		regionLabelText.font = font;
		regionLabelObject.transform.x = renderer.width - font.measureWidth('region x ${scrollRegion.x}') - 16;

		var spinnerObject = uiScene.findById("spinning-icon");
		spinnerObject.transform.x = renderer.width - iconSize - 16;

		var interfaceLayer = new InterfaceLayer(uiScene, panelObject, panelWidth, panelHeight);

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

		var shortcutsObject = scene.add(new GameObject("Shortcuts"));
		shortcutsObject.addComponent(new KeyShortcuts()).add(Key.F4, toggleInterface).add(Key.F5, toggleColliders);

		overlay.setSceneDetails(context, function() {
			var contact = playerController.blockedBy == null ? "none" : playerController.blockedBy;
			return [
				'camera ${Std.int(camera.transform.x)}, ${Std.int(camera.transform.y)}',
				'zoom ${Math.round(camera.zoom * 100) / 100}',
				'player priority ${playerObject.priority}',
				'blocked by $contact'
			];
		});
		overlay.addSceneButton(context, () -> 'Interface ${interfaceLayer.renderer != null ? "on" : "off"}', toggleInterface);
		overlay.addSceneButton(context, () -> 'Colliders ${colliders[0].isDebugVisible ? "on" : "off"}', toggleColliders);

		context.pushLayer(renderer, new WorldLayer(scene, playerCollider));
		context.pushLayer(renderer, interfaceLayer);

		context.onUnload(function() {
			Log.info('Spinner reached ${spinnerObject.transform.rotation} degrees by the time ${context.name} unloaded');
			Log.info('Region icon ended with its region at x ${regionSprite.source.x}');
		});

		Log.success('Scene "${scene.name}" holds ${scene.objectCount} world objects, "${uiScene.name}" holds ${uiScene.objectCount} screen-space ones');
		var spriteScale = playerObject.transform.scaleX;
		Log.info('The player starts at world ${playerObject.transform.x}, ${playerObject.transform.y} and the wall sits at world y ${wallObject.transform.y}');
		Log.info('The player collider measures ${playerCollider.right - playerCollider.left}x${playerCollider.bottom - playerCollider.top} once the transform scale of $spriteScale is applied to a ${sprite.width}x${sprite.height} sprite');
		Log.info('The wall carries no collider, so it stays the draw order demo and the ${colliders.length - 1} posts are what the player cannot walk through');
	}
}
