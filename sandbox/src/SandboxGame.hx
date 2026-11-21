import debug.DebugOverlay;
import scene2d.Scene2D;
import scene3d.Scene3D;
import fried.Application;
import fried.Bootstrap;
import fried.Game;
import fried.Log;
import fried.Project;
import fried.Window;
import fried.audio.Music;
import fried.audio.Sound;
import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Font;
import fried.graphics.Renderer;
import fried.input.GamepadButton;
import fried.input.Input;
import fried.input.InputActionMap;
import fried.input.InputEventType;
import fried.input.Key;
import fried.input.MouseButton;
import fried.io.Assets;
import fried.io.Filesystem;
import fried.io.UserData;
import fried.scene.Scene;
import fried.scene.SceneContext;
import fried.scene.SceneManager;

// The sandbox's own code on top of what the editor describes: the scenes in assets/scenes are loaded by Bootstrap, and this adds to them what a scene file cannot hold, so the editor's Play runs the same game as a build.
class SandboxGame extends Game {
	var window:Window;
	var renderer:Renderer;
	var secondWindow:Window;
	var secondRenderer:Renderer;
	var font:Font;
	var beep:Sound;
	var music:Music;
	var overlay:DebugOverlay;
	var debugScene:Scene;
	var gameplay:InputActionMap;
	var zoom:fried.input.InputAction;
	var scene2d:Scene2D;
	var scene3d:Scene3D;
	var runs:Int;

	var windowSpeed = 400.0;
	var windowMoving = false;
	var windowX = 0.0;
	var windowY = 0.0;
	var was3D = false;
	var gameplayWasOn = false;

	override function start():Void {
		window = Bootstrap.window;
		renderer = Bootstrap.renderer;

		Log.success('${Project.name()} ${Project.version()} initialized. Base path: ${Filesystem.basePath}');
		Log.info("Asset path: " + Filesystem.assetPath);
		checkAsset(Assets.engine("NunitoSans.ttf"));
		checkAsset(Assets.game("sprite.png"));
		checkAsset(Assets.game("beep.wav"));
		checkAsset(Assets.game("music.wav"));

		var previousRuns = UserData.exists("saves/runs.txt") ? Std.parseInt(UserData.read("saves/runs.txt")) : null;
		runs = (previousRuns == null ? 0 : previousRuns) + 1;
		UserData.write("saves/runs.txt", Std.string(runs));
		Log.success('User data path: ${UserData.path} (run $runs)');

		UserData.writeJson("saves/profile.json", {runs: runs, name: "sandbox"}, "\t");
		var profile = UserData.readJson("saves/profile.json");
		Log.info('Saved profile: ${profile.name}, ${profile.runs} runs');

		Log.success('Window created: ${window.width}x${window.height} at ${window.x}, ${window.y}');
		window.onResize = function(width, height) {
			Log.info('Window resized: ${width}x${height}');
		};
		window.onMove = function(x, y) {
			Log.info('Window moved: ${x}, ${y}');
		};
		window.onFocusChanged = function(focused) {
			Log.info(focused ? "Window focused" : "Window unfocused");
		};
		Log.success('Renderer created: ${renderer.width}x${renderer.height}, vsync ${renderer.isVsyncEnabled ? "on" : "off"}');

		// The world keeps its view on every screen, so on a small one the text grows in logical pixels to stay 12 pixels tall on the output.
		font = Font.from(Assets.engine("NunitoSans.ttf"), renderer.legibleSize(16, 12));
		Log.success('Font loaded: line height ${font.lineHeight}');

		beep = Sound.from(Assets.game("beep.wav"));
		beep.volume = 0.6;
		Log.success('Sound loaded at volume ${beep.volume}');

		music = new Music(Assets.game("music.wav"));
		Music.volume = 0.2;

		// The editor shows one screen, so the overlay stays on it there.
		#if !fried_editor
		if (Window.maxCount > 1) {
			secondWindow = new Window(Project.windowTitle(), 320, 240);
			secondRenderer = Application.createRenderer(secondWindow, Project.vsync());
			secondRenderer.drawColor = Color.rgb(32, 24, 24);
			Log.success('Second window created: ${secondRenderer.width}x${secondRenderer.height}, so the debug overlay moves to it');
		}
		#end

		// Each screen has its own scale, so each gets a font sized for it: the overlay's screen may not be the game's.
		var overlayRenderer = secondRenderer != null ? secondRenderer : renderer;
		var overlayFont = overlayRenderer == renderer ? font : Font.from(Assets.engine("NunitoSans.ttf"), overlayRenderer.legibleSize(overlayRenderer.height < 240 ? 10 : 16, 10));

		debugScene = new Scene("Sandbox debug");
		overlay = new DebugOverlay(debugScene, overlayFont, renderer);

		overlay.addButton(() -> "Next scene", loadNextScene);
		overlay.addButton(() -> 'Music ${music.paused ? "off" : "on"}', toggleMusic);
		overlay.addButton(() -> "Sound", playSound);

		gameplay = new InputActionMap("Gameplay");
		zoom = gameplay.addAction("Zoom", Value);
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

		overlayRenderer.pushLayer(overlay);

		scene2d = new Scene2D(renderer, font, overlay, zoom, runs);
		scene3d = new Scene3D(renderer, font, overlay);

		Log.info(Input.isGamepadConnected ? "Gamepad connected" : "No gamepad connected");

		// Started last, so it does not play over a screen still being set up.
		music.play();
		Log.success('Music playing at volume ${Music.volume}');
	}

	// The sandbox's two screens are the world scene and the 3D one. The interface scene is loaded over the world by Scene2D, so it is not a screen of its own.
	override function sceneLoaded(context:SceneContext, scene:Scene):Void {
		switch (context.name) {
			case "sandbox":
				scene2d.wire(context, scene);
			case "sandbox_3d":
				scene3d.wire(context, scene);
			case _:
		}
	}

	override function update(delta:Float):Void {
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
			windowX += windowDirX * windowSpeed * delta;
			windowY += windowDirY * windowSpeed * delta;
			window.setPosition(Math.round(windowX), Math.round(windowY));
		} else {
			windowMoving = false;
		}

		// The face buttons turn the camera of the 3D scene, so R1 changes scene there, and the actions the buttons are bound to are left off while it is shown.
		var is3D = SceneManager.activeName == "sandbox_3d";
		if (is3D != was3D) {
			was3D = is3D;
			if (is3D) {
				gameplayWasOn = zoom.isEnabled;
				gameplay.disable();
			} else if (gameplayWasOn) {
				gameplay.enable();
			}
		}
		var nextButton = is3D ? GamepadButton.R1 : GamepadButton.North;
		if (Input.isKeyDown(Key.F2) || Input.isGamepadButtonDown(nextButton)) {
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
	}

	override function shutdown():Void {
		Log.info('Draw queue pool ended at ${DrawQueue.capacity} commands');
		if (secondRenderer != null) {
			Application.destroyRenderer(secondRenderer);
			secondRenderer = null;
			secondWindow.destroy();
		}
		debugScene.destroy();
		music.destroy();
		Log.success("Fried Engine sandbox run complete");
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

	function loadNextScene():Void {
		var screens = ["sandbox", "sandbox_3d"];
		var next = screens[(screens.indexOf(SceneManager.activeName) + 1) % screens.length];
		Log.info('Loading scene $next');
		SceneManager.load(next);
	}

	static function checkAsset(path:String):Void {
		if (Filesystem.exists(path)) {
			Log.success('Found asset: $path');
		} else {
			Log.error('Missing asset: $path');
		}
	}
}
