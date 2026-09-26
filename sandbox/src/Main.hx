import fried.Application;
import fried.Log;
import fried.Project;
import fried.Time;
import fried.Window;
import fried.audio.Music;
import fried.audio.Sound;
import fried.graphics.Font;
import fried.graphics.Renderer;
import fried.graphics.Texture;
import fried.input.GamepadAxis;
import fried.input.GamepadButton;
import fried.input.Input;
import fried.input.Key;
import fried.input.MouseButton;
import fried.io.Assets;
import fried.io.Filesystem;
import fried.io.UserData;

class Main {
	public static function main():Void {
		Application.init();
		Log.success('${Project.name()} ${Project.version()} initialized. Base path: ${Filesystem.basePath}');

		if (Filesystem.exists("README.md")) {
			var bytes = Filesystem.readBytes("README.md");
			Log.info('Read README.md: ${bytes.length} bytes');
		} else {
			Log.warn("README.md not found relative to the working directory");
		}

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

		window.onResize = function(width, height) {
			Log.info('Window resized: ${width}x${height}');
		};
		window.onClose = function() {
			Log.info("Window close requested");
			Application.quit();
		};
		window.onFocusChanged = function(focused) {
			Log.info(focused ? "Window focused" : "Window unfocused");
		};

		var renderer = Application.createRenderer(window);
		Log.success('Renderer created: ${renderer.width}x${renderer.height}, vsync ${renderer.vsync ? "on" : "off"}');
		renderer.setDrawColor(24, 24, 32);

		var sprite = Texture.load(renderer, Assets.game("sprite.png"));
		Log.success('Texture loaded: ${sprite.width}x${sprite.height}');

		var font = new Font(Assets.engine("NunitoSans.ttf"), 16);
		Log.success('Font loaded: line height ${font.lineHeight}');

		var hint = 'Run $runs   Space/South: sound   M/East: music   WASD/stick: move';
		var label = font.renderText(renderer, hint, 220, 220, 230);
		Log.info('Text rendered: ${label.width}x${label.height} for ${font.measureWidth(hint)} measured pixels');

		var beep = new Sound(Assets.game("beep.wav"));
		beep.volume = 0.6;
		Log.success('Sound loaded at volume ${beep.volume}');

		var music = new Music(Assets.game("music.wav"));
		Music.volume = 0.2;
		music.play();
		Log.success('Music playing at volume ${Music.volume}');

		var spriteScale = 8;
		var spriteWidth = sprite.width * spriteScale;
		var spriteHeight = sprite.height * spriteScale;
		var spriteX = 0.0;
		var spriteY = 0.0;
		var spriteSpeed = 240.0;

		Log.info(Input.gamepadConnected ? "Gamepad connected" : "No gamepad connected");

		Application.run(function() {
			if (Input.isButtonDown(MouseButton.Left)) {
				Log.info('Left click at ${Input.mouseX}, ${Input.mouseY}');
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

			var moveX = clamp(Input.getGamepadAxis(GamepadAxis.LeftX) + keyAxis(Key.A, Key.D));
			var moveY = clamp(Input.getGamepadAxis(GamepadAxis.LeftY) + keyAxis(Key.W, Key.S));
			spriteX += moveX * spriteSpeed * Time.deltaSeconds;
			spriteY += moveY * spriteSpeed * Time.deltaSeconds;

			renderer.drawTexture(sprite, Std.int((renderer.width - spriteWidth) / 2 + spriteX), Std.int((renderer.height - spriteHeight) / 2 + spriteY),
				spriteWidth, spriteHeight);
			renderer.drawTexture(label, 16, 16);
		});

		music.destroy();
		beep.destroy();
		label.destroy();
		font.destroy();
		sprite.destroy();
		Application.destroyRenderer();
		window.destroy();

		Application.shutdown();

		Log.success("Fried Engine sandbox run complete");
	}

	static function keyAxis(negative:Key, positive:Key):Float {
		var value = 0.0;
		if (Input.isKeyPressed(negative)) {
			value -= 1.0;
		}
		if (Input.isKeyPressed(positive)) {
			value += 1.0;
		}
		return value;
	}

	static function clamp(value:Float):Float {
		return Math.max(-1.0, Math.min(1.0, value));
	}

	static function checkAsset(path:String):Void {
		if (Filesystem.exists(path)) {
			Log.success('Found asset: $path');
		} else {
			Log.error('Missing asset: $path');
		}
	}
}
