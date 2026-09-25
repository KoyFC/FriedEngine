import fried.Application;
import fried.Input;
import fried.Key;
import fried.Log;
import fried.MouseButton;
import fried.Window;

class Main {
	public static function main():Void {
		Application.init();

		var window = new Window("Fried Engine sandbox", 640, 480);
		Log.info('Window created: ${window.width}x${window.height}');

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

		Application.run(function() {
			// if (Time.frameCount % 30 == 0) {
			// 	Log.info('frame ${Time.frameCount}, elapsed=${Time.elapsedSeconds}s, delta=${Time.deltaSeconds}s');
			// }
			if (Input.isKeyDown(Key.Escape)) {
				Log.info("Escape pressed, quitting");
				Application.quit();
			}
			if (Input.isButtonDown(MouseButton.Left)) {
				Log.info('Left click at ${Input.mouseX}, ${Input.mouseY}');
			}
		});

		window.destroy();

		Application.shutdown();

		Log.info("Fried Engine sandbox run complete");
	}
}
