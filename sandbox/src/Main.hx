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
import fried.input.Key;
import fried.io.Assets;
import fried.io.Filesystem;
import fried.io.UserData;
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

		var window = new Window(Project.windowTitle(), 640, 480);
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

		var hintTop = 'Run $runs   Space/A: sound   M/B: music   WASD/stick: move   Q/E: zoom';
		var hintBottom = 'F3/Select: overlay   F4: interface   Start: quit';
		var labelColor = Color.rgb(220, 220, 230);

		var beep = Sound.from(Assets.game("beep.wav"));
		beep.volume = 0.6;
		Log.success('Sound loaded at volume ${beep.volume}');

		var music = new Music(Assets.game("music.wav"));
		Music.volume = 0.2;
		music.play();
		Log.success('Music playing at volume ${Music.volume}');

		var spriteScale = 8.0;
		var playerSpeed = 240.0;
		var iconSize = 64;

		var wallWidth = 900;
		var wallHeight = 48;

		var scrollRegion = new Rect(0, 0, Std.int(sprite.width / 2), Std.int(sprite.height / 2));

		var scene = new Scene("Sandbox");

		var wallObject = scene.add(new GameObject("Wall", -wallWidth / 2, 160));
		wallObject.addComponent(new Box(wallWidth, wallHeight, Color.rgb(70, 70, 90), Color.rgb(150, 150, 190)));

		for (index in 0...5) {
			var postObject = scene.add(new GameObject('Post $index', -600 + index * 300, -220));
			postObject.priority = -2;
			postObject.addComponent(new Box(32, 96, Color.rgb(58, 48, 44), Color.rgb(120, 100, 80)));
		}

		var playerObject = scene.add(new GameObject("Player", -sprite.width * spriteScale / 2, -sprite.height * spriteScale / 2));
		playerObject.transform.setScale(spriteScale);
		playerObject.addComponent(new Sprite(sprite));
		playerObject.addComponent(new PlayerController(playerSpeed, wallObject));

		var cameraObject = scene.add(new GameObject("Camera"));
		var camera = cameraObject.addComponent(new Camera());
		cameraObject.addComponent(new CameraFollow(playerObject, sprite.width * spriteScale / 2, sprite.height * spriteScale / 2));
		scene.camera = camera;

		var uiScene = new Scene("Sandbox UI");

		var topLabelObject = uiScene.add(new GameObject("Hint label, top line", 16, 16));
		topLabelObject.priority = 1;
		var topLabel = topLabelObject.addComponent(new Text(font, hintTop, labelColor));

		var bottomLabelObject = uiScene.add(new GameObject("Hint label, bottom line", 16, 16 + topLabel.height));
		bottomLabelObject.priority = 1;
		var bottomLabel = bottomLabelObject.addComponent(new Text(font, hintBottom, labelColor));

		Log.info('The top hint measures ${topLabel.width}x${topLabel.height} before a frame has drawn it');

		var panelWidth = (topLabel.width > bottomLabel.width ? topLabel.width : bottomLabel.width) + 8;
		var panelHeight = topLabel.height + bottomLabel.height + 8;

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
		var overlay = new DebugOverlay(font, camera, playerObject, interfaceLayer);

		renderer.pushLayer(new WorldLayer(scene));
		renderer.pushLayer(overlay);
		renderer.pushLayer(interfaceLayer);

		function closeWindow():Void {
			if (renderer == null) {
				return;
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

		Log.info(Input.isGamepadConnected ? "Gamepad connected" : "No gamepad connected");

		Application.run(function() {
			if (Input.isGamepadButtonDown(GamepadButton.Start)) {
				Log.info("Start pressed, so the program quits without a window to close");
				Application.quit();
			}

			if (Input.isKeyDown(Key.F3) || Input.isGamepadButtonDown(GamepadButton.Select)) {
				overlay.isEnabled = !overlay.isEnabled;
				Log.info('Debug overlay ${overlay.isEnabled ? "enabled" : "disabled"}, still on the stack either way');
			}

			if (Input.isKeyPressed(Key.Q)) {
				camera.zoom -= Time.deltaSeconds;
			}
			if (Input.isKeyPressed(Key.E)) {
				camera.zoom += Time.deltaSeconds;
			}

			if (Input.isGamepadButtonDown(GamepadButton.South)) {
				Log.info("Gamepad South pressed");
			}

			if (Input.isKeyDown(Key.Space) || Input.isGamepadButtonDown(GamepadButton.South)) {
				beep.play();
				Log.info("Sound played");
			}

			if (Input.isKeyDown(Key.M) || Input.isGamepadButtonDown(GamepadButton.East)) {
				if (music.paused) {
					music.resume();
					Log.info("Music resumed");
				} else {
					music.pause();
					Log.info("Music paused");
				}
			}
		});

		Log.info('Spinner reached ${spinnerObject.transform.rotation} degrees over ${Time.elapsedSeconds} seconds');
		Log.info('Region icon ended with its region at x ${regionSprite.source.x}');
		Log.info('Draw queue pool ended at ${DrawQueue.capacity} commands for ${scene.objectCount + uiScene.objectCount} objects');

		closeWindow();
		overlay.destroy();
		scene.destroy();
		uiScene.destroy();
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
