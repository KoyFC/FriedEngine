import fried.Application;
import fried.Log;
import fried.Window;
import fried.audio.Music;
import fried.audio.Sound;
import fried.graphics.Font;
import fried.graphics.Renderer;
import fried.graphics.Texture;
import fried.input.Input;
import fried.input.Key;
import fried.input.MouseButton;
import fried.io.Assets;
import fried.io.Filesystem;

class Main {
	public static function main():Void {
		Application.init();
		Log.success("Fried Engine sandbox initialized. Base path: " + Filesystem.basePath);

		if (Filesystem.exists("README.md")) {
			var bytes = Filesystem.readBytes("README.md");
			Log.info('Read README.md: ${bytes.length} bytes');
		} else {
			Log.warn("README.md not found relative to the working directory");
		}

		Log.info("Asset path: " + Filesystem.assetPath);
		checkAsset(Assets.engine("font.ttf"));
		checkAsset(Assets.game("sprite.png"));
		checkAsset(Assets.game("beep.wav"));
		checkAsset(Assets.game("music.wav"));

		var window = new Window("Fried Engine sandbox", 640, 480);
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

		var font = new Font(Assets.engine("font.ttf"), 16);
		Log.success('Font loaded: line height ${font.lineHeight}');

		var hint = "Space: sound   M: music";
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

		Application.run(function() {
			if (Input.isButtonDown(MouseButton.Left)) {
				Log.info('Left click at ${Input.mouseX}, ${Input.mouseY}');
			}

			if (Input.isKeyDown(Key.Space)) {
				beep.play();
				Log.info("Sound played");
			}

			if (Input.isKeyDown(Key.M)) {
				if (music.paused) {
					music.resume();
					Log.info("Music resumed");
				} else {
					music.pause();
					Log.info("Music paused");
				}
			}

			renderer.drawTexture(sprite, Std.int((renderer.width - spriteWidth) / 2), Std.int((renderer.height - spriteHeight) / 2), spriteWidth,
				spriteHeight);
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

	static function checkAsset(path:String):Void {
		if (Filesystem.exists(path)) {
			Log.success('Found asset: $path');
		} else {
			Log.error('Missing asset: $path');
		}
	}
}
