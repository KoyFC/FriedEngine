import fried.Application;
import fried.Log;
import fried.Window;
import fried.graphics.Renderer;
import fried.graphics.Texture;
import fried.input.Input;
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

		var sprite = new Texture(renderer, Assets.game("sprite.png"));
		Log.success('Texture loaded: ${sprite.width}x${sprite.height}');

		var spriteScale = 8;
		var spriteWidth = sprite.width * spriteScale;
		var spriteHeight = sprite.height * spriteScale;

		Application.run(function() {
			if (Input.isButtonDown(MouseButton.Left)) {
				Log.info('Left click at ${Input.mouseX}, ${Input.mouseY}');
			}

			renderer.drawTexture(sprite, Std.int((renderer.width - spriteWidth) / 2), Std.int((renderer.height - spriteHeight) / 2), spriteWidth,
				spriteHeight);
		});

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
