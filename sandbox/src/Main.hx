import fried.Application;
import fried.Log;
import fried.Project;
import fried.Time;
import fried.Window;
import fried.audio.Music;
import fried.audio.Sound;
import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Font;
import fried.graphics.Rect;
import fried.graphics.Renderer;
import fried.graphics.Texture;
import fried.input.GamepadButton;
import fried.input.Input;
import fried.input.InputEventType;
import fried.input.Key;
import fried.io.Assets;
import fried.io.Filesystem;
import fried.io.UserData;
import fried.physics.Collider;
import fried.scene.Camera;
import fried.scene.GameObject;
import fried.scene.Scene;
import fried.scene.Sprite;
import fried.scene.Text;

class Main {
	public static function main():Void {
		Application.init();
		Log.success('${Project.name()} ${Project.version()} initialized. Base path: ${Filesystem.basePath}');

		Log.info("Asset path: " + Filesystem.assetPath);
		checkAsset(Assets.engine("NunitoSans.ttf"));
		checkAsset(Assets.game("sprite.png"));
		checkAsset(Assets.game("beep.wav"));
		checkAsset(Assets.game("music.wav"));

		var previousRuns = UserData.exists("saves/runs.txt") ? Std.parseInt(UserData.read("saves/runs.txt")) : null;
		var runs = (previousRuns == null ? 0 : previousRuns) + 1;
		UserData.write("saves/runs.txt", Std.string(runs));
		Log.success('User data path: ${UserData.path} (run $runs)');

		var designWidth = 640;
		var designHeight = 480;

		var window = new Window(Project.windowTitle(), designWidth, designHeight);
		Log.success('Window created: ${window.width}x${window.height}');

		window.setIcon(Assets.game("icon.png"));

		window.onResize = function(width, height) {
			Log.info('Window resized: ${width}x${height}');
		};
		window.onFocusChanged = function(focused) {
			Log.info(focused ? "Window focused" : "Window unfocused");
		};

		var vsyncEnabled = true;

		var renderer = Application.createRenderer(window, vsyncEnabled);
		Log.success('Renderer created: ${renderer.width}x${renderer.height}, vsync ${renderer.isVsyncEnabled ? "on" : "off"}');
		renderer.drawColor = Color.rgb(24, 24, 32);

		var sprite = Texture.from(renderer, Assets.game("sprite.png"));
		Log.info('Same path twice on one renderer: ${sprite == Texture.from(renderer, Assets.game("sprite.png"))}');
		Log.success('Texture loaded: ${sprite.width}x${sprite.height}');

		var font = Font.from(Assets.engine("NunitoSans.ttf"), 16);
		Log.success('Font loaded: line height ${font.lineHeight}');

		var hints = [
			'Run $runs', "Space/A: sound", "M/B: music", "WASD/stick: move", "Q/E/L/R: zoom",
			"F3/Select: overlay", "F4: interface", "F5: collider bounds", "Start: quit"
		];
		var labelColor = Color.rgb(220, 220, 230);

		var beep = Sound.from(Assets.game("beep.wav"));
		beep.volume = 0.6;
		Log.success('Sound loaded at volume ${beep.volume}');

		var music = new Music(Assets.game("music.wav"));
		Music.volume = 0.2;

		var spriteScale = 8.0;
		var playerSpeed = 240.0;
		var iconSize = 64;

		var wallWidth = 900;
		var wallHeight = 48;

		var scrollRegion = new Rect(0, 0, Std.int(sprite.width / 2), Std.int(sprite.height / 2));

		var scene = new Scene("Sandbox");

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
		playerObject.addComponent(new PlayerController(playerSpeed, wallObject));

		var cameraObject = scene.add(new GameObject("Camera"));
		var camera = cameraObject.addComponent(new Camera(renderer.height / designHeight));
		cameraObject.addComponent(new CameraFollow(playerObject, sprite.width * spriteScale / 2, sprite.height * spriteScale / 2));
		scene.camera = camera;

		var uiScene = new Scene("Sandbox UI");

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

		var secondWindow:Window = null;
		var secondRenderer:Renderer = null;
		if (Window.maxCount > 1) {
			secondWindow = new Window(Project.windowTitle(), 320, 240);
			secondRenderer = Application.createRenderer(secondWindow, vsyncEnabled);
			secondRenderer.drawColor = Color.rgb(32, 24, 24);
			Log.success('Second window created: ${secondRenderer.width}x${secondRenderer.height}, so the debug overlay moves to it');
		}

		var interfaceLayer = new InterfaceLayer(uiScene, panelObject, panelWidth, panelHeight);
		var debugScene = new Scene("Sandbox debug");
		var overlay = new DebugOverlay(debugScene, font, camera, playerObject, interfaceLayer, renderer);

		function toggleColliders():Void {
			for (collider in colliders) {
				collider.isDebugVisible = !collider.isDebugVisible;
			}
			Log.info('Collider bounds ${colliders[0].isDebugVisible ? "shown" : "hidden"} for ${colliders.length} colliders');
		}

		function toggleMusic():Void {
			if (music.paused) {
				music.resume();
				Log.info("Music resumed");
			} else {
				music.pause();
				Log.info("Music paused");
			}
		}

		function playSound():Void {
			beep.play();
			Log.info("Sound played");
		}

		overlay.addButton(() -> 'Colliders ${colliders[0].isDebugVisible ? "on" : "off"}', toggleColliders);
		overlay.addButton(() -> 'Music ${music.paused ? "off" : "on"}', toggleMusic);
		overlay.addButton(() -> "Sound", playSound);

		renderer.pushLayer(new WorldLayer(scene, playerCollider));
		var overlayRenderer = secondRenderer != null ? secondRenderer : renderer;
		overlayRenderer.pushLayer(overlay);
		renderer.pushLayer(interfaceLayer);

		function closeWindow():Void {
			if (renderer == null) {
				return;
			}
			if (secondRenderer != null) {
				Application.destroyRenderer(secondRenderer);
				secondRenderer = null;
				secondWindow.destroy();
			}
			Application.destroyRenderer(renderer);
			renderer = null;
			window.destroy();
			Log.info("Window closed");
			Application.quit();
		}

		window.onClose = closeWindow;

		Log.success('Scene "${scene.name}" holds ${scene.objectCount} world objects, "${uiScene.name}" holds ${uiScene.objectCount} screen-space ones');
		Log.info('Region icon scrolls a ${scrollRegion.width}x${scrollRegion.height} region across a ${sprite.width}x${sprite.height} texture');
		Log.info('The player starts at world ${playerObject.transform.x}, ${playerObject.transform.y} and the wall sits at world y ${wallObject.transform.y}');
		Log.info('The player collider measures ${playerCollider.right - playerCollider.left}x${playerCollider.bottom - playerCollider.top} once the transform scale of $spriteScale is applied to a ${sprite.width}x${sprite.height} sprite');
		Log.info('The wall carries no collider, so it stays the draw order demo and the ${colliders.length - 1} posts are what the player cannot walk through');

		Log.info(Input.isGamepadConnected ? "Gamepad connected" : "No gamepad connected");

		// Started last, so it does not play over a screen still being set up.
		music.play();
		Log.success('Music playing at volume ${Music.volume}');

		Application.run(function() {
			for (event in Input.events) {
				if (event.type == InputEventType.TouchDown || event.type == InputEventType.TouchUp) {
					var action = event.type == InputEventType.TouchDown ? "down" : "up";
					Log.info('Finger ${event.fingerId} $action on touch device ${event.touchDevice} at ${event.x}, ${event.y}');
				}
			}

			if (Input.isGamepadButtonDown(GamepadButton.Start)) {
				Log.info("Start pressed, so the program quits without a window to close");
				Application.quit();
			}

			if (Input.isKeyDown(Key.F5)) {
				toggleColliders();
			}

			if (Input.isKeyDown(Key.F3) || Input.isGamepadButtonDown(GamepadButton.Select)) {
				overlay.isEnabled = !overlay.isEnabled;
				Log.info('Debug overlay ${overlay.isEnabled ? "enabled" : "disabled"}, still on the stack either way');
			}

			if (Input.isKeyPressed(Key.Q) || Input.isGamepadButtonPressed(GamepadButton.L1)) {
				camera.zoom -= Time.deltaSeconds;
			}
			if (Input.isKeyPressed(Key.E) || Input.isGamepadButtonPressed(GamepadButton.R1)) {
				camera.zoom += Time.deltaSeconds;
			}

			if (Input.isGamepadButtonDown(GamepadButton.South)) {
				Log.info("Gamepad South pressed");
			}

			if (Input.isKeyDown(Key.Space) || Input.isGamepadButtonDown(GamepadButton.South)) {
				playSound();
			}

			if (Input.isKeyDown(Key.M) || Input.isGamepadButtonDown(GamepadButton.East)) {
				toggleMusic();
			}
		});

		Log.info('Spinner reached ${spinnerObject.transform.rotation} degrees over ${Time.elapsedSeconds} seconds');
		Log.info('Region icon ended with its region at x ${regionSprite.source.x}');
		Log.info('Draw queue pool ended at ${DrawQueue.capacity} commands for ${scene.objectCount + uiScene.objectCount} objects');

		closeWindow();
		scene.destroy();
		uiScene.destroy();
		debugScene.destroy();
		music.destroy();

		Application.shutdown();

		Log.success("Fried Engine sandbox run complete");
	}

	static function checkAsset(path:String):Void {
		if (Filesystem.exists(path)) {
			Log.success('Found asset: $path');
		} else {
			Log.error('Missing asset: $path');
		}
	}
}
