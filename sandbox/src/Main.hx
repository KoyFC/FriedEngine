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
import fried.graphics.Renderer;
import fried.graphics.Texture;
import fried.input.GamepadButton;
import fried.input.Input;
import fried.input.InputActionMap;
import fried.input.InputBinding;
import fried.input.InputEventType;
import fried.input.InputSource;
import fried.input.Key;
import fried.input.MouseButton;
import fried.io.Assets;
import fried.io.Filesystem;
import fried.io.UserData;
import fried.scene.Scene;
import fried.scene.SceneManager;

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

		UserData.writeJson("saves/profile.json", {runs: runs, name: "sandbox"}, "\t");
		var profile = UserData.readJson("saves/profile.json");
		Log.info('Saved profile: ${profile.name}, ${profile.runs} runs');

		var window = new Window(Project.windowTitle(), 640, 480);
		Log.success('Window created: ${window.width}x${window.height} at ${window.x}, ${window.y}');

		window.setIcon(Assets.game("icon.png"));

		window.onResize = function(width, height) {
			Log.info('Window resized: ${width}x${height}');
		};
		window.onMove = function(x, y) {
			Log.info('Window moved: ${x}, ${y}');
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

		// Below the 3DS's 240 lines, a smaller size is what keeps the hints and the overlay on screen together.
		var font = Font.from(Assets.engine("NunitoSans.ttf"), renderer.height < 240 ? 10 : 16);
		Log.success('Font loaded: line height ${font.lineHeight}');

		var beep = Sound.from(Assets.game("beep.wav"));
		beep.volume = 0.6;
		Log.success('Sound loaded at volume ${beep.volume}');

		var music = new Music(Assets.game("music.wav"));
		Music.volume = 0.2;

		var windowSpeed = 400.0;
		var windowMoving = false;
		var windowX = 0.0;
		var windowY = 0.0;

		var secondWindow:Window = null;
		var secondRenderer:Renderer = null;
		if (Window.maxCount > 1) {
			secondWindow = new Window(Project.windowTitle(), 320, 240);
			secondRenderer = Application.createRenderer(secondWindow, vsyncEnabled);
			secondRenderer.drawColor = Color.rgb(32, 24, 24);
			Log.success('Second window created: ${secondRenderer.width}x${secondRenderer.height}, so the debug overlay moves to it');
		}

		var debugScene = new Scene("Sandbox debug");
		var overlay = new DebugOverlay(debugScene, font, renderer);

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

		function loadNextScene():Void {
			var names = SceneManager.names();
			var next = names[(names.indexOf(SceneManager.activeName) + 1) % names.length];
			Log.info('Loading scene $next');
			SceneManager.load(next);
		}

		overlay.addButton(() -> "Next scene", loadNextScene);
		overlay.addButton(() -> 'Music ${music.paused ? "off" : "on"}', toggleMusic);
		overlay.addButton(() -> "Sound", playSound);

		var gameplay = new InputActionMap("Gameplay");
		var zoom = gameplay.addAction("Zoom", Value);
		zoom.addBinding(Axis(Keyboard(Key.Q), Keyboard(Key.E)));
		zoom.addBinding(Axis(PadButton(GamepadButton.L1), PadButton(GamepadButton.R1)));
		var playSoundAction = gameplay.addAction("PlaySound", Button);
		// The overlay's Sound button handles the click it receives, so it sounds once, not twice.
		playSoundAction.addKey(Key.Space).addKey(Key.Enter).addGamepadButton(GamepadButton.South).addMouseButton(MouseButton.Left);
		playSoundAction.onPressed = playSound;
		var toggleMusicAction = gameplay.addAction("ToggleMusic", Button);
		toggleMusicAction.addKey(Key.M).addKey(Key.F6).addGamepadButton(GamepadButton.East);
		toggleMusicAction.onPressed = toggleMusic;

		gameplay.enable();

		var overlayRenderer = secondRenderer != null ? secondRenderer : renderer;
		overlayRenderer.pushLayer(overlay);

		SceneManager.register("2D", new Scene2D(renderer, font, overlay, zoom, runs).load);
		SceneManager.register("3D", new Scene3D(renderer, font, overlay).load);
		SceneManager.load("2D");

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

			if (Input.isKeyDown(Key.Escape) || Input.isGamepadButtonDown(GamepadButton.Start)) {
				Log.info("Escape or Start pressed, so the program quits without a window to close");
				Application.quit();
			}

			var shiftHeld = Input.isKeyPressed(Key.LShift) || Input.isKeyPressed(Key.RShift);
			var windowDirX = (Input.isKeyPressed(Key.Right) ? 1 : 0) - (Input.isKeyPressed(Key.Left) ? 1 : 0);
			var windowDirY = (Input.isKeyPressed(Key.Down) ? 1 : 0) - (Input.isKeyPressed(Key.Up) ? 1 : 0);
			if (shiftHeld && (windowDirX != 0 || windowDirY != 0)) {
				if (!windowMoving) {
					windowX = window.x;
					windowY = window.y;
					windowMoving = true;
				}
				windowX += windowDirX * windowSpeed * Time.deltaSeconds;
				windowY += windowDirY * windowSpeed * Time.deltaSeconds;
				window.setPosition(Math.round(windowX), Math.round(windowY));
			} else {
				windowMoving = false;
			}

			if (Input.isKeyDown(Key.F2) || Input.isGamepadButtonDown(GamepadButton.North)) {
				loadNextScene();
			}

			if (Input.isKeyDown(Key.F3) || Input.isGamepadButtonDown(GamepadButton.Select)) {
				overlay.isEnabled = !overlay.isEnabled;
				Log.info('Debug overlay ${overlay.isEnabled ? "enabled" : "disabled"}, still on the stack either way');
			}

			if (Input.isKeyDown(Key.F7)) {
				if (zoom.isEnabled) {
					gameplay.disable();
				} else {
					gameplay.enable();
				}
				Log.info('Gameplay actions ${zoom.isEnabled ? "enabled" : "disabled"}');
			}
		});

		Log.info('Draw queue pool ended at ${DrawQueue.capacity} commands');

		closeWindow();
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
