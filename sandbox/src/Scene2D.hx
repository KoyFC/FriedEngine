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
			"WASD/arrows/stick: move",
			"Q/E/L/R: zoom",
			"Shift+arrows: move window",
			"F2/North: next scene",
			"F3/Select: overlay",
			"F4: interface",
			"F5: collider bounds",
			"F7: gameplay actions",
			"Esc/Start: quit"
		];

		var spriteScale = 8.0;
		var playerSpeed = 240.0;
		var iconSize = 64;
		var wallWidth = 900;
		var wallHeight = 48;
		var scrollRegion = new Rect(0, 0, Std.int(sprite.width / 2), Std.int(sprite.height / 2));

		var scene = context.addScene(new Scene("Sandbox"));

		var wallObject = scene.add(new GameObject("Wall", -wallWidth / 2, 160));
		wallObject.addComponent(new Box(wallWidth, wallHeight, Color.rgb(70, 70, 90), Color.rgb(150, 150, 190)));

		var postWidth = 32;
		var postHeight = 96;
		var colliders = [];

		for (index in 0...5) {
			var postObject = scene.add(new GameObject('Post $index', -600 + index * 300, -220));
			postObject.priority = -2;
			postObject.addComponent(new Box(postWidth, postHeight, Color.rgb(58, 48, 44), Color.rgb(120, 100, 80)));
			colliders.push(postObject.addComponent(new Collider(postWidth, postHeight)));
		}

		var playerObject = scene.add(new GameObject("Player", -sprite.width * spriteScale / 2, -sprite.height * spriteScale / 2));
		playerObject.transform.setScale(spriteScale);
		playerObject.addComponent(new Sprite(sprite));
		var playerCollider = playerObject.addComponent(new Collider(sprite.width, sprite.height));
		colliders.push(playerCollider);
		var playerController = playerObject.addComponent(new PlayerController(playerSpeed, wallObject));

		var cameraObject = scene.add(new GameObject("Camera"));
		var camera = cameraObject.addComponent(new Camera(renderer.height / WORLD_VIEW_HEIGHT));
		cameraObject.addComponent(new CameraFollow(playerObject, sprite.width * spriteScale / 2, sprite.height * spriteScale / 2));
		cameraObject.addComponent(new CameraZoom(zoom));
		scene.camera = camera;

		var uiScene = context.addScene(new Scene("Sandbox UI"));

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

		var panelObject = uiScene.add(new GameObject("Hint panel", 12, 12));
		panelObject.addComponent(new Box(panelWidth, panelHeight, Color.rgb(40, 40, 55), Color.rgb(90, 200, 140)));

		var regionObject = uiScene.add(new GameObject("Region icon", renderer.width - iconSize - 16, 16 + iconSize + 16));
		regionObject.transform.scaleX = iconSize / scrollRegion.width;
		regionObject.transform.scaleY = iconSize / scrollRegion.height;
		var regionSprite = regionObject.addComponent(new Sprite(sprite, scrollRegion));
		regionObject.addComponent(new RegionScroller(8.0));

		var regionLabelText = 'region x ${scrollRegion.x}';
		var regionLabelX = renderer.width - font.measureWidth(regionLabelText) - 16;
		var regionLabelObject = uiScene.add(new GameObject("Region label", regionLabelX, 16 + iconSize + 16 + iconSize + 4));
		regionLabelObject.priority = 1;
		regionLabelObject.addComponent(new Text(font, regionLabelText, labelColor));
		regionLabelObject.addComponent(new RegionLabel(regionSprite));

		var spinnerObject = uiScene.add(new GameObject("Spinning icon", renderer.width - iconSize - 16, 16));
		spinnerObject.transform.scaleX = iconSize / sprite.width;
		spinnerObject.transform.scaleY = iconSize / sprite.height;
		spinnerObject.addComponent(new Sprite(sprite));
		spinnerObject.addComponent(new Spinner(90.0));

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
		Log.info('The player starts at world ${playerObject.transform.x}, ${playerObject.transform.y} and the wall sits at world y ${wallObject.transform.y}');
		Log.info('The player collider measures ${playerCollider.right - playerCollider.left}x${playerCollider.bottom - playerCollider.top} once the transform scale of $spriteScale is applied to a ${sprite.width}x${sprite.height} sprite');
		Log.info('The wall carries no collider, so it stays the draw order demo and the ${colliders.length - 1} posts are what the player cannot walk through');
	}
}
